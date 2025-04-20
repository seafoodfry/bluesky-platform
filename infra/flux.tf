provider "flux" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
  git = {
    #url    = "https://github.com/seafoodfry/bluesky-platform"
    url    = "ssh://git@github.com/seafoodfry/bluesky-platform.git"
    branch = var.git_branch
    #http = {
    #  username = var.github_username
    #  password = var.github_token
    #}
    ssh = {
      # DO not make the username your actual username!
      # This is meant for a deploy key, and it you do use something other than `git`, then you'll get something like:
      # could not clone git repository: unable to clone 'ssh://USERNAME@github.com/seafoodfry/bluesky-platform.git':
      # ssh: handshake failed: ssh: unable to authenticate, attempted methods [none publickey], 
      # no supported methods remain.
      username    = "git"
      private_key = var.github_deploy_private_key
    }
    gpg_key_ring = var.gpg_key_ring
    gpg_key_id   = var.gpg_key_id
    author_email = var.github_email
  }
}

resource "flux_bootstrap_git" "this" {
  delete_git_manifests = true
  keep_namespace       = true
  path                 = "kube/clusters/platform"
  # See https://github.com/fluxcd/flux2
  version = "v2.5.1"
  # Borrow the EKS addon nodes.
  toleration_keys = ["CriticalAddonsOnly"]
}