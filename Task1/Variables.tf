# AWS Provider Variables

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "ap-south-1"
}

# Domain / Route53 / ACM

variable "domain_name" {
  description = "Your primary domain name"
  type        = string
  default     = "rameshmandigowdas.com"
}


# RDS Database Variables

variable "db_username" {
  description = "Username for the WordPress RDS database"
  type        = string
  default     = "cloudzenia"
}

variable "db_password" {
  description = "Password for the WordPress RDS database"
  type        = string
  sensitive   = true
}

# Docker Image Variables

variable "wordpress_image" {
  description = "Docker image to use for WordPress (Docker Hub or ECR URI)"
  type        = string
  default     = "wordpress:php8.4-fpm-alpine"
}

variable "microservice_image" {
  description = "Docker image URI for the Node.js microservice from ECR"
  type        = string
  default     = "mrameshr5211/cloudzenia-microservice:demo"
}
