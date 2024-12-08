provider "flux" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
  git = {
    url    = "https://github.com/seafoodfry/bluesky-platform"
    branch = "valkey" # "main"
    http = {
      username = var.github_username
      password = var.github_token
    }
    gpg_key_ring = var.gpg_key_ring
    gpg_key_id   = var.gpg_key_id
  }
}

resource "flux_bootstrap_git" "this" {
  delete_git_manifests = true
  keep_namespace       = true
  path                 = "kube/platform"
  # See https://github.com/fluxcd/flux2
  version = "v2.4.0"
  # Borrow the EKS addon nodes.
  toleration_keys = ["CriticalAddonsOnly"]
}