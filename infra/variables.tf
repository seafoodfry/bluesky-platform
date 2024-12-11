data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

variable "my_ip" {
  type      = string
  sensitive = true
}

variable "eks_access_iam_role" {
  type        = string
  description = "IAM role ARN to be granted access to the EKS cluster"
  sensitive   = true
}

variable "github_username" {
  type        = string
  sensitive   = true
  description = "Used by flux to authenticate"
}

variable "github_token" {
  type        = string
  sensitive   = true
  description = "Used by flux to authenticate"
}

variable "github_email" {
  type        = string
  sensitive   = true
  description = "Used by flux to generate signed commits"
}

variable "git_branch" {
  type        = string
  default     = "main"
  description = "Used by flux to figure out what branch will drive deployments"
}

variable "gpg_key_id" {
  type = string
}

variable "gpg_key_ring" {
  type      = string
  sensitive = true
}