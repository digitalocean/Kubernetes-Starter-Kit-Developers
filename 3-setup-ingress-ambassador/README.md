## Ingress using Ambassador 

### Options for Load Balancer and Ingress

In most of the cases you will use the `Load Balancer` that is made available by the `Cloud` provider of your choice. In case of `DigitalOcean` when you configure a service as a `Load Balancer`, `DOKS` automatically provisions one in your account (unless you configure to use an existing one). Now the `service` is exposed to the outside world and can be accessed via the `Load Balancer` endpoint. In a real world scenario you do not want to use one `Load Balancer` per service so you need a `proxy` inside the cluster. That is `Ingress`.

When an `Ingress Proxy` is installed it creates a service and exposes it as a `Load Balancer`. Now you can have as many services behind the ingress and all accessible through a single endpoint. Ingress operates at the `HTTP` layer.

Let us say you are exposing `REST` or `GRPC` APIs for different tasks (reading account info, writing orders, searching orders, etc.). Depending on the `API` you will want to be able to route to a specific target. For this to happen more functionality needs to be built inside the ingress proxy. That is `API Gateway` and it is capable of doing more things besides routing traffic. For this tutorial we are going to pick an ingress that can do both `HTTP` routing and `API Gateway`.

As there are many vendors, `Kubernetes API` has an `Ingress` spec. The idea is that developers should be able to use the `Ingress API` and it should work with any vendor. That works well but has limited capability in the current version. The new version of ingress is called `Gateway API` and is currently in alpha. The idea is the same - users should be able to provide a rich set of ingress configuration using the `Gateway API` syntax. As long as the vendor supports it users will be able to manage the ingress in a vendor-agnostic way.

We will use the `Ambassador Edge Stack` in this tutorial. You can pick any `Ingress/API Gateway` solution as long as it has good support from the community because we may want more options to be available in the near future as well.

Why use the `Ambassador Edge Stack`?

`Ambassador Edge Stack` gives platform engineers a comprehensive, self-service edge stack for managing the boundary between `end-users` and `Kubernetes`. Built on the `Envoy Proxy` and fully `Kubernetes-native`, `Ambassador Edge Stack` is made to support multiple, independent teams that need to rapidly publish, monitor, and update services for end-users. A true edge stack, `Ambassador Edge Stack` can also be used to handle the functions of an `API Gateway`, a `Kubernetes ingress controller` and a `layer 7 load balancer`.

### Ambassador Edge Stack (AES)

The `Ambassador Edge Stack` or `AES` for short, is a specialized [Control Plane](https://blog.getambassador.io/the-importance-of-control-planes-with-service-meshes-and-front-proxies-665f90c80b3d) for the `Envoy Proxy`. In this architecture, `Ambassador Edge Stack` translates configuration (in the form of `Kubernetes Custom Resources`) to `Envoy` configuration. All the actual traffic is directly handled by the high-performance [Envoy Proxy](https://www.envoyproxy.io).

At a very high level `AES` works as follows:
1.  The service owner defines configuration via `Kubernetes` manifests.
2.  When the manifest is applied to the cluster, the `Kubernetes API` notifies `Ambassador Edge Stack` of the change.
3.  `Ambassador Edge Stack` parses the change and transforms the configuration into a semantic intermediate representation. `Envoy` configuration is generated from this `IR`.
4.  The new configuration is passed to `Envoy` via the `gRPC-based Aggregated Discovery Service (ADS) API`.
5.  Traffic flows through the reconfigured `Envoy`, without dropping any connections.

For more details and in depth explanation please visit: [The Ambassador Edge Stack Architecture](https://www.getambassador.io/docs/edge-stack/2.0/topics/concepts/architecture) 

Our example set of configuration steps are as follows:
1. Install `AES`.
2. Configure two hosts (`quote`, `echo`) on the cluster. For this example we're going to use `quote.mandake.xyz` and `echo.mandrake.xyz` as two different hosts on the same cluster.
3. Hosts will have `TLS` termination enabled.
4. Verify the installation.

This is how the `Ambassador Edge Stack` setup will look like after following the steps:

![AES Setup](../images/aes_setup.jpg)

### Ambassador Edge Stack Deployment

Deploying the `Ambassador Edge Stack` into the `DOKS` cluster via [Helm](https://helm.sh):
1. Adding the Helm repo:

    ```bash
    helm repo add datawire https://www.getambassador.io
    helm repo update
    ```
2. Listing the available versions (we will use the `6.7.13 ` version of the `Chart` which maps to the `1.13.0` release of `AES`):

    ```bash
    helm search repo datawire
    ```
   
   The output looks similar to the following:
   ```
   NAME                            CHART VERSION   APP VERSION     DESCRIPTION                                       
   datawire/ambassador             6.7.13          1.13.10         A Helm chart for Datawire Ambassador              
   datawire/ambassador-operator    0.3.0           v1.3.0          A Helm chart for Kubernetes                       
   datawire/telepresence           2.4.0           2.4.0           A chart for deploying the server-side component...
   ```
3. Creating a dedicated `ambassador` namespace and finishing the installation:

    ```bash
    kubectl create namespace ambassador &&  \
    helm install ambassador --namespace ambassador datawire/ambassador --version 6.7.13 &&  \
    kubectl -n ambassador wait --for condition=available --timeout=90s deploy -lproduct=aes
    ```

### Defining the Domain and Hosts

In a real world scenario each `host` maps to a `service` so we need a way to tell `AES` about our intentions - meet the [Host](https://www.getambassador.io/docs/edge-stack/1.13/topics/running/host-crd/) CRD.

The custom `Host` resource defines how `Ambassador Edge Stack` will be visible to the outside world. It collects all the following information in a single configuration resource. The most relevant parts are:

* The `hostname` by which `Ambassador Edge Stack` will be reachable
* How `Ambassador Edge Stack` should handle `TLS` certificates
* How `Ambassador Edge Stack` should handle secure and insecure requests

For more details please visit the [AES Host CRD](https://www.getambassador.io/docs/edge-stack/1.13/topics/running/host-crd/) official documentation.

Notes on `ACME` support:

* If the `Authority` is not supplied then a `Let’s Encrypt` **production environment** is assumed.
* In general the `registrant email address` is mandatory when using `ACME` and it should be a valid one in order to receive notifications when the certificates are going to expire.
* `ACME` stores certificates using `Kubernetes Secrets`. The name of the secret can be set using the `tlsSecret` element.

The following example will configure the `TLS` enabled hosts for this tutorial:

```bash
cat << EOF | kubectl apply -f -
apiVersion: getambassador.io/v2
kind: Host
metadata:
  name: quote-host
  namespace: ambassador
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
  namespace: ambassador
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
EOF
```

Let's review the hosts that were created:

```bash
kubectl get hosts -n ambassador
```

The output looks similar to the following:

```
NAME         HOSTNAME              STATE     PHASE COMPLETED      PHASE PENDING              AGE
echo-host    echo.mandrakee.xyz    Pending   ACMEUserRegistered   ACMECertificateChallenge   3s
quote-host   quote.mandrakee.xyz   Pending   ACMEUserRegistered   ACMECertificateChallenge   3s
```

It takes `~30 seconds` to get the signed certificate for the hosts. At this point we have the `Ambassador Edge Stack` installed and the hosts configured. But we still don't have the networking (eg. `DNS` and `Load Balancer`) configured to route traffic to the cluster. The missing parts can be noticed in the `Kubernetes` events of the hosts that were configured earlier.

Let's take a look and see what happens for the `echo-host`:

```bash
kubectl describe host echo-host -n ambassador
```

The output looks similar to the following:

```
Events:
  Type     Reason   Age                From                   Message
  ----     ------   ----               ----                   -------
  Normal   Pending  32m                Ambassador Edge Stack  waiting for Host DefaultsFilled change to be reflected in snapshot
  Normal   Pending  32m                Ambassador Edge Stack  creating private key Secret
  Normal   Pending  32m                Ambassador Edge Stack  waiting for private key Secret creation to be reflected in snapshot
  Normal   Pending  32m                Ambassador Edge Stack  waiting for Host status change to be reflected in snapshot
  Normal   Pending  32m                Ambassador Edge Stack  registering ACME account
  Normal   Pending  32m                Ambassador Edge Stack  ACME account registered
  Normal   Pending  32m                Ambassador Edge Stack  waiting for Host ACME account registration change to be reflected in snapshot
  Normal   Pending  16m (x4 over 32m)  Ambassador Edge Stack  tlsSecret "tls2-cert"."ambassador" (hostnames=["echo.mandrakee.xyz"]): needs updated: tlsSecret does not exist
  Normal   Pending  16m (x4 over 32m)  Ambassador Edge Stack  performing ACME challenge for tlsSecret "tls2-cert"."ambassador" (hostnames=["echo.mandrakee.xyz"])...
  Warning  Error    16m (x4 over 32m)  Ambassador Edge Stack  obtaining tlsSecret "tls2-cert"."ambassador" (hostnames=["echo.mandrakee.xyz"]): acme: Error -> One or more domains had a problem:
[echo.mandrakee.xyz] acme: error: 400 :: urn:ietf:params:acme:error:dns :: DNS problem: SERVFAIL looking up A for echo.mandrakee.xyz - the domain's nameservers may be malfunctioning
...
```
As seen above, the last event tells us that there's no `A` record to point to the `echo` host for the `mandrakee.xyz` domain which results in a lookup failure. Let's fix this in the next section of the tutorial.

### Configuring Domain Mappings

Adding a domain you own to your `DigitalOcean` account lets you manage the domain’s `DNS` records via the `Control Panel` and `API`. Domains you manage on `DigitalOcean` also integrate with `DigitalOcean Load Balancers` and `Spaces` to streamline automatic `SSL` certificate management.

What we need to do next is to create a `domain` and add the required `A` records for the new hosts: `echo` and `quote`. Let's do that via the [doctl](https://docs.digitalocean.com/reference/doctl/how-to/install) utility.

First we create a new `domain` (`mandrakee.xyz` in this example):

```bash
doctl compute domain create mandrakee.xyz
```

The output looks similar to the following:

```
Domain           TTL
mandrakee.xyz    0
```

YOU NEED TO ENSURE THAT YOUR DOMAIN REGISTRAR IS CONFIGURED TO POINT TO DO NAMESERVERS.

Let's add some `A` records now for the hosts created earlier. First we need to identify the `Load Balancer` IP that points to your `Kubernetes` cluster (one should be already available when the cluster was created). Pick the one that matches your configuration from the list:

```bash
doctl compute load-balancer list
```

Then add the records (please replace the `<>` placheholders accordingly):

```bash
doctl compute domain records create mandrakee.xyz --record-type "A" --record-name "echo" --record-data "<your_lb_ip_address>"
doctl compute domain records create mandrakee.xyz --record-type "A" --record-name "quote" --record-data "<your_lb_ip_address>"
```

**Note:**

If you have only one `LB` in your account then this snippet should help:

```bash
LOAD_BALANCER_IP=$(doctl compute load-balancer list --format IP --no-header)
doctl compute domain records create mandrakee.xyz --record-type "A" --record-name "echo" --record-data "$LOAD_BALANCER_IP"
doctl compute domain records create mandrakee.xyz --record-type "A" --record-name "quote" --record-data "$LOAD_BALANCER_IP"
```

List the available records for the `mandrakee.xyz` domain:

```bash
doctl compute domain records list mandrakee.xyz
```

The output looks similar to the following:

```
ID           Type    Name     Data                    Priority    Port    TTL     Weight
164171755    SOA     @        1800                    0           0       1800    0
164171756    NS      @        ns1.digitalocean.com    0           0       1800    0
164171757    NS      @        ns2.digitalocean.com    0           0       1800    0
164171758    NS      @        ns3.digitalocean.com    0           0       1800    0
164171801    A       echo     143.244.208.191         0           0       3600    0
164171809    A       quote    143.244.208.191         0           0       3600    0
```

Great! Now let's see if the `AES Hosts` are OK:

```bash
kubectl get hosts -n ambassador
```

The output looks similar to the following:

```
NAME         HOSTNAME              STATE   PHASE COMPLETED   PHASE PENDING   AGE
echo-host    echo.mandrakee.xyz    Ready                                     2m11s
quote-host   quote.mandrakee.xyz   Ready                                     2m12s
```

If the `STATE` column prints `Ready` then awesome! Now we're ready to rock!

At this point the network traffic will reach the `AES enabled` cluster but we need to configure the `backend services paths` for each of the hosts. All `DNS` records have one thing in common: `TTL` or time to live. It determines how long a `record` can remain cached before it expires. Loading data from a local cache is faster but visitors won’t see `DNS` changes until their local cache expires and gets updated after a new `DNS` lookup. As a result, higher `TTL` values give visitors faster performance and lower `TTL` values ensure that `DNS` changes are picked up quickly. All `DNS` records require a minimum `TTL` value of `30 seconds`.

Please visit the [How to Create, Edit and Delete DNS Records](https://docs.digitalocean.com/products/networking/dns/how-to/manage-records) page for more information.

### Creating AES Backend Services <a name="AMBA_BK_SVC"></a>

In this section we will deploy two example `backend applications`, named `echo` and `quote`. The main goal here is to have a basic understanding on how the `AES` stack will route requests to each application by introducing a new custom `AES` resource named `Mapping`.

We can have multiple `TLS enabled` hosts on the same cluster. On the other hand we can have multiple deployments and services as well. So for each `backend application` a corresponding `Kubernetes Deployment` and `Service` has to be created.

Let's define a new `namespace` for our `quote` and `echo` backend applications. This is a good practice because we don't want to pollute the `AES` space (or any other) with our application specific stuff.

```bash
kubectl create ns backend
```

Spinning up the deployments for the `quote` and `echo` applications in the `backend` namespace:

```bash
cat << EOF | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quote
  namespace: backend
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
  namespace: backend
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
EOF
```

Creating the corresponding services is just a matter of:

```bash
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: quote
  namespace: backend
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
  namespace: backend
spec:
  ports:
  - name: http
    port: 80
    targetPort: 8080
  selector:
    app: echo
EOF
```

Inspecting the deployments and services we just created:

```bash
kubectl get deployments -n backend
```

The output looks similar to the following:

```
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
echo    1/1     1            1           2m22s
quote   1/1     1            1           2m23s
```

```bash
kubectl get svc -n backend
```

The output looks similar to the following:

```
NAME    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
echo    ClusterIP   10.245.175.185   <none>        80/TCP    2m32s
quote   ClusterIP   10.245.158.116   <none>        80/TCP    2m33s
```

As the last configuration step, create the `mappings` for Ambassador.

### Configuring the AES Mapping for each Host

`Ambassador Edge Stack` is designed around a [declarative, self-service management model](https://www.getambassador.io/docs/edge-stack/latest/topics/concepts/gitops-continuous-delivery). It means that you can manage the `Edge` via a dedicated `Kubernetes CRD`, namely the `Mapping` resource. More info about [Mappings](https://www.getambassador.io/docs/edge-stack/1.13/topics/using/intro-mappings) can be found on the official page.

What a `Mapping` does is to manage routing for all inbound traffic to the `/quote/` path for the `quote` service and `/echo/` for the `echo` service.

**Mapping fields description:**

* `name` - a string identifying the `Mapping` (e.g. in diagnostics).
* `prefix` - the `URL` prefix identifying your resource.
* `service` - the name of the service handling the resource; must include the `namespace` (e.g. myservice.othernamespace) if the service is in a different namespace than `Ambassador Edge Stack`.

Creating a `Mapping` for each of our applications:

```bash
cat << EOF | kubectl apply -f -
---
apiVersion: getambassador.io/v2
kind: Mapping
metadata:
  name: quote-backend
  namespace: ambassador
spec:
  prefix: /quote/
  host: quote.mandrakee.xyz
  service: quote.backend
 
---
apiVersion: getambassador.io/v2
kind: Mapping
metadata:
  name: echo-backend
  namespace: ambassador
spec:
  prefix: /echo/
  host: echo.mandrakee.xyz
  service: echo.backend
EOF
```

Inspecting the results:

```bash
kubectl get mappings -n ambassador
```

The output looks similar to the following (notice the `echo-backend` and `quote-backend` lines):

```
NAME                          SOURCE HOST           SOURCE PREFIX                               DEST SERVICE     STATE   REASON
ambassador-devportal                                /documentation/                             127.0.0.1:8500           
ambassador-devportal-api                            /openapi/                                   127.0.0.1:8500           
ambassador-devportal-assets                         /documentation/(assets|styles)/(.*)(.css)   127.0.0.1:8500           
ambassador-devportal-demo                           /docs/                                      127.0.0.1:8500           
echo-backend                  echo.mandrakee.xyz    /echo/                                      echo.backend             
quote-backend                 quote.mandrakee.xyz   /quote/                                     quote.backend 
```

**Next Steps**

Further explore some of the concepts you learned about so far:

* [Mapping](https://www.getambassador.io/docs/edge-stack/1.13/topics/using/intro-mappings/) resource: `routes` traffic from the `edge` of your cluster to a `Kubernetes` service
* [Host](https://www.getambassador.io/docs/edge-stack/1.13/topics/running/host-crd/) resource: sets the `hostname` by which `Ambassador Edge Stack` will be accessed and secured with `TLS` certificates

### Enabling Proxy Protocol

L4 load balancer replaces the original client IP with it's own IP address. This is a problem, as we lose the client IP visibility in the application. Hence we enable proxy protocol. Proxy protocol enables a `L4 Load Balancer` to communicate the the original `client IP`. For this to work we need to configure both `DigitalOcean Load Balancer` and `AES`. After deploying the `Services` as seen earlier in the tutorial and manually enabling the `proxy protocol`, you need to configure `Ambassador Module` to enable `AES` to use the proxy protocol. 

So the steps for proxy protocol are the following.
1. Enable proxy protocol on DigitalOcean LB through service annotation on Ambassador LB service.
2. Enable proxy protocol configuration on Ambassador module. 

For different DO LB configuration examples, please refer to the examples from the official [DigitalOcean Cloud Controller Manager](https://github.com/digitalocean/digitalocean-cloud-controller-manager/tree/master/docs/controllers/services/examples) documentation. Proxyprotocol on the LB is enabled with the following annotation on Ambassador LB service: `service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol: "true"`. You must NOT create a load balancer with `Proxy` support by using the `DO` web console, as any setting done outside the DOKS is automatically overridden by DOKS reconciliation. 

You can enable proxy support in the `Ambassador` stack by using the below configuration:

```bash
cat << EOF | kubectl apply -f -
apiVersion: getambassador.io/v2
kind: Module
metadata:
  name: ambassador
  namespace: ambassador
spec:
  config:
    use_proxy_proto: true
EOF
```

Note that module configuration is a global option (enable/disable) for AES.

### Verifying the AES Setup

In the current setup we have two hosts configured with `TLS` termination and `ACME` protocol: `quote.mandrakee.xyz` and `echo.mandrakee.xyz`. By creating `AES Mappings` it's very easy to have `TLS termination` support and `API Gateway` capabilities. 

If pinging `quote.mandrakee.xyz` or `echo.mandrakee.xyz` in the terminal one can see that packets are being sent to the `AES` external `IP`. Then, `AES` is using the mapping feature to reach the endpoints. 

```bash
kubectl get svc -n ambassador 
```

The output looks similar to the following:

```
NAME               TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)                      AGE
ambassador         LoadBalancer   10.245.39.13   68.183.252.190   80:31499/TCP,443:30759/TCP   2d8h
ambassador-admin   ClusterIP      10.245.68.14   <none>           8877/TCP,8005/TCP            2d8h
ambassador-redis   ClusterIP      10.245.9.81    <none>           6379/TCP                     2d8h
```

```bash
ping quote.mandrakee.xyz
```

The output looks similar to the following:

```
PING quote.mandrakee.xyz (68.183.252.190): 56 data bytes
64 bytes from 68.183.252.190: icmp_seq=0 ttl=54 time=199.863 ms
64 bytes from 68.183.252.190: icmp_seq=1 ttl=54 time=202.999 ms
...
```

As explained above, notice that it hits the `AES` external IP (`68.183.252.190`).

We're going to test the backend services now via `curl` and use the `quote` service first. You can also inspect and see the results in a web browser if desired.

```bash
curl -Li http://quote.mandrakee.xyz/quote/
```

The output looks similar to the following (notice how it automatically redirects and uses `https` instead):

```
HTTP/1.1 301 Moved Permanently
location: https://quote.mandrakee.xyz/quote/
date: Thu, 12 Aug 2021 18:28:43 GMT
server: envoy
content-length: 0

HTTP/1.1 200 OK
content-type: application/json
date: Thu, 12 Aug 2021 18:28:43 GMT
content-length: 167
x-envoy-upstream-service-time: 0
server: envoy

{
    "server": "avaricious-blackberry-5xw0vf5k",
    "quote": "The last sentence you read is often sensible nonsense.",
    "time": "2021-08-12T18:28:43.861400709Z"
}
```

Let's do the same for the `echo` service:

```bash
curl -Li http://echo.mandrakee.xyz/echo/
```

The output looks similar to the following (notice how it automatically redirects and uses `https` instead):
```
HTTP/1.1 301 Moved Permanently
location: https://echo.mandrakee.xyz/echo/
date: Thu, 12 Aug 2021 18:31:27 GMT
server: envoy
content-length: 0

HTTP/1.1 200 OK
content-type: text/plain
date: Thu, 12 Aug 2021 18:31:28 GMT
content-length: 331
x-envoy-upstream-service-time: 0
server: envoy

Request served by echo-5d5bdf99cf-cq8nh

HTTP/1.1 GET /

Host: echo.mandrakee.xyz
X-Forwarded-Proto: https
X-Envoy-Internal: true
X-Request-Id: 07afec17-4535-4157-bf5f-ad19dafb7bff
Content-Length: 0
X-Forwarded-For: 10.106.0.3
User-Agent: curl/7.64.1
Accept: */*
X-Envoy-Expected-Rq-Timeout-Ms: 3000
X-Envoy-Original-Path: /echo/
```

Given that we have proxy protocol configured, you should see the original client IP in the http request header.

If everything looks like above we're all set and configured the `Ambassador Edge Stack` successfully. 

Because `Monitoring` and `Logging` is a very important aspect of every production ready system in the next section we're going to focus on how to enable it via `Prometheus` and `Loki` for the `AES` stack as well as other backend services.

Go to [Section 4 - Set up prometheus stack](../4-setup-prometheus-stack)
