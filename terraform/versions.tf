terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Estado no S3 (bucket criado no Console, com versionamento) e lock nativo
  # do S3: o estado não fica preso a uma máquina só.
  backend "s3" {
    bucket       = "fake-news-tfstate-kaue"
    key          = "model-fit-a-nuvem/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}

# Credenciais: as do `aws login` na sua máquina (perfil default).
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "model-fit-a-nuvem"
      ManagedBy = "terraform"
    }
  }
}
