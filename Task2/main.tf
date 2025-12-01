# EC2 Instances

resource "aws_instance" "ec2_1" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.private_subnet_ids[0]
  key_name      = var.key_name

  vpc_security_group_ids = [var.ec2_security_group_id]

  tags = {
    Name = "Private-EC2-1"
  }

  user_data = <<EOF
#!/bin/bash
sudo apt update -y
sudo apt install -y nginx docker.io

# Docker container
sudo docker rm -f docker1 || true

sudo docker run -d -p 8080:5678 --name docker1 \
  hashicorp/http-echo \
  -listen=:5678 \
  -text="Namaste from Container1"

sudo docker start docker1


# NGINX Config
cat > /etc/nginx/sites-available/default <<NGINX
server {
    listen 80;
    server_name ec2-instance1.${var.domain_name};

    location / {
        return 200 "Hello from Instance 1";
    }
}

server {
    listen 80;
    server_name ec2-docker1.${var.domain_name};

    location / {
        proxy_pass http://localhost:8080;
    }
}
NGINX

systemctl restart nginx
EOF
}

resource "aws_instance" "ec2_2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.private_subnet_ids[1]
  key_name      = var.key_name

  vpc_security_group_ids = [var.ec2_security_group_id]

  tags = {
    Name = "Private-EC2-2"
  }

  user_data = <<EOF
#!/bin/bash
sudo apt update -y
sudo apt install -y nginx docker.io

sudo docker rm -f docker2 || true
sudo docker run -d -p 8080:5678 --name docker2 \
  hashicorp/http-echo \
  -listen=:5678 \
  -text="Namaste from Container2"
    
sudo docker start docker2

cat > /etc/nginx/sites-available/default <<NGINX
server {
    listen 80;
    server_name ec2-instance2.${var.domain_name};

    location / {
        return 200 "Hello from Instance 2";
    }
}

server {
    listen 80;
    server_name ec2-docker2.${var.domain_name};

    location / {
        proxy_pass http://localhost:8080;
    }
}
NGINX

systemctl restart nginx
EOF
}

# Target Group

resource "aws_lb_target_group" "tg_ec2_1" {
  name     = "ec2-1-tg-new"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "instance"

  health_check {
    protocol = "HTTP"
    path     = "/"
    matcher  = "200"
  }
}

resource "aws_lb_target_group" "tg_ec2_2" {
  name     = "ec2-2-tg-new"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "instance"

  health_check {
    protocol = "HTTP"
    path     = "/"
    matcher  = "200"
  }
}

# Attach Each EC2 to its own Target Group

resource "aws_lb_target_group_attachment" "attach_ec2_1" {
  target_group_arn = aws_lb_target_group.tg_ec2_1.arn
  target_id        = aws_instance.ec2_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach_ec2_2" {
  target_group_arn = aws_lb_target_group.tg_ec2_2.arn
  target_id        = aws_instance.ec2_2.id
  port             = 80
}


# ALB Listener Rules

# Instance 1
#resource "aws_lb_listener_rule" "instance1" {
 # listener_arn = var.alb_listener_https_arn
  #priority     = 100

  #condition {
  #  host_header {
    #  values = ["ec2-instance1.${var.domain_name}"]
   # }
  #}

  #action {
   # type             = "forward"
    #target_group_arn = aws_lb_target_group.tg_ec2_1.arn
  #}
#}

# Docker 1
resource "aws_lb_listener_rule" "docker1" {
  listener_arn = var.alb_listener_https_arn
  priority     = 110

  condition {
    host_header {
      values = ["ec2-docker1.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_ec2_1.arn
  }
}

# Instance 2
resource "aws_lb_listener_rule" "instance2" {
  listener_arn = var.alb_listener_https_arn
  priority     = 120

  condition {
    host_header {
      values = ["ec2-instance2.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_ec2_2.arn
  }
}

# Docker 2
resource "aws_lb_listener_rule" "docker2" {
  listener_arn = var.alb_listener_https_arn
  priority     = 130

  condition {
    host_header {
      values = ["ec2-docker2.${var.domain_name}"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg_ec2_2.arn
  }
}


# Route53 Records

resource "aws_route53_record" "instance1" {
  zone_id = var.route53_zone_id
  name    = "ec2-instance1.${var.domain_name}"
  type    = "A"

#  alias {
#    name                   = data.aws_lb.alb.dns_name
#    zone_id                = data.aws_lb.alb.zone_id
#    evaluate_target_health = true
#  }
}

resource "aws_route53_record" "instance2" {
  zone_id = var.route53_zone_id
  name    = "ec2-instance2.${var.domain_name}"
  type    = "A"

#  alias {
#    name                   = data.aws_lb.alb.dns_name
#    zone_id                = data.aws_lb.alb.zone_id
#    evaluate_target_health = true
#  }
}

resource "aws_route53_record" "docker1" {
  zone_id = var.route53_zone_id
  name    = "ec2-docker1.${var.domain_name}"
  type    = "A"

#  alias {
#    name                   = data.aws_lb.alb.dns_name
#    zone_id                = data.aws_lb.alb.zone_id
#    evaluate_target_health = true
#  }
}

resource "aws_route53_record" "docker2" {
  zone_id = var.route53_zone_id
  name    = "ec2-docker2.${var.domain_name}"
  type    = "A"

#  alias {
#    name                   = data.aws_lb.alb.dns_name
#    zone_id                = data.aws_lb.alb.zone_id
#    evaluate_target_health = true
#  }
}

# Data source for ALB

# data "aws_lb" "alb" {
# arn = var.alb_arn
# }
