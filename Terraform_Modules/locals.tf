# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Fetches information about AWS User's Identity
data "aws_caller_identity" "current" {}

locals {
  # Network Configuration
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]

  # Common tags applied to all resources
  common_tags = {
    Environment   = var.environment
    Project       = "sre_god_project"
    ManagedBy     = "terraform"
    CreatedBy     = "DakshSawhney"
    Owner         = data.aws_caller_identity.current.user_id
    CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
  }
}

# Fetching Latest ubuntu image
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}