# https://github.com/terraform-aws-modules/terraform-aws-eks
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  #version = "~> 20.31"

  cluster_name    = "platform"
  cluster_version = "1.31"

  cluster_endpoint_public_access = true
  cluster_endpoint_public_access_cidrs = ["${var.my_ip}/32"]

  enable_cluster_creator_admin_permissions = false

  enable_irsa = true

  authentication_mode = "API"

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id 
  subnet_ids = module.vpc.private_subnet_arns
}