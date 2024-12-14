# Design: An EKS cluster

# Summary

We created a platform on top of EKS.
The EKS cluster has a single managed node group.
The node group spins up nodes with taints that will only allow EKS addons along with [flux](https://fluxcd.io/)
and [karpenter](https://karpenter.sh/).

Flux is installed via its Terraform provider and it uses the contents of `kube/platform` to deploy different workloads.
There are only two workloads we currently implement: 

1. ~Karpenter,~ a Karpenter EC2NodeCLass, and a Karpenter NodePool
2. A test pod and deployment running ubuntu and executing the command `sleep infinity`

We also provide utility scripts to create a shell terminal with temporary IAM role credentials.
The magic here is that we make use of 1Password to manage the corresponding IAM user creds, so these scripts rely on
`op` CLI mechanics.
Same with our Terraform management scripts.


In general, we want to manage all kube resources via GitOps.
But this makes the management of non-default resources turn into a recipe-driven method (there is some fancy way of saying this but the word is not coming to me right now).

**Update:** As of December 2024, Flux is not smart enough to bootstrap entire environments

But what it means is that flux will fail to install itself because the kustomize controller will continuously throw errors
such as this one because the resources it is trying to manage do not yet exist:
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

Because of that, we are managing karpenter via Terraform, with the Helm provider, instead.

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




## Risks ad Mitigations

We aim to protect personal and identifiable information about the user spining up the cluster.
We also aim to protect the AWS account ID of the account being used.
Thus, any such information is obtained from 1Password via the `op` CLI.


## Costs



## Test Plans


## Graduation Criteria



---
# Production Readiness



---
# Implementation History


---
# Drawbacks


---
# Alternatives



---
# Insfrasturcture Needed
