variable "region" {
  description = "Região da AWS (nesta conta, a organização só libera EC2 em us-east-2)"
  type        = string
  default     = "us-east-2"
}

variable "instance_type" {
  description = "Tipo da EC2. t4g = Graviton (arm64); t3 = Intel (amd64)"
  type        = string
  default     = "t4g.small"
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

# SSH é opcional: a demo não precisa dele (deploy via SSM, API pela NodePort).
# Para usar kubectl da sua máquina, preencha os dois.
variable "ssh_cidr" {
  description = "IP com acesso SSH, em CIDR (ex.: 203.0.113.10/32). Vazio = sem SSH"
  type        = string
  default     = ""
}

variable "ssh_public_key" {
  description = "Conteúdo da chave pública SSH. Vazio = sem key pair"
  type        = string
  default     = ""
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

variable "budget_limit_usd" {
  description = "Limite mensal do alerta de custo (US$)"
  type        = string
  default     = "5"
}

variable "budget_email" {
  description = "E-mail que recebe os alertas do AWS Budgets"
  type        = string
}
