output "resume_website_endpoint" {
  value       = aws_s3_bucket_website_configuration.resume_site.website_endpoint
  description = "The URL for the S3 bucket resume website"

}