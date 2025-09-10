# =============================================================================
# VPC CONFIGURATION
# =============================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}"
  cidr = "${var.vpc_cidr}"

  azs = local.azs
  public_subnets = local.public_subnets
  private_subnets = local.private_subnets

  # Enable NAT gateway
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  # Internet Gateway
  create_igw = true

  # DNS configuration -- Allows instances within your VPC to resolve public domain names
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Manage default resources for better control
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.project_name}-default-nacl" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.project_name}-default-rt" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.project_name}-default-sg" }

  # Apply Kubernetes-specific tags to subnets
  public_subnet_tags  = merge(local.common_tags, local.public_subnet_tags)
  private_subnet_tags = merge(local.common_tags, local.private_subnet_tags)

  tags = local.common_tags
}

# =============================================================================
# EKS CLUSTER CONFIGURATION
# =============================================================================
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  # Basic cluster configuration
  cluster_name    = var.project_name
  cluster_version = var.kubernetes_version

  # Cluster access configuration
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true

  # EKS Auto Mode configuration - simplified node management
  eks_managed_node_groups = {
    general_purpose = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t2.micro"]
    }
  }

  # Network configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # KMS configuration to avoid conflicts
  create_kms_key = true
  kms_key_description = "EKS cluster ${var.project_name} encryption key"
  kms_key_deletion_window_in_days = 7
  
  # Cluster logging (optional - can be expensive)
  # cluster_enabled_log_types = []

  tags = local.common_tags
}