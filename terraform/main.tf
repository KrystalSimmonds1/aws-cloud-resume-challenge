terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.83.0"
    }
  }

  required_version = ">= 1.9.7"
}

provider "aws" {
  region = var.region
}

# S3 Bucket configuration

resource "aws_s3_bucket" "resume_bucket" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name = var.bucket_name
  }
}

resource "aws_s3_bucket_public_access_block" "resume_site" {
  bucket                  = aws_s3_bucket.resume_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "resume_bucket" {
  bucket = aws_s3_bucket.resume_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "resume_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.resume_bucket]

  bucket = aws_s3_bucket.resume_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_policy" "resume_bucket_policy" {
  bucket = aws_s3_bucket.resume_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadAccess"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.resume_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "aws:PrincipalOrgID" = "*"
          }
        }
      }
    ]
  })
}

# DynamoDB Table for Visitor Counter

resource "aws_dynamodb_table" "visitor_count" {
  name         = "VisitorCount"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Lambda Function Configuration

resource "aws_lambda_function" "resume_lambda" {
  function_name    = "ResumeVisitorCounter"
  role             = aws_iam_role.lambda_iam_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  filename         = "../lambda.zip"
  source_code_hash = filebase64sha256("../lambda.zip")
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_count.name
    }
  }
}

# IAM Roles
# Lambda IAM Role

resource "aws_iam_role" "lambda_iam_role" {
  name = "lambda_iam_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "lambda_dynamodb_access"
  description = "Allows Lambda function to read and write to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.visitor_count.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_iam_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Create Origin Access Control (OAC) for CloudFront Distribution
resource "aws_cloudfront_origin_access_control" "resume_oac" {
  name                              = "ResumeOAC"
  description                       = "OAC for S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "resume_bucket_distribution" {
  origin {
    domain_name              = "${var.bucket_name}.s3.amazonaws.com"
    origin_id                = "S3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.resume_oac.id
  }

  enabled = true

  default_cache_behavior {
    target_origin_id       = "S3Origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS Managed Caching Policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    # AWS Managed Origin Request Policy for S3
    origin_request_policy_id = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"

    # AWS Managed Response Headers Policy (For Cloudflare Host Header)
    response_headers_policy_id = "eaab4381-ed33-4a86-88ca-d9558dc6cd63"
  }


  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
