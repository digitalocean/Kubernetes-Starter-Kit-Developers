# Overview

The concept of Secrets refers to any type of confidential credential that requires privileged access with which to interact. These objects often act as keys or methods of authentication with protected computing resources in secure applications, tools, or computing environments. If Kubernetes Secrets are not used, the credentials are hardcoded in the application code or could be saved in a file. This application code when pushed to Source Code Management systems will have credentials hardcoded in it. This is not at all recommended, as the credentials can be compromised.

A Secret is an object that contains a small amount of sensitive data such as a password, a token, or a key. Such information might otherwise be put in a Pod specification or in a container image. Using a Secret means that you don't need to include confidential data in your application code.

In a distributed computing environment it is important that containerized applications remain ephemeral and do not share their resources with other pods. This is especially true in relation to PKI and other confidential resources that pods need to access external resources. For this reason, applications need a way to query their authentication methods externally without being held in the application itself.

Kubernetes offers a solution to this that follows the path of least privilege. Kubernetes Secrets act as separate objects which can be queried by the application Pod to provide credentials to the application for access to external resources. Using Secrets gives you control over how sensitive data is used, and reduces the risk of exposing the data to unauthorized users.

Kubernetes Secrets can be used in three main ways:

- As [files](https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets-as-files-from-a-pod) in a volume mounted on one or more of its containers.
- As [container environment variable](https://kubernetes.io/docs/concepts/configuration/secret/#using-secrets-as-environment-variables).
- By the [kubelet when pulling images](https://kubernetes.io/docs/concepts/configuration/secret/#using-imagepullsecrets) for the Pod.

During this chapter you will install and configure one of the two ways of handling Kubernetes Secrets and those are `Sealed Secrets` and `External Secrets Operator`.

Please pick one from the below list:

| Sealed Secrets | External Secrets Operator |
|:-----------------------------------:|:---------------------------------------------------------:|
| [Sealed Secrets](sealed-secrets.md) | [External Secrets Operator](external-secrets-operator.md) |
