# data "http" "aes-crd" {
#   url = "https://app.getambassador.io/yaml/edge-stack/2.1.2/aes-crds.yaml"

# }

# output "data_http" {
#   value = data.http.aes-crd.body
# }

# resource "kubectl_manifest" "aes-crd-manifest" {
#   yaml_body = "https://app.getambassador.io/yaml/edge-stack/2.1.2/aes-crds.yaml"
# }

# resource "helm_release" "ambassador_ingress" {
#  name      = "ambassador"
#  namespace = "ambassador"

#  repository       = "https://app.getambassador.io"
#  chart            = "edge-stack"
#  version          = "7.2.2"
#  create_namespace = true

#    set {
#      name  = "emissary-ingress.createDefaultListeners"
#      value = "true"
#    }

# }
