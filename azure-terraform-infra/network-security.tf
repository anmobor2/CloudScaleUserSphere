#network config, security group and scaling group

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "myapp-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = data.terraform_remote_state.acr.outputs.resource_group_name
}

# Subnets
resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = data.terraform_remote_state.acr.outputs.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  service_endpoints    = ["Microsoft.Sql", "Microsoft.KeyVault"]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = data.terraform_remote_state.acr.outputs.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
}

# Network Security Group for App Subnet
resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = var.location
  resource_group_name = data.terraform_remote_state.acr.outputs.resource_group_name

  security_rule {
    name                       = "AllowHTTPInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with App Subnet
resource "azurerm_subnet_network_security_group_association" "app_nsg_association" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

resource "azurerm_postgresql_virtual_network_rule" "postgresql_vnet_rule" {
  name                = "postgresql-vnet-rule"
  resource_group_name = data.terraform_remote_state.acr.outputs.resource_group_name
  server_name         = azurerm_postgresql_server.postgresql.name
  subnet_id           = azurerm_subnet.app_subnet.id
}

# VNet Integration for App Service
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id = azurerm_app_service.app.id
  subnet_id      = azurerm_subnet.app_subnet.id
}

# Autoscale settings for App Service
resource "azurerm_monitor_autoscale_setting" "app_autoscale" {
  name                = "app-autoscale"
  resource_group_name = data.terraform_remote_state.acr.outputs.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_app_service_plan.appserviceplan.id

  profile {
    name = "default"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.appserviceplan.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75 # when CPU is greater than 75% then scale out (increase instance count)
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M" # wait for 1 minute before scaling again
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.appserviceplan.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25 # when CPU is less than 25% then scale in (decrease instance count)
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}

