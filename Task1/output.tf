# VPC Outputs

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.cloudzenia.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

# ALB Outputs

output "alb_name" {
  description = "Application Load Balancer Name"
  value       = aws_lb.cloudzeniaalb.name
}

output "alb_dns_name" {
  description = "ALB DNS Name"
  value       = aws_lb.cloudzeniaalb.dns_name
}

output "alb_https_listener_arn" {
  description = "HTTPS Listener ARN"
  value       = aws_lb_listener.https.arn
}

# Application Endpoints

output "wordpress_url" {
  description = "WordPress public endpoint"
  value       = "https://wordpress.${var.domain_name}"
}

output "microservice_url" {
  description = "Microservice public endpoint"
  value       = "https://microservice.${var.domain_name}"
}

# ECS Outputs

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.cluster.name
}

output "wordpress_service_name" {
  description = "WordPress ECS Service name"
  value       = aws_ecs_service.wordpress.name
}

output "microservice_service_name" {
  description = "Microservice ECS Service name"
  value       = aws_ecs_service.microservice.name
}


# RDS Outputs

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.wordpress.address
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.wordpress.port
}

output "rds_db_name" {
  description = "RDS Database name"
  value       = aws_db_instance.wordpress.db_name
}

# Secrets Manager Outputs

output "secrets_manager_arn" {
  description = "Secrets Manager ARN storing WordPress DB credentials"
  value       = aws_secretsmanager_secret.wp_secret.arn
}

# Docker Images Used

output "wordpress_docker_image" {
  description = "WordPress Docker image used in ECS"
  value       = var.wordpress_image
}

output "microservice_docker_image" {
  description = "Microservice Docker image used in ECS"
  value       = var.microservice_image
}
