# =============================================================================
# DEV ENVIRONMENT: wires the modules together
# =============================================================================
# Each module is one building block from the console build. This file calls
# them in order and passes outputs from one module into the next, for example
# the VPC ID from the network module into the compute module.
#
# Modules are added here one at a time as the build progresses:
#   T3 network, T4 kms + evidence, T5 iam, T6 logging, T7 compute,
#   T8 monitoring
# =============================================================================

# Looks up the current account ID so names can include it without
# hard-coding 575141563901.
data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# T3: network (console Phase 1)
# -----------------------------------------------------------------------------
# "source" is the folder holding the module code. The other lines are the
# module's input variables (see modules/network/variables.tf). CIDRs and the
# Availability Zone use the module's defaults.
module "network" {
  source = "../../modules/network"

  name_prefix = var.name_prefix
  region      = var.region
}

# -----------------------------------------------------------------------------
# T4: kms and evidence (console Phase 2)
# -----------------------------------------------------------------------------
module "kms" {
  source = "../../modules/kms"

  key_alias  = "cis-hardened-key"
  account_id = data.aws_caller_identity.current.account_id
  region     = var.region
}

module "evidence" {
  source = "../../modules/evidence"

  bucket_name = "cis-evidence-${data.aws_caller_identity.current.account_id}"
  kms_key_arn = module.kms.key_arn
}
# The bucket is encrypted with the key from the kms module. Passing
# module.kms.key_arn here also tells Terraform to build the key first.

# -----------------------------------------------------------------------------
# T5: iam (console Phase 3)
# -----------------------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  name_prefix         = var.name_prefix
  evidence_bucket_arn = module.evidence.bucket_arn
  kms_key_arn         = module.kms.key_arn
}
# The role's upload policy names the bucket and the key, so it takes their
# ARNs from the evidence and kms modules (built at T4).

# -----------------------------------------------------------------------------
# T6: logging (console Phase 4, log groups from Phase 8)
# -----------------------------------------------------------------------------
module "logging" {
  source = "../../modules/logging"

  kms_key_arn = module.kms.key_arn
}
# The log groups are encrypted with the key from the kms module. Retention
# uses the module default (7 days).

# -----------------------------------------------------------------------------
# T7: compute (console Phases 5 to 8)
# -----------------------------------------------------------------------------
module "compute" {
  source = "../../modules/compute"

  name_prefix           = var.name_prefix
  region                = var.region
  subnet_id             = module.network.private_subnet_id
  security_group_id     = module.network.instance_security_group_id
  instance_profile_name = module.iam.instance_profile_name
  kms_key_arn           = module.kms.key_arn

  depends_on = [module.logging]
}
# The server takes its subnet and security group from network (T3), its role
# from iam (T5) and its disk key from kms (T4).
# depends_on: the log groups and Session Manager preferences (T6) must exist
# before the server boots, otherwise the CloudWatch agent would create the log
# groups itself, unencrypted and outside Terraform.

# -----------------------------------------------------------------------------
# T8: monitoring (console Phase 9)
# -----------------------------------------------------------------------------
module "monitoring" {
  source = "../../modules/monitoring"

  account_id = data.aws_caller_identity.current.account_id
  region     = var.region

  depends_on = [module.compute]
}
# depends_on: Config and Security Hub are switched on last, once everything
# they watch already exists (the same order as the console build).
