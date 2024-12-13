# https://github.com/terraform-aws-modules/terraform-aws-eks
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = "platform"
  cluster_version = "1.31"

  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }

  bootstrap_self_managed_addons = true
  cluster_addons = {
    coredns = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      timeouts = {
        create = "3m" # Shorter timeout.
      }
    }
    eks-pod-identity-agent = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    vpc-cni = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      service_account_role_arn    = aws_iam_role.ebs_csi_controller.arn
    }

    snapshot-controller = {
      most_recent                 = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }

  }

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["${var.my_ip}/32"]
  cluster_endpoint_private_access      = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  cluster_encryption_config = {
    "resources" : [
      "secrets"
    ]
  }

  enable_cluster_creator_admin_permissions = false
  authentication_mode                      = "API"
  # See https://aws.amazon.com/blogs/containers/a-deep-dive-into-simplified-amazon-eks-access-management-controls/
  access_entries = {
    cluster_poweruser = {
      principal_arn = var.eks_access_iam_role
      type          = "STANDARD"

      policy_associations = {
        poweruser = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Possible values:
  # "AL2_x86_64" "AL2_x86_64_GPU" "AL2_ARM_64" "CUSTOM" "BOTTLEROCKET_ARM_64" "BOTTLEROCKET_x86_64"
  # "BOTTLEROCKET_ARM_64_NVIDIA" "BOTTLEROCKET_x86_64_NVIDIA" "WINDOWS_CORE_2019_x86_64" "WINDOWS_FULL_2019_x86_64"
  # "WINDOWS_CORE_2022_x86_64" "WINDOWS_FULL_2022_x86_64" "AL2023_x86_64_STANDARD" "AL2023_ARM_64_STANDARD"
  # "AL2023_x86_64_NEURON" "AL2023_x86_64_NVIDIA"
  eks_managed_node_groups = {
    karpenter = {
      ami_type      = "AL2023_ARM_64_STANDARD"
      capacity_type = "SPOT"
      instance_types = [
        "t4g.medium", # ARM
        "c6g.medium", # ARM
        "m6g.medium"  # ARM
      ]

      # NOTE: do keep this with more than 1 node.
      # Ay addon that requires its own nodes WILL ask for a node with these taints.
      min_size     = 1
      max_size     = 3
      desired_size = 2 # Karpenter controller redundancy.

      taints = {
        # This Taint aims to keep just EKS Addons and Karpenter running on this MNG
        # The pods that do not tolerate this taint should run on nodes created by Karpenter
        addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        },
      }

      update_config = {
        max_unavailable_percentage = 33
      }
      enable_capacity_rebalancing = true
    }

    apps = {
      ami_type      = "AL2023_ARM_64_STANDARD"
      capacity_type = "SPOT"
      instance_types = [
        "t4g.medium", # ARM
        "c6g.medium", # ARM
        "m6g.medium"  # ARM
      ]
      min_size     = 2 # Needed when running flux.
      max_size     = 10
      desired_size = 2

      update_config = {
        max_unavailable_percentage = 33
      }
      enable_capacity_rebalancing = true
    }
  }
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.31"

  cluster_name = module.eks.cluster_name

  enable_pod_identity             = true
  create_pod_identity_association = true

  # Attach additional IAM policies to the Karpenter node IAM role.
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}