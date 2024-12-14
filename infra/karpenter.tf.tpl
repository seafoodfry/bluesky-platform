provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# data "aws_ecrpublic_authorization_token" "token" {}

resource "helm_release" "karpenter" {
  depends_on = [module.eks]

  namespace  = "kube-system"
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  #   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  #   repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart   = "karpenter"
  version = "1.1.0"
  wait    = true

  create_namespace = false

  # Lower resources than normal because the node pools we created use small EC2s.
  values = [
    <<-EOT
dnsPolicy: Default
settings:
    clusterName: ${module.eks.cluster_name}
    interruptionQueue: ${module.karpenter.queue_name}
controller:
    resources:
        requests:
            cpu: "300m"
            memory: "300Mi"
EOT
  ]
}