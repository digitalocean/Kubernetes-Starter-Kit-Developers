# How to Install and Configure an Ingress Controller

## Overview

In most of the cases, you will use the `Load Balancer` that is made available by the `Cloud` provider of your choice. In case of `DigitalOcean` when you configure a service as a `Load Balancer`, `DOKS` automatically provisions one in your account. Now, the `service` is exposed to the outside world and can be accessed via the `Load Balancer` endpoint. In a real world scenario, you do not want to use one `Load Balancer` per service, so you need a `proxy` inside the cluster. That is `Ingress`.

When an `Ingress Controller` is installed, it creates a service and exposes it as a `Load Balancer`. Now, you can have as many services behind the ingress and all accessible through a single endpoint. Ingress operates at the `HTTP` layer.

As there are many vendors, `Kubernetes API` has an `Ingress` spec. The idea is that developers should be able to use the `Ingress API` and it should work with any vendor.

`Starter Kit` tutorial lets you explore two of the available ingress solutions: `Ambassador Edge Stack` and `NGINX`. While the first one may not be so popular yet, it has many `powerful features` built-in besides ingress functionality (like `rate limiting`, extra protocols handling: `websockets`, `gRPC`, etc.). `NGINX` on the other hand, is the most `popular` solution and widely adopted by the community, but it has less features, and adding more functionality is not so trivial or easy to achieve. It is more suited for basic HTTP/S routing and SSL termination.

Starter Kit will present you both, using the same structure and steps for each so that you can see how basic ingress functionality is achieved. In the end, you can decide which one suits best your needs.

Without further ado, please pick one to start from below list.

### Starter Kit Ingress Controllers

| Ambassador Edge Stack | Nginx |
|:------------------------------------------------------:|:---------------------------------------------------:|
| [![aes](assets/images/aes-logo.png)](ambassador.md) | [![nginx](assets/images/nginx_ingress-logo.png)](nginx.md) |
