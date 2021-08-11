# Day-2 Operations-ready DOKS (DigitalOcean Kubernetes) for Developers

**WORK-IN-PROGRESS**

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
7. [Backup using Velero](#VELE)
8. [Automate everything using Terraform and Flux](#AUTO)


## Scope <a name="SCOP"></a>
This is meant to be a beginner tutorial to demonstrate the setups you need to be operations-ready. The list is an work-in-progress.

All the steps are done manually using commandline. If you need end-to-end automation, refer to the last section.

None of the installed tools are exposed using ingress or LB. To access the console for individual tools, we use kubectl port-forward.

We will use brew (on mac) to install the commmands on our local machine. We will skip the how-to-install and command on your local laptop, and focus on using the command to work on DOKS cluster. 

For every tool, we will make sure to enable metrics and logs. At the end, we will review the overhead from all these additional tools. That gives an idea of what it takes to be operations-ready after your first cluster install. <br/><br/>


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

Now connect loki data source to grafana. Go the grafana web console, and add settings - data sources - add - loki. Add loki url "http://loki:3100". Save and quote.

Now you can access logs from explore tab of grafana. Make sure to select loki as the data source. Use help button for log search cheat sheet.

## Ingress using Ambassador <a name="AMBA"></a>

### Options for LB and Ingress

You will almost always use the LB provided by the cloud provider. In the case of DO, when you configure a service as an LB, DOKS automatically provisions an LB in your account (unless you configure to use an existing one). Now the service is exposed to outside world and can be accessed through LB endpoint. You do not want to use one LB per service, so you need an proxy inside the cluster. That is ingress.

  

When you install an ingress proxy, it create a service and exposes it as an LB. Now you can have any many services behind ingress, and all accessible through a single LB endpoint. Ingress operates at http layer.

  

Let us say you are exposing REST or GRPC API's for different tasks (reading account info, writing orders, searching orders etc.). Depending on the API, you want to be able to route to specific target. For this you will need more capabilities built into the ingress proxy. That is API gateway and it can do many more things. For this tutorial, we are going to pick an ingress that can do both http routing and API gateway.

  

As there are many vendors, kubernetes API has an ingress spec. The idea is that developers should be able to use the ingress api, and it should work with any vendor. That works well, but has limited capability in the current version. The new version of ingress is called Gateway API and is currently in alpha. The idea is same - users should be able to provide a rich set of ingress configuration using gateway API syntax. As long as the vendor supports gateway API, users will be able to manage the ingress in a vendor-agnostic configuration.


We will use Ambassador Edge Stack for this tutorial. You can pick ANY ingress/api-gateway as long as it is well-supported, has a vibrant community. We may more options for ingress in future.

  

### Ambassador Edge Stack (AES)
Ambassador Edge Stack is a specialized [control plane for Envoy Proxy](https://blog.getambassador.io/the-importance-of-control-planes-with-service-meshes-and-front-proxies-665f90c80b3d). In this architecture, Ambassador Edge Stack translates configuration (in the form of Kubernetes Custom Resources) to Envoy configuration. All actual traffic is directly handled by the high-performance [Envoy Proxy](https://www.envoyproxy.io/).

At a high level, AES works as follows.
1.  The service owner defines configuration in Kubernetes manifests.
2.  When the manifest is applied to the cluster, the Kubernetes API notifies Ambassador Edge Stack of the change.
3.  Ambassador Edge Stack parses the change and transforms the configuration into a semantic intermediate representation. Envoy configuration is generated from this IR.
4.  The new configuration is passed to Envoy via the gRPC-based Aggregated Discovery Service (ADS) API.
5.  Traffic flows through the reconfigured Envoy, without dropping any connections.

More Details and extended explanation please visit: [The Ambassador Edge Stack Architecture](https://www.getambassador.io/docs/edge-stack/2.0/topics/concepts/architecture/) 

The set of configuration steps are as follows
- Install AES.
- Enable prometheus for metrics, and loki for logs.
- Configure 2 hosts (domain1, domain2) on the cluster. For this example, we're using quote.mandake.xyz, and echo.mandrake.xyz as 2 differents hosts on the same cluster.
- Enable different paths for the domains. For quote.mandrake.xyz, we create a backend service called quote. For echo.mandrake.xyz, we create a echo service called echo.
- Domains are configured with TLS, and have different URL paths.
- Verify the installation.
  
![AES image](images/AESNetwork.jpg)


 ### Install Ambassador
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
### Define the Hosts (domains)

Creating echo-host for echo service helps to host multiple TLS-enabled hosts on the same cluster Because of that, This Host tells Ambassador Edge Stack to expect to be reached at echo.mandrakee.xyz, and to manage TLS certificates using Let’s Encrypt, registering as echo@gmail.com. Since it doesn’t specify otherwise, requests using cleartext will be automatically redirected to use HTTPS, and Ambassador Edge Stack will not search for any specific further configuration resources related to this Host.[For More Details ,Please visit Ambassador : The Host CRD, ACME support, and external load balancer configuration](https://www.getambassador.io/docs/edge-stack/1.13/topics/running/host-crd/)

Notes on ACME Support:

* If the authority is not supplied, the Let’s Encrypt production environment is assumed.

* In general, email-of-registrant is mandatory when using ACME: it should be a valid email address that will reach someone responsible for certificate management.

* ACME stores certificates in Kubernetes secrets. The name of the secret can be set using the tlsSecret element:
```

apiVersion: getambassador.io/v2
kind: Host
metadata:
  name: quote-host
spec:
  hostname: quote.mandrakee.xyz
  acmeProvider:
    email: quote@gmail.com
  tlsSecret:
    name: tls-cert
  requestPolicy:
    insecure:
       action: Redirect
       additionalPort: 8080

---
apiVersion: getambassador.io/v2
kind: Host
metadata:
  name: echo-host
spec:
  hostname: echo.mandrakee.xyz
  acmeProvider:
    email: echo@gmail.com
  tlsSecret:
    name: tls2-cert
  requestPolicy:
    insecure:
       action: Redirect
       additionalPort: 8080

```

It takes ~30 seconds to get the signed certificate for the hosts. At this point, we have Ambassador installed, and hosts configured. BUT, we still do not have the networking (eg. DNS and Load balancer) configured to route the traffic to the cluster. 


### Configure your domain mapping to point the domains to the cluster LB

Adding a domain you own to your DigitalOcean account lets you manage the domain’s DNS records with the control panel and API. Domains you manage on DigitalOcean also integrate with DigitalOcean Load Balancers and Spaces to streamline automatic SSL certificate management.In this case, we created 2 hosts first one is echo and second domain is quote.

```
~ doctl compute domain records list mandrakee.xyz  
ID           Type    Name     Data                    Priority    Port    TTL     Weight
164171755    SOA     @        1800                    0           0       1800    0
164171756    NS      @        ns1.digitalocean.com    0           0       1800    0
164171757    NS      @        ns2.digitalocean.com    0           0       1800    0
164171758    NS      @        ns3.digitalocean.com    0           0       1800    0
164171801    A       echo     143.244.208.191         0           0       3600    0
164171809    A       quote    143.244.208.191         0           0       3600    0
 
~   
~ kgsvcn ambassador   
NAME               TYPE           CLUSTER-IP       EXTERNAL-IP       PORT(S)                      AGE  
ambassador         LoadBalancer   10.245.215.249   xxx.xxx.xxx.xxx   80:32723/TCP,443:31416/TCP   23h  
ambassador-admin   ClusterIP      10.245.147.231   <none>            8877/TCP,8005/TCP            23h  
ambassador-redis   ClusterIP      10.245.12.247    <none>            6379/TCP                     23h  
quote              ClusterIP      10.245.172.174   <none>            80/TCP                       19h  
~
```

At this point, the network traffic for the hosts will reach the cluster (AES). Now we need to configure the paths (backend services) for each of the hosts.All DNS records have one value in common: TTL, or time to live, which determines how long the record can remain cached before it expires. Loading data from a local cache is fast, but visitors won’t see DNS changes until their local cache expires and updates with a new DNS lookup. As a result, higher TTL values give visitors faster performance and lower TTL values ensure that DNS changes are picked up quickly. All DNS records require a minimum TTL value of 30 seconds.[Please visit How to Create, Edit, and Delete DNS Records page for more information](https://docs.digitalocean.com/products/networking/dns/how-to/manage-records/)
 ### Create Backend Services

we have multiple TLS-enabled hosts on the same cluster. It means that we have multiple deployments and services. 
deployment and service are separated from each other in this setup. Echo and quote service will be deployed by using the below code. It means:

By using Deployment.Yml:

```
~ kapp deployment.yml 
  
  deployment.apps/quote configured
  deployment.apps/echo configured

#Deployment.yml for quote and echo images
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
#service.yml for quote and echo deployment.

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

As the last configuration step, create the mapping for Ambassador.

#### Configure Mapping for each Hosts

Ambassador Edge Stack is designed around a [declarative, self-service management model](https://www.getambassador.io/docs/edge-stack/latest/topics/concepts/gitops-continuous-delivery) It means that you can manage the edge with Ambassador Edge Stack is the `Mapping` resource.
> More info : https://www.getambassador.io/docs/edge-stack/1.13/topics/using/intro-mappings/

This Mapping is managing Edge Stack to route all traffic inbound to the /backend/ path to the quote & also /echo/ to the echo service.
**Details**

* name:	It's a string identifying the Mapping (e.g. in diagnostics)
* prefix:	It's the URL prefix identifying your resource.
* service: It's the name of the service handling the resource; must include the namespace (e.g. myservice.othernamespace) if the service is in a different namespace than Ambassador Edge Stack.

**Mapping.yml**:
Creating 2 independent mappings 

- echo services accessible to quote.mandrakee.xyz AND and quote service accessible to echo.mandrakee.xyz
  

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
  host: quote.mandrakee.xyz
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

### Enabling Proxy Protocol

When adding an LB in the beginning and installing AES, a DO LB is automatically created.Proxy protocol enables a L4 Load balancer to communicate the original client IP. For this work, we need to configure both ends (DO LB and AES).After deploying the Service above  and manually enabling the proxy protocol you have to need to deploy the following Ambassador Module to manage Ambassador Edge Stack to utilize the proxy protocol and then restart Ambassador Edge Stack for the configuration to take effect.


[For more Details Please visit digital ocean cloud controller manager documents](https://github.com/digitalocean/digitalocean-cloud-controller-manager/tree/master/docs/controllers/services/examples)


By using the belove command you can see that all loadbalancer lists for your cluster. Also, you can create your load balancer with proxy by using DO web dashboard automatically. When you check advanced settings of kub cluster, The most commonly used settings are selected by default, you can change them at any time by clicking "Edit Advanced Settings". When you decide to add Proxy for your cluster, you can proxy protocol setting.

```
~ doctl compute load-balancer list

```
[For more information](https://www.digitalocean.com/community/questions/how-to-set-up-nginx-ingress-for-load-balancers-with-proxy-protocol-support)

[For More details about how to use proxy for Ambassador](https://www.getambassador.io/docs/edge-stack/1.13/topics/running/ambassador-with-aws/). You can create a proxy in Ambassador by using below code. Ambassador Edge Stack will now expect traffic from the load balancer to be wrapped with the proxy protocol so it can read the client IP address.

```
# Manually enabling proxy protocol...

apiVersion: getambassador.io/v2
kind: Module
metadata:
  name: ambassador
  namespace: ambassador
spec:
  config:
    use_proxy_proto: true
```

### Verify the Configuration

>Checking configurations 2 hosts with TLS termination and ACME protocol in this setup. quote.mandrakee.xyz and echo.mandrakee.xyz are binding directly ambassador gateway. Because of that, having been a map between hosts and ambassador gateways helps clients for using ambassador tls and gateway technologies. When you ping quote.mandrakee.xyz, or echo.mandrakee.xyz on the terminal, you can see that it is routing ambassador endpoints. After that, the ambassador is using the mapping feature for mapping target endpoints. 

```
~ kg host -A                                                              
NAMESPACE    NAME                              HOSTNAME                           STATE   PHASE COMPLETED   PHASE PENDING   AGE  
default      quote-host                        quote.mandrakee.xyz                Ready                                     18h  
default      echo-host                         echo.mandrakee.xyz                 Ready                                     9m19s
```
> Checking  2 independent mappings. Please be sure mapping is correct such as source host etc.

 ```
 ~ kg mapping -A  
 
NAMESPACE    NAME                          SOURCE HOST           SOURCE PREFIX                               DEST SERVICE     STATE   REASON
ambassador   ambassador-devportal                                /documentation/                             127.0.0.1:8500
ambassador   ambassador-devportal-api                            /openapi/                                   127.0.0.1:8500
ambassador   ambassador-devportal-assets                         /documentation/(assets|styles)/(.*)(.css)   127.0.0.1:8500
ambassador   ambassador-devportal-demo                           /docs/                                      127.0.0.1:8500
ambassador   echo-backend                  echo.mandrakee.xyz    /echo/                                      echo
ambassador   quote-backend                 quote.mandrakee.xyz   /quote/                                     quote
     

~ kg mapping -n ambassador echo-backend -o yaml  
...  
apiVersion: getambassador.io/v2
kind: Mapping
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"getambassador.io/v2","kind":"Mapping","metadata":{"annotations":{},"name":"echo-backend","namespace":"ambassador"},"spec":{"host":"echo.mandrakee.xyz","prefix":"/echo/","service":"echo-service"}}
  creationTimestamp: "2021-07-30T16:11:57Z"
  generation: 1
  name: echo-backend
  namespace: ambassador
  resourceVersion: "1239310"
  uid: 3fc67511-6e04-4d56-bde2-5de07fcc9748
spec:
  host: echo.mandrakee.xyz
  prefix: /echo/
  service: echo
 

~ kg mapping -n ambassador quote-backend -o yaml  
...  
apiVersion: getambassador.io/v2
kind: Mapping
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"getambassador.io/v2","kind":"Mapping","metadata":{"annotations":{},"name":"quote-backend","namespace":"ambassador"},"spec":{"host":"quote.mandrakee.xyz","prefix":"/quote/","service":"quote-service"}}
  creationTimestamp: "2021-07-30T16:11:57Z"
  generation: 1
  name: quote-backend
  namespace: ambassador
  resourceVersion: "1239310"
  uid: 3fc67511-6e04-4d56-bde2-5de07fcc9748
spec:
  host: quote.mandrakee.xyz
  prefix: /quote/
  service: quote



~doctl compute domain records list mandrakee.xyz 

ID           Type    Name     Data                    Priority    Port    TTL     Weight
162442979    SOA     @        1800                    0           0       1800    0
162442981    NS      @        ns1.digitalocean.com    0           0       1800    0
162442983    NS      @        ns2.digitalocean.com    0           0       1800    0
162442986    NS      @        ns3.digitalocean.com    0           0       1800    0
162892121    A       echo     143.244.208.191         0           0       3600    0
164017635    A       quote    143.244.208.191         0           0       3600    0

~kgsvcn ambassador

NAME               TYPE           CLUSTER-IP       EXTERNAL-IP       PORT(S)                      AGE
ambassador         LoadBalancer   10.245.92.121    143.244.208.191   80:31153/TCP,443:30706/TCP   6d6h
ambassador-admin   ClusterIP      10.245.23.172    <none>            8877/TCP,8005/TCP            6d6h
ambassador-redis   ClusterIP      10.245.133.196   <none>            6379/TCP                     6d6h
echo               ClusterIP      10.245.27.179    <none>            80/TCP                       13s
quote              ClusterIP      10.245.229.63    <none>            80/TCP                       13s

 
 ```

Now let us quote the connectivity. In the simple sample below, when invoked without any option, curl displays the specified resource to the standard output of hosted services. You can see that quote.mandrakee.xyz doesn't have any echo
end point. Because of that, the result is empty. The same situation happens for echo.mandrakee.xyz when calling quote end point. 

*Checking quote service with quote endpoint. Being sure it returns 200 OK.*

```
~ curl -Li http://quote.mandrakee.xyz/echo/
HTTP/1.1 404 Not Found
date: Sun, 25 Jul 2021 22:13:04 GMT
server: envoy
content-length: 0
~ 


~ curl -Li http://quote.mandrakee.xyz/quote/  
HTTP/1.1 301 Moved Permanently
location: https://quote.mandrakee.xyz/quote/
date: Sun, 25 Jul 2021 22:12:54 GMT
server: envoy
content-length: 0
HTTP/1.1 200 OK
content-type: text/plain
date: Sun, 25 Jul 2021 22:12:55 GMT
content-length: 366
x-envoy-upstream-service-time: 1
server: envoy
Request served by quote-deployment-869b7bf9c7-m2qgs
HTTP/1.1 GET /
Host: quote.mandrakee.xyz
User-Agent: curl/7.64.1
Accept: */*
X-Forwarded-For: xxx
X-Forwarded-Proto: https
X-Request-Id: 32343d7b-1737-4506-b29c-0622d9554cb4
X-Envoy-Original-Path: /quote/
X-Envoy-External-Address: xxx
X-Envoy-Expected-Rq-Timeout-Ms: 3000
Content-Length: 0



```
*Checking echo service with backend endpoint. Being sure it returns 200 OK.*
```
~ curl -Li http://echo.mandrakee.xyz/quote/ 
HTTP/1.1 404 Not Found
date: Sun, 25 Jul 2021 22:12:13 GMT
server: envoy
content-length: 0


~ curl -Li http://echo.mandrakee.xyz/echo/
HTTP/1.1 301 Moved Permanently
location: https://echo.mandrakee.xyz/echo/
date: Sun, 25 Jul 2021 22:12:25 GMT
server: envoy
content-length: 0
HTTP/1.1 200 OK
content-type: application/json
date: Sun, 25 Jul 2021 22:12:25 GMT
content-length: 156
x-envoy-upstream-service-time: 0
server: envoy
{
    "server": "gargantuan-kiwi-irbqzsp6",
    "quote": "A principal idea is omnipresent, much like candy.",
    "time": "2021-07-25T22:12:25.764754935Z"
}
```

### Configure Prometheus & Grafana
We already install prometheus, and grafana into our cluster by using above prior sections called [Prometheus monitoring stack](#PROM). Also you can make your own environment again from scratch by using fallowing link. 
(Monitoring with Prometheus and Grafana for Ambassador)[https://www.getambassador.io/docs/edge-stack/latest/howtos/prometheus/#monitoring-with-prometheus-and-grafana]

But we are considering you have a prometheus environment and you want to bind new ambassador gateway cluster with existed prometheus enviroment.Before creating a servicemonitor to let prometheus know how to scrap the metrics, you should know that ambassador is broadcasting own metrics by using metrics end point.The /metrics endpoint can be accessed internally via the Ambassador Edge Stack admin port (default 8877).Please test it by calling below link on your web browser yourself.

```
http(s)://ambassador:8877/metrics
```
we have existed monitoring configuration yaml file called *prom-stack-values.yaml*. it has really important section and we have to change with service monitor configuration and then run helm upgrade to modify existed chart.There are 2 steps for that.

(1) Please find *additionalServiceMonitors* section and modify tihs part like below in *prom-stack-values.yaml*
```
  additionalServiceMonitors:
      - name: "ambassador-monitor"
        selector:
          matchLabels:
            service: "ambassador-admin"
        namespaceSelector:
          matchNames:
            - ambassador
        endpoints:
        - port: "ambassador-admin"
          path: /metrics
          scheme: http
```
(2) Last step is *helm upgrade* to modify existed prometheus chart for seeing changes.
```
helm upgrade kube-prom-stack prometheus-community/kube-prometheus-stack -n monitoring -f prom-stack-values.yaml
```
That's it! Final touch for seeing metrics values on prometheus dashboard.For that, you have to forward your 9090 port to another available port.
```
 kubectl --namespace monitoring port-forward svc/kube-prom-stack-kube-prome-prometheus 9090:9090
```

#### DashBoard

After port forwarding like below, you can access the metrics in Grafana. 
```
kubectl --namespace monitoring port-forward svc/kube-prom-stack-grafana 3000:80
```
if you want to see all ambassador metrics in well designed dashboard Add the following dashboard in grafana: https://grafana.com/grafana/dashboards/4698

When you decide to test your first Grafana DashBoard, please call below ambassador test service. if you call below service 2 times, you will see that 4 responses. Because it is a gateway, your request pass a gateway and arrive real service. Because of that, your response also will have same steps. 

```
~# curl -Lk https://104.248.102.80/backend/
{
    "server": "buoyant-pear-girnlk37",
    "quote": "A small mercy is nothing at all?",
    "time": "2021-08-11T18:18:56.654108372Z"
}
```

<TBD>


### Configure Loki and Grafana

We already install loki, and grafana into our cluster by following prior sections. 

<TBD>

## Backup using Velero <a name="VELE"></a>
TBD


## Automate everything using Terraform and Flux <a name="AUTO"></a>
TBD

