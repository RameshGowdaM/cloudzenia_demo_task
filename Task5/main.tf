# S3 Bucket
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Public Policy
resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.website.id

  policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject"],
      "Resource": ["${aws_s3_bucket.website.arn}/*"]
    }
  ]
}
EOF
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  enabled = true

  origins {
    domain_name = "${aws_s3_bucket.website.bucket}.s3-website-${var.aws_region}.amazonaws.com"
    origin_id   = "s3-origin"
  }

  default_cache_behavior {
    target_origin_id = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
  }

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = var.blocked_countries
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.acm_certificate_arn
    ssl_support_method   = "sni-only"
  }

  aliases = [var.domain_name]
}
