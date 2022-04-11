resource "helm_release" "nginx_ingress" {
  name      = "ingress-nginx"
  namespace = "ingress-nginx"

  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.0.13"
  create_namespace = true

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/do-loadbalancer-name"
    value = format("%s-nginx-ingress", var.cluster_name)
  }
}

resource "kubernetes_namespace" "backend" {
  metadata {
    name = "backend"
  }
}

resource "kubernetes_deployment" "echo" {
  metadata {
    name      = "echo"
    namespace = kubernetes_namespace.backend.metadata.0.name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "echo"
      }
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

resource "kubernetes_service" "echo" {
  metadata {
    name      = "echo-service"
    namespace = kubernetes_namespace.backend.metadata.0.name
  }
  spec {
    selector = {
      app = kubernetes_deployment.echo.metadata.0.name
    }

    port {
      port        = 80
      target_port = 8080
    }
  }
}

resource "kubernetes_ingress" "test_ingress" {
  wait_for_load_balancer = true
  metadata {
    name      = "test-ingress"
    namespace = kubernetes_namespace.backend.metadata.0.name
    annotations = {
      "kubernetes.io/ingress.class"          = "nginx"
      "ingress.kubernetes.io/rewrite-target" = "/"
    }
  }

  spec {
    rule {
      http {
        path {
          backend {
            service_name = kubernetes_service.echo.metadata.0.name
            service_port = 80
          }

          path = "/test"
        }
      }
    }
  }
}
