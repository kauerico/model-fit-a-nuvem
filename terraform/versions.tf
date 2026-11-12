terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Estado local (terraform.tfstate, ignorado pelo git). Num time de verdade,
  # use um backend remoto (S3) para o estado não ficar só numa máquina.
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "model-fit-a-nuvem"
      ManagedBy = "terraform"
    }
  }
}
