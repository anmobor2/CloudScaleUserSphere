provider "azurerm" {
  features {}
  use_cli = true
}

resource "azurerm_resource_group" "backend" {
  name     = "terraform-backend-rg"
  location = "East US"
}

resource "random_string" "storage_account_suffix" {#this storage acconunt sufix is used to make the storage account name unique in all azure
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_storage_account" "backend" {
  name                     = "tfstate${random_string.storage_account_suffix.result}"  # Must be globally unique
  resource_group_name      = azurerm_resource_group.backend.name
  location                 = azurerm_resource_group.backend.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "backend" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.backend.name
  container_access_type = "private"
}

output "storage_account_name" {
  value = azurerm_storage_account.backend.name
}

output "container_name" {
  value = azurerm_storage_container.backend.name
}

output "backend_resource_group_name" {
  value = azurerm_resource_group.backend.name
}

output "backend_storage_account_name" {
  value = azurerm_storage_account.backend.name
}

output "backend_container_name" {
  value = azurerm_storage_container.backend.name
}