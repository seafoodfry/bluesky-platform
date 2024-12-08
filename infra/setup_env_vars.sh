#!/bin/sh

export TF_VAR_my_ip=$(curl https://cloudflare.com/cdn-cgi/trace | grep ip | awk -F= '{print $2}')
export TF_VAR_eks_access_iam_role=$(op run --no-masking --env-file=tf.env -- printenv ROLE)
export TF_VAR_github_username=$(op read "op://eng-vault/flux-github-pat/username")
export TF_VAR_github_token=$(op read "op://eng-vault/flux-github-pat/credential")
export TF_VAR_gpg_key_id=$(op read "op://eng-vault/gpg-signing-key/key_id")
export TF_VAR_gpg_key_ring=$(op read "op://eng-vault/gpg-signing-key/key_ring")