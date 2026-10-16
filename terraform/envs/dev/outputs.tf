# Values printed after "terraform apply". Read them again any time with
# "terraform output".

output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_id" {
  value = module.network.private_subnet_id
}

output "nat_public_ip" {
  value = module.network.nat_public_ip
}

output "kms_key_arn" {
  value = module.kms.key_arn
}

output "evidence_bucket_name" {
  value = module.evidence.bucket_name
}

output "instance_role_arn" {
  value = module.iam.role_arn
}

output "log_group_names" {
  value = module.logging.log_group_names
}

output "instance_id" {
  value = module.compute.instance_id
}

output "private_ip" {
  value = module.compute.private_ip
}

output "config_bucket_name" {
  value = module.monitoring.config_bucket_name
}
