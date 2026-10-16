# Outputs are how a module hands values to other modules.
# envs/dev/main.tf reads them as module.monitoring.<name>.

output "config_bucket_name" {
  description = "Bucket AWS Config delivers to"
  value       = aws_s3_bucket.config.id
}
