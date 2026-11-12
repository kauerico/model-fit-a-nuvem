# Credencial do GitHub Actions para implantar.
#
# O ideal é OIDC (sem chave guardada: o GitHub troca um token por credenciais
# temporárias). Nesta conta a organização bloqueia o provedor OIDC do GitHub,
# então usamos um usuário IAM com o MÍNIMO de permissão: mandar comandos SSM
# para ESTA instância e ler o resultado. A chave vai para GitHub Secrets e é
# apagada junto com o resto no `make destroy`.

resource "aws_iam_user" "github_deploy" {
  name = "fake-news-github-deploy"
}

resource "aws_iam_user_policy" "github_deploy" {
  name = "ssm-deploy"
  user = aws_iam_user.github_deploy.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "ssm:SendCommand"
        Resource = [
          aws_instance.k3s.arn,
          "arn:aws:ssm:${var.region}::document/AWS-RunShellScript",
        ]
      },
      {
        # Ler o resultado do comando (a AWS não permite restringir por recurso)
        Effect   = "Allow"
        Action   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
        Resource = "*"
      },
    ]
  })
}

# Atenção: a chave secreta fica no terraform.tfstate (local e ignorado pelo git)
resource "aws_iam_access_key" "github_deploy" {
  user = aws_iam_user.github_deploy.name
}
