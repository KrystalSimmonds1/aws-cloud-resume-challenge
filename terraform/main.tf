terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.77.0"
    }
  }

  required_version = ">= 1.9.7"
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}
