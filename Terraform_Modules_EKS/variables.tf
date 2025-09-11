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

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.30"
}

variable "db_user" {
  description = "Username for the RDS database"
  type        = string
  default     = "dakshsawhneyy"
}

variable "db_name" {
  description = "Name of the RDS database"
  type        = string
  default     = "SREGodDB"
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true # This tells Terraform to hide the value in its output
}