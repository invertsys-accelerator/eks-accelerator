# Karpenter Prerequisites and AWS Resources
module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name


  enable_v1_permissions           = true
  enable_pod_identity             = true
  create_pod_identity_association = true
  create_instance_profile         = true

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  depends_on = [module.eks]
}

resource "time_sleep" "wait_for_addons" {
  depends_on      = [module.eks_blueprints_addons]
  create_duration = "60s"
}

# Karpenter Helm Chart deployment
resource "helm_release" "karpenter" {
  namespace           = "kube-system"
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart               = "karpenter"
  version             = "1.4.0"
  wait                = true
  timeout             = 900

  values = [
    <<-EOT
    serviceAccount:
      name: ${module.karpenter.service_account}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    controller:
      resources:
        requests:
          cpu: 1
          memory: 1Gi
        limits:
          cpu: 1
          memory: 1Gi
    aws:
      defaultInstanceProfile: ${module.karpenter.instance_profile_name}
    EOT
  ]
  depends_on = [
    module.eks,
    module.karpenter,
    time_sleep.wait_for_addons
  ]
   lifecycle {
    ignore_changes = [
      repository_password
    ]
  }
}

# Add explicit wait time for kubectl provider to be properly initialized
resource "time_sleep" "wait_for_kubectl" {
  depends_on      = [helm_release.karpenter]
  create_duration = "30s"
}

# Karpenter NodePool
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1
    kind: NodePool
    metadata:
      name: app-general
    spec:
      template:
        metadata:
            labels:
              workload: app-general
        spec:
          nodeClassRef:
            group: karpenter.k8s.aws
            kind: EC2NodeClass
            name: default
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["4", "8", "16", "32"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
            - key: "kubernetes.io/os"
              operator: In
              values: ["linux"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["2"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["on-demand"]
            - key: "topology.kubernetes.io/zone"
              operator: In
              values: ${jsonencode(local.private_subnet_azs)}
      limits:
        cpu: 100
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
        budgets:
          - nodes: "100%"
            reasons:
              - Empty
          - nodes: "100%"
            schedule: "0 12 * * 6"  # Every Saturday at 12 PM
            duration: "6h"
            reasons:
              - Drifted
              - Underutilized
        expireAfter: 384h  # 16 days
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class,
    time_sleep.wait_for_kubectl
  ]
}

# Karpenter EC2NodeClass
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiSelectorTerms:
        - alias: al2023@latest
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 100Gi
            volumeType: gp3
            encrypted: true
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 1
        httpTokens: required
      driftControl:
        enabled: true
        configuration:
          - type: AMI
            properties:
              updateStrategy: Rolling
              maxUnavailable: "25%"
  YAML

  depends_on = [
    helm_release.karpenter,
    time_sleep.wait_for_kubectl
  ]
}
