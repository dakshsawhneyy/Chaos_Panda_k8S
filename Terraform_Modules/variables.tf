variable "project_name" {
  description = "name of the project"
  type = string
  default = "sre-god-project"
}

variable "vpc_cidr" {
  description = "defining CIDR range for vpc"
  type = string
  default = "10.0.0.0/16"
}

variable "environment" {
  description = "specifying envirnment (dev, prod)"
  type = string
  default = "dev"
}

variable "single_nat_gateway" {
  description = "bool value for enabling single nat gateway"
  type = bool
  default = true
}