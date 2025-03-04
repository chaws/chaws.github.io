---
layout: post
title:  "AWS EKS+Fargate bug"
date:   2020-08-07 07:41:10 -0300
categories: en linux kubernetes
---

# Introduction

The purpose of this post is to expose a bug (at least I think it's a bug) with Fargate + AWS EKS. The bug appears when a pod running on Fargate is OOMKilled multiple times. The pod is restarted over and over as expected but at some point, it loses networking configuration.

# How to reproduce

Here are steps to reproduce it:

* [Create an EKS cluster](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html)
* [Create a fargate profile](https://docs.aws.amazon.com/eks/latest/userguide/fargate-getting-started.html)
  * Create it for `default` namespace
* Run two pods in `default` namespace
* Make the second pod ping the first one, and leave it there
* In the first pod, use all available memory
  * It's easier when you have python installed: `python3 -c "bytearray(512000000)"`
  * K8s will OOMKill it, and it should be restarted automatically
  * Repeat steps above until you see the ping in the second pod stop working

## Pod manifest

I'm using the following pod manifest:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: root-shell
spec:
  containers:
  - command:
    - /bin/cat
    image: docker.io/library/alpine
    # Make two files and pick a different name for the second pod
    name: root-shell
    resources:
      limits:
        memory: 64Mi
        cpu: 50m
```


# What I already tried

There are a few blog posts that attempt getting node shell thru privileged pods. Those won't work on Fargate due to its serverless principle. Also having pods with hostNetwork does not work :(

Bottom line, I don't really know how to debug a serverless node. Maybe I'm missing something? Any help is welcome!


Thanks for your time and attention.

Chaws
