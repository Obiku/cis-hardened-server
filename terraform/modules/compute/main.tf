# =============================================================================
# MODULE: compute  (console Phases 5 to 8)
# =============================================================================
# Builds the server and everything it needs to set itself up at first boot:
#   EBS encryption by default, the Ubuntu 24.04 instance (private subnet,
#   IMDSv2, encrypted disk, server role), and the boot setup in
#   cloud-init.yaml.tftpl (hardening, daily check, AWS CLI, CloudWatch agent).
# =============================================================================

resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}
# EBS encryption by default for the region: every new disk is encrypted,
# however it is launched. The preventive control added in console Phase 6
# after "Launch more like this" produced an unencrypted disk.
# On "terraform destroy" this is switched back off.

resource "aws_ebs_default_kms_key" "this" {
  key_arn = var.kms_key_arn
}
# The key used for that default encryption: the project key, not the AWS
# managed aws/ebs key. Reset to aws/ebs on destroy.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}
# Finds the newest official Ubuntu 24.04 (noble) image.
# A "data" block only LOOKS UP something that already exists. It creates
# nothing, so it is not counted in the plan's "to add".
# owners: 099720109477 is Canonical, the company behind Ubuntu. Filtering on
#   the owner means a look-alike image from someone else is never picked.

locals {
  agent_config = jsonencode({
    agent = { run_as_user = "root" }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path       = "/var/log/auth.log"
              log_group_name  = "/cis/auth"
              log_stream_name = "{instance_id}"
            },
            {
              file_path       = "/var/log/cis-evidence/*.json"
              log_group_name  = "/cis/evidence"
              log_stream_name = "{instance_id}"
            }
          ]
        }
      }
    }
  })
}
# A local is a named value used inside this module only.
# agent_config: the CloudWatch agent settings from console Phase 8.
#   run_as_user root: needed to read auth.log.
#   auth.log goes to /cis/auth, the evidence files go to /cis/evidence.
#   {instance_id} (single braces) is filled in by the agent itself, so each
#   server gets its own log stream.
#   No retention here: the log groups and their retention belong to the
#   logging module (T6).

resource "aws_instance" "this" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
    kms_key_id  = var.kms_key_arn
  }

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    harden_script = filebase64("${path.module}/../../../scripts/harden.sh")
    check_script  = filebase64("${path.module}/../../../scripts/cis-check.sh")
    agent_config  = base64encode(local.agent_config)
    region        = var.region
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.name_prefix}-server" }

  lifecycle {
    ignore_changes = [ami]
  }
}
# The server (console Phase 5).
# No key_name: there is no key pair. Access is Session Manager only.
# associate_public_ip_address false: private subnet, no public IP.
# metadata_options: IMDSv2 only.
#   http_tokens required: a session token is needed first (blocks the
#     Capital One style credential theft).
#   hop_limit 1: containers or forwarded traffic cannot reach IMDS.
# root_block_device: 8 GiB gp3 disk, encrypted with the project key. Set here
#   AND by the default above, so the disk is encrypted even if one is removed.
# user_data: the boot setup. templatefile reads cloud-init.yaml.tftpl and
#   fills in each ${...} with the values in the map.
#   filebase64 reads the scripts from the scripts folder (three folders up
#   from this module) already base64 encoded. path.module is this folder.
# user_data_replace_on_change: user data only runs at first boot, so if it
#   changes Terraform builds a NEW server instead of keeping the old one with
#   stale setup.
# ignore_changes ami: Canonical publishes new Ubuntu images often. Without
#   this, every new image would make "terraform plan" want to replace the
#   server. To move to a newer image, remove this line or rebuild.
