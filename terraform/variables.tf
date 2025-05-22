variable "aws_region" {
  description = "Region"
  type        = string
}

variable "environment" {
  description = "Environment"
  type        = string
}

variable "account_name" {
  description = "Account Name"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}


variable "default_tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "log_groups" {
  description = "Cloud watch Log groups "
  type = map(object({
    name = string
  }))

}
variable "vpc_name" {
  type = string
}

variable "system_name" {
  type = string
}

//create a varible that acess number 1.32
variable "kubernetes_version" {
  type    = string
  default = "1.32"
}

variable "cluster_name" {
  type = string
}

variable "domain" {
  description = "domain"
  type        = string
}
