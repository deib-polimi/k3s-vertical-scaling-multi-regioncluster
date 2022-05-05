variable "aws_credentials_filepath" {

}

variable "SSH_PUBLIC_KEYPATH" {
}

variable "ssh_private_key_path" {
}

variable "master" {
  description = "indicates whether a master node should be created in region"
  type        = bool
  default     = false
}

variable "region" {
  type = string
}

variable "master_ip" {
  type    = string
  default = ""
}

variable "cpu_instances" {
  description = "Number of EC2 instances"
  type        = number
  default     = 3
}

variable "gpu_instances" {
  description = "Number of EC2 instances"
  type        = number
  default     = 1
}

variable "az_per_region" {
  description = "Specify how many subnets terraform should use per region to create nodes"
  type        = number
  default     = 3
}

variable "cluster_secret" {
  description = "Secret used by nodes to join the cluster"
  type        = string
  default     = ""
}

variable "master_instance_type" {
  type    = string
  default = "t3.large"
}

variable "worker_instance_type" {
  type    = string
  default = "t3.large"
}
