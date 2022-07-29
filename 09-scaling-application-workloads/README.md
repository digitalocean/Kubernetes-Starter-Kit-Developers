# How to Automatically Scale Application Workloads

## Overview

When starting with `Kubernetes`, you definitely learned about the basic unit it can handle - a `Pod`. A Pod by itself doesn't offer any interesting features, rather than the most basic task of running your application inside containers (e.g. `Docker`). Going further, Kubernetes also offers a shared network space for your application Pods to communicate. Then, shared storage space is provided as well, via volumes. Think of a Pod as a single instance of a virtual machine running your custom application.

Going back to practice and real world scenarios, you discovered that just a single Pod is not quite useful by itself. It does provide some abstractions to help you run your workloads but still, there's a missing piece from the puzzle to make your applications more resilient to system failures.

Kubernetes is back to the rescue and provides a rich set of objects (or resources) to work with and overcome these limitations. It offers you more advanced features and possibilities, like: `ReplicaSets`, `Deployments`, `StatefulSets`. The most important feature offered is the ability to run multiple instances of your application, and create high availability configurations.

This is nice and gives you confidence that your application is up and running no matter what. But you will soon discover that the aforementioned features that Kubernetes has to offer, are somehow rigid in their nature. Take for example the most used one - the `Deployment` resource. You start to deploy your applications, and configure a fixed replica value in the `Deployment` spec of 2, or even 4. How do you computed those values? Why choose 2 ? Why 4 and not 6, or even 8 just to make sure?

There's a level of uncertainty, and most probably the values are picked by observing how applications respond to load over time. This method is inefficient and implies lots of iterations, such as manually adjusting values over time when applications start to misbehave. And, this is not the only issue - what if the load decreases? Precious resources (such as CPU, RAM) are consumed because your applications do not automatically scale down, which leads to additional costs.

Kubernetes has once again a solution for this limitations. Meet the `HorizontalPodAutoscaler`, or `HPA` for short. Instead of manually changing the replica set value for your application deployments, a dedicated controller (the one sitting behind HPAs) takes care of this task. The HorizontalPodAutoscaler will automatically scale your deployments up or down, based on the load. In other words, applications are scaled on demand.

Horizontal pod scaling means increasing or decreasing the number of replicas (Pods) for an application, as opposed to vertical pod scaling which adjusts resource requests and limits for containers within Pods.

There's also the `Cluster Autoscaler` which deals with adding more hardware resources such as CPU and RAM to your cluster, by adjusting the number of worker nodes.

In the next chapters, you will learn how to use the `HorizontalPodAutoscaler` feature of Kubernetes, as well as the `VerticalPodAutoscaler`. The first one recommended to start with, is the `HorizontalPodAutoscaler`:

| HorizontalPodAutoscaler | VerticalPodAutoscaler |
|:-----------------------------------------------------:|:-----------------------------------------------------:|
| [![HPA](assets/images/hpa-logo.png)](hpa.md) | [![VPA](assets/images/vpa-logo.png)](vpa.md) |
