output "cloudfront_domain" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.website.bucket
}

output "website_endpoint" {
  value = "http://${aws_s3_bucket.website.bucket}.s3-website-${var.aws_region}.amazonaws.com"
}
