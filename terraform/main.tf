# Konfiguracja dostawcy AWS i zdalnego stanu Terraform
# Określa wymaganą wersję AWS provider i region działania
provider "aws" {
  region = var.aws_region
}

# Konfiguracja zdalnego backendu dla stanu Terraform
# Używa S3 do przechowywania pliku stanu oraz do jego blokowania (native locking),
# aby zapobiec jednoczesnym modyfikacjom.
terraform {
  backend "s3" {
    bucket       = "projekt-brch-terraform-state-bucket"
    key          = "global/s3/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

# Losowy, bezpieczny klucz dla Django SECRET_KEY
resource "random_password" "django_secret" {
  length           = 50
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

