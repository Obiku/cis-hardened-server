# =============================================================================
# MODULE: kms  (console Phase 2, step 1, plus the logs statement from Phase 4)
# =============================================================================
# Builds the customer managed key that encrypts everything in this project:
#   the evidence bucket (T4), the log groups (T6) and the server's disk (T7).
# =============================================================================

resource "aws_kms_key" "this" {
  description             = "Encrypts the CIS server disk, evidence bucket and log groups"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableIAMUserPermissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      # Statement 1: the same first statement the console creates. ":root"
      # means the whole account, not the root user. It lets IAM policies
      # decide who can use the key, which is how Saintkings (admin) and later
      # the server role get access. Without it, the key could lock everyone out.

      {
        Sid       = "AllowCloudWatchLogsForCisLogGroups"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/cis/*"
          }
        }
      }
      # Statement 2: lets the CloudWatch Logs service encrypt the /cis/* log
      # groups with this key (added by hand in console Phase 4). The condition
      # limits it to this account's /cis/ log groups only.
    ]
  })

  tags = { Name = var.key_alias }
}
# The key.
# enable_key_rotation: AWS creates new key material every year. Old data can
#   still be decrypted because the old material is kept.
# deletion_window_in_days: after destroy, the key waits this many days before
#   it is really deleted. 7 is the minimum (the console default is 30). Short,
#   because this lab is rebuilt often.

resource "aws_kms_alias" "this" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}
# The alias: the friendly name shown in the console (alias/cis-hardened-key).
