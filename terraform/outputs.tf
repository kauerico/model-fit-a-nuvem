output "public_ip" {
  value = aws_instance.k3s.public_ip
}

output "api_url" {
  value = "http://${aws_instance.k3s.public_ip}:${var.node_port}"
}

output "instance_id" {
  description = "GitHub Secret EC2_INSTANCE_ID"
  value       = aws_instance.k3s.id
}

output "github_access_key_id" {
  description = "GitHub Secret AWS_ACCESS_KEY_ID"
  value       = aws_iam_access_key.github_deploy.id
}

output "github_secret_access_key" {
  description = "GitHub Secret AWS_SECRET_ACCESS_KEY (terraform output -raw ...)"
  value       = aws_iam_access_key.github_deploy.secret
  sensitive   = true
}

output "ssh" {
  value = "ssh ubuntu@${aws_instance.k3s.public_ip}"
}

# A 6443 não fica exposta: o kubectl local passa por um túnel SSH.
output "kubeconfig_command" {
  value = <<-EOT
    ssh ubuntu@${aws_instance.k3s.public_ip} sudo cat /etc/rancher/k3s/k3s.yaml > ../kubeconfig-aws.yaml
    ssh -N -L 6443:127.0.0.1:6443 ubuntu@${aws_instance.k3s.public_ip} &
    export KUBECONFIG=$PWD/../kubeconfig-aws.yaml && kubectl get pods
  EOT
}
