variable "vpc_id" {
  description = "Existing VPC ID"
  default     = "vpc-0e96dd4a61d3d0660"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs"
  default = [
    "subnet-0bfe17c49997a571e",
    "subnet-0b6a007f842480a0c"
  ]
}

variable "alb_arn" {
  description = "Existing ALB ARN"
  default     = "arn:aws:elasticloadbalancing:ap-south-1:136268832766:loadbalancer/app/ecs-cloudzeniaalb/bed2260183ffa320"
}

variable "alb_listener_https_arn" {
  description = "Existing ALB HTTPS listener ARN (443)"
  default     = "arn:aws:elasticloadbalancing:ap-south-1:136268832766:listener/app/ecs-cloudzeniaalb/bed2260183ffa320/b91b039dbd8d9b07"
}

variable "alb_security_group_id" {
  description = "ALB Security Group ID"
  default     = "sg-00532c10546e981cd"
}

variable "ec2_security_group_id" {
  description = "EC2 Security Group ID (allows ALB traffic)"
  default     = "sg-0e41209ffb3dd8286"
}

variable "ami_id" {
  description = "Ubuntu AMI ID"
  default     = "ami-02b8269d5e85954ef"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  description = "Key pair name"
  default     = "ramesh"
}

variable "domain_name" {
  default = "rameshmandigowdas.com"
}

variable "route53_zone_id" {
  description = "Hosted Zone ID of your domain"
  default     = "Z10125422SC4UW5QTV439"
}
