# Outputs are how a module hands values to other modules.
# envs/dev/main.tf reads them as module.compute.<name>.

output "instance_id" {
  description = "ID of the server, used to connect with Session Manager"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP of the server"
  value       = aws_instance.this.private_ip
}
