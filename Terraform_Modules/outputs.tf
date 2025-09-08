output "vpc_id" {
  description = "Output for VPC ID"
  value = module.vpc.vpc_id
}

output "web_security_group_id" {
  description = "Output for Web Security Group"
  value = resource.aws_security_group.web_sg.id
}
output "db_security_group_id" {
  description = "Output for DB Security Group"
  value = resource.aws_security_group.db_sg.id
}


output "ec2_id" {
  description = "Output for EC2 ID"
  value = module.ec2_instance.id
}

output "rds_id" {
  description = "Output for RDS ID"
  value = module.rds.id
}