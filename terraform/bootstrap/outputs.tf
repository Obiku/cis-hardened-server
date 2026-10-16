# Outputs are printed after "terraform apply" and can be read later with
# "terraform output". The bucket name is needed for the backend block in
# envs/dev/backend.tf.

output "state_bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state"
  value       = aws_s3_bucket.state.bucket
}
