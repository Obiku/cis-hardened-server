# =============================================================================
# TERRAFORM AND PROVIDER SETTINGS
# =============================================================================

terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# The AWS provider. Credentials come from ~/.aws/credentials, the same as the
# AWS CLI. default_tags are added to every resource in every module, so the
# Project, Owner and ManagedBy tags never have to be typed again.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Owner     = var.owner
      ManagedBy = "terraform"
    }
  }
}
