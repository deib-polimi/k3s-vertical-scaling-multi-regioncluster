output "master_endpoint" {
  value = var.master ? module.master[0].public_ip : var.master_ip
}

output "workers_endpoint" {
  value = merge(
    {
      for worker in module.workers_cpu :
      (worker.node_name) => worker.public_ip
    },
    {
      for worker in module.workers_gpu :
      (worker.node_name) => worker.public_ip
    }
  )
}
output "cluster_secret" {
  value = var.master ? random_password.k3s[0].result : var.cluster_secret
}
