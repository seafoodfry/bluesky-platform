# Design: An EKS cluster

# Summary

We created a platform on top of EKS.
The EKS cluster has a single managed node group.
The node group spins up nodeswith taints that will only allow EKS addons along with [flux](https://fluxcd.io/)
and [karpenter](https://karpenter.sh/).

Flux is installed via its Terraform provider and it uses the contents of `kube/platform` to deploy different workloads.
There are only two workloads we currently implement: 

1. Karpenter, a Karpenter EC2NodeCLass, and a Karpenter NodePool
2. A test pod and deployment running ubuntu and executing the command `sleep infinity`

We also provide utility scripts to create a shell terminal with temporary IAM role credentials.
The magic here is that we make use of 1Password to manage the corresponding IAM user creds, so these scripts rely on
`op` CLI mechanics.
Same with our Terraform management scripts.


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
