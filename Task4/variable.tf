variable "aws_region" {
  default = "ap-south-1"
}

variable "microservice_name" {
  default = "cloudzenia-microservice"
}

variable "ecr_repo_name" {
  default = "cloudzenia-microservice-repo"
}

variable "ecs_cluster_name" {
  default = "cloudzenia-cluster"
}

variable "ecs_cpu" {
  default = 256
}

variable "ecs_memory" {
  default = 512
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "task_execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "container_port" {
  default = 3000
}
