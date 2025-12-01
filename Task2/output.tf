output "ec2_1_private_ip" {
  value = aws_instance.ec2_1.private_ip
}

output "ec2_2_private_ip" {
  value = aws_instance.ec2_2.private_ip
}

output "docker_domains" {
  value = [
    "https://ec2-docker1.${var.domain_name}",
    "https://ec2-docker2.${var.domain_name}"
  ]
}

output "instance_domains" {
  value = [
    "https://ec2-instance1.${var.domain_name}",
    "https://ec2-instance2.${var.domain_name}"
  ]
}
