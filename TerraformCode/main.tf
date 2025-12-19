resource aws_s3_bucket "private_bucket" {
  bucket = var.bucket_name
}

# Make the bucket private by blocking all public access
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.private_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 3. Create the Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "example-oac-config"
  description                       = "OAC for my S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always" # Most common use case
  signing_protocol                  = "sigv4"
}

# 4. Create the CloudFront distribution and associate the OAC
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.private_bucket.bucket_regional_domain_name
    origin_id                = "S3-Origin-Example"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "My secure CloudFront distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-Origin-Example"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


resource "aws_s3_bucket_policy" "allow_cf" {
  bucket = aws_s3_bucket.private_bucket.id
  depends_on = [ aws_s3_bucket_public_access_block.block ]
    # 5. Define the S3 bucket policy to allow access only from the CloudFront OAC
  policy = jsonencode({
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "${aws_s3_bucket.private_bucket.arn}/*"
        Condition = {
            StringEquals = {
                "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
            }
        }
    }

  ]
})
}

# Upload website content to the S3 bucket
resource "aws_s3_object" "object" {
  for_each = fileset("${path.module}/../www","**/../*")
  bucket = aws_s3_bucket.private_bucket.id
  key = each.value
  source = "${path.module}/../www/${each.value}"
  etag = filemd5("${path.module}/../www/${each.value}")
    content_type = lookup({
        html = "text/html"
        css  = "text/css"
        js   = "application/javascript"
        png  = "image/png"
        jpg  = "image/jpeg"
        jpeg = "image/jpeg"
        gif  = "image/gif"
        svg  = "image/svg+xml"
    }, split(".", each.value)[length(split(".", each.value)) - 1], "application/octet-stream")
}