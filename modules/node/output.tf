output "public_ip" {
  value = aws_spot_instance_request.k3s_node.public_ip
}

output "node_name" {
  value = var.node_name
}
