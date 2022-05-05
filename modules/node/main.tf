resource "aws_spot_instance_request" "k3s_node" {

  wait_for_fulfillment = true

  associate_public_ip_address = true

  ####################################
  #                                  #
  #             AMI                  #
  #                                  #
  ####################################

  ami           = var.ami
  instance_type = var.instance_type

  ####################################
  #                                  #
  #    Subnet and security group     #
  #                                  #
  ####################################

  # Used to put master node in the last subnet to avoid
  # having some components in the same subnet

  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids
  key_name               = var.key_name

  ####################################
  #                                  #
  #             Disk                 #
  #                                  #
  ####################################
  root_block_device {
    volume_size = var.disk_size
    volume_type = "gp2"
  }
}

resource "aws_ec2_tag" "name_tag" {
  resource_id = aws_spot_instance_request.k3s_node.id
  key         = "Name"
  value       = var.node_name
}