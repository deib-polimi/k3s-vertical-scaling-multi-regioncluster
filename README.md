
# NEPTUNE Infrastructure
<p align="center">
  <img width="100%" src="https://i.imgur.com/tm9mSuM.png" alt="Politecnico di Milano" />
</p>

## Overview

NEPTUNE-infrastructure is an infrastructure as code definition for k3s cluster in edge-autoscaler project. It uses Terraform to create multi-region and multi-availability zones AWS clusters with networking delays similar to an edge computing cluster.

# Getting started
- `terraform init`
- `terraform validate`
- create a `scripts` directory and populate it with the files that should be copied on each node (at least `k3s` executable is required)
- create a valid plan:
```
    terraform plan -out plan \  
    -var 'AWS_CREDENTIALS_FILEPATH=<value>' \  
    -var 'SSH_PUBLIC_KEYPATH=<value>' \  
    -var 'SSH_PRIVATE_KEYPATH=<value>'
```
- apply the plan
```
terraform apply plan
```
- Enjoy your k3s cluster
