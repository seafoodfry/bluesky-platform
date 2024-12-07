#!/bin/sh
#
# Note that when relying on the 1pass shell plugin inside of a script we do have to prefix commands
# with `op plugin run --`.
# We are explicitly not using AWS_PROFILE because otherwise the aws cmds will not work.
set -e

SESSION_TIME=1800

ROLE=$(op run --no-masking --env-file=tf.env -- printenv ROLE)

OUT=$(op plugin run -- aws sts assume-role  --duration-seconds $SESSION_TIME --role-arn $ROLE --role-session-name test)

# Create a temporary file for the credentials.
CREDS_FILE=$(mktemp)
cat > "$CREDS_FILE" << EOF
export AWS_ACCESS_KEY_ID=$(echo $OUT | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $OUT | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $OUT | jq -r '.Credentials.SessionToken')
EOF

# Source the credentials and clean them up
source "$CREDS_FILE"
rm "$CREDS_FILE"

# Launch a clean shell with the AWS credentials.
# Uses env -i to start with a clean environment.
# Preserves essential vars (HOME, PATH, and TERM for proper terminal behavior)
# Tries zsh first, falls back to bash if not found
# Uses --no-rcs which works in both shells to prevent loading any RC files
echo "Starting clean shell with AWS credentials..."
env -i \
    HOME=$HOME \
    PATH=$PATH \
    TERM=$TERM \
    AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
    $(which zsh || which bash) --no-rcs

echo "AWS session ended."
