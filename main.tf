module "master_region" {
  source = "./modules/regional_cluster"

  region = "us-east-2"

  master               = true
  master_instance_type = "c5.4xlarge"
  worker_instance_type = "c5.xlarge"
  cpu_instances        = 3
  gpu_instances        = 0
  ssh_private_key_path = var.SSH_PRIVATE_KEYPATH
  SSH_PUBLIC_KEYPATH   = var.SSH_PUBLIC_KEYPATH
  az_per_region        = var.az_per_region

  aws_credentials_filepath = var.AWS_CREDENTIALS_FILEPATH
}

module "workers_region" {
  source = "./modules/regional_cluster"

  region               = "us-east-1"
  master               = false
  worker_instance_type = "c5.xlarge"
  cpu_instances        = 3
  gpu_instances        = 0
  ssh_private_key_path = var.SSH_PRIVATE_KEYPATH
  SSH_PUBLIC_KEYPATH   = var.SSH_PUBLIC_KEYPATH
  az_per_region        = var.az_per_region
  master_ip            = module.master_region.master_endpoint
  cluster_secret       = module.master_region.cluster_secret

  aws_credentials_filepath = var.AWS_CREDENTIALS_FILEPATH
}