locals {
all_linux_vm = { for k,v in local.deployment.virtual_machines : k => v
    if v.type == "linux_vitual_machine"
    }

    all_linux_vm_disk = { for entry in flatten([
        for key, data in local.all_linux_vm : [
            for dk,disk in lookup(data, "data_disk", []) : merge({
            vm_name = key
            lun = dk+1
            },disk)
        ] if lookup(data, "data_disk", [])!= []
    ]) : "${entry.vm_name}_${entry.name}" => entry }
}

resource "random_password" "linux_vm_user_password" {
  for_each = local.all_linux_vm
  length      = 24
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false

  keepers = {
    admin_password = "linux"
  }
}

resource "random_string" "linux_vm_user_name" {
  for_each = local.all_linux_vm
  length  = 10
  special = false
  upper   = false
  keepers = {
    domain_name_label = each.key
  }
}

#-----------------------------------
# Store Password for Local Username in KeyVault Secret
#-----------------------------------

resource "azurerm_key_vault_secret" "linux_vm_user_password" {
    for_each = random_password.linux_vm_user_password
    name         = replace(format("vm-%s-password", each.key),"_","-") 
    value        = random_password.linux_vm_user_password[each.key].result
    key_vault_id = data.azurerm_key_vault.vm_keyvault[lookup(local.all_linux_vm,each.key).keyvault].id
    
    lifecycle {
    ignore_changes = [
      key_vault_id
    ]
  }
}

resource "azurerm_key_vault_secret" "linux_vm_user_name" {
    for_each = random_string.linux_vm_user_name

    name         = replace(format("vm-%s-user-name", each.key),"_","-") 
    value        = random_string.linux_vm_user_name[each.key].result
    key_vault_id = data.azurerm_key_vault.vm_keyvault[lookup(local.all_linux_vm,each.key).keyvault].id
    #tags = merge(lookup(each.value,"tags",{}), local.management.tags)
    
    lifecycle {
    ignore_changes = [
      key_vault_id
    ]
  }
  }

#---------------------------------------------------------------
# Generates SSH2 key Pair for Linux VM's (Dev Environment only)
#---------------------------------------------------------------
resource "tls_private_key" "linux_vm_ssh_key" {
    for_each = local.all_linux_vm
    algorithm = "RSA"
    rsa_bits  = 4096
}

#---------------------------------------
# Linux Virutal machine
#---------------------------------------

resource "azurerm_linux_virtual_machine" "linux_vm" {
    for_each = local.all_linux_vm
    name                          = each.key
    location                      = each.value.location
    resource_group_name           = each.value.resource_group_name
    size                          = each.value.vm_size
    admin_username                = random_string.linux_vm_user_name[each.key].result
    admin_password                = random_password.linux_vm_user_password[each.key].result
    disable_password_authentication = lookup(each.value,"generate_admin_ssh_key",false) 
    network_interface_ids         = [azurerm_network_interface.nic[each.key].id]
    source_image_id               = lookup(each.value,"source_image_id",null) 
    
   
    dynamic "source_image_reference" {
        for_each = (lookup(each.value, "storage_image_reference",{}) != {} && lookup(each.value,"source_image_id",null)==null) ? [1] : []
        content {
        publisher = lookup(each.value.storage_image_reference,"publisher","RedHat") 
        offer     = lookup(each.value.storage_image_reference,"offer","RHEL") 
        sku       = lookup(each.value.storage_image_reference,"sku","7-LVM")
        version   =  lookup(each.value.storage_image_reference,"version","latest")
        }
    }

    allow_extension_operations = true
    availability_set_id              = lookup(each.value,"availability_set",null)!=null? data.azurerm_availability_set.vm_availability_set[each.value.availability_set].id:null

    dedicated_host_id          = lookup(each.value,"dedicated_host_id",null) # default null
    
    tags = merge(lookup(each.value,"tags",{}), local.management.tags)
    
    # admin_ssh_key {
    #     username   = random_string.linux_vm_user_name[each.key].result
    #     admin_password =random_password.linux_vm_user_password[each.key].result
    #    # public_key = lookup(each.value,"generate_admin_ssh_key",false) == true  ? tls_private_key.linux_vm_ssh_key[each.key].public_key_openssh : null
    # }

    
        os_disk {
            storage_account_type    = lookup(each.value,"os_disk_storage_account_type", "Standard_LRS")
            disk_size_gb            = lookup(each.value,"os_disk_size_gb",null)
            caching                 = "ReadWrite"
        }

        

    dynamic "boot_diagnostics" {
        for_each = lookup(each.value, "boot_diagnostic_storage_account",null) != null ? [1] : []
        content {
             #"https://wlprodeusmgmtdiagstr01.blob.core.windows.net/"
                  storage_account_uri  = format("https://%s.blob.core.windows.net/",lookup(each.value, "boot_diagnostic_storage_account")) 
                # data.azurerm_storage_account.storeacc[lookup(each.value, "boot_diagnostic_storage_account")].primary_blob_endpoint
        }
    }

     lifecycle {
    ignore_changes = [
      network_interface_ids, availability_set_id, dedicated_host_id
    ]
  }
}


resource "azurerm_managed_disk" "linux_vm_disk" {
  for_each = local.all_linux_vm_disk
  name                 = each.key
  location             = azurerm_linux_virtual_machine.linux_vm[each.value.vm_name].location
  resource_group_name  = azurerm_linux_virtual_machine.linux_vm[each.value.vm_name].resource_group_name
  storage_account_type = lookup(each.value,"storage_account_type","Premium_LRS")
  create_option        = lookup(each.value,"create_option","Empty")
  disk_size_gb         = each.value.disk_size_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "linux_vm_disk_attachment" {
  for_each = local.all_linux_vm_disk

  managed_disk_id    = azurerm_managed_disk.linux_vm_disk[each.key].id
  virtual_machine_id = azurerm_linux_virtual_machine.linux_vm[each.value.vm_name].id
  #The Logical Unit Number of the Data Disk, which needs to be unique within the Virtual Machine. 
  #Changing this forces a new resource to be created
  lun                = lookup(each.value,"lun","1")
  caching            = "ReadWrite"

  lifecycle {
    ignore_changes = [
      managed_disk_id, virtual_machine_id
    ]
  }
}



#--------------------------------------------------------------
# Azure Log Analytics Workspace Agent Installation for Linux
#--------------------------------------------------------------
# resource "azurerm_virtual_machine_extension" "omsagentlinux" {
#   count                      = var.log_analytics_workspace_name != null && var.os_flavor == "linux" ? var.instances_count : 0
#   name                       = var.instances_count == 1 ? "OmsAgentForLinux" : format("%s%s", "OmsAgentForLinux", count.index + 1)
#   virtual_machine_id         = azurerm_linux_virtual_machine.linux_vm[count.index].id
#   publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
#   type                       = "OmsAgentForLinux"
#   type_handler_version       = "1.13"
#   auto_upgrade_minor_version = true

#   settings = <<SETTINGS
#     {
#       "workspaceId": "${data.azurerm_log_analytics_workspace.logws.0.workspace_id}"
#     }
#   SETTINGS

#   protected_settings = <<PROTECTED_SETTINGS
#     {
#     "workspaceKey": "${data.azurerm_log_analytics_workspace.logws.0.primary_shared_key}"
#     }
#   PROTECTED_SETTINGS
# }


#--------------------------------------
# azurerm monitoring diagnostics 
#--------------------------------------
# resource "azurerm_monitor_diagnostic_setting" "nsg" {
#   count                      = var.log_analytics_workspace_name != null && var.hub_storage_account_name != null ? 1 : 0
#   name                       = lower("nsg-${var.virtual_machine_name}-diag")
#   target_resource_id         = azurerm_network_security_group.nsg.id
#   storage_account_id         = data.azurerm_storage_account.storeacc.0.id
#   log_analytics_workspace_id = data.azurerm_log_analytics_workspace.logws.0.id

#   dynamic "log" {
#     for_each = var.nsg_diag_logs
#     content {
#       category = log.value
#       enabled  = true

#       retention_policy {
#         enabled = false
#       }
#     }
#   }
# }