# Performance Considerations for the Nginx Ingress Controller

## Table of contents

## Introduction

When we talk about performance in general, there are two key points that need to be addressed:

- Operating System level tuning.
- Application level tuning.

`Nginx` performance depends on a few key parameters related to the underlying operating system (`Linux` kernel usually). `DigitalOcean` is using `Linux` as the main `OS` for the `Kubernetes` worker nodes, so you can tune `kernel` parameters via the [sysctl](https://kubernetes.io/docs/tasks/administer-cluster/sysctl-cluster) interface.

`Linux` kernel parameters that affect `Nginx` performance in general:

- File descriptors limit.
- Connection queue size.
- Ephemeral ports range.

On the other hand, you can adjust some parameters at the application level, meaning `Nginx` itself:

- Worker processes.
- Keepalive connections.
- Access logging.
- Limits.
- Caching and compression.

## Prerequisites

## Tuning Linux Kernel Parameters

## Tuning Nginx Configuration
