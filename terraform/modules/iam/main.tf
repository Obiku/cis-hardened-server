# =============================================================================
# MODULE: iam  (console Phase 3)
# =============================================================================
# Builds the server's identity: one role with only the permissions it needs.
#   SSM agent        : AmazonSSMManagedInstanceCore (AWS managed)
#   CloudWatch agent : CloudWatchAgentServerPolicy  (AWS managed)
#   Daily check      : cis-evidence-upload-policy   (custom, below)
# =============================================================================

resource "aws_iam_policy" "evidence_upload" {
  name        = "${var.name_prefix}-evidence-upload-policy"
  description = "Write-only upload of CIS evidence to the evidence/ prefix"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "UploadEvidenceToOnePrefix"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${var.evidence_bucket_arn}/evidence/*"
      },
      # Statement 1: the server can ADD files under evidence/ only. It cannot
      # read, list or delete, so a compromised server cannot wipe or change
      # existing evidence.

      {
        Sid      = "UseKeyForEvidenceEncryption"
        Effect   = "Allow"
        Action   = "kms:GenerateDataKey"
        Resource = var.kms_key_arn
      }
      # Statement 2: with SSE-KMS, S3 asks KMS for a data key on the uploader's
      # behalf, so the uploader needs kms:GenerateDataKey on the key. Only that
      # action, only this key. It cannot decrypt anything.
    ]
  })
}
# Custom policy for the daily check script (same as the console build).
# Works together with the key policy's "Enable IAM User Permissions" statement.

resource "aws_iam_role" "instance" {
  name        = "${var.name_prefix}-instance-role"
  description = "Role for the CIS hardened server"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}
# The role.
# assume_role_policy is the TRUST policy: WHO can take on this role. Only the
#   EC2 service, so only an EC2 instance can use it, never a person.
#   The permission policies (attached below) say WHAT the role can do.
# In the console, choosing "AWS service, EC2" wrote this trust policy for you.

resource "aws_iam_role_policy_attachment" "instance" {
  for_each = {
    ssm        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    cloudwatch = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    evidence   = aws_iam_policy.evidence_upload.arn
  }

  role       = aws_iam_role.instance.name
  policy_arn = each.value
}
# Attaches the three permission policies to the role.
# for_each creates one attachment per line in the map, so three attachments
#   are written once. each.value is the policy ARN on that line.
# The two AWS managed policies have "aws" where the account ID normally goes,
#   because AWS owns them.

resource "aws_iam_instance_profile" "instance" {
  name = aws_iam_role.instance.name
  role = aws_iam_role.instance.name
}
# Instance profile: the container that actually attaches a role to an EC2
# instance. The console created it silently with the same name as the role.
# Terraform makes it a separate resource. The server (T7) is launched with it.
