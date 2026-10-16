# Outputs are how a module hands values to other modules.
# envs/dev/main.tf reads them as module.logging.<name>.

output "log_group_names" {
  description = "Names of the /cis/ log groups"
  value       = [for lg in aws_cloudwatch_log_group.this : lg.name]
}
