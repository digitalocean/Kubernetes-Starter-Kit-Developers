data "kubectl_file_documents" "aes-crd" {
  content = file("manifests/aes-crds-2.2.2.yaml")
}

resource "kubectl_manifest" "install-aes-crd" {
  for_each  = data.kubectl_file_documents.aes-crd.manifests
  yaml_body = each.value
}

resource "helm_release" "ambassador_ingress" {
  depends_on = [kubectl_manifest.install-aes-crd]
  name       = "ambassador"
  namespace  = "ambassador"

  repository       = "https://app.getambassador.io"
  chart            = "edge-stack"
  version          = var.helm_chart_ambassador
  create_namespace = true
  atomic           = true

  set {
    name  = "emissary-ingress.createDefaultListeners"
    value = "true"
  }
}
