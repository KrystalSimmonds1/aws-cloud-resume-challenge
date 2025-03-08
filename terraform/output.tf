output "resume_website_url" {
  value       = aws_cloudfront_distribution.resume_bucket_distribution.domain_name
  description = "The CloudFront URL for the resume website"
}
