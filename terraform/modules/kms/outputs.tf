# Outputs are how a module hands values to other modules.
# envs/dev/main.tf reads them as module.kms.<name>.

output "key_arn" {
  description = "ARN of the key, used by the bucket, log groups and disk"
  value       = aws_kms_key.this.arn
}

output "key_id" {
  description = "ID of the key"
  value       = aws_kms_key.this.key_id
}
