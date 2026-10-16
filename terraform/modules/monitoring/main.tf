# =============================================================================
# MODULE: monitoring  (console Phase 9)
# =============================================================================
# Watches the AWS setup from the OUTSIDE (the daily script checks the server
# from the inside):
#   AWS Config      : records every resource change and runs rules on them
#   restricted-ssh  : flags any security group open on port 22 to the world
#   Security Hub    : one place for findings, with two standards switched on
# In the console, Config "1-click setup" built the first five resources below
# in one go.
# =============================================================================

data "aws_iam_role" "config" {
  name = "AWSServiceRoleForConfig"
}
# Looks up the role Config uses to read your resources. It is a
# service-linked role: AWS creates it once per account, the first time Config
# is set up, and it already exists from the console build. Only looked up,
# not created, so it is not counted in the plan.

resource "aws_s3_bucket" "config" {
  bucket        = "config-bucket-${var.account_id}"
  force_destroy = true
}
# Where Config delivers its snapshots and history files (same name the
# console 1-click setup used). force_destroy: lets "terraform destroy" empty
# and delete it at T11.

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
# Block all public access: all four settings ON.

resource "aws_s3_bucket_policy" "config" {
  bucket = aws_s3_bucket.config.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSConfigBucketPermissionsCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:ListBucket"]
        Resource  = aws_s3_bucket.config.arn
        Condition = { StringEquals = { "AWS:SourceAccount" = var.account_id } }
      },
      # Statement 1: Config checks the bucket exists and who owns it before
      # writing.

      {
        Sid       = "AWSConfigBucketDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config.arn}/AWSLogs/${var.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = var.account_id
          }
        }
      }
      # Statement 2: Config writes its files under AWSLogs/<account>/Config/.
      # AWS:SourceAccount means only Config working for THIS account can
      # write, not Config working for someone else's account.
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.config]
}
# Bucket policy: lets the Config service deliver files. The console 1-click
# setup wrote this policy for you.

resource "aws_config_configuration_recorder" "this" {
  name     = "default"
  role_arn = data.aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = false
  }
}
# The recorder: WHAT Config records. Only one is allowed per region.
# all_supported: every resource type Config supports, security groups included.
# include_global_resource_types false: skips IAM (global) types, the same as
#   the console build.

resource "aws_config_delivery_channel" "this" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.config.id

  depends_on = [aws_config_configuration_recorder.this, aws_s3_bucket_policy.config]
}
# The delivery channel: WHERE Config sends what it records (the bucket above).
# depends_on: AWS refuses a delivery channel until a recorder exists and the
#   bucket policy allows delivery.

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
# Switches the recorder ON. Creating a recorder does not start it; this does.

resource "aws_config_config_rule" "restricted_ssh" {
  name        = "restricted-ssh"
  description = "Flags security groups that allow SSH (port 22) from 0.0.0.0/0"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder_status.this]
}
# The drift rule from the console build. owner AWS: an AWS managed rule, so
# AWS wrote the logic. INCOMING_SSH_DISABLED is its internal name.

resource "aws_securityhub_account" "this" {
  enable_default_standards = false

  depends_on = [aws_config_configuration_recorder_status.this]
}
# Switches Security Hub on for this region.
# enable_default_standards false: the standards are switched on explicitly
#   below instead, so the code shows exactly which ones are on.
# depends_on: Security Hub's controls use Config's recordings, so Config is
#   switched on first.

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"

  depends_on = [aws_securityhub_account.this]
}
# Standard 1: AWS Foundational Security Best Practices v1.0.0.

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"

  depends_on = [aws_securityhub_account.this]
}
# Standard 2: CIS AWS Foundations Benchmark v1.2.0. This checks the AWS
# ACCOUNT settings, not Ubuntu. The Ubuntu benchmark is covered by
# cis-check.sh. (This older ARN has no region in it, which is AWS's format.)
