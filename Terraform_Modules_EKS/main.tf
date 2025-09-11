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
# Security Group CONFIGURATION
# =============================================================================
resource "aws_security_group" "db_sg" {
  name = "${var.project_name}-db-sg"
  description = "Allows PostgreSQL traffic only from the EKS worker nodes"
  vpc_id = module.vpc.vpc_id

  # Allow traffic on RDS postgres port only from the EKS node security group
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"

    security_groups = [module.eks.node_security_group_id]
  }

  # Allow all outgoing traffic
  egress {
    from_port = 0
    to_port = 0
    protocol = "tcp"

    security_groups = [module.eks.node_security_group_id]
  }

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

# =============================================================================
# secrets and configmaps CONFIGURATION
# =============================================================================
resource "kubernetes_secret" "rds_credentials" {
  metadata {
    name = "rds-credentials"
  }
  # Terraform automatically Base64 encodes this data for you
  data = {
    DB_USER = var.db_user
    DB_PASSWORD = var.db_password
    DB_NAME     = var.db_name
  }
}

# Creating config map for storing db host name
resource "kubernetes_config_map" "rds_endpoint" {
  metadata {
    name = "rds-endpoint"
  }
  data = {
    # We get live address from RDS and store that in configmap
    DB_HOST = module.db.db_instance_address
  }
}

# =============================================================================
# RDS CONFIGURATION
# =============================================================================
module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "sre-god-db"

  engine            = "postgres"
  engine_version    = "15.7"
  major_engine_version = "15"
  instance_class    = "db.t4g.micro"
  allocated_storage = 10

  db_name  = "SREGodDB"
  username = "dakshsawhneyy"
  port     = "5432"

  iam_database_authentication_enabled = true

  vpc_security_group_ids = [aws_security_group.db_sg.id]

  tags = local.common_tags

  # AWS will automatically create a standby replica of your database in a different Availability Zone
  multi_az = true

  # DB subnet group
  create_db_subnet_group = true
  subnet_ids             = module.vpc.private_subnets

  # DB parameter group
  family = "postgres15"
}