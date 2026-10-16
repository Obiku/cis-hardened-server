# Outputs are how a module hands values to other modules.
# envs/dev/main.tf reads them as module.iam.<name>.

output "role_arn" {
  description = "ARN of the server role"
  value       = aws_iam_role.instance.arn
}

output "instance_profile_name" {
  description = "Name of the instance profile, used when launching the server at T7"
  value       = aws_iam_instance_profile.instance.name
}
