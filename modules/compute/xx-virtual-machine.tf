#     locals {

# all_linux_vm = { for k,v in local.deployment.virtual_machines : k => v
#     if v.type == "linux_vitual_machine"
#     }

#     all_linux_vm_disk = { for entry in flatten([
#         for key, data in local.all_linux_vm : [
#             for dk,disk in lookup(data, "data_disk", []) : merge({
#             vm_name = key
#             lun = dk+1
#             },disk)
#         ] if lookup(data, "data_disk", [])!= []
#     ]) : "${entry.vm_name}_${entry.name}" => entry }

# }


# resource "random_password" "linux_vm_user_password" {
#   for_each = local.all_linux_vm
#   length      = 24
#   min_upper   = 4
#   min_lower   = 2
#   min_numeric = 4
#   special     = false

#   keepers = {
#     admin_password = "linux"
#   }
# }

# resource "random_string" "linux_vm_user_name" {
#   for_each = local.all_linux_vm
#   length  = 10
#   special = false
#   upper   = false
#   keepers = {
#     domain_name_label = each.key
#   }
# }


# #-----------------------------------
# # Store Password for Local Username in KeyVault Secret
# #-----------------------------------

# resource "azurerm_key_vault_secret" "vm_user_password" {
#     for_each = random_password.linux_vm_user_password

#     name         = replace(format("vm-%s-password", each.key),"_","-") 
#     value        = random_password.linux_vm_user_password[each.key].result
#     key_vault_id = data.azurerm_key_vault.vm_keyvault[lookup(local.all_linux_vm,each.key).keyvault].id
  
# }


# resource "azurerm_key_vault_secret" "vm_user_name" {
#     for_each = random_string.linux_vm_user_name

#     name         = replace(format("vm-%s-user-name", each.key),"_","-") 
#     value        = random_string.linux_vm_user_name[each.key].result
#     key_vault_id = data.azurerm_key_vault.vm_keyvault[lookup(local.all_linux_vm,each.key).keyvault].id
#     #tags = merge(lookup(each.value,"tags",{}), local.management.tags)
# }


# #-----------------------------------
# # Public IP for Virtual Machine
# #-----------------------------------
# resource "azurerm_public_ip" "pip" {
# for_each =  { for k,v in local.linux_vm_user_name : k => v
#         if lookup(v, "enable_public_ip_address",false) 
#     }
  
#   name                = format("%s-pip",each.key)
#   location            = each.value.location
#   resource_group_name = each.value.resource_group_name
#   allocation_method   = "Static"
#   sku                 = "Standard"
#   domain_name_label   = format("%s-pip",each.key)
#   tags = merge(lookup(each.value,"tags",{}), local.management.tags)
# }


# #-----------------------------------
# # Linux Virtual Machine
# #-----------------------------------
# resource "azurerm_linux_virtual_machine" "vm" {
#     for_each = local.all_windows_vm
#     name                          = each.key
#     location                      = each.value.location
#     resource_group_name           = each.value.resource_group_name
    
#     network_interface_ids = [azurerm_network_interface.nic.id]
#     size                  = var.vm_size

#     tags = merge(local.default_tags, local.default_vm_tags, var.extra_tags)

#     source_image_id = var.vm_image_id

#     source_image_reference {
#         offer     = lookup(var.vm_image, "offer", null)
#         publisher = lookup(var.vm_image, "publisher", null)
#         sku       = lookup(var.vm_image, "sku", null)
#         version   = lookup(var.vm_image, "version", null)
#     }

#     availability_set_id = var.availability_set_id

#     zone = var.zone_id

#     boot_diagnostics {
#         storage_account_uri = "https://${var.diagnostics_storage_account_name}.blob.core.windows.net"
#     }

#     os_disk {
#         name                 = coalesce(var.os_disk_custom_name, "${local.vm_name}-osdisk")
#         caching              = var.os_disk_caching
#         storage_account_type = var.os_disk_storage_account_type
#         disk_size_gb         = var.os_disk_size_gb
#     }

#     identity {
#         type = "SystemAssigned"
#     }

#     computer_name  = local.vm_name
#     admin_username = var.admin_username
#     admin_password = var.admin_password

#     custom_data = var.custom_data

#     disable_password_authentication = var.admin_password != null ? false : true

#     dynamic "admin_ssh_key" {
#         for_each = var.ssh_public_key != null ? ["fake"] : []
#         content {
#         public_key = var.ssh_public_key
#         username   = var.admin_username
#         }
#     }

#     }

#     resource "azurerm_managed_disk" "disk" {
#     for_each = var.storage_data_disk_config

#     location            = var.location
#     resource_group_name = var.resource_group_name

#     name = lookup(each.value, "name", "${local.vm_name}-datadisk${each.key}")

#     zones                = [var.zone_id]
#     storage_account_type = lookup(each.value, "storage_account_type", "Standard_LRS")

#     create_option = lookup(each.value, "create_option", "Empty")
#     disk_size_gb  = lookup(each.value, "disk_size_gb", null)

#     tags = merge(local.default_tags, local.default_vm_tags, var.extra_tags, lookup(each.value, "extra_tags", var.storage_data_disk_extra_tags))
#     }

#     resource "azurerm_virtual_machine_data_disk_attachment" "disk-attach" {
#     for_each = var.storage_data_disk_config

#     managed_disk_id    = azurerm_managed_disk.disk[each.key].id
#     virtual_machine_id = azurerm_linux_virtual_machine.vm.id

#     lun     = lookup(each.value, "lun", each.key)
#     caching = lookup(each.value, "caching", "ReadWrite")
#     }