## Introducing azure provider to terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.56.0"
    }

  }
}

provider "azurerm" {
  features {}
}

## Creating a new resource group

resource "azurerm_resource_group" "monitor-rg" {
  name     = "monitor-rg-test"
  location = "canadacentral"
}

## creating a test virtual machine

resource "azurerm_windows_virtual_machine" "vm_test1" {
  name                = "vmtest1"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  location            = azurerm_resource_group.monitor-rg.location
  size                = "Standard_B1s"
  network_interface_ids = [
    azurerm_network_interface.newnic.id
  ]
  admin_username = "adminuser1"
  admin_password = "123456Ap!@"
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

##Creating network interface for the vm
resource "azurerm_network_interface" "newnic" {
  name                = "example-nic"
  location            = azurerm_resource_group.monitor-rg.location
  resource_group_name = azurerm_resource_group.monitor-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.newsubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


#creating vnet for the vm
resource "azurerm_virtual_network" "newvnet" {
  name                = "example-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.monitor-rg.location
  resource_group_name = azurerm_resource_group.monitor-rg.name
}

resource "azurerm_subnet" "newsubnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.monitor-rg.name
  virtual_network_name = azurerm_virtual_network.newvnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

## Defining the action group for alerts

resource "azurerm_monitor_action_group" "email_alert_ag" {
  name                = "email-alert-ag"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  short_name          = "email"

  email_receiver {
    name                    = "sendemailtouser"
    email_address           = "ansh.paul1@bell.ca"
    use_common_alert_schema = true
  }
}

## Creating the metric for WARNING CPU alerts

resource "azurerm_monitor_metric_alert" "warning_cpu_threshold_alert" {
  name                = "WARNING-cpu-threshold-alert"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  scopes              = [azurerm_windows_virtual_machine.vm_test1.id]
  description         = "The alert will be sent if the cpu threshold increases by 10 percent"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "CPU Credits Consumed"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
}

## Creating the metric for CRITICAL cpu alerts
resource "azurerm_monitor_metric_alert" "critical_cpu_threshold_alert" {
  name                = "CRITICAL-cpu-threshold-alert"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  scopes              = [azurerm_windows_virtual_machine.vm_test1.id]
  description         = "The alert will be sent if the cpu threshold increases by 10 percent"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "CPU Credits Consumed"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }
  action {
    action_group_id = azurerm_monitor_action_group.email_alert_ag.id
  }
}
# ## Creating the metric for WARNING available memory

resource "azurerm_monitor_metric_alert" "warning_available_memory_alerts" {
  name = "WARNING-available_memory_alerts"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  scopes = [azurerm_windows_virtual_machine.vm_test1.id]
  description = "The alert will be sent if the available memory is less than 2 gig"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name = "Available Memory Bytes"
    aggregation = "Average"
    operator = "LessThan"
    threshold = "1000000000"
  }
    action {
    action_group_id = azurerm_monitor_action_group.email_alert_ag.id
  }
}

## Creating the mertic for CRITICAL availble memory

resource "azurerm_monitor_metric_alert" "critical_available_memory_alerts" {
  name = "CRITICAL-available-memory-alerts"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  scopes = [azurerm_windows_virtual_machine.vm_test1.id]
  description = "The alert will be sent if the available memory is less than 1gig"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name = "Available Memory Bytes"
    aggregation = "Average"
    operator = "LessThan"
    threshold = "1000000000"
  }
  action {
    action_group_id = azurerm_monitor_action_group.email_alert_ag.id
  }
  depends_on = [azurerm_windows_virtual_machine.vm_test1, azurerm_monitor_action_group.email_alert_ag]
}