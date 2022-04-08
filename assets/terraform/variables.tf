
variable "cluster_version" {
  default = "1.21"
}

variable "worker_count" {
  default = 3
}

variable "worker_size" {
  default = "s-4vcpu-8gb-amd"
}

variable "helm_chart_nginx" {
  default = "4.0.13"
}

variable "helm_chart_ambassador" {
  default = "7.2.2"
}

variable "write_kubeconfig" {
  type    = bool
  default = false
}