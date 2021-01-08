provider "azurerm" {
  #  version         = "=2.1.0"
  skip_provider_registration = true
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

terraform {
  backend "azurerm" {
    container_name = "tf-state-files"
  }
}
