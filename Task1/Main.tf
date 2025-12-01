# Network: VPC + Subnets + IGW + NAT

data "aws_availability_zones" "available" {}

resource "aws_vpc" "cloudzenia" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "ecs-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cloudzenia.id

  tags = {
    Name = "ecs-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.cloudzenia.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.cloudzenia.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-${count.index}"
  }
}

# EIP for NAT (new style, more robust)
resource "aws_eip" "nat" {
  domain = "vpc"

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "nat-gateway"
  }
}

# Route Tables

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cloudzenia.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.cloudzenia.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_rt_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# Security Groups

resource "aws_security_group" "cloudzeniaalb_sg" {
  vpc_id = aws_vpc.cloudzenia.id
  name   = "cloudzeniaalb-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloudzeniaalb-sg"
  }
}

resource "aws_security_group" "ecs_sg" {
  vpc_id = aws_vpc.cloudzenia.id
  name   = "ecs-sg"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.cloudzeniaalb_sg.id]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.cloudzeniaalb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecs-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.cloudzenia.id
  name   = "rds-sg"

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# RDS (Private Subnets)

resource "aws_db_subnet_group" "db_subnets" {
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "wordpress-db-subnets"
  }
}

resource "aws_db_instance" "wordpress" {
  allocated_storage       = 20
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  db_name                 = "wordpressdb"
  username                = var.db_username
  password                = var.db_password
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnets.name
  backup_retention_period = 7
  skip_final_snapshot     = true
  publicly_accessible     = false

  tags = {
    Name = "wordpress-db"
  }
}

# Secrets Manager

resource "aws_secretsmanager_secret" "wp_secret" {
  name = "wordpress-db-secret"

  tags = {
    Name = "wordpress-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "wp_secret_value" {
  secret_id = aws_secretsmanager_secret.wp_secret.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.wordpress.address
    dbname   = "wordpressdb"
  })
}

# IAM Roles for ECS (Task + Execution)

# Task Role – used inside the container 
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_secrets_policy" {
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = aws_secretsmanager_secret.wp_secret.arn
    }]
  })
}

# Execution Role – used by ECS agent to pull images, send logs
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_managed_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#Create Secrets Access Policy for Execution Role

resource "aws_iam_policy" "ecs_execution_secrets_policy" {
  name = "ecs-execution-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.wp_secret.arn
      }
    ]
  })
}

# alb + Target Groups

resource "aws_lb" "cloudzeniaalb" {
  name               = "ecs-cloudzeniaalb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.cloudzeniaalb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "ecs-cloudzeniaalb"
  }
}

resource "aws_lb_target_group" "wordpress_tg" {
  name        = "wordpress-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.cloudzenia.id
  target_type = "ip"

  tags = {
    Name = "wordpress-tg"
  }
}

resource "aws_lb_target_group" "microservice_tg" {
  name        = "microservice-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.cloudzenia.id
  target_type = "ip"

  tags = {
    Name = "microservice-tg"
  }
}

# ACM + SSL

resource "aws_acm_certificate" "ssl_cert" {
  domain_name       = "*.rameshmandigowdas.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "wildcard-cert"
  }
}

# Route53 Lookup & Certificate Validation

data "aws_route53_zone" "main" {
  name         = "rameshmandigowdas.com."
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.ssl_cert.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "ssl_validation" {
  certificate_arn         = aws_acm_certificate.ssl_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# cloudzeniaalb Listeners + Host-based Routing

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.cloudzeniaalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.cloudzeniaalb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.ssl_cert.arn
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Invalid host"
      status_code  = "404"
    }
  }

  depends_on = [aws_acm_certificate_validation.ssl_validation]
}

resource "aws_lb_listener_rule" "wordpress_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  condition {
    host_header {
      values = ["wordpress.rameshmandigowdas.com"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}

resource "aws_lb_listener_rule" "microservice_rule" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20

  condition {
    host_header {
      values = ["microservice.rameshmandigowdas.com"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservice_tg.arn
  }
}

# Route53 DNS Records for Subdomains

resource "aws_route53_record" "wordpress_dns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "wordpress.rameshmandigowdas.com"
  type    = "A"

  alias {
    name                   = aws_lb.cloudzeniaalb.dns_name
    zone_id                = aws_lb.cloudzeniaalb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "microservice_dns" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "microservice.rameshmandigowdas.com"
  type    = "A"

  alias {
    name                   = aws_lb.cloudzeniaalb.dns_name
    zone_id                = aws_lb.cloudzeniaalb.zone_id
    evaluate_target_health = true
  }
}

# ECS Cluster

resource "aws_ecs_cluster" "cluster" {
  name = "ecs-wp-ms-cluster"
}

# ECS Task Definitions
# WordPress Task – uses Secrets Manager + RDS

resource "aws_ecs_task_definition" "wordpress" {
  family                   = "wordpress-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "wordpress"
      image = var.wordpress_image
      portMappings = [
        {
          containerPort = 80
        }
      ]
      environment = [
        {
          name  = "WORDPRESS_DB_HOST"
          value = aws_db_instance.wordpress.address
        },
        {
          name  = "WORDPRESS_DB_USER"
          value = var.db_username
        },
        {
          name  = "WORDPRESS_DB_NAME"
          value = "wordpressdb"
        }
      ]
      secrets = [
        {
          name      = "WORDPRESS_DB_PASSWORD"
          valueFrom = aws_secretsmanager_secret.wp_secret.arn
        }
      ]
    }
  ])
}

# Microservice Task – Node.js "Hello from Microservice"
resource "aws_ecs_task_definition" "microservice" {
  family                   = "microservice-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "microservice"
      image = var.microservice_image   
      portMappings = [
        {
          containerPort = 3000
        }
      ]
      essential = true
    }
  ])
}

# ECS Services (Private Subnets)

resource "aws_ecs_service" "wordpress" {
  name            = "wordpress-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.wordpress.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
    container_name   = "wordpress"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.https,
    aws_lb_target_group.wordpress_tg
  ]
}

resource "aws_ecs_service" "microservice" {
  name            = "microservice-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.microservice.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.microservice_tg.arn
    container_name   = "microservice"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.https,
    aws_lb_target_group.microservice_tg
  ]
}

# ECS Auto Scaling (CPU + Memory)

# WordPress autoscaling target
resource "aws_appautoscaling_target" "wordpress_target" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.wordpress.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# WordPress CPU-based scaling
resource "aws_appautoscaling_policy" "wordpress_cpu" {
  name               = "wordpress-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.wordpress_target.resource_id
  scalable_dimension = aws_appautoscaling_target.wordpress_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.wordpress_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# WordPress Memory-based scaling
resource "aws_appautoscaling_policy" "wordpress_memory" {
  name               = "wordpress-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.wordpress_target.resource_id
  scalable_dimension = aws_appautoscaling_target.wordpress_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.wordpress_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

# Microservice autoscaling target
resource "aws_appautoscaling_target" "microservice_target" {
  max_capacity       = 3
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.microservice.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Microservice CPU-based scaling
resource "aws_appautoscaling_policy" "microservice_cpu" {
  name               = "microservice-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.microservice_target.resource_id
  scalable_dimension = aws_appautoscaling_target.microservice_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.microservice_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

# Microservice Memory-based scaling
resource "aws_appautoscaling_policy" "microservice_memory" {
  name               = "microservice-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.microservice_target.resource_id
  scalable_dimension = aws_appautoscaling_target.microservice_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.microservice_target.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = 70

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}










































































































