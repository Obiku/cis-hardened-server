# =============================================================================
# MODULE: evidence  (console Phase 2, steps 2 and 3)
# =============================================================================
# Builds the bucket the daily CIS check uploads its evidence to:
#   private, no ACLs, versioned, encrypted with the project KMS key, and a
#   bucket policy that denies non-HTTPS requests and the wrong encryption.
#
# In the console all of this was one bucket page. In Terraform each setting
# is its own resource that points at the bucket.
# =============================================================================

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = { Name = var.bucket_name }
}
# The bucket.
# force_destroy: lets "terraform destroy" delete the bucket even when it holds
#   evidence files and old versions. Right for a lab that is destroyed at T11.
#   In a real environment this stays false so evidence cannot be wiped by
#   mistake.

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
# ACLs disabled: only policies control access (console "Object Ownership").

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}
# Block all public access: all four settings ON.

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}
# Versioning: overwritten or deleted evidence is kept as an old version.

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}
# Default encryption: SSE-KMS with the project key.
# bucket_key_enabled: S3 uses one short-lived bucket key for many files, so
#   fewer KMS calls and lower cost.

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      # Statement 1: deny every request that does not use HTTPS.

      {
        Sid       = "DenyWrongEncryption"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.this.arn}/*"
        Condition = {
          StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" }
          Null            = { "s3:x-amz-server-side-encryption" = "false" }
        }
      }
      # Statement 2: deny uploads that send an encryption header (Null = false)
      # AND ask for something other than KMS. Both conditions must be true.
      # No header at all is allowed, and the bucket default (KMS) applies.
      # This is the fixed version: the first console version used
      # StringNotEqualsIfExists, which wrongly denied uploads with no header.
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}
# Bucket policy: two Deny statements, the same as the console build. Only
# Deny statements; the server's Allow comes from IAM at T5.
# depends_on: apply the policy after public access is blocked, so the bucket
#   is never briefly open while it is being built.
