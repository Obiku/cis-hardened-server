# =============================================================================
# BOOTSTRAP: the Terraform state bucket
# =============================================================================
# Terraform keeps a "state" file: its record of every resource it created and
# their IDs. The main project stores that state in S3 so it survives on any
# machine and can be locked during a run.
#
# The chicken-and-egg problem: Terraform cannot store its state in a bucket
# that does not exist yet. So this small, separate configuration creates the
# bucket ONCE, using local state on the laptop. After that it is never
# destroyed, which is what lets the main project be destroyed and recreated
# as often as you like.
#
# Run once:  terraform init  then  terraform apply
# =============================================================================

terraform {
  # Minimum Terraform version. 1.10+ supports S3 state locking with a lock
  # file (use_lockfile), so no DynamoDB table is needed.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # any 6.x version, but not 7.0 (avoids breaking changes)
    }
  }
}

# The AWS provider is the plugin that talks to the AWS APIs.
# It uses the same credentials as the AWS CLI (~/.aws/credentials).
provider "aws" {
  region = var.region

  # default_tags are added to EVERY resource this provider creates.
  # This replaces typing Project and Owner by hand on each resource in the
  # console, and removes the hidden-space tag mistakes from Phase 1.
  default_tags {
    tags = {
      Project   = var.project
      Owner     = var.owner
      ManagedBy = "terraform"
    }
  }
}

# A "data source" READS something that already exists instead of creating it.
# Here it looks up the current account ID, so the bucket name is unique
# without hard-coding 575141563901.
data "aws_caller_identity" "current" {}

locals {
  # locals are named values used inside this file.
  state_bucket_name = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
}

# -----------------------------------------------------------------------------
# The bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket_name

  # prevent_destroy makes Terraform REFUSE any plan that would delete this
  # bucket. Losing the state bucket means Terraform forgets what it built.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning: every change to the state file is kept as a version, so a
# corrupted or bad state can be rolled back.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest. SSE-S3 (AES256, keys managed by S3) is used on purpose,
# NOT the project's KMS key: the project key is destroyed with the project,
# and the state bucket must outlive it.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access, same four settings as the evidence bucket.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACLs disabled: only policies control access (BucketOwnerEnforced).
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Bucket policy: deny any request that is not over TLS (HTTPS).
# Same control as DenyInsecureTransport on the evidence bucket in Phase 2.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  # jsonencode turns a Terraform map into a JSON policy document,
  # so there is no hand-written JSON to get wrong.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.state.arn,
        "${aws_s3_bucket.state.arn}/*"
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  # Apply the public access block first, so the policy is never briefly
  # evaluated without it.
  depends_on = [aws_s3_bucket_public_access_block.state]
}
