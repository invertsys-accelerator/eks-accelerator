# account config
aws_region="us-east-1"
environment="dev"
account_name="generic" 

# Network Config
vpc_name = "use1-dev-vpc-01" # change your vpc name  and name subnets as follwing
#$var.vpc_name}-Compute* private eks nodes will be hosted
#${var.vpc_name}-FrontEnd* # public load balabcers open to internet
#${var.vpc_name}-Data*" # private data for databases
cluster_name = "generic-eks-ss"

# Eks Config
kubernetes_version = "1.32"
domain = "aws.test.com" # change to your route53 domain
#application config
system_name="example"
tags={}
default_tags={
   Environment               = "development"
}
log_groups = {
   "app-logs" = {
      name = "/example/dev/application"
   }
}