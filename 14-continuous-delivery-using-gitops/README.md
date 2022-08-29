# GitOps and Continuous Delivery

## Overview

What is [GitOps](https://www.gitops.tech) and why it's important?

The `GitOps` term is not quite new, and most likely you heard about it at some point in time. If not, you will start to hear about it more and more often. In a nutshell, `GitOps` is just a `set of practices` and it focuses around the main idea of having `Git` as the `single source of truth`. It means, you keep all your Kubernetes configuration manifests stored in a `Git` repository. Then, a GitOps tool (such as [Flux CD](https://fluxcd.io) or [Argo CD](https://argoproj.github.io/cd/)) fetches current configuration from the Git repository, and applies required changes to your Kubernetes cluster to maintain desired state.

The GitOps tool continuously watches the current system state (your Kubernetes cluster) and Git repository state. If there's a difference (or deviation) between the two, it will take the appropriate actions to match Git repository state. It means, whenever someone applies manual changes (via `kubectl`) those will be overwritten, and your Kubernetes applications state reverted to reflect current configuration from Git repository. In other words, the Git repository always wins, hence the statement - Git as the single source of truth. This approach has a tremendous advantage, because it eliminates all issues due to manual system changes which cannot be tracked or audited.

So, `GitOps` keeps your system state `synchronized` with a `Git` repository, and works with `infrastructure` that can be `observed` and `described declaratively` (like `Kubernetes`, for example). One of the core ideas of GitOps is letting developers use the tools they are familiar with to operate your infrastructure. The most used source control management today is `Git`, hence the term `GitOps`.

This has many advantages, most important being:

- Simplicity. Every developer should be familiar using Git nowadays.
- Keeping track of extra tools, or learning about new ones is not required anymore.
- Fast recovery. In case something goes wrong and need to revert back to a previous working state, you can rely on Git history.
- Fast auditing. What changed and when? Who is to blame? Git has you covered as well.
- Version control. Easily keep and switch between revisions of your infrastructure.
- Benefit from other important features offered by Git, like pull requests and the ability to perform reviews.

Please bear in mind that a GitOps tool (such as Flux or Argo) is not a replacement for other traditional CI/CD systems (such as Jenkins for example). It is best suited for Kubernetes based systems, and takes advantage of all benefits Kubernetes has to offer, such as extending the Kubernetes API, maintaining applications state via controllers, etc.

You can keep both infrastructure configuration and application code in the same Git repository. Regarding how you keep everything organized and propagate changes to different environments or stages (like INT, QA, UAT, PROD), this is usually a personal preference and not related to GitOps necessarily. On the other hand, GitOps tools can help you setup such configurations and better streamline code propagation to different stages (or environments). For example, you can set up one environment per branch or repository. Or, leverage the power of `Kustomizations` and set up different overlays for each environment using a single Git repository (this is a much more simpler approach, rather than managing multiple repositories and/or branches). There are some guidelines for this matter on the `FluxCD` documentation website, more specifically the [ways of structuring repositories](https://fluxcd.io/docs/guides/repository-structure) page.

You can read and learn more about GitOps in general by visiting [Weaveworks](https://www.weave.works/technologies/gitops/) website, the main creator of `GitOps`.

## Starter Kit GitOps Solutions

In the Starter Kit, you will learn about two of the most popular tools available for implementing GitOps principles:

| Flux CD | Argo CD |
|:---------------------------------------------------:|:---------------------------------------------------:|
| [![flux](assets/images/fluxcd-logo.png)](fluxcd.md) | [![argo](assets/images/argocd-logo.png)](argocd.md) |
