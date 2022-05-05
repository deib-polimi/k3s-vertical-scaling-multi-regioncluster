# ea-infrastructure
Infrastructure as code definition for k3s cluster in edge-autoscaler project

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
terraform apply "plan" \  
    -var 'AWS_CREDENTIALS_FILEPATH=<value>' \  
    -var 'SSH_PUBLIC_KEYPATH=<value>' \  
    -var 'SSH_PRIVATE_KEYPATH=<value>'
```
- Enjoy your k3s cluster