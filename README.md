# Day-2 Operations-ready DOKS (DigitalOcean Kubernetes) for Developers

**WORK-IN-PROGRESS, initial stage**

**TBD- Complete the sections** </br>
**TBD- Opinionated configuration** </br>
**TBD- Automation to set up the stack** </br>

Kubernetes has become really simple to understand and setup. In a way, it has democratized the cloud. With kubernetes, developers can use the identical tooling and configurations across any cloud.

Installing kubernetes is only getting started. Making it operationally ready requires lot more things. The objective of this tutorial is to provide developers an hands-on introduction on how to get started with an operations-ready kubernetes cluster on DO Kubernetes.


# Table of contents
1. [Scope](#SCOP)
2. [Set up DO Kubernetes](#DOKS)
3. [Set up DO Container Registry](#DOCR)
4. [Prometheus monitoring stack](#PROM)
5. [Configure logging using Loki](#LOKI)
6. [Ingress using Ambassador](#AMBA)
7. [Service mesh using Linkerd](#LINK)
8. [Backup using Velero](#VELE)
9. [GitOps using ArgoCD & Sealed Secrets](#ARGO)
10. [Progressive releases using Argo Rollout](#ROLL)
11. [Sample Application with Cloudflare CDN](#APPL)



## Scope <a name="SCOP"></a>
This is meant to be a beginner tutorial to demonstrate the setups you need to be operations-ready. The list is an work-in-progress.

All the steps are done manually using commandline. Additional services listed above serve as examples. You can pick any other tool that suits your requirements better.

None of the installed tools are exposed using ingress or LB. To access the console, we use kubectl port-forward.

We will use brew (on mac) to install the commmands on our local machine. We will skip the how-to-install and command on your local laptop, and focus on using the command to work on DOKS cluster. 

For every tool, we will make sure to enable metrics and logs. At the end, we will review the overhead from all these additional tools. That gives an idea of what it takes to be operations-ready after your first cluster install. 

In future, we may plan to automate this by using terraform to create DO Kubernetes, Registry and Argo CD, and then install rest of the tools using GitOps.<br/><br/>


## Set up DO Kubernetes <a name="DOKS"></a>
Explore doctl options.
```
~ doctl version
doctl version 1.61.0-release
~ doctl auth list
bgdo (current)
default
~ 
```

Explore options for creating the cluster.
```
~ doctl k8s -h
~ doctl k8s options -h
~ doctl k8s options regions
~ doctl k8s options sizes  
~ doctl k8s options versions
~ doctl k8s cluster create -h
```

Let us create a DOKS cluster with 3 worker nodes. Use "--wait false", if you do not want the command to wait until cluster is ready.

```
~ doctl kubernetes cluster create bg-cluster-2 \
--auto-upgrade=false \
--maintenance-window "saturday=21:00" \
--node-pool "name=basicnp;size=s-2vcpu-4gb;count=3;tag=cluster2;label=type=basic;auto-scale=true;min-nodes=3;max-nodes=5" \
--region sfo3 \

Notice: Cluster is provisioning, waiting for cluster to be running
..................................................................
Notice: Cluster created, fetching credentials
Notice: Adding cluster credentials to kubeconfig file found in "/Users/bgupta/.kube/config"
Notice: Setting current-context to do-sfo3-bg-cluster-1
ID                                      Name            Region    Version        Auto Upgrade    Status     Node Pools
0922a629-7f2e-4bda-940c-4d42a3f987ad    bg-cluster-1    sfo3      1.20.7-do.0    false           running    basicnp
~ 
```

Now let us set up kubectl, if the context is not set.

```
~ kubectl config current-context 
do-sfo3-bg-cluster-1
~ 
~ doctl k8s cluster list
ID                                      Name            Region    Version        Auto Upgrade    Status          Node Pools
0922a629-7f2e-4bda-940c-4d42a3f987ad    bg-cluster-1    sfo3      1.20.7-do.0    false           provisioning    basicnp
# YOU MAY NOT NEED THIS COMMAND, IF CONTEXT IS ALREADY SET.
~ doctl kubernetes cluster kubeconfig save 0922a629-7f2e-4bda-940c-4d42a3f987ad
Notice: Adding cluster credentials to kubeconfig file found in "/Users/bgupta/.kube/config"
Notice: Setting current-context to do-sfo3-bg-cluster-1
~ 
~ kubectl get nodes
NAME            STATUS   ROLES    AGE     VERSION
basicnp-865x3   Ready    <none>   2m55s   v1.20.7
basicnp-865x8   Ready    <none>   2m21s   v1.20.7
basicnp-865xu   Ready    <none>   2m56s   v1.20.7
~ 
```

## Set up DO Container Registry <a name="DOCR"></a>
You need a container registry (Docker Hub, DO container registry, etc.) when you need to build a container image and deploy it to the cluster. The cluster can pull images from a configured registry. Here we will set up a DO container registry (DOCR) for our cluster.

```
~ doctl registry create bg-reg-1 --subscription-tier basic
Name        Endpoint
bg-reg-1    registry.digitalocean.com/bg-reg-1
~ 
```

You can have only 1 registry endpoint per account in DOCR. A repository in a registry refers to the collection of a container image with different versions (tags). Given that the DOCR registry is a private endpoint, we need to configure the DOKS cluster to be able to fetch images from the DOCR registry.

```
~ doctl registry kubernetes-manifest | kubectl apply -f -
secret/registry-bg-reg-1 created
~ k get secrets registry-bg-reg-1
NAME                TYPE                             DATA   AGE
registry-bg-reg-1   kubernetes.io/dockerconfigjson   1      13s
~
```

This create the above secret in default namespace. 

## Prometheus monitoring stack <a name="PROM"></a>
We will install kube-prometheus stack using helm, which is an opinionated full monitoring stack for kubernetes. It includes prometheus operator, kube-state-metrics, pre-built manifests, node exporters, metrics api, and alerts manager. 

Helm chart: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

Update helm repo
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Download values.yaml
```
curl https://raw.githubusercontent.com/prometheus-community/helm-charts/main/charts/kube-prometheus-stack/values.yaml -o prom-stack-values.yaml
```

Modify values.yaml file to disable (false) metrics for etcd and kubeScheduler. Those components are managed by DOKS, and are not accessible to prometheus. Note that we're keeping the storage to be emptyDir. It means the storage will be gone if prometheus pods restart.

Install kube-prometheus-stack. 

```
helm install kube-prom-stack prometheus-community/kube-prometheus-stack -n monitoring -f prom-stack-values.yaml --create-namespace --wait
```

Now you can connect to grafana (admin/prom-monitor, see values.yaml) by port forwarding to local machine. Once in, you can go to dashboards - manage, and choose different dashboards. 

```
kubectl --namespace monitoring port-forward svc/kube-prom-stack-grafana 3000:80
```


## Configure logging using Loki <a name="LOKI"></a>
We need loki for logs. Loki runs on the cluster itself as a statefulset. Logs are aggregated and compressed by loki, then sent to the configured storage. Then we can connect loki data source to grafana, and view the logs.

```
helm repo add grafana https://grafana.github.io/helm-charts
helm search repo grafana
```

We are interested in loki-stack (https://github.com/grafana/helm-charts/tree/main/charts/loki-stack), which will install standalone loki on the cluster.

```
curl https://raw.githubusercontent.com/grafana/helm-charts/main/charts/loki-stack/values.yaml -o loki-values.yaml
helm upgrade --install loki --namespace=monitoring grafana/loki-stack -f loki-values.yaml --create-namespace --wait
```

Now connect loki data source to grafana. Go the grafana web console, and add settings - data sources - add - loki. Add loki url "http://loki:3100". Save and test.

Now you can access logs from explore tab of grafana. Make sure to select loki as the data source. Use help button for log search cheat sheet.

## Ingress using Ambassador

### Options for LB and Ingress

You will almost always use the LB provided by the cloud provider. In the case of DO, when you configure a service as an LB, DOKS automatically provisions an LB in your account (unless you configure to use an existing one). Now the service is exposed to outside world and can be accessed through LB endpoint. You do not want to use one LB per service, so you need an proxy inside the cluster. That is ingress.

  

When you install an ingress proxy, it create a service and exposes it as an LB. Now you can have any many services behind ingress, and all accessible through a single LB endpoint. Ingress operates at http layer.

  

Let us say you are exposing REST or GRPC API's for different tasks (reading account info, writing orders, searching orders etc.). Depending on the API, you want to be able to route to specific target. For this you will need more capabilities built into the ingress proxy. That is API gateway and it can do many more things. For this tutorial, we are going to pick an ingress that can do both http routing and API gateway.

  

As there are many vendors, kubernetes API has an ingress spec. The idea is that developers should be able to use the ingress api, and it should work with any vendor. That works well, but has limited capability in the current version. The new version of ingress is called Gateway API and is currently in alpha. The idea is same - users should be able to provide a rich set of ingress configuration using gateway API syntax. As long as the vendor supports gateway API, users will be able to manage the ingress in a vendor-agnostic configuration.


We will use Ambassador Edge Stack for this tutorial. You can pick ANY ingress/api-gateway as long as it is well-supported, has a vibrant community. We may more options for ingress in future.

  

### Ambassador Edge Stack
Ambassador Edge Stack is a specialized [control plane for Envoy Proxy](https://blog.getambassador.io/the-importance-of-control-planes-with-service-meshes-and-front-proxies-665f90c80b3d). In this architecture, Ambassador Edge Stack translates configuration (in the form of Kubernetes Custom Resources) to Envoy configuration. All actual traffic is directly handled by the high-performance [Envoy Proxy](https://www.envoyproxy.io/).

#### Details

1.  The service owner defines configuration in Kubernetes manifests.
2.  When the manifest is applied to the cluster, the Kubernetes API notifies Ambassador Edge Stack of the change.
3.  Ambassador Edge Stack parses the change and transforms the configuration into a semantic intermediate representation. Envoy configuration is generated from this IR.
4.  The new configuration is passed to Envoy via the gRPC-based Aggregated Discovery Service (ADS) API.
5.  Traffic flows through the reconfigured Envoy, without dropping any connections.

 #### :arrow_down_small: Install Ambassador
 We'll start by installing Ambassador Edge Stack into your cluster. Helm helps you manage required packages.
 Installing  Ambassador using helm. - stable 1.13 version
 Instructions - https://www.getambassador.io/docs/edge-stack/1.13/tutorials/getting-started/

```
# Add the Repo:

helm repo add datawire https://www.getambassador.io

# Create Namespace and Install:

kubectl create namespace ambassador &&  \

helm install ambassador --namespace ambassador datawire/ambassador &&  \

kubectl -n ambassador wait --for condition=available --timeout=90s deploy -lproduct=aes

```
#### :memo: Create Issuer
   Enabling 2 domains (eg. echo & test ) to be hosted on the cluster, using ACME provider letsencrypt. Issuer.yml will help us. When you look at belowsample,  you will see that only one host, please create example2-host for echo service helps to host multiple TLS-enabled hosts on the same cluster.

By using issuer.yml:
```
~kapp issuer.yml


host.getambassador.io/example-host configured
host.getambassador.io/example2-host configured


```
```
apiVersion: getambassador.io/v2
kind: Host
metadata:
  name: example-host
  namespace: default
spec:
  acmeProvider:
    authority: 'https://acme-v02.api.letsencrypt.org/directory'
    email: test@gmail.com
  ambassadorId:
    - default
  hostname: test.mandrakee.xyz
  requestPolicy:
    insecure:
      action: Redirect
      additionalPort: 8080
  selector:
    matchLabels:
      hostname: test.mandrakee.xyz
  tlsSecret:
    name: tls-cert

---
apiVersion: getambassador.io/v2
kind: Host
metadata:
  name: example2-host
  namespace: default
spec:
  acmeProvider:
    authority: 'https://acme-v02.api.letsencrypt.org/directory'
    email: test@gmail.com
  ambassadorId:
    - default
  hostname: echo.mandrakee.xyz
  requestPolicy:
    insecure:
      action: Redirect
      additionalPort: 8080
  selector:
    matchLabels:
      hostname: echo.mandrakee.xyz
  tlsSecret:
    name: tls-cert
```
It takes ~30 seconds to get the signed certificate for the hosts.
 #### :memo: Create Deployment and Service Yaml

we have multiple TLS-enabled hosts on the same cluster. It means that we have multiple deployments and services. 
deployment and service are separated from each other in this setup. Echo and quote service will be deployed by using the below code.It means:
>Deployment.yml has 2 deployments: quote for test and echo for echo hosts.

>quote-backend  have container named backend with :whale2: docker.io/datawire/quote:0.4.1 as image.

>echo-backend  have container named echo with :whale2: jmalloc/echo-server as image.


By using Deployment.Yml:

```
~ kapp deployment.yml 
  
  deployment.apps/quote configured
  deployment.apps/echo configured

```

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quote
  namespace: ambassador
spec:
  replicas: 1
  selector:
    matchLabels:
      app: quote
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: quote
    spec:
      containers:
      - name: backend
        image: docker.io/datawire/quote:0.4.1
        ports:
        - name: http
          containerPort: 8080
          
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo
  namespace: ambassador
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: echo
    spec:
      containers:
      - name: echo
        image: jmalloc/echo-server
        ports:
        - name: http
          containerPort: 8080
```

After Deployment, we can use below yml configuration for services up! 

```
~ kapp service.yml 
```

```
apiVersion: v1
kind: Service
metadata:
  name: quote
  namespace: ambassador
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: quote
---
apiVersion: v1
kind: Service
metadata:
  name: echo
  namespace: ambassador
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: echo
```
#### :earth_americas: Mapping

Ambassador Edge Stack is designed around a [declarative, self-service management model](https://www.getambassador.io/docs/edge-stack/latest/topics/concepts/gitops-continuous-delivery) It means that you can manage the edge with Ambassador Edge Stack is the `Mapping` resource.
> More info : :pushpin:
https://www.getambassador.io/docs/edge-stack/1.13/topics/using/intro-mappings/

This Mapping is managing Edge Stack to route all traffic inbound to the /backend/ path to the quote & also /echo/ to the echo service.
**Details**

* name:	It's a string identifying the Mapping (e.g. in diagnostics)
* prefix:	It's the URL prefix identifying your resource.
* service: It's the name of the service handling the resource; must include the namespace (e.g. myservice.othernamespace) if the service is in a different namespace than Ambassador Edge Stack.

**Mapping.yml**:
Creating 2 independent mappings - echo services accessible to test.kubenuggets.dev host, and quote service accessible to echo.kubenuggets.dev host.
```
~kapp mapping.yml
---
apiVersion: getambassador.io/v2
kind: Mapping
metadata:
  name: quote-backend
  namespace: ambassador
spec:
  prefix: /backend/
  host: test.mandrakee.xyz
  service: quote
 
---
apiVersion: getambassador.io/v2
kind: Mapping
metadata:
  name: echo-backend
  namespace: ambassador
spec:
  prefix: /echo/
  host: echo.mandrakee.xyz
  service: echo
  ```

###  :rocket: Doctl Compute!

Here  hosting 2 hosts (echo.kubenuggets.dev, test.kubenuggets.dev) on the same cluster.

```
~ doctl compute domain records list kubenuggets.dev  
ID           Type    Name    Data                    Priority    Port    TTL     Weight  
158200732    SOA     @       1800                    0           0       1800    0  
158200733    NS      @       ns1.digitalocean.com    0           0       1800    0  
158200734    NS      @       ns2.digitalocean.com    0           0       1800    0  
158200735    NS      @       ns3.digitalocean.com    0           0       1800    0  
158200782    A       echo    143.244.208.164         0           0       180     0  
158201299    A       test    143.244.208.164         0           0       180     0  
~   
~ kgsvcn ambassador   
NAME               TYPE           CLUSTER-IP       EXTERNAL-IP       PORT(S)                      AGE  
ambassador         LoadBalancer   10.245.215.249   143.244.208.164   80:32723/TCP,443:31416/TCP   23h  
ambassador-admin   ClusterIP      10.245.147.231   <none>            8877/TCP,8005/TCP            23h  
ambassador-redis   ClusterIP      10.245.12.247    <none>            6379/TCP                     23h  
quote              ClusterIP      10.245.172.174   <none>            80/TCP                       19h  
~
```

### :performing_arts: Creating A Proxy
Because of using L4 LB , we have to enable proxy protocol through an annotation.After running this command, the public and private load balancers that expose your LB with the PROXY protocol feature enabled.

```
~ kgsvcn ambassador ambassador -o yaml | grep proxy        
    service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol: "true"  
~
```

###  :book: Summary

>Checking configurations 2 hosts with TLS termination and ACME protocol in this setup. test.kubenuggets.dev and echo.kubenuggets.dev are binding directly ambassador gateway. Because of that, having been a map between hosts and ambassador gateways helps clients for using ambassador tls and gateway technologies. When you ping test.kubenuggets.dev, or echo.kubenuggets.dev on the terminal, you can see that it is routing ambassador endpoints. After that, the ambassador is using the mapping feature for mapping target endpoints. 

```
~ kg host -A                                                              
NAMESPACE    NAME                                HOSTNAME                            STATE   PHASE COMPLETED   PHASE PENDING   AGE  
ambassador   charming-galileo-913.edgestack.me   charming-galileo-913.edgestack.me   Ready                                     13h  
default      example-host                        test.kubenuggets.dev                Ready                                     18h  
default      example2-host                       echo.kubenuggets.dev                Ready                                     9m19s
```
> Checking  2 independent mappings. Please be sure mapping is correct such as source host etc.

 ```
 ~ kg mapping -A  
NAMESPACE    NAME                          SOURCE HOST            SOURCE PREFIX                               DEST SERVICE     STATE   REASON  
ambassador   ambassador-devportal                                 /documentation/                             127.0.0.1:8500             
ambassador   ambassador-devportal-api                             /openapi/                                   127.0.0.1:8500             
ambassador   ambassador-devportal-assets                          /documentation/(assets|styles)/(.*)(.css)   127.0.0.1:8500             
ambassador   ambassador-devportal-demo                            /docs/                                      127.0.0.1:8500             
ambassador   quote-backend                 echo.kubenuggets.dev   /backend/                                   quote                      
default      echo-backend                  test.kubenuggets.dev   /echo/                                      echo-service               
~ kg mapping -n ambassador echo-backend -o yaml  
...  
spec:  
  host: test.kubenuggets.dev  
  prefix: /echo/  
  service: echo-service  
~   
~ kg mapping -n ambassador quote-backend -o yaml  
...  
spec:  
  host: echo.kubenuggets.dev  
  prefix: /backend/  
  service: quote  
~
 ```

###  :speech_balloon: Let's Curl

Checking test service with echo endpoint. Being sure it returns 200 OK.
```
~ curl -Li [http://test.kubenuggets.dev/echo/](http://test.kubenuggets.dev/echo/)     
HTTP/1.1 301 Moved Permanently  
location: [https://test.kubenuggets.dev/echo/](https://test.kubenuggets.dev/echo/)  
date: Sun, 25 Jul 2021 22:12:54 GMT  
server: envoy  
content-length: 0HTTP/1.1 200 OK  
content-type: text/plain  
date: Sun, 25 Jul 2021 22:12:55 GMT  
content-length: 366  
x-envoy-upstream-service-time: 1  
server: envoy
```
Checking echo service with backend endpoint. Being sure it returns 200 OK.

```
~ curl -Li [http://echo.kubenuggets.dev/backend/](http://echo.kubenuggets.dev/backend/)  
HTTP/1.1 301 Moved Permanently  
location: [https://echo.kubenuggets.dev/backend/](https://echo.kubenuggets.dev/backend/)  
date: Sun, 25 Jul 2021 22:12:25 GMT  
server: envoy  
content-length: 0HTTP/1.1 200 OK  
content-type: application/json  
date: Sun, 25 Jul 2021 22:12:25 GMT  
content-length: 156  
x-envoy-upstream-service-time: 0  
server: envoy{  
    "server": "gargantuan-kiwi-irbqzsp6",  
    "quote": "A principal idea is omnipresent, much like candy.",  
    "time": "2021-07-25T22:12:25.764754935Z"  
}%
```

## Service mesh using Linkerd <a name="LINK"></a>
TBD

## Backup using Velero <a name="VELE"></a>
TBD


## GitOps using ArgoCD & Sealed Secrets <a name="ARGO"></a>
TBD

## Progressive releases using Argo Rollout <a name="ROLL"></a>
TBD

## Sample Application with Cloudflare CDN <a name="APPL"></a>
TBD
