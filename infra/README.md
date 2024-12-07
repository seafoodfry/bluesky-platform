# Infra


Commands to get things up and running
```
./run-cmd-in-shell.sh terraform init

export TF_VAR_my_ip=$(curl https://cloudflare.com/cdn-cgi/trace | grep ip | awk -F= '{print $2}')
export TF_VAR_eks_access_iam_role=$(op run --no-masking --env-file=tf.env -- printenv ROLE)

./run-cmd-in-shell.sh terraform plan -out a.plan

./run-cmd-in-shell.sh terraform apply a.plan
```

To clean up
```
./run-cmd-in-shell.sh terraform destroy
```
