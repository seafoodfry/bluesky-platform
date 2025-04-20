terraform {
  backend "s3" {
    bucket       = "seafoodfry-tf-backend"
    key          = "bluesky-platform"
    region       = "us-east-2"
    use_lockfile = true
    # TODO: dyanmi state locking has been deprecated. We should remove it.
    #dynamodb_table = "terraform-state-lock"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.95"
    }
    # https://registry.terraform.io/providers/fluxcd/flux/latest/docs
    flux = {
      source  = "fluxcd/flux"
      version = "~> 1.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }

  required_version = "~> 1.11"
}

# EC2 types https://aws.amazon.com/ec2/instance-types/
# Spot costs https://aws.amazon.com/ec2/spot/pricing/

provider "aws" {
  #alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_east_2"
  region = "us-east-2"
}

# resource "aws_dynamodb_table" "terraform_lock" {
#   name           = "terraform-state-lock"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "LockID"

#   attribute {
#     name = "LockID"
#     type = "S"
#   }
# }
