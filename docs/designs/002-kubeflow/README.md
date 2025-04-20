# Design: ML with Kubeflow

# Summary

We want to make use of kubeflow to design a full ML platform.


---

# Motivation

The following comparisons are made against the
[github.com/seafoodfry/ml-workspace/gpu-sandbox](https://github.com/seafoodfry/ml-workspace/tree/main/gpu-sandbox)
way:
1. Doing a couple of experiments is aok, but juggling multiple terminals, SSH, and tmux sessions can get confusing
1. Testing different architectures can be slow
1. Hyperparameter searches require extra work
1. We haven't integrated the use of EFS for restarts
1. We hardcode model restarts into our training code in ways that are inconsistent
1. We pray that our spot instances don't get interrupted before we have rsync'd

## Goals

We want to explore all of the above in kubeflow

## Non-Goals

We will be pursuing a variety of experiments and models so no specific functionality will be pursued.


---

# Design Details