data "http" "aes-crd" {
  url = "https://app.getambassador.io/yaml/edge-stack/2.1.2/aes-crds.yaml"
}

data "kubectl_file_documents" "aes_crd_body" {
  content = data.http.aes-crd.body
}

resource "kubectl_manifest" "aes-crd-manifest" {
  for_each  = data.kubectl_file_documents.aes_crd_body.manifests
  yaml_body = each.value
}

resource "helm_release" "ambassador_ingress" {
 name      = "ambassador"
 namespace = "ambassador"

 repository       = "https://app.getambassador.io"
 chart            = "edge-stack"
 version          = "7.2.2"
 create_namespace = true

   set {
     name  = "emissary-ingress.createDefaultListeners"
     value = "true"
   }
}

resource "kubernetes_manifest" "echo-host" {
  manifest = {
    "apiVersion" = "getambassador.io/v3alpha1"
    "kind"       = "Host"
    "metadata" = {
      "name"      = "echo-host"
      "namespace" = helm_release.ambassador_ingress.namespace
    }
    "spec" = {
      "hostname" = "*"
      "requestPolicy" = {
        "insecure" = {
          "action" = "Route"
          "additionalPort" = "8080"
        }
      }
    }
  }
}

resource "kubernetes_manifest" "echo-mapping" {
  manifest = {
    "apiVersion" = "getambassador.io/v3alpha1"
    "kind"       = "Mapping"
    "metadata" = {
      "name"      = "echo-backend"
      "namespace" = helm_release.ambassador_ingress.namespace
    }
    "spec" = {
      "prefix" = "/echo/"
      "hostname": "*"
      "service": "echo-service.backend"
    }
  }
}

resource "kubernetes_namespace" "aes-backend" {
  metadata {
    name = "aes-backed"
  }
}

resource "kubernetes_deployment" "aes-echo" {
  metadata {
    name      = "echo"
    namespace = kubernetes_namespace.aes-backend.metadata.0.name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "echo"
      }
    }
    strategy {
      type = "RollingUpdate"
    }
    template {
      metadata {
        labels = {
          app = "echo"
        }
      }
      spec {
        container {
          image = "jmalloc/echo-server"
          name  = "echo"

          port {
            container_port = "8080"
          }

          resources {
            limits = {
              memory = "512M"
              cpu    = "1"
            }
            requests = {
              memory = "256M"
              cpu    = "50m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "aes-echo" {
  metadata {
    name      = "echo-service"
    namespace = kubernetes_namespace.aes-backend.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.aes-echo.metadata.0.name
    }

    port {
      port        = 80
      target_port = 8080
    }
  }
}