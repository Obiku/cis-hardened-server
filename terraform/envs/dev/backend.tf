# =============================================================================
# BACKEND: where this project's state lives
# =============================================================================
# State is stored in the S3 bucket created by terraform/bootstrap, not on the
# laptop. This means:
#   - state survives destroy and rebuild, and works from any machine
#   - every change to state is versioned in the bucket
#   - use_lockfile writes a small .tflock file next to the state during a run,
#     so two runs can never change the state at the same time (no DynamoDB)
#
# Backend blocks cannot use variables, so the values are written out in full.
# =============================================================================

terraform {
  backend "s3" {
    bucket       = "cis-hardened-server-tfstate-575141563901"
    key          = "envs/dev/terraform.tfstate" # path of the state file in the bucket
    region       = "eu-west-2"
    encrypt      = true # encrypt the state file at rest
    use_lockfile = true # S3 native state locking
  }
}
