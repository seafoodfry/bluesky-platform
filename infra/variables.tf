data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

variable "my_ip" {
  type = string
}

variable "eks_access_iam_role" {
  type        = string
  description = "IAM role ARN to be granted access to the EKS cluster"
}