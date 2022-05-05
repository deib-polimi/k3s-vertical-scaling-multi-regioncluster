variable "subnet_id" {
  type    = string
  default = ""
}

variable "vpc_security_group_ids" {
  type    = list(any)
  default = []
}

variable "key_name" {
  type    = string
  default = ""
}

variable "ami" {
  type    = string
  default = ""
}

variable "disk_size" {
  type    = number
  default = 30
}

variable "node_name" {
  type    = string
  default = ""
}

variable "instance_type" {
  type    = string
  default = "t3.large"
}
