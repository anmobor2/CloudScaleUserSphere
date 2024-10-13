resource "azurerm_application_insights" "app_insights" {
  name                = "app-insights-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

output "instrumentation_key" {
  value     = azurerm_application_insights.app_insights.instrumentation_key
  sensitive = true
}

resource "azurerm_monitor_diagnostic_setting" "app_service_logs" {
  name                       = "app-service-logs"
  target_resource_id         = azurerm_app_service.app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.workspace.id

  log {
    category = "AppServiceHTTPLogs"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 30
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 30
    }
  }
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "log-analytics-${var.project_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_action_group" "main" {
  name                = "example-actiongroup"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "exampleact"

  email_receiver {
    name          = "sendtoadmin"
    email_address = "tonibandal@hotmail.com"
  }
}

resource "azurerm_monitor_metric_alert" "request_metricalert" {
  name                = "request-metricalert"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_app_service.app.id]

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10 # when the number of requests is greater than 10 then trigger the alert
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}