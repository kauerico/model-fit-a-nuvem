terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Estado no S3, com lock nativo do S3 (o CI começa do zero a cada execução,
  # então o estado não pode ficar no runner). O nome do bucket vem de fora:
  #   terraform init -backend-config="bucket=$TF_STATE_BUCKET"
  backend "s3" {
    key          = "model-fit-a-nuvem/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}

# Credenciais: no CI, as do usuário IAM criado no Console (GitHub Secrets);
# na sua máquina, as do `aws login`.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "model-fit-a-nuvem"
      ManagedBy = "terraform"
    }
  }
}
