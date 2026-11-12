output "instance_id" {
  value = aws_instance.k3s.id
}

output "public_ip" {
  value = aws_instance.k3s.public_ip
}

output "api_url" {
  value = "http://${aws_instance.k3s.public_ip}:${var.node_port}"
}

# Sem SSH: abra um shell na EC2 pelo SSM (precisa do session-manager-plugin)
output "shell" {
  value = "aws ssm start-session --region ${var.region} --target ${aws_instance.k3s.id}"
}
