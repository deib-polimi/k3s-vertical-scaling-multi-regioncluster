#########################################
#                                       #
#              SSH Key                  #
#                                       #
#########################################

resource "aws_key_pair" "edge_autoscaler" {
  key_name   = "kosmos-2"
  public_key = file(var.SSH_PUBLIC_KEYPATH)
}

#########################################
#                                       #
#              K3s secret               #
#                                       #
#########################################

resource "random_password" "k3s" {
  count   = var.master ? 1 : 0
  length  = 30
  special = false
}

#########################################
#                                       #
#                  VPC                  #
#                                       #
#########################################

resource "aws_vpc" "edge_autoscaler" {
  tags = {
    Name = "edge_autoscaler"
  }

  cidr_block           = "10.255.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "edge_autoscaler" {
  vpc_id = aws_vpc.edge_autoscaler.id

  tags = {
    Name = "edge_autoscaler"
  }
}

resource "aws_route_table" "edge_autoscaler" {
  vpc_id = aws_vpc.edge_autoscaler.id

  depends_on = [
    aws_internet_gateway.edge_autoscaler,
    aws_vpc.edge_autoscaler,
  ]

  tags = {
    Name = "edge_autoscaler"
  }

  route {
    //associated subnet can reach everywhere
    cidr_block = "0.0.0.0/0" //CRT uses this IGW to reach internet
    gateway_id = aws_internet_gateway.edge_autoscaler.id
  }
}

resource "aws_route_table_association" "edge_autoscaler" {
  depends_on = [
    aws_subnet.edge_autoscaler,
    aws_route_table.edge_autoscaler,
  ]

  count          = length(aws_subnet.edge_autoscaler)
  subnet_id      = aws_subnet.edge_autoscaler[count.index].id
  route_table_id = aws_route_table.edge_autoscaler.id
}
#########################################
#                                       #
#                 Subnet                #
#                                       #
#########################################

resource "aws_subnet" "edge_autoscaler" {
  vpc_id = aws_vpc.edge_autoscaler.id

  # count = length(local.subnets_cidr)
  count = local.subnets

  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  cidr_block              = local.subnets_cidr[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = format("edge-autoscaler-%s", data.aws_availability_zones.azs.names[count.index])
  }
}


#########################################
#                                       #
#            Security Group             #
#                                       #
#########################################

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.edge_autoscaler.id

  depends_on = [
    aws_vpc.edge_autoscaler
  ]

  tags = {
    Name = "edge_autoscaler"
  }
}

resource "aws_security_group_rule" "ingress_all" {

  depends_on = [
    aws_security_group.sg
  ]

  type              = "ingress"
  security_group_id = aws_security_group.sg.id
  protocol          = -1
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

resource "aws_security_group_rule" "egress_all" {

  depends_on = [
    aws_security_group.sg
  ]

  type              = "egress"
  security_group_id = aws_security_group.sg.id
  from_port         = 0
  to_port           = 0
  protocol          = -1
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
}

#########################################
#                                       #
#              Master Node              #
#                                       #
#########################################


module "master" {
  source = "../node"

  depends_on = [
    aws_key_pair.edge_autoscaler,
    random_password.k3s[0],
    aws_security_group_rule.egress_all,
    aws_security_group_rule.ingress_all,
    aws_route_table.edge_autoscaler,
  ]

  instance_type = var.master_instance_type

  disk_size = 60
  
  count = var.master ? 1 : 0

  subnet_id              = aws_subnet.edge_autoscaler[0].id
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name               = aws_key_pair.edge_autoscaler.key_name

  ami       = data.aws_ami.ubuntu.id
  node_name = "k3s-master"
}



#########################################
#                                       #
#            Worker CPU Nodes           #
#                                       #
#########################################

module "workers_cpu" {
  source = "../node"

  depends_on = [
    module.master
  ]

  instance_type = var.worker_instance_type

  for_each = toset(formatlist("%d", range(var.master ? 1 : 0, var.master ? var.cpu_instances + 1 : var.cpu_instances)))

  subnet_id              = aws_subnet.edge_autoscaler[each.value % local.subnets].id
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name               = aws_key_pair.edge_autoscaler.key_name

  ami       = data.aws_ami.ubuntu.id
  node_name = format("${local.worker_prefix}-${var.region}-%d", each.value)
}



#########################################
#                                       #
#            Worker GPU Nodes           #
#                                       #
#########################################

module "workers_gpu" {
  source = "../node"

  depends_on = [
    module.master
  ]

  instance_type = "g4dn.xlarge"

  for_each = toset(formatlist("%d", range(var.master ? 1 : 0, var.master ? var.gpu_instances + 1 : var.gpu_instances)))

  subnet_id              = aws_subnet.edge_autoscaler[each.value % local.subnets].id
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name               = aws_key_pair.edge_autoscaler.key_name

  ami       = data.aws_ami.ubuntu.id
  node_name = format("${local.worker_prefix}-${var.region}-gpu-%d", each.value)
}

########################################
#                                      #
#             Master init              #
#                                      #
########################################

resource "null_resource" "master_init" {

  depends_on = [
    module.master
  ]

  count = var.master ? 1 : 0

  connection {
    agent       = false
    type        = "ssh"
    port        = 22
    user        = "ubuntu"
    password    = ""
    private_key = file(pathexpand(var.ssh_private_key_path))
    host        = module.master[0].public_ip
  }

  provisioner "file" {
    source      = "./scripts/"
    destination = "/home/ubuntu"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 777 k3s",
      "sudo apt update",
      "sudo apt upgrade -y",
      "sudo apt install -y docker.io",
      "sudo apt install -y linuxbrew-wrapper",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo cp -r ./k3s /usr/local/bin/",
      "sudo snap install helm --classic",
      "sudo snap install go --classic",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_DOWNLOAD=true K3S_KUBECONFIG_MODE=666 INSTALL_K3S_VERSION=v1.19.13+k3s1 INSTALL_K3S_EXEC='server --token=${random_password.k3s[0].result} --node-external-ip=${module.master[0].public_ip} --node-name=${module.master[0].node_name} --docker --cluster-init --write-kubeconfig-mode  777 --kube-apiserver-arg=feature-gates=InPlacePodVerticalScaling=true,ServiceTopology=true' sh -",
      # "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=666 INSTALL_K3S_EXEC='server --token=${random_password.k3s[0].result} --node-external-ip=${module.master[0].public_ip} --node-name=${module.master[0].node_name} --docker --cluster-init --write-kubeconfig-mode  777 --kube-apiserver-arg=feature-gates=ServiceTopology=true' sh -",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir /home/ubuntu/.kube",
      "sudo mv /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config",
      "sudo chmod u+rwx /home/ubuntu/.kube/config",
      "sudo chmod go-rwx /home/ubuntu/.kube/config",
      "sudo chown ubuntu /home/ubuntu/.kube/config",
      "kubectl apply -f https://raw.githubusercontent.com/alekc-go/flannel-fixer/master/deployment.yaml",
      "chmod +x install-ea.sh",
    ]
  }
}

#########################################
#                                       #
#              Worker init              #
#                                       #
#########################################

resource "null_resource" "worker_init" {

  depends_on = [
    module.master[0],
    module.workers_cpu,
    null_resource.master_init
  ]

  for_each = module.workers_cpu

  connection {
    agent       = false
    type        = "ssh"
    user        = "ubuntu"
    password    = ""
    timeout     = "10m"
    private_key = file(pathexpand(var.ssh_private_key_path))
    host        = each.value.public_ip
  }
  provisioner "file" {
    source      = "./scripts/k3s"
    destination = "/home/ubuntu/k3s"
  }

  # Change permissions on bash script and execute from ec2-user.
  provisioner "remote-exec" {
    inline = [
      "sudo chmod 777 k3s",
      "sudo apt update",
      "sudo apt upgrade -y",
      "sudo apt install -y docker.io",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo cp -r ./k3s /usr/local/bin/",
      "sleep 30",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_DOWNLOAD=true K3S_KUBECONFIG_MODE=666 INSTALL_K3S_VERSION=v1.19.13+k3s1 K3S_TOKEN=${var.master ? random_password.k3s[0].result : var.cluster_secret} K3S_URL=https://${var.master ? module.master[0].public_ip : var.master_ip}:6443 INSTALL_K3S_EXEC=' --node-name=${each.value.node_name} --node-external-ip=${each.value.public_ip} --docker ' sh -",
      # "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=666 K3S_TOKEN=${var.master ? random_password.k3s[0].result : var.cluster_secret} K3S_URL=https://${var.master ? module.master[0].public_ip : var.master_ip}:6443 INSTALL_K3S_EXEC=' --node-name=${each.value.node_name} --node-external-ip=${each.value.public_ip} --docker ' sh -",
    ]
  }
}


resource "null_resource" "worker_gpu_init" {

  depends_on = [
    module.master[0],
    module.workers_gpu,
    null_resource.master_init
  ]

  for_each = module.workers_gpu

  connection {
    agent       = false
    type        = "ssh"
    user        = "ubuntu"
    password    = ""
    timeout     = "10m"
    private_key = file(pathexpand(var.ssh_private_key_path))
    host        = each.value.public_ip
  }
  provisioner "file" {
    source      = "./scripts/k3s"
    destination = "/home/ubuntu/k3s"
  }


  # Change permissions on bash script and execute from ec2-user.
  provisioner "remote-exec" {
    inline = [
      "sudo chmod 777 k3s",
      "sudo apt update",
      "sudo apt upgrade -y",
      "sudo add-apt-repository ppa:graphics-drivers/ppa -y",
      "sudo apt -y install nvidia-headless-470 nvidia-driver-470 nvidia-compute-utils-470 nvidia-cuda-toolkit",
      "sudo shutdown -r",
    ]
  }

  provisioner "local-exec" {
    command = "sleep 180"
  }

  provisioner "remote-exec" {
    inline = [
      "distribution=$(. /etc/os-release;echo $ID$VERSION_ID) && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -  && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list",
      "sudo apt update",
      "sudo apt install nvidia-docker2 -y",
      "sudo systemctl restart docker",
      "sudo cp -r ./k3s /usr/local/bin/",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_DOWNLOAD=true K3S_KUBECONFIG_MODE=666 INSTALL_K3S_VERSION=v1.19.13+k3s1 K3S_TOKEN=${var.master ? random_password.k3s[0].result : var.cluster_secret} K3S_URL=https://${var.master ? module.master[0].public_ip : var.master_ip}:6443 INSTALL_K3S_EXEC=' --node-name=${each.value.node_name} --node-external-ip=${each.value.public_ip} ' sh -",
      # "curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=666 K3S_TOKEN=${var.master ? random_password.k3s[0].result : var.cluster_secret} K3S_URL=https://${var.master ? module.master[0].public_ip : var.master_ip}:6443 INSTALL_K3S_EXEC=' --node-name=${each.value.node_name} --node-external-ip=${each.value.public_ip} ' sh -",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 10",
      "sudo wget https://k3d.io/usage/guides/cuda/config.toml.tmpl -O /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl;",
      "sudo systemctl restart k3s-agent",
    ]
  }
}


resource "null_resource" "label_gpu_nodes" {

  depends_on = [
    null_resource.worker_gpu_init
  ]

  for_each = module.workers_gpu

  connection {
    agent       = false
    type        = "ssh"
    port        = 22
    user        = "ubuntu"
    password    = ""
    private_key = file(pathexpand(var.ssh_private_key_path))
    host        = var.master ? module.master[0].public_ip : var.master_ip
  }

  provisioner "local-exec" {
    command = "sleep 60"
  }

  provisioner "remote-exec" {
    inline = [
      "kubectl label node ${each.value.node_name} k8s.amazonaws.com/accelerator=vgpu",
      "kubectl label node ${each.value.node_name} edgeautoscaler.polimi.it/gpu-memory=16G",
      "kubectl label node ${each.value.node_name} edgeautoscaler.polimi.it/gpu=true",
      "kubectl label node ${each.value.node_name} edgeautoscaler.polimi.it/node=worker",
    ]
  }
}

# resource "null_resource" "label_cpu_nodes" {

#   depends_on = [
#     null_resource.worker_init
#   ]

#   for_each = module.workers_cpu

#   connection {
#     agent       = false
#     type        = "ssh"
#     port        = 22
#     user        = "ubuntu"
#     password    = ""
#     private_key = file(pathexpand(var.ssh_private_key_path))
#     host        = var.master ? module.master[0].public_ip : var.master_ip
#   }

#   provisioner "local-exec" {
#     command = "sleep 120"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "kubectl label node ${each.value.node_name} edgeautoscaler.polimi.it/node=worker",
#     ]
#   }
# }