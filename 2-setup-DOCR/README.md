## Set up DigitalOcean Container Registry

You need a container registry, such as Docker Hub or DigitalOcean Container Registry (DOCR), when you need to build a container image and deploy it to the cluster. The cluster can pull images from a configured registry. Here, we will set up a DOCR for our cluster.

```
~ doctl registry create bg-reg-1 --subscription-tier basic
Name        Endpoint
bg-reg-1    registry.digitalocean.com/bg-reg-1
~ 
```

You can have only 1 registry endpoint per account in DOCR. A `repository` in a `registry` refers to a collection of `container images` using different versions (`tags`). Given that the `DOCR` registry is a private endpoint, we need to configure the `DOKS` cluster to be able to fetch images from the `DOCR` registry.

```
~ doctl registry kubernetes-manifest | kubectl apply -f -
secret/registry-bg-reg-1 created
~ k get secrets registry-bg-reg-1
NAME                TYPE                             DATA   AGE
registry-bg-reg-1   kubernetes.io/dockerconfigjson   1      13s
~
```

This creates the above secret in the `default` namespace. 

**Next steps**

This concludes the `DOCR` setup. In the next section, you will learn how to set up an `Ingress` controller and some sample `backend` applications to serve content from, by making use of the `Ambassador Edge Stack` solution.

Go to [Section 3 - Ingress using Ambassador](../3-setup-ingress-ambassador)
