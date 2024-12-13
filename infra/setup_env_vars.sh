#!/bin/sh

GPG_FILE="${HOME}/.gnupg/secring.gpg"
GPG_OK=1

if [ ! -f "$GPG_FILE" ]; then
    echo "Error: GPG secret keyring not found at $GPG_FILE"
    echo "Please generate a GPG key pair using: gpg --gen-key"
    GPG_OK=0
fi

if [ "$GPG_OK" = "1" ]; then
    # If we don't move it out of ~/.gnupg TF will have issues reading the key ring 'cas of
    # directory permissions.
    mkdir -p /tmp/gpgkey/
    cp "${GPG_FILE}" /tmp/gpgkey/secring.gpg

    export TF_VAR_my_ip=$(curl https://cloudflare.com/cdn-cgi/trace | grep ip | awk -F= '{print $2}')
    export TF_VAR_eks_access_iam_role=$(op run --no-masking --env-file=tf.env -- printenv ROLE)
    export TF_VAR_github_username=$(op read "op://eng-vault/flux-github-pat/username")
    export TF_VAR_github_token=$(op read "op://eng-vault/flux-github-pat/credential")
    # The ID is the thing that appears after the algorithm in:
    # gpg --list-secret-keys # --keyid-format LONG
    # The super long string is the fingerprint.
    export TF_VAR_gpg_key_id=$(op read "op://eng-vault/gpg-signing-key/key_id")
    # Make sure to run:
    # gpg --export-secret-keys > ~/.gnupg/secring.gpg
    export TF_VAR_gpg_key_ring="/tmp/gpgkey/secring.gpg" #"~/.gnupg/secring.gpg"
    export TF_VAR_github_email=$(op read "op://eng-vault/gpg-signing-key/email")
    export TF_VAR_git_branch=$(git branch --show-current)
fi
