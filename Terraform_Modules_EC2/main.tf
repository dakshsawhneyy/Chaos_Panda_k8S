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

  # This tells the public subnets to automatically assign a public IP to any instance launched in them.
  map_public_ip_on_launch = true 
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

  # New Rules for our services
  ingress {
    from_port   = 9000
    to_port     =  9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3000
    to_port     =  3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 9090
    to_port     =  9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
# AWS IAM ROLE for EC2-ECR Communication (No Need to put credentials)
# =============================================================================

# Creates a role for EC2 Service
resource "aws_iam_role" "ec2_ecr_role" {
  name = "ec2-to-ecr-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = local.common_tags
}

# Attach Permissions with this role
resource "aws_iam_role_policy_attachment" "ecr_read_only_attachment" {
  role = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Attach this role with our EC2 Instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-ecr-profile" 
  role = aws_iam_role.ec2_ecr_role.name
}

# =============================================================================
# EC2 CONFIGURATION
# =============================================================================
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "${var.project_name}-ec2"

  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "general-key-pair"
  subnet_id     = module.vpc.public_subnets[0]

  # Attach web security group to ssh into web_server
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Attaching user_data with EC2 -- my script acts as configuration management
  # Converting into tpl file, so we can pass env while calling the file
  user_data = templatefile("${path.module}/user-data.sh.tpl", {
    service_a_imageurl = "897722695334.dkr.ecr.ap-south-1.amazonaws.com/god_level_project/service-a:latest"
    service_b_imageurl = "897722695334.dkr.ecr.ap-south-1.amazonaws.com/god-level-project/service-b:latest"
    db_host = module.db.db_instance_address
    prometheus_config = file("${path.module}/prometheus.yml")
  })

  # Attaching Role with EC2
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  tags = local.common_tags
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