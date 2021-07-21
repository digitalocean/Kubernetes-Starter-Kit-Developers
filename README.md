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


## Ingress using Ambassador <a name="AMBA"></a>
### Options for LB and Ingress 
You will almost always use the LB provided by the cloud provider. In the case of DO, when you configure a service as an LB, DOKS automatically provisions an LB in your account (unless you configure to use an existing one). Now the service is exposed to outside world and can be accessed through LB endpoint. You do not want to use one LB per service, so you need an proxy inside the cluster. That is ingress.

When you install an ingress proxy, it create a service and exposes it as an LB. Now you can have any many services behind ingress, and all accessible through a single LB endpoint. Ingress operates at http layer. 

Let us say you are exposing REST or GRPC API's for different tasks (reading account info, writing orders, searching orders etc.). Depending on the API, you want to be able to route to specific target. For this you will need more capabilities built into the ingress proxy. That is API gateway and it can do many more things. For this tutorial, we are going to pick an ingress that can do both http routing and API gateway.

As there are many vendors, kubernetes API has an ingress spec. The idea is that developers should be able to use the ingress api, and it should work with any vendor. That works well, but has limited capability in the current version. The new version of ingress is called Gateway API and is currently in alpha. The idea is same - users should be able to provide a rich set of ingress configuration using gateway API syntax. As long as the vendor supports gateway API, users will be able to manage the ingress in a vendor-agnostic configuration. 

Vendor lanscape of ingress is very mature. NGINX-based ingress (kong, nginx) are used very widely. Envoy-based ingresses (contour, gloo, emissary, istio ingress) have become the preferred choice in recent years. 

We will use Ambassador/Emissary for this tutorial. You can pick ANY ingress/api-gateway as long as it is well-supported, has a vibrant community. We may more options for ingress in future.

### Ambassador/Emissary Ingress
Instructions - https://www.getambassador.io/docs/emissary/latest/topics/install/helm/

Note that Emissary-Ingress 2.0 is in Developer Preview because it has a number of breaking changes over the 1.x series. That said, 1.x has been battle-tested in thousands of deployments. Both 1.x and 2.x are built on Envoy Proxy. For production, it is recommended to use 1.x. 

```
helm repo add datawire https://app.getambassador.io
helm repo update
```

Default values.yaml: https://raw.githubusercontent.com/emissary-ingress/emissary/master/charts/emissary-ingress/values.yaml

Install Emissary gateway.
```
helm install -n emissary --create-namespace emissary-ingress --devel datawire/emissary-ingress
kubectl rollout status  -n emissary deployment/emissary-ingress -w
```

The default installation created the following. The default request/limit for the proxy are 200MB/600MB memory, and 200m/1 CPU. 

```
~ k get svc -n emissary  
NAME                                TYPE           CLUSTER-IP       EXTERNAL-IP       PORT(S)                      AGE
emissary-ingress-edge-stack         LoadBalancer   10.245.24.155    143.198.246.xxx   80:32472/TCP,443:31327/TCP   9h
emissary-ingress-edge-stack-admin   ClusterIP      10.245.35.45     <none>            8877/TCP,8005/TCP            9h
emissary-ingress-edge-stack-redis   ClusterIP      10.245.132.203   <none>            6379/TCP                     9h
quote                               ClusterIP      10.245.241.66    <none>            80/TCP                       20h
~ 

~ k get deploy -n emissary 
NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
emissary-ingress-edge-stack         3/3     3            3           9h
emissary-ingress-edge-stack-agent   1/1     1            1           9h
emissary-ingress-edge-stack-redis   1/1     1            1           9h
~
```

#### Getting traffic in using LB IP address. 
What we have so far is that any traffic that comes to DO LB is sent to emissary proxy. Emissary/Ambassador has no idea what to do with it. First, we need to have a principle understanding of how Emissary gateway works. There're 5 custom resources (CRDs), we need to work with.
- From an operator standpoint, we need to create AmbassadorListener, AmbassadorHost, and TLSContext CRDs.
* AmbassadorListener defines where, and how, Emissary-ingress should listen for requests from the network, and which AmbassadorHost definitions should be used to process those requests. Think of protocol and ports.
* AmbassadorHost resource defines how Emissary-ingress will be visible to the outside world. Think of fqdn, TLS. 
* TLSContext defines TLS options. 
- From a developer standpoint, we need to deal to AmbassadorMapping CRD.
*  AmbassadorMapping resource maps a resource (group of URLs with the common prefix) to a backend service. At the most basic level, you just forward a prefix to a backend service. You can also configure auth, circuit breaking, automatic retries, header based routing, method based routing, regex on the header, request rewrite, traffic shadowing, rate limiting etc.

Let us configure a most basic forwarding by using the above resources.

First, create a http echo service. We need this so we can test if client ip is visible to the echo service.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: echo-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: echo-server
  template:
    metadata:
      labels:
        app: echo-server
    spec:
      containers:
        - name: echo-server
          image: jmalloc/echo-server
          ports:
            - name: http-port
              containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: echo-service
spec:
  ports:
    - name: http-port
      port: 80
      targetPort: 8080
  selector:
    app: echo-server
    
```

The echo server is up and running. But it is not exposed to outside world.

```
~ kgpo
NAME                               READY   STATUS    RESTARTS   AGE
echo-deployment-869b7bf9c7-qpnxk   1/1     Running   0          8s
~ kgsvc
NAME           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
echo-service   ClusterIP   10.245.145.227   <none>        80/TCP    21h
kubernetes     ClusterIP   10.245.0.1       <none>        443/TCP   7d
~ 
```

First we need to tell Emissary to listen on port 80 for all hosts (*). 

```
---
apiVersion: x.getambassador.io/v3alpha1
kind: AmbassadorListener
metadata:
  name: emissary-ingress-listener-8080
  namespace: emissary
spec:
  port: 8080
  protocol: HTTP
  securityModel: XFP
  hostBinding:
    namespace:
      from: ALL
```

We will skip creating an AmbassadorHost, and use wildcard instead. Let us define an AmbassadorMapping, and that should be all.

```
---
apiVersion: x.getambassador.io/v3alpha1
kind: AmbassadorMapping
metadata:
  name: echo-backend
  namespace: default
spec:
  hostname: "*"
  prefix: /echo/
  service: echo-service
```

Now the echo service should be reachable from outside.

```
~ export LB_ENDPOINT=$(kubectl -n emissary get svc  emissary-ingress \
  -o "go-template={{range .status.loadBalancer.ingress}}{{or .ip .hostname}}{{end}}")

~ curl -i http://$LB_ENDPOINT/echo/
HTTP/1.1 200 OK
content-type: text/plain
date: Mon, 28 Jun 2021 05:42:31 GMT
content-length: 337
x-envoy-upstream-service-time: 0
server: envoy

Request served by echo-deployment-869b7bf9c7-r5mmd

HTTP/1.1 GET /

Host: 164.90.247.161
X-Request-Id: 2bd9da96-0bb4-4108-9e17-b3e47ff943e7
User-Agent: curl/7.64.1
Accept: */*
X-Forwarded-Proto: http
Content-Length: 0
X-Forwarded-For: 10.124.0.2
X-Envoy-Internal: true
X-Envoy-Expected-Rq-Timeout-Ms: 3000
X-Envoy-Original-Path: /echo/

```

So it worked well, but there's a challenge. We do not see the actual client IP at the destination pod. We can fix it by using proxy protocol at the LB. 

#### Using Proxy protocol

To configure proxy protocol, edit the spec for emissary-ingress-edge-stack. Add the annotation (service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol: "true"). 

You can check the LB configuration using doctl. Get your LB ID from the annotations in your emissary LB service.

```
~ doctl compute load-balancer get "230926ab-9483-4ba5-aa1a-f7850f63cxxx" -o json
[
  {
    "id": "230926ab-9483-4ba5-aa1a-f7850f63cxxx",
    "name": "a7a979feb06504072a66238a105756b8",
...
```

With proxy protocol enabled, the curl to the service fails.

```
~ curl -i http://$LB_ENDPOINT/echo/         
HTTP/1.1 400 Bad Request
content-length: 11
content-type: text/plain
date: Mon, 28 Jun 2021 05:46:21 GMT
server: envoy
connection: close

Bad Request%                                                                                                                  ~ 
```

That is because we need to tell Emissary ingress to treat the traffic coming in with a proxy protocol header.

```
kubectl apply -f - <<EOF
---
apiVersion: x.getambassador.io/v3alpha1
kind: AmbassadorListener
metadata:
  name: emissary-ingress-listener-8080
  namespace: emissary
spec:
  port: 8080
  protocol: HTTPPROXY
  securityModel: XFP
  hostBinding:
    namespace:
      from: ALL
EOF

```

Now I see the actual client IP at the pod.

```
~ curl -i http://$LB_ENDPOINT/echo/
HTTP/1.1 200 OK
content-type: text/plain
date: Mon, 28 Jun 2021 05:48:48 GMT
content-length: 359
x-envoy-upstream-service-time: 5
server: envoy

Request served by echo-deployment-869b7bf9c7-r5mmd

HTTP/1.1 GET /

Host: 164.90.247.161
Accept: */*
X-Envoy-External-Address: 73.162.138.xxx
X-Request-Id: 04e0e2a8-8b3b-474d-bc01-7a68d0bb01ed
User-Agent: curl/7.64.1
X-Forwarded-For: 73.162.138.xxx
X-Forwarded-Proto: http
X-Envoy-Expected-Rq-Timeout-Ms: 3000
X-Envoy-Original-Path: /echo/
Content-Length: 0

```

#### Getting traffic in using DNS name
This is fairly straightforward. We will just add an A record for every host into the DNS. In my case, I added 2 hosts (echo and test) pointing to the same LB.

```
~ doctl compute domain records list kubenuggets.dev
ID           Type    Name    Data                    Priority    Port    TTL     Weight
158200732    SOA     @       1800                    0           0       1800    0
158200733    NS      @       ns1.digitalocean.com    0           0       1800    0
158200734    NS      @       ns2.digitalocean.com    0           0       1800    0
158200735    NS      @       ns3.digitalocean.com    0           0       1800    0
158200782    A       echo    164.90.247.161          0           0       180     0
158201299    A       test    164.90.247.161          0           0       180     0
```

Now I can curl the echo service using any of the following commands.
curl -i http://echo.kubenuggets.dev/echo/ 
curl -i http://test.kubenuggets.dev/echo/ 


#### Getting traffic in using TLS and LetsEncrypt certificates. 

#### Getting traffic in using TLS and LetsEncrypt certificates.

* Run Edge Stack with a free community license. Follow the directions to use ACME to get a certificate. This is definitely the easiest. https://www.getambassador.io/docs/edge-stack/latest/topics/running/host-crd/

  

* Use Emissary with cert-manager: https://www.getambassador.io/docs/edge-stack/latest/howtos/cert-manager/#using-cert-manager — note that I haven’t personally tried this, but I know people use it.

  

The point of the free community license is to make it easy to use the Edge Stack features that make life easier.

  
  

(1a) Download the edgectl installer or (1b) download it with a curl command:

  

```C

sudo curl -fL https://metriton.datawire.io/downloads/linux/edgectl -o /usr/local/bin/edgectl && sudo chmod a+x /usr/local/bin/edgectl

```

Run the installer with ``` edgectl install ```

  

The installer will provision a load balancer, configure TLS, and provide you with an edgestack.me subdomain. The edgestack.me subdomain allows Ambassador Edge Stack to automatically provision TLS and HTTPS for a domain name, so you can get started right away.

  

> Set up Service Catalog to view all of your service metadata in Ambassador Cloud.

  

>Important Note : We're using the helm charts where our normal setup is that the LB listens on 443 and all is well. When we add 80 to our LB, the pod also gets updated to expose 8080, but then Ambassador appears to stop listening on 8443.

  For Admin Dashboard, First time users  will need to download and install the edgectl executable. Once complete, log in to Ambassador with the edgectl command.

### {{Ambassador IP}}/edge_stack/admin/#dashboard
* Linux :penguin:
Download with this CLI
```C
sudo curl -fL https://metriton.datawire.io/downloads/linux/edgectl -o /usr/local/bin/edgectl && sudo chmod a+x /usr/local/bin/edgectl
```
Or download the binary:

[Download edgectl for Linux](https://metriton.datawire.io/downloads/linux/edgectl)

make it executable:
```C
chmod a+x ~/Downloads/edgectl
```
and place it somewhere in your shell PATH.

* MacOS

Download with this CLI
```
sudo curl -fL https://metriton.datawire.io/downloads/darwin/edgectl -o /usr/local/bin/edgectl && sudo chmod a+x /usr/local/bin/edgectl
````
Or download the binary:
[Download edgectl for MacOS](https://metriton.datawire.io/downloads/darwin/edgectl)
make it executable:
```
chmod a+x ~/Downloads/edgectl
```
and place it somewhere in your shell PATH.


* Windows 

Download the binary:

[Download edgectl for Windows](https://metriton.datawire.io/downloads/windows/edgectl.exe)

and place it somewhere in your Windows System PATH.

### Cert-Manager

we can summarize cert manager issue 3 parts. First part is Instaling Cert Manager. Second one is ACME's `http-01` challenge and the last one is ACME's `dns-01` challenge, or using a non-ACME certificate source.

#### Install Cert-Manager
There are many different ways to install cert-manager. For simplicity, we will use Helm v3.

(1) Create the cert-manager CRDs.

```
kubectl apply -f https://github.com/jetstack/cert-manager/releases/latest/download/cert-manager.crds.yaml
```
(2) Add the jetstack Helm repository.

```
helm repo add jetstack https://charts.jetstack.io && helm repo update

```
(3) Install cert-manager.
```
kubectl create ns cert-manager
helm install cert-manager --namespace cert-manager jetstack/cert-manager
```

####  DNS-01 challenge

The DNS-01 challenge verifies domain ownership by proving you have control over its DNS records. Issuer configuration will depend on your  [DNS provider](https://cert-manager.readthedocs.io/en/latest/tasks/acme/configuring-dns01/index.html#supported-dns01-providers).
Issuer.yml :
```C
---

apiVersion: cert-manager.io/v1

kind: ClusterIssuer

metadata:

name: letsencrypt-prod

spec:

acme:

email: email@sample.com

server: https://acme-v02.api.letsencrypt.org/directory

privateKeySecretRef:

name: letsencrypt-prod

solvers:

- dns01:

digitalocean:

tokenSecretRef:

name: digitalocean-dns

key: ce28952b5b4e33ea7d98de190f3148a7cc82d31f030bde966ad13b22c1abc524
```

Create and apply a `Certificate`.

```C
apiVersion: cert-manager.io/v1alpha2

kind: Certificate

metadata:

name: ambassador-certs

namespace: ambassador

spec:

secretName: ambassador-certs

issuerRef:

name: letsencrypt-prod

kind: ClusterIssuer

dnsNames:

- mandrakee.xyz
```

Verify the secret is created.


#### HTTP-01 challenge

The HTTP-01 challenge verifies ownership of the domain by sending a request for a specific file on that domain. cert-manager accomplishes this by sending a request to a temporary pod with the prefix `/.well-known/acme-challenge/`. To perform this challenge:

**issuer.yml:**
```C
apiVersion: cert-manager.io/v1alpha2

kind: ClusterIssuer

metadata:

name: letsencrypt-prod

spec:

acme:

email: email@sample.com

server: https://acme-v02.api.letsencrypt.org/directory

privateKeySecretRef:

name: letsencrypt-prod

solvers:

- http01:

ingress:

class: nginx

selector: {}
```

**Cert.yml:**

```C
apiVersion: cert-manager.io/v1alpha2

kind: Certificate

metadata:

name: ambassador-certs

# cert-manager will put the resulting Secret in the same Kubernetes

# namespace as the Certificate. You should create the certificate in

# whichever namespace you want to configure a Host.

namespace: ambassador

spec:

secretName: ambassador-certs

issuerRef:

name: letsencrypt-prod

kind: ClusterIssuer

dnsNames:

- mandrakee.xyz
```
**Ingress.yml:**

```C
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
annotations:
kubernetes.io/ingress.class: ambassador
cert-manager.io/issuer: letsencrypt-prod
name: test-ingress
spec:
tls:
- hosts:
- mandrakee.xyz
secretName: letsencrypt-prod
rules:
- host: mandrakee.xyz
http:
paths:
- backend:
service:
name: echo-service
port:
number: 80
path: /
pathType: Prefix
```
**Deployment.yml**

```C
apiVersion: apps/v1
kind: Deployment
metadata:
name: echo-deployment
spec:
replicas: 1
selector:
matchLabels:
app: echo-server
template:
metadata:
labels:
app: echo-server
spec:
containers:
- name: httpapi-host
image: jmalloc/echo-server
imagePullPolicy: Always

resources:
requests:
memory: "128Mi"
cpu: "500m"
ports:
- containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
name: echo-service
spec:
ports:
- name: http-port
port: 80
targetPort: 8080
selector:
app: echo-server
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
annotations:
kubernetes.io/ingress.class: ambassador
cert-manager.io/issuer: letsencrypt-prod
name: test-ingress
spec:
tls:
- hosts:
- mandrakee.xyz
secretName: letsencrypt-prod
rules:
- host: mandrakee.xyz
http:
paths:
- backend:
service:
name: echo-service
port:
number: 80
path: /
pathType: Prefix
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
