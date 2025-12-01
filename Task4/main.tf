# ECR Repository
resource "aws_ecr_repository" "repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  lifecycle_policy {
    policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire old images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "cluster" {
  name = var.ecs_cluster_name
}

# Task Definition
resource "aws_ecs_task_definition" "task" {
  family                   = var.microservice_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_cpu
  memory                   = var.ecs_memory
  execution_role_arn       = var.task_execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.microservice_name
      image     = "${aws_ecr_repository.repo.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "service" {
  name            = var.microservice_name
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.security_group_id]
    assign_public_ip = false
  }
}
