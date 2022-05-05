variable "AWS_CREDENTIALS_FILEPATH" {
}

variable "SSH_PUBLIC_KEYPATH" {
}

variable "SSH_PRIVATE_KEYPATH" {
}

variable "ubuntu_account_number" {
  default = "099720109477"
}

variable "instances_per_az" {
  description = "Number of EC2 instances in each private subnet"
  type        = number
  default     = 1
}

variable "az_per_region" {
  description = "Specify how many subnets terraform should use per region to create nodes"
  type        = number
  default     = 3
}
