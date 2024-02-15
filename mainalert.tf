## Introducing azure provider to terraform
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.91.0"
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

## Creating the metric for WARNING CPU alerts

resource "azurerm_monitor_metric_alert" "warning_cpu_threshold_alert" {
  name                = "WARNING-cpu-threshold-alert"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  scopes              = [azurerm_windows_virtual_machine.vm_test1.id]
  description         = "The alert will be sent if the cpu threshold increases by 80 percent"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "CPU Credits Consumed"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  action {
    action_group_id = azurerm_monitor_action_group.email_opsgenie.id
  }
}

## Creating the metric for CRITICAL cpu alerts

resource "azurerm_monitor_metric_alert" "critical_cpu_threshold_alert" {
  name                = "CRITICAL-cpu-threshold-alert"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  scopes              = [azurerm_windows_virtual_machine.vm_test1.id]
  description         = "The alert will be sent if the cpu threshold increases by 90 percent"
  severity            = 0

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "CPU Credits Consumed"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }
  action {
    action_group_id = azurerm_monitor_action_group.email_opsgenie.id
  }
}
## Creating the metric for WARNING available memory

resource "azurerm_monitor_metric_alert" "warning_available_memory_alerts" {
  name                = "WARNING-available_memory_alerts"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  scopes              = [azurerm_windows_virtual_machine.vm_test1.id]
  description         = "The alert will be sent if the available memory is less than 2 gig"
  severity            = 2

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = "2000000000"
  }
  action {
    action_group_id = azurerm_monitor_action_group.email_opsgenie.id
  }
}

## Creating the mertic for CRITICAL availble memory

resource "azurerm_monitor_metric_alert" "critical_available_memory_alerts" {
  name                = "CRITICAL-available-memory-alerts"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  scopes              = [azurerm_windows_virtual_machine.vm_test1.id]
  description         = "The alert will be sent if the available memory is less than 1gig"
  severity            = 0

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = "1000000000"
  }
  action {
    action_group_id = azurerm_monitor_action_group.email_alert_ag.id
  }
  depends_on = [azurerm_windows_virtual_machine.vm_test1, azurerm_monitor_action_group.email_alert_ag]
}

## Adding Scheduled Triggers - Alert Processing Rule 

## Step 1 : Create Action Group 
resource "azurerm_monitor_action_group" "email_opsgenie" {
  name                = "email_opsgenie-ag"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  short_name          = "emailOps"

  email_receiver {
    name                    = "sendemailtouser"
    email_address           = "636baa80-d096-4a10-977c-6b93d7db0f98@bwsjira.opsgenie.net"
    use_common_alert_schema = true
  }
}

## Step 2 : Creating the mertic alert for VM Availabilty Memory
resource "azurerm_monitor_metric_alert" "vm_availability_metric_alert" {
  name                = "vm_availability_metric_alert"
  resource_group_name = azurerm_resource_group.monitor-rg.name
  scopes              = [azurerm_windows_virtual_machine.vm_test1.id]
  description         = "Measure of Availability of Virtual machines over time."
  severity            = 0

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "VmAvailabilityMetric"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = "1"
  }
  action {
    action_group_id = azurerm_monitor_action_group.email_opsgenie.id
  }
  depends_on = [azurerm_windows_virtual_machine.vm_test1, azurerm_monitor_action_group.email_opsgenie]
}

## Step 3: Create Alert Processing Rule
resource "azurerm_monitor_alert_processing_rule_action_group" "vm_available_schedule" {
  name                 = "vm_available_schedule"
  resource_group_name  = azurerm_resource_group.monitor-rg.name
  scopes               = [azurerm_windows_virtual_machine.vm_test1.id]
  add_action_group_ids = [azurerm_monitor_action_group.email_opsgenie.id] # Changed from "example" to "email_opsgenie"

  #Rule Applies only to VM Availabity Alerts 
  condition {
    target_resource_type {
      operator = "Equals"
      values   = ["Microsoft.Compute/VirtualMachines"]
    }
    alert_rule_name {
      operator = "Equals"
      values   = ["vm_availability_metric_alert"]
    }
  }

  schedule {
    effective_from  = "2022-01-01T01:02:03"
    effective_until = "2022-02-02T01:02:03"
    time_zone       = "Eastern Standard Time"

    recurrence {
      weekly {
        days_of_week = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        start_time   = "09:00:00"
        end_time     = "17:00:00"
      }
    }
  }

}