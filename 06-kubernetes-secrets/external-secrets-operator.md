# How to Configure External Secrets Operator with Vault

## Introduction

In this tutorial, you will learn how to configure and use the [External Secrets Operator](https://github.com/external-secrets/external-secrets/). External Secrets Operator is a Kubernetes operator that integrates external secret management systems like [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/), [HashiCorp Vault](https://www.vaultproject.io/), [Google Secrets Manager](https://cloud.google.com/secret-manager), [Azure Key Vault](https://azure.microsoft.com/en-us/services/key-vault/) and many more. The operator reads information from external APIs and automatically injects the values into a [Kubernetes Secret](https://kubernetes.io/docs/concepts/configuration/secret/).
You will be installing and configuring Vault server on an external DO Droplet.

The goal of External Secrets Operator is to synchronize secrets from external APIs into Kubernetes. ESO is a collection of custom API resources - ExternalSecret, SecretStore and ClusterSecretStore that provide a user-friendly abstraction for the external API that stores and manages the lifecycle of the secrets for you.

If you are using an external secrets manager to handle sensitive data then ESO if the way to go. Examples of secrets managers include HashiCorp Vault, AWS Secrets Manager, IBM Secrets Manager, Azure Key Vault, Akeyless, Google Secrets Manager, etc. To get secrets from you secrets manager into your cluster is by using the External Secrets Operator, a Kubernetes operator that enables you to integrate and read values from your external secrets management system and insert them as Secrets in your cluster.
On the other hand if you are not using an external secrets manager you can use Sealed Secrets to handle sensitive data. Sealed Secrets allow for “one-way” encryption of your Kubernetes Secrets and can only be decrypted by the Sealed Secrets controller running in your target cluster. This mechanism is based on public-key encryption, a form of cryptography consisting of a public key and a private key pair. One can be used for encryption, and only the other key can be used to decrypt what was encrypted.
To use Sealed Secrets, you have to deploy the controller to your target cluster and download the kubeseal CLI tool.

## External Operator Architecture

![External Secrets Operator Architecture](assets/images/external-secrets-operator.png)

## Table of contents

- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Step - 1](#step-1---understanding-external-secrets-operator)
- [Step - 2](#step-2---configuring-the-vault-server)
- [Step - 3](#step-3---installing-and-configuring-the-external-secrets-operator)
- [Step - 4](#step-4---fetching-an-example-secret)
- [Conclusion](#conclusion)

## Prerequisites

To complete this tutorial, you will need:

1. A [Git](https://git-scm.com/downloads) client, for cloning the `Starter Kit` repository.
2. [Helm](https://www.helm.sh), for installing the `Loki` stack chart.
3. [Kubectl](https://kubernetes.io/docs/tasks/tools), for `Kubernetes` interaction.
4. A text editor with `YAML` lint support, for example: [Visual Studio Code](https://code.visualstudio.com).
5. Vault sever installed on a DO Droplet as explained in this [article](https://www.digitalocean.com/community/tutorials/how-to-build-a-hashicorp-vault-server-using-packer-and-terraform-on-digitalocean). Please install the Vault sever on the same VPC Network as the Kubernetes droplet for easier access via private address.

**Note:**
Please make sure that you replace the vault version in the packer `template.json` from 1.8.4 to 1.11.3. That is specified in the `provisioner` block on line 16.
Change it from:

```text
"curl -L https://releases.hashicorp.com/vault/1.8.4/vault_1.8.4_linux_amd64.zip -o vault.zip"
```

to

```text
"curl -L https://releases.hashicorp.com/vault/1.11.3/vault_1.11.3_linux_amd64.zip -o vault.zip"
```

## Step 1 - Understanding External Secrets Operator

The External Secrets Operator extends Kubernetes with [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/), which define where secrets live and how to synchronize them. The controller fetches secrets from an external API and creates Kubernetes [secrets](https://kubernetes.io/docs/concepts/configuration/secret/). If the secret from the external API changes, the controller will reconcile the state in the cluster and update the secrets accordingly.

The External Secrets Operator uses the following CRDs:

- [Secret Store](https://external-secrets.io/v0.5.9/api-secretstore/) - the idea behind the SecretStore resource is to separate concerns of authentication/access and the actual Secret and configuration needed for workloads. The ExternalSecret specifies what to fetch, the SecretStore specifies how to access. This resource is namespaced.
- [Cluster Secret Store](https://external-secrets.io/v0.5.9/api-clustersecretstore/) - The ClusterSecretStore is a global, cluster-wide SecretStore that can be referenced from all namespaces. You can use it to provide a central gateway to your secret provider.
- [External Secret](https://external-secrets.io/v0.5.9/api-externalsecret/) - An ExternalSecret declares what data to fetch. It has a reference to a SecretStore which knows how to access that data. The controller uses that ExternalSecret as a blueprint to create secrets.

During this guide you will be using [Hashicorp Vault](https://www.vaultproject.io/) as a provider for secrets management. Vault itself implements lots of different secret engines. ESO only supports the [KV Secrets Engine](https://www.vaultproject.io/docs/secrets/kv).

## Step 2 - Configuring the Vault Server

**Note:**

The vault server in this chapter is for development/demonstration purposes only.

HashiCorp Vault is an identity-based secrets and encryption management system. A secret is anything that you want to tightly control access to, such as API encryption keys, passwords, and certificates. Vault provides encryption services that are gated by authentication and authorization methods. Using Vault’s UI, CLI, or HTTP API, access to secrets and other sensitive data can be securely stored and managed, tightly controlled (restricted), and auditable.

A modern system requires access to a multitude of secrets, including database credentials, API keys for external services, credentials for service-oriented architecture communication, etc. It can be difficult to understand who is accessing which secrets, especially since this can be platform-specific. Adding on key rolling, secure storage, and detailed audit logs is almost impossible without a custom solution. This is where Vault steps in.

Vault validates and authorizes clients (users, machines, apps) before providing them access to secrets or stored sensitive data.

Please follow the next steps to configure vault:

1. SSH into the droplet created in Step 5.
2. Create a file called `config.hcl` and add the following content to it:

    ```text
    listener "tcp" {
    address = "0.0.0.0:8200"
    tls_disable = "true"
    }

    storage "raft" {
    path = "./vault/data"
    node_id = "node1"
    }
    cluster_addr = "http://127.0.0.1:8201"
    api_addr = "http://127.0.0.1:8200"
    ```

    Explanations for the above configuration:

    - `listener` - Configures how Vault is listening for API requests. It's currently set to listen on all interfaces so your Kubernetes Cluster can communicate to it.
    - `storage` - Configures the storage backend where Vault data is stored. `Raft` is the integrated storage backend used by Vault.

    **Note:**
    When using the Integrated Storage backend, it is required to provide `cluster_addr` and `api_addr` to indicate the address and port to be used for communication between Vault servers in the cluster for client redirection.

3. Create the `vault` directory which will be used as storage from the current working directory:

    ```shell
    mkdir -p vault/data
    ```

4. Start the Vault server using the config file created in the above step:

    ```shell
    vault server -config=config.hcl
    ```

5. Open a new terminal instance and ssh into the droplet

6. Export the `VAULT_ADDR` environment variable to the following:

    ```shell
    export VAULT_ADDR=http://127.0.0.1:8200
    ```

7. Initialize the vault server with the following command:

    ```shell
    vault operator init
    ```

    **IMPORTANT NOTE:**
    After the initialize command the ouput will show 5 `Unseal Keys` and an initial `Root Token`. These are very important. Vault is sealed by default so you will use three keys to unseal it. The `Root Token` value will be used in the `SecretStore` CRD to connect to the `Vault server` from the `Kubernetes Cluster`. You should save these values and keep them stored in a secure place like a Password Manager with limited access.

8. Export the `VAULT_TOKEN` environment variable to the value of the `Root Token` from the previous step:

    ```shell
    export VAULT_TOKEN=<ROOT_TOKEN_VALUE>

9. Unseal the vault server with the `Unseal Kyes` outputted above:

    ```shell
    vault operator unseal
    ```

    You should see something similar to the following:

    ```text
    root@vault:~# vault operator unseal
    Unseal Key (will be hidden):
    Key                Value
    ---                -----
    Seal Type          shamir
    Initialized        true
    Sealed             true
    Total Shares       5
    Threshold          3
    Unseal Progress    1/3
    Unseal Nonce       5f5492b4-b89a-cbf1-9e02-1f95c890710b
    Version            1.11.3
    Build Date         2022-08-26T10:27:10Z
    Storage Type       raft
    HA Enabled         true
    ```

    **Note:**
    Please note that you will need to repeat this step three times with different keys as shown in the `Unseal Progress` line.

10. Enable the KV secrets engine:

    ```shell
    vault secrets enable -path=secret/ kv
    ```

11. Check the status of the Vault server:

    ```shell
    vault status
    ```

    You should see something similar to the following:

    ```text
    root@vault:~# vault status
    Key                     Value
    ---                     -----
    Seal Type               shamir
    Initialized             true
    Sealed                  false
    Total Shares            5
    Threshold               3
    Version                 1.11.3
    Build Date              2022-08-26T10:27:10Z
    Storage Type            raft
    Cluster Name            vault-cluster-5641086a
    Cluster ID              9ea65968-d2fc-cca1-d396-75de70e1289b
    HA Enabled              true
    HA Cluster              https://127.0.0.1:8201
    HA Mode                 active
    Active Since            2022-09-09T12:21:20.509152959Z
    Raft Committed Index    36
    Raft Applied Index      36
    ```

    **Note:**
    Take note of the `Initialized` and `Sealed` lines. They should show `true` and `false`, respectively.

As a precaution you should also restrict incoming connections to the Vault Server Droplet to just the Kubernetes cluster. This is necessary as for the time being as TLS is disabled in the vault config file. To achieve this please follow the next steps:

1. Log into your DO account and go to the "Networking" --> "Firewalls" menu.
2. Click on the "Create Firewall" button.
3. Add a name to the firewall and from the Inbound rules configure the following rule: "Custom" rule type, "TCP" protocol, 8200 port and the "Source" should be set the Kubernetes Cluster which will consume secrets from the Vault server.
4. After the rule is created make sure you add this rule to the droplet from the "Droplets" menu.

**Note:**
TBD - Securing the Vault Server with TLS certificates.

At this point the Vault Server should be initialized and ready for use. In the next section you will create a `ClusterSecretStore` and `ExternalSecret` CRD.

## Step 3 - Installing and Configuring the External Secrets Operator

In this step, you will learn how to deploy `External Secrets Operator` to your `DOKS` cluster, using `Helm`. The chart of interest can be found [here](https://github.com/external-secrets/external-secrets/).

First, clone the `Starter Kit` repository, and then change directory to your local copy:

```shell
git clone https://github.com/digitalocean/Kubernetes-Starter-Kit-Developers.git

cd Kubernetes-Starter-Kit-Developers
```

Next, add the `External Secrets` Helm repository and list the available charts:

```shell
helm repo add external-secrets https://charts.external-secrets.io

helm repo update external-secrets

helm search repo external-secrets
```

The output looks similar to the following:

```text
NAME                                    CHART VERSION   APP VERSION     DESCRIPTION                              
external-secrets/external-secrets       0.5.9           v0.5.9          External secret management for Kubernetes
```

**Notes:**

- It's good practice in general, to use a specific version for the `Helm` chart. This way, you can `version` it using `Git`, and target if for a specific `release`. In this tutorial, the Helm chart version `0.5.9` is picked for `external-secrets`, which maps to application version `0.5.9`.

Next, install the stack using `Helm`. The following command installs version `0.5.9` of `external-secrets/external-secrets` in your cluster, and also creates the `external-secrets` namespace, if it doesn't exist (it also installs CRDs):

```shell
HELM_CHART_VERSION="0.5.9"

helm install external-secrets external-secrets/external-secrets --version "${HELM_CHART_VERSION}" \
  --namespace=external-secrets \
  --create-namespace \
  --set installCRDs=true
```

Finally, check `Helm` release status:

```shell
helm ls -n external-secrets
```

The output looks similar to (`STATUS` column should display 'deployed'):

```text
NAME                    NAMESPACE               REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
external-secrets        external-secrets        1               2022-09-10 10:33:50.324582 +0300 EEST   deployed        external-secrets-0.5.9  v0.5.9    
```

Next, inspect all the `Kubernetes` resources created for `External Secrets`:

```shell
kubectl get all -n external-secrets
```

The output looks similar to:

```text
NAME                                                    READY   STATUS    RESTARTS   AGE
pod/external-secrets-66457766c4-95mvm                   1/1     Running   0          48s
pod/external-secrets-cert-controller-6bd49df95b-8bw6x   1/1     Running   0          48s
pod/external-secrets-webhook-579c46bf-g4z6p             1/1     Running   0          48s

NAME                               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/external-secrets-webhook   ClusterIP   10.245.78.48   <none>        443/TCP   49s

NAME                                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/external-secrets                   1/1     1            1           50s
deployment.apps/external-secrets-cert-controller   1/1     1            1           50s
deployment.apps/external-secrets-webhook           1/1     1            1           50s

NAME                                                          DESIRED   CURRENT   READY   AGE
replicaset.apps/external-secrets-66457766c4                   1         1         1       50s
replicaset.apps/external-secrets-cert-controller-6bd49df95b   1         1         1       50s
replicaset.apps/external-secrets-webhook-579c46bf             1         1         1       50s
```

Next, you will create a `ClusterSecretStore`, which is what External Secrets Operator uses to store information about how to communicate with the given secrets provider. But before you work with the External Secrets Operator, you’ll need to add your Vault token inside a `Kubernetes secret` so that the External Secrets Operator can communicate with the secrets provider. This token was created when you first initalized the operator in [Step 2](#step-2---configuring-the-vault-server).

To create the Kubernetes secret containing the token follow the next steps:

```shell
kubectl create secret generic vault-token --from-literal=token=<YOUR_VAULT_TOKEN>
```

The output should look similar to:

```text
secret/vault-token created
```

**Note:**
The ClusterSecretStore is a cluster scoped SecretStore that can be referenced by all ExternalSecrets from all namespaces whereas SecretStore is namespaced. Use it to offer a central gateway to your secret backend.

A typical `ClusterSecretStore` configuration looks like below:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "<YOUR_DROPLET_ADDRESS>:<PORT>"
      path: "secret"
      version: "v1"
      auth:
        tokenSecretRef:
          name: "<YOUR_SECRET_NAME>"
          key: "<YOUR_SECRET_KEY>"
```

Explanations for the above configuration:

- `spec.provider.vault.server`: Interal IP address of the Vault server droplet. Runs on port 8200.
- `spec.provider.vault.path`: Path where secrets are located.
- `spec.provider.vault.version`: Version of the Vault KV engine.
- `auth.tokenSecretRef.name`: Name of the previously created secret holding the Root Token of the Vault server.
- `auth.tokenSecretRef.key`: Key name in the secret since the secret was created with a key-value pair.

Then, open and inspect the `06-kubernetes-secrets/assets/manifests/cluster-secret-store.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). Please make sure to replace the `<>` placeholders accordingly:

```shell
code 06-kubernetes-secrets/assets/manifests/cluster-secret-store.yaml
```

Next, create the `ClusterSecretStore` resource:

```shell
kubectl apply -f 06-kubernetes-secrets/assets/manifests/cluster-secret-store.yaml
```

This command applies the `ClusterSecretStore` CRD to your cluster and creates the object. You can see the object by running the following command, which will show you all of the information about the object inside of Kubernetes:

```shell
kubectl get ClusterSecretStore vault-backend
```

You should see something similar to:

```text
NAME            AGE   STATUS   READY
vault-backend   97s   Valid    True
```

**Note:**
If you created the SecretStore successfully, you should see the `STATUS` column with a `Valid` value. If not, a very common issue is `message: unable to validate store`. This generally means that the authentication method for your client has failed as the ClusterSecretStore will try and create a client for your provider to verify everything is working. Recheck the secret containing the token and the status of the vault server.

## Step 4 - Fetching an Example Secret

In this section, you will create an `ExternalSecret`, which is the main resource in the `External Secrets Operator`. The `ExternalSecret` resource tells ESO to fetch a specific secret from a specific `SecretStore` and where to put the information. This resource is very important because it defines what secret you’d like to get from the external secret provider, where to put it, which secret store to use, and how often to sync the secret, among several other options.

Before creating the `ExternalSecret` you need to have a secret available in the `VaultServer`. If you do not have one, follow the next steps:

1. SSH into the Vault Server droplet (if you closed the server you will need to restart the server and unseal it. Steps highlighted in [Step 2](#step-2---configuring-the-vault-server))
2. Create a secret using the following command:

    ```ssh
    vault kv put -mount=secret secret key=secret-value
    ```

    You should see the following output:

    ```text
    Success! Data written to: secret/secret
    ```

A typical `ExternalSecret` configuration looks like below:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: <EXTERNAL_SECRET_NAME>
spec:
  refreshInterval: "15s"
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: <KUBERNETES_SECRET_NAME>
    creationPolicy: Owner
  data:
    - secretKey: <SECRET_KEY>
      remoteRef:
        key: <VAULT_SECRET_KEY>
        property: <VAULT_SECRET_PROPRETY>

```

Explanations for the above configuration:

- `spec.refreshInterval`: How often this secret is synchronized. If the secret's value changes in Vault it will be updated it's Kubernetes counterpart.
- `spec.secretStoreRef`: Referance to the `ClusterSecretStore` resource created earlier.
- `spec.target.name`: Secret to be created in Kuberentes. If not present, then the `secretKey` field under `data` will be used
- `spec.target.creationPolicy`: This will create the secret if it doesn't exist
- `data.[].secretKey`: This is the key inside of the Kubernetes secret that you would like to populate.
- `data.[].remoteRef.key`: This is the remote key in the secret provider. (As an example the previously created secret would be: `secret/secret`)
- `data.[].remoteRef.property`: This is the property inside of the secret at the path specified in in `data.[].remoteRef.key`. (As an example the previously created secret would be: `key`)

Then, open and inspect the `06-kubernetes-secrets/assets/manifests/external-secret.yaml` file provided in the `Starter Kit` repository, using an editor of your choice (preferably with `YAML` lint support). Please make sure to replace the `<>` placeholders accordingly:

```shell
code 06-kubernetes-secrets/assets/manifests/cluster-secret-store.yaml
```

Next, create the `ExternalSecret` resource:

```shell
kubectl apply -f 06-kubernetes-secrets/assets/manifests/external-secret.yaml
```

This command applies the `ExternalSecret` CRD to your cluster and creates the object. You can see the object by running the following command, which will show you all of the information about the object inside of Kubernetes:

```shell
kubectl get ExternalSecret example-sync
```

You should see something similar to:

```text
NAME           STORE           REFRESH INTERVAL   STATUS         READY
example-sync   vault-backend   15s                SecretSynced   True
```

If the previous output has a `Sync Error` under `STATUS`, nmake sure your `SecretStore` is set up correctly. You can view the actual error by running the following command:

```shell
kubectl get ExternalSecret example-sync -o yaml
```

## Conclusion

In this tutorial, you learned how to setup `Vault` on an external server and how to setup and configure the `External Secrets Operator`. You enabled communication between your DOKS cluster and the `Vault Server` making use of the `External Secrets Operator` CRDs.
You also created a secret in your DOKS cluster by syncing an existing secret in `Vault Server`.

This guide showed the basic functionalities of both `Vault` and `External Secrets Operator`
For more advanced funtionalities make sure you read their documentation here:

- [Vault](https://www.vaultproject.io/)
- [External Secrets Operator](https://external-secrets.io/)

Go to [Section 7 - Scaling Application Workloads](../07-scaling-application-workloads/README.md).
