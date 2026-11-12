variable "region" {
  description = "Região da AWS"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "Perfil do AWS CLI (configurado com `aws configure sso`)"
  type        = string
  default     = "cefet"
}

variable "instance_type" {
  description = "Tipo da EC2. t4g = Graviton (arm64); t3 = Intel (amd64)"
  type        = string
  default     = "t4g.small"
}

variable "my_ip_cidr" {
  description = "Seu IP público em CIDR (ex.: 203.0.113.10/32). Único IP com SSH"
  type        = string
}

variable "app_cidr" {
  description = "Quem pode acessar a API na NodePort. Aberto para a plateia testar"
  type        = string
  default     = "0.0.0.0/0"
}

variable "node_port" {
  description = "NodePort do Service (igual ao values-aws.yaml do Helm)"
  type        = number
  default     = 30080
}

variable "ssh_public_key_path" {
  description = "Chave pública SSH instalada na EC2"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "k3s_version" {
  description = "Versão fixada do k3s"
  type        = string
  default     = "v1.37.2+k3s1"
}

variable "helm_version" {
  description = "Versão fixada do Helm instalado na EC2"
  type        = string
  default     = "v4.3.1"
}

variable "github_repo" {
  description = "Repositório (dono/nome) cujo GitHub Actions pode implantar"
  type        = string
  default     = "kauerico/model-fit-a-nuvem"
}

variable "budget_limit_usd" {
  description = "Limite mensal do alerta de custo (US$)"
  type        = string
  default     = "15"
}

variable "budget_email" {
  description = "E-mail que recebe os alertas do AWS Budgets"
  type        = string
  sensitive   = true
}
