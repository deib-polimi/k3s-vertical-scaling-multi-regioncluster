locals {
  worker_prefix  = "ea-k3s-node"
  az_per_region  = min(var.az_per_region, length(data.aws_availability_zones.azs.names))
  needed_subnets = var.master ? max(var.cpu_instances, var.gpu_instances) + 1 : max(var.cpu_instances, var.gpu_instances)
  subnets        = max(1, min(local.az_per_region, local.needed_subnets))
  cidr_mask      = ceil(local.az_per_region / 2) + 1
  subnets_cidr = [
    for i in range(local.subnets) :
    cidrsubnet(aws_vpc.edge_autoscaler.cidr_block, local.cidr_mask, i)
  ]
}
