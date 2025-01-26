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

resource "aws_s3_bucket" "resume_bucket" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    Name = var.bucket_name
  }
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

resource "aws_s3_bucket_website_configuration" "resume_site" {
  bucket = aws_s3_bucket.resume_bucket.id

  index_document {
    suffix = "index.html"
  }

  # error_document {
  #   key = error.html
  # }
}