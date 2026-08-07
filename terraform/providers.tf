terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # DEMO DEFAULT: local backend, zero setup required.
  # For anything beyond a one-off demo, switch to a remote backend so state
  # isn't sitting on a laptop. Uncomment below and run:
  #   terraform init -reconfigure \
  #     -backend-config="storage_account_name=<your-tfstate-account>" \
  #     -backend-config="container_name=tfstate" \
  #     -backend-config="key=demo.tfstate" \
  #     -backend-config="resource_group_name=<your-tfstate-rg>"
  #
  # backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      # Lets `terraform destroy` clean up even if the RG has resources
      # Terraform doesn't know about (handy for a live demo, remove for real envs)
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "random" {}
