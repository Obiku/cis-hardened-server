# =============================================================================
# MODULE: logging  (console Phase 4, plus the log groups from Phase 8)
# =============================================================================
# Builds where the server's logs go, before the server exists:
#   /cis/ssm-sessions : who typed what in Session Manager
#   /cis/auth         : logins and sudo on the server (CloudWatch agent)
#   /cis/evidence     : the daily CIS check results (CloudWatch agent)
# and the Session Manager preferences that send sessions to /cis/ssm-sessions.
# =============================================================================

resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(["ssm-sessions", "auth", "evidence"])

  name              = "/cis/${each.value}"
  retention_in_days = var.retention_days
  kms_key_id        = var.kms_key_arn
}
# The three log groups, all encrypted with the project key, 7-day retention.
# for_each creates one log group per name in the set. each.value is the name.
# kms_key_id: works because of the key policy statement that allows the
#   CloudWatch Logs service for /cis/* (written at T4).
# retention_in_days: the default is "never expire", which keeps logs and cost
#   forever. 7 days is enough for the lab.
# In the console, /cis/auth and /cis/evidence were created by the CloudWatch
#   agent in Phase 8. Creating them here first means they are encrypted, have
#   retention set, and are removed by "terraform destroy".

resource "aws_ssm_document" "session_preferences" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Session Manager preferences for the CIS hardened server"
    sessionType   = "Standard_Stream"
    inputs = {
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.this["ssm-sessions"].name
      cloudWatchEncryptionEnabled = true
      cloudWatchStreamingEnabled  = true
      idleSessionTimeout          = "15"
      maxSessionDuration          = "60"
      s3BucketName                = ""
      s3KeyPrefix                 = ""
      s3EncryptionEnabled         = true
      kmsKeyId                    = ""
      runAsEnabled                = false
      runAsDefaultUser            = ""
      shellProfile = {
        windows = ""
        linux   = "cd $HOME\nexec /bin/bash"
      }
    }
  })
}
# Session Manager preferences (console: Session Manager, Preferences, Edit).
# The console saves them as an SSM document with this exact name. Session
#   Manager looks for that name, so it cannot be changed.
# cloudWatchLogGroupName: every session is logged to /cis/ssm-sessions.
# cloudWatchEncryptionEnabled: sessions are only allowed if the log group is
#   encrypted.
# cloudWatchStreamingEnabled: commands are sent to the log as they happen, not
#   only when the session ends.
# idleSessionTimeout / maxSessionDuration: minutes. Closes forgotten sessions
#   and limits how long any session can stay open.
# S3 logging, KMS session encryption and Run As: OFF, as in the console build
#   (empty values or false).
# shellProfile linux: runs at the start of every session. \n is a new line, so
#   it is two commands: go to the home folder, then start bash.
# These preferences apply to every instance in the region.
