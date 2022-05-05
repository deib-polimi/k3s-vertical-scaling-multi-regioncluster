terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.59.0"
    }
  }
}

provider "aws" {
  region                  = var.region
  shared_credentials_file = var.aws_credentials_filepath
}
