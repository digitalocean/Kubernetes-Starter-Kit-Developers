output "cluster_id" {
  value = digitalocean_kubernetes_cluster.primary.id
}

output "cluster_name" {
  value = digitalocean_kubernetes_cluster.primary.name
}
