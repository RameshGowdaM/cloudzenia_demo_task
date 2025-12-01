variable "aws_region" {
  default = "ap-south-1"
}

variable "bucket_name" {
  description = "S3 bucket for static website"
}

variable "domain_name" {
  description = "static-s3.<domain-name>"
}

variable "blocked_countries" {
  type    = list(string)
  default = ["CN", "RU"]
}

variable "acm_certificate_arn" {
  description = "ACM certificate for CloudFront (must be in us-east-1)"
}
