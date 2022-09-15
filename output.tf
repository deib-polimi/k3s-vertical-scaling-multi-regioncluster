output "master_endpoint" {
  value = {
    "master" = module.master_region.master_endpoint
  }
}

output "master_region_nodes" {
  value = module.master_region.workers_endpoint
}

# output "workers_region_nodes" {
#   value = module.workers_region.workers_endpoint
# }
