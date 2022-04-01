
variable "cluster_version" {
  default = "1.21"
}

variable "worker_count" {
  default = 3
}

variable "worker_size" {
  default = "s-4vcpu-8gb-amd"
}

variable "write_kubeconfig" {
  type    = bool
  default = false
}
