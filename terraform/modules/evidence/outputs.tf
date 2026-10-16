# Outputs are how a module hands values to other modules.
# envs/dev/main.tf reads them as module.evidence.<name>.

output "bucket_name" {
  description = "Name of the evidence bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the evidence bucket, used by the IAM policy at T5"
  value       = aws_s3_bucket.this.arn
}
