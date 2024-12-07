#!/bin/sh
#
# Note that when relying on the 1pass shell plugin inside of a script we do have to prefix commands
# with `op plugin run --`.
# We are explicitly not using AWS_PROFILE because otherwise the aws cmds will not work.
#
# Also, remember that one of the steps in installing the AWS CLI 1Password plugin involves
# something along the lines of
# echo "source ~/.config/op/plugins.sh" >> ~/.zshrc && source ~/.zshrc
# So make sure to uncomment this!
# xref: https://developer.1password.com/docs/cli/shell-plugins/aws/
#
# We discovered the above issue with the help of `aws configure list`.
set -e

SESSION_TIME=1800

ROLE=$(op run --no-masking --env-file=tf.env -- printenv ROLE)

OUT=$(op plugin run -- aws sts assume-role  --duration-seconds $SESSION_TIME --role-arn $ROLE --role-session-name test)

export AWS_ACCESS_KEY_ID=$(echo $OUT | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $OUT | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $OUT | jq -r '.Credentials.SessionToken')
