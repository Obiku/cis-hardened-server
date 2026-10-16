# Outputs are how a module hands values to other modules.
# envs/dev/main.tf reads them as module.network.<name>.

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "private_subnet_id" {
  description = "ID of the private subnet (where the server is launched)"
  value       = aws_subnet.private.id
}

output "instance_security_group_id" {
  description = "ID of the instance security group"
  value       = aws_security_group.instance.id
}

output "nat_public_ip" {
  description = "Public IP the NAT gateway uses for outbound traffic"
  value       = aws_eip.nat.public_ip
}
