#!/bin/sh

export TF_VAR_my_ip=$(curl https://cloudflare.com/cdn-cgi/trace | grep ip | awk -F= '{print $2}')
export TF_VAR_eks_access_iam_role=$(op run --no-masking --env-file=tf.env -- printenv ROLE)
