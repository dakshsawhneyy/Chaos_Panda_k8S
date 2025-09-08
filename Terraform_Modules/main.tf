# =============================================================================
# VPC CONFIGURATION
# =============================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}"
  cidr = "${var.vpc_cidr}/16"

  azs = locals.azs
  public_subnets = local.public_subnets
  private_subnets = local.private_subnets

  # Enable NAT gateway
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  # Internet Gateway
  create_igw = true

}

# =============================================================================
# Security Groups CONFIGURATION
# =============================================================================
# ! Creating two security groups. One WebSG which includes all users and DBSG which only allow WebSG
resource "aws_security_group" "web_sg" {
  name = "${var.project_name}-web_sg"
  description = "Allows SSH and HTTP traffic"
  vpc_id = module.vpc.vpc_id

  # Rule 1: Allow SSH traffic from your IP address
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Rule 2: Allow HTTP traffic from anywhere on the internet
  ingress {
    from_port   = 80
    to_port     =  80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # This is the universal code for "anywhere"
  }
  # Rule 3: Allow HTTPS traffic from anywhere on the internet
  ingress {
    from_port   = 443
    to_port     =  443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # This is the universal code for "anywhere"
  }

  tags = local.common_tags
}
resource "aws_security_group" "db_sg" {
  name = "${var.project_name}-db_sg"
  description = "Allows PostGres Traffic only from web server"
  vpc_id = module.vpc.vpc_id

  # Rule: Allow PostGres Traffic from our webserver security group
  ingress {
    from_port = 5432
    to_port = 5432
    protocol = "tcp"
    
    # Instead of CIDR Blocks, we do this
    security_groups = [aws_security_group.web_sg.id]
  }

  tags = local.common_tags
}


# =============================================================================
# EC2 CONFIGURATION
# =============================================================================
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "${var.project_name}-ec2"

  instance_type = "t2.micro"
  key_name      = "sre-god-project"
  subnet_id     = module.vpc.public_subnets[0]

  tags = local.common_tags
}


# =============================================================================
# RDS CONFIGURATION
# =============================================================================
module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "sre_god_db"

  engine            = "postgresql"
  engine_version    = "15.3"
  instance_class    = "db.t4g.micro"
  allocated_storage = 10

  db_name  = "sre_god_db"
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