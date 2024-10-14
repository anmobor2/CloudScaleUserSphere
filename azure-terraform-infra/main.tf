terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_cli = true
}

terraform {
  backend "azurerm" {
    # This will be filled by the pipeline
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "my-resource-group"
  location = "East US"
}

resource "azurerm_container_registry" "acr" {
  name                = "mycontainerregistry"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

resource "azurerm_user_assigned_identity" "app_identity" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  name                = "app-identity"
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

resource "azurerm_key_vault" "kv" {
  name                = "UserSphereKeyVault"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.app_subnet.id]
  }
}

resource "azurerm_app_service_plan" "appserviceplan" {
  name                = "my-app-service-plan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_app_service" "app" {
  name                = "app-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.appserviceplan.id

  site_config {
    linux_fx_version = "DOCKER|${azurerm_container_registry.acr.login_server}/${var.docker_image_name}:latest"
    always_on        = true
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
    WEBSITES_PORT                       = "8000"
    DOCKER_REGISTRY_SERVER_URL          = "https://${azurerm_container_registry.acr.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME     = azurerm_container_registry.acr.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD     = azurerm_container_registry.acr.admin_password
    DOCKER_ENABLE_CI                    = "true" # Enable CI/CD that means the app will be redeployed when the image in the registry changes
    "KEY_VAULT_URL"                     = azurerm_key_vault.kv.vault_uri
    "APPINSIGHTS_INSTRUMENTATIONKEY"    = azurerm_application_insights.app_insights.instrumentation_key
  }
}

resource "azurerm_app_service_slot" "staging" {#this deploys the app to the staging slot and later I can swap the staging slot with the production slot
  name                = "staging"
  app_service_name    = azurerm_app_service.app.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.appserviceplan.id

  site_config {
    linux_fx_version = "DOCKER|${azurerm_container_registry.acr.login_server}/${var.docker_image_name}:latest"
  }

  app_settings = {
    DOCKER_ENABLE_CI              = "true"
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  }
}

resource "azurerm_application_insights" "appinsights" {
  name                = "my-app-insights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

resource "azurerm_redis_cache" "redis" {
  name                = "my-redis-cache"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  capacity            = 1
  family              = "C"
  sku_name            = "Basic"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
  }
}

resource "azurerm_key_vault_secret" "redis_connection_string" {
  name         = "REDIS-URL"
  value        = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}/0"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_app_service.app.identity[0].principal_id

  secret_permissions = [
    "Get",
  ]
}

resource "azurerm_postgresql_server" "postgresql" {
  name                = "my-psql-server"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  public_network_access_enabled = false

  sku_name = "B_Gen5_1"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = "psqladmin"
  administrator_login_password = "H@Sh1CoR3!" # Please change this!
  version                      = "11"
  ssl_enforcement_enabled      = true
}

resource "azurerm_postgresql_database" "database" {
  name                = "myapp"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_postgresql_server.postgresql.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_key_vault_secret" "database_url" {
  name         = "DATABASE-URL"
  value        = "postgresql://${azurerm_postgresql_server.postgresql.administrator_login}:${azurerm_postgresql_server.postgresql.administrator_login_password}@${azurerm_postgresql_server.postgresql.fqdn}:5432/${azurerm_postgresql_database.database.name}"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "random_password" "secret_key" {
  length  = 32
  special = true
}

resource "azurerm_key_vault_secret" "secret_key" {
  name         = "SECRET-KEY"
  value        = random_password.secret_key.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_container_registry_webhook" "acr_webhook" {
  name                = "myacrwebhook"
  resource_group_name = azurerm_resource_group.rg.name
  registry_name       = azurerm_container_registry.acr.name
  service_uri         = "https://${azurerm_app_service.app.site_credential[0].username}:${azurerm_app_service.app.site_credential[0].password}@${azurerm_app_service.app.name}.scm.azurewebsites.net/docker/hook"

  actions = ["push"]
  location = var.location
}

data "azurerm_client_config" "current" {}

output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  value = azurerm_container_registry.acr.admin_username
}

output "acr_admin_password" {
  value     = azurerm_container_registry.acr.admin_password
  sensitive = true
}

output "redis_connection_string" {
  value     = "rediss://:${azurerm_redis_cache.redis.primary_access_key}@${azurerm_redis_cache.redis.hostname}:${azurerm_redis_cache.redis.ssl_port}/0"
  sensitive = true
}

output "acr_name" {
  value = azurerm_container_registry.acr.name
}

output "acr_resource_group" {
  value = azurerm_resource_group.rg.name
}