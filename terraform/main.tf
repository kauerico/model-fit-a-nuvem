# Uma única EC2 com k3s. EKS custaria ~US$ 73/mês só pelo plano de controle.

locals {
  # t4g, m7g, c7g... (letra "g" após o número) = Graviton/arm64
  arm  = can(regex("^[a-z]+[0-9]+g", var.instance_type))
  arch = local.arm ? "arm64" : "amd64"
}

# Ubuntu 24.04 oficial da Canonical (já vem com o agente do SSM)
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/${local.arch}/hvm/ebs-gp3/ami-id"
}

data "aws_vpc" "default" {
  default = true
}

# ---------- Rede: só SSH (do seu IP) e a NodePort da API ----------
resource "aws_security_group" "k3s" {
  name        = "fake-news-k3s"
  description = "SSH do apresentador e NodePort da API. A 6443 fica fechada."
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.k3s.id
  description       = "SSH so do meu IP"
  cidr_ipv4         = var.my_ip_cidr
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "api" {
  security_group_id = aws_security_group.k3s.id
  description       = "NodePort da API"
  cidr_ipv4         = var.app_cidr
  ip_protocol       = "tcp"
  from_port         = var.node_port
  to_port           = var.node_port
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.k3s.id
  description       = "Saida liberada (baixar k3s, imagens do GHCR, falar com o SSM)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------- Permissão da EC2: ser gerenciada pelo SSM ----------
resource "aws_iam_role" "ec2" {
  name = "fake-news-ec2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "fake-news-ec2"
  role = aws_iam_role.ec2.name
}

# ---------- A instância ----------
resource "aws_key_pair" "me" {
  key_name   = "fake-news"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "aws_instance" "k3s" {
  ami                    = data.aws_ssm_parameter.ubuntu.value
  instance_type          = var.instance_type
  key_name               = aws_key_pair.me.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # user_data roda uma vez, no primeiro boot: instala k3s e Helm
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    k3s_version  = var.k3s_version
    helm_version = var.helm_version
    arch         = local.arch
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  # IMDSv2 obrigatório (boa prática contra roubo de credenciais via SSRF)
  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "fake-news-k3s" }

  # Uma AMI nova da Canonical não deve recriar a instância no meio do semestre
  lifecycle {
    ignore_changes = [ami]
  }
}
