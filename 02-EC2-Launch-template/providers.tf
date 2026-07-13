# providers.tf

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws" #provider source
      version = "~> 5.0"  #allow any version in the 5.x series
    }
  }
}

provider "aws" { #This actually initializes the downloaded plugin.
  region = var.aws_region
}