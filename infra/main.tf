terraform {
  backend "s3" {
    bucket = "seafoodfry-tf-backend"
    key    = "bluesky-platform"
    region = "us-east-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.76"
    }
  }

  required_version = "~> 1.9.8"
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
