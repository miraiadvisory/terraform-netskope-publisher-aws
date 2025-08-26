terraform {
  required_providers {
    netskope = {
      version = ">= 0.3.2"
      source  = "netskopeoss/netskope"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.0"
    }
  }
  required_version = ">= 1.1.7"
}
