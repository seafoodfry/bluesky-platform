# Design: An EKS cluster

# Summary

We created a platform on top of EKS.
The EKS cluster has a single managed node group.
The node group spins up nodes with taints that will only allow EKS addons along with [flux](https://fluxcd.io/)
and [karpenter](https://karpenter.sh/).

Flux is installed via its Terraform provider and it uses the contents of `kube/clusters/platform` to deploy
different workloads.
There are only two workloads we currently implement: 

1. Karpenter, a Karpenter EC2NodeCLass, and a Karpenter NodePool
2. A test pod and deployment running ubuntu and executing the command `sleep infinity`

We also provide utility scripts to create a shell terminal with temporary IAM role credentials.
The magic here is that we make use of 1Password to manage the corresponding IAM user creds, so these scripts rely on
`op` CLI mechanics.
Same with our Terraform management scripts.


In general, we want to manage all kube resources via GitOps.
But just adding your YAML and elmReleases to a directory for flux to apply does not make for an indepotent system.
This becomes obvious when you bootstrap a new environment.

For example, when trying to configure a Karpenter NodePool resource we came across this error in the kustomize-controller
pod:

```
{
    "level":"error",
    "ts":"2024-12-14T15:33:18.180Z",
    "msg":"Reconciliation failed after 1.161220852s, next try in 10m0s",
    "controller":"kustomization",
    "controllerGroup":"kustomize.toolkit.fluxcd.io",
    "controllerKind":"Kustomization",
    "Kustomization":{"name":"flux-system","namespace":"flux-system"},
    "namespace":"flux-system",
    "name":"flux-system",
    "reconcileID":"05c2cd5b-c0a3-4246-8b1b-7b2a95501d5f","revision":"platform-tuning@sha1:f45da305f9133345f18b88dfc7e0f40db0ab3625",
    "error":"EC2NodeClass/default dry-run failed: no matches for kind \"EC2NodeClass\" in version \"karpenter.k8s.aws/v1\""
}
```

The way to apply gitops in an indepotent manner is to follow the tips of
[github.com/fluxcd/flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example/tree/main).

Where it outlines how to separate your apps, from "cluster manager apps", from resources that depend on said
"cluster manager apps" being already installed.

---
# Motivation

We want an environment for development, testing, and running workloads that is relatively easy to spin up but robust.
We also want to document common patterns (reuse, reduce, recycle).

## Goals

- A cluster with on-demand (ha!) compute
- Workload resources managed via GitOps (there is such a thing as too much TF - the author believes)

## Non-Goals

- Showcase every possible thing one can do in Kube


---
# Design Details

## Infrastructure

When creating the cluster and the VPC, you need to properly tag subnets and security groups with `karpenter.sh/discovery = CLUSTER_NAME` in order to be discoverable by Karpenter.

Also, the same people who maintain the EKS TF module maintain a module for Karpenter.
Said module will provision all the infra you need. Use it.

We also added Cloudtrail resources because feeding cloudtrail logs into cloudwatch and then using Cloudwatch Log Insights
to make queries makes for a very handy and easy way to debug AWS permission issues.
We used to to figure out an issue with our Pod Identity mapping for the Karpenter controller h=which failed ebcause it was not able to find the interruption SQS queue.

The EKS cluster we provision also enables the public endpoint access but it only allows traffic from your current IP address.
All other cluster traffic will go through the private endpoint.

Along with that, we only enable "API" as the authentication mode to get rid of the config map that allows very
inconvenient permissions to unauthenticated users from being done via kube API calls.
With this method only IAM entities will be granted access, and these identities can readily be observed and managed via AWS
resources.

Lastly, we only provision a managed node group for the core system controllers to run on.
We will have flux run, and then have it installed karpenter.
Karpenter will then have a default NodePool that will provision spot ARM instances for any other apps we run.

## Flux and GitOps

We followed the outline of
[github.com/fluxcd/flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example/tree/main).
to bootstrap our cluster with Karpenter and a sample app.

In our implementation, flux synchronizes things in `kube/clusters/platform`.
This directory then defines `Kustomization` resources that bring in all the rest of our apps.

Our apps are devided into:

1. Cluster controllers: things that every cluster should run (i.e., Karpenter).
    1. These are under `kube/infra/controllers`
2. Infra configs: things that rely on cluster controllers existing and that provide additional infra (i.e., EC2NodeClasses and NodePools)
    1. These are under `kube/infra/configs`
3. Our apps
    1. We have a "base" definitions in `kube/apps/base`
    2. Each has a `kustomization.yaml` file that must be updated each time a resource is added
    3. Patchng of the base apps is done under `kube/apps/CLUSTER_NAME` via `Kustomization` resources

## Risks ad Mitigations

We aim to protect personal and identifiable information about the user spining up the cluster.
We also aim to protect the AWS account ID of the account being used.
Thus, any such information is obtained from 1Password via the `op` CLI.


## Costs

1. We provision the cluster using a standard support policy, so $0.10 per cluster per hour.
2. We have 1 NAT gateway which costs $0.045 per hour.
3. NAT gateways charge $0.045 per GB data processed.
    1. We reduce some of the charges by enabling the private EKS endpoint.
4. We have 3 spot instances managed by the managed node group and at least 1 by karpenter.
    1. We've been observing mostly C6 instances. The most expensive C6 instance we've seen is about $0.03 per hour.
    So it is about $0.12 per hour.
5. Cloudtrail events are charged as $2.00 per 100,000 management events delivered and $0.10 per 100,000 data events delivered.
    1. Let's guesstimate this as $2.1 per day.

In total: 0.1 (cluster) + 0.045 (NAT existing) + 0.12 (nodes) = 0.265 / hour.
Plus $2 ish for cloudtrail.
So let's leave it at about $7 / day. 

References:

1. https://aws.amazon.com/eks/pricing/
2. (NAT gateway pricing) https://aws.amazon.com/vpc/pricing/
3. https://aws.amazon.com/cloudtrail/pricing/

## Test Plans

The workspace is defined to manage everything from the current branch.
So we test the creation and destruction multiple times per PR.


## Graduation Criteria

We want to have our own workloads gathering data, training machine learnign models, and testing them end-to-end.


---
# Production Readiness

- [ ] Document how to patch common fields in different workloads using kustomizations.
- [ ] Document how to do development in the cluster.

---
# Implementation History

- [x] basic EKS cluster using the popular TF module
- [x] flux running and configured
- [x] karpenter running and configured via flux

---
# Drawbacks

People have to become acquainted with kustomizations.

---
# Alternatives

We could keep using our [ml-workspace: GPU sandbox](https://github.com/seafoodfry/ml-workspace/tree/main/gpu-sandbox)
environment but defining workloads on kubernetes is more reliable and reproducible.

Another smaller thing to notice is that we could bootstrap Karpenter via Terraform by using something like

```hcl
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
```

Then we could use flux in a more simplistic manner by just putting all files without kustomization in some directory.


---
# Insfrasturcture Needed

- VPC
- EKS cluster
- EKS Managed Node Group
- Cloudtrail
- S3 bucket for cloudtrail
- CLoudwatch log group for cloudtrail events
- 1Password vaults for IAM user creds, GPG key associated with your GitHub Account, a personal access token (classic)
    for your GitHub account.