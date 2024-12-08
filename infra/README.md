# Infra

## Usage

Commands to get things up and running
```
./run-cmd-in-shell.sh terraform init

. ./setup_env_vars.sh 

./run-cmd-in-shell.sh terraform plan -out a.plan

./run-cmd-in-shell.sh terraform apply a.plan
```

Once you got the cluster running, get your kubeconfig:
```
./run-cmd-in-shell.sh aws eks update-kubeconfig --region us-east-1 --name platform
```

To clean up
```
. ./setup_env_vars.sh

./run-cmd-in-shell.sh terraform destroy -auto-approve
```

### Shells

The script `./run-cmd-in-shell.sh` will run one command per invokation.
We created
- [`exec-shell-with-envvars.sh`](./exec-shell-with-envvars.sh) to be executed as `./exec-shell-with-envvars.sh` and provide a brand new shell to run multiple commands under the same temporary STS role creds.
- [`source-envars-for-shell.sh`](./source-envars-for-shell.sh) to be executed as `. ./source-envars-for-shell.sh` to source the necessary env vars to run AWS commands under a temporary STS session.
    - If you installed the [AWS CLI 1Password plugin](https://developer.1password.com/docs/cli/shell-plugins/aws/) you'll need to uncomment the line in your `~/.zshrc` or `~/.bashrc` file where you first source `~/.config/op/plugins.sh`. Otherwise the AWS cli will always be picking up the default IAM user you set it up with.
    - We discovered this thanks to `aws configure list`.


---
# GPG Keys

GitHub has these docs on how to do it
[Generating a new GPG key](https://docs.github.com/en/authentication/managing-commit-signature-verification/generating-a-new-gpg-key).

To create a key:
```
gpg --full-generate-key
```

Or in one go with:

```
gpg --batch --generate-key <<EOF
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: sign
Name-Real: Flux
Name-Comment: signing key
Name-Email: 99568361+seafoodfry@users.noreply.github.com
Expire-Date: 7d
%no-protection
EOF
```

You can list them by running:

```
gpg --list-secret-keys --keyid-format=long
```

and to delete them:

```
# You must delete the secret key first before you can delete the public key.

gpg --delete-secret-key $KEY_ID

gpg --delete-key $KEY_ID
```

Then you can get the public part by running:

```
gpg --armor --export $KEY_ID
```

And to get the key ring for TF:

```
gpg --export-secret-keys --armor $KEY_ID
```

---
# EBS CSI Driver

## Dynamic Storage Provisioning
```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3 # Specify EBS volume type
  fsType: ext4
  encrypted: "true"
```

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ebs-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-sc
  resources:
    requests:
      storage: 20Gi
```

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: app-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - mountPath: "/data"
      name: ebs-volume
  volumes:
  - name: ebs-volume
    persistentVolumeClaim:
      claimName: ebs-pvc
```

## CSI Snapshot Controller

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapshot-class
driver: ebs.csi.aws.com
deletionPolicy: Delete # Or Retain
```

Create a Volume Snapshot

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: ebs-volume-snapshot
spec:
  volumeSnapshotClassName: ebs-snapshot-class
  source:
    persistentVolumeClaimName: ebs-pvc
```

Restore a Snapshot to a New PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  dataSource:
    name: ebs-volume-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-sc
  resources:
    requests:
      storage: 20Gi
```

Automated Backups

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-snapshot-job
spec:
  schedule: "0 2 * * *" # Runs daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: snapshot-creator
            image: ebs-snapshot-tool:latest # Replace with your snapshot automation image
          restartPolicy: OnFailure
```