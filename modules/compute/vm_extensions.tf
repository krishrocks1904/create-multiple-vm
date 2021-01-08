#https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/network-watcher-windows
#https://azure.microsoft.com/en-us/resources/templates/201-vm-domain-join-existing/
#--------------------------------------------------------------
# Azure Log Analytics Workspace Agent Installation for windows
#--------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "omsagentwin" {
  for_each = local.all_log_analytics_ws
  name                       = each.key
  virtual_machine_id         = azurerm_windows_virtual_machine.win_vm[each.value.virtual_machine].id
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "MicrosoftMonitoringAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  settings = jsonencode({
      "workspaceId": data.azurerm_log_analytics_workspace.logws[each.key].workspace_id
    })

  protected_settings = jsonencode({
    "workspaceKey": data.azurerm_log_analytics_workspace.logws[each.key].primary_shared_key
    })

  lifecycle {
    ignore_changes = [
      virtual_machine_id
    ]
  }

}

locals {
  
  encrypt_name                          = "encrypt"
  vm_encrypt_publisher                  = "Microsoft.Azure.Security"
  vm_encrypt_auto_upgrade_minor_version = true
  vm_encrypt_operation                  = "EnableEncryption"
  vm_encrypt_algorithm                  = "RSA-OAEP"
  vm_encrypt_volume_type                = "All"

  vm_win_encrypt_type   = "AzureDiskEncryption"
  vm_linux_encrypt_type = "AzureDiskEncryptionForLinux"

  vm_win_encrypt_type_handler_version   = "2.2"
  vm_linux_encrypt_type_handler_version = "1.1"
}

resource "azurerm_virtual_machine_extension" "win_bitlocker_encryptionextension" {
  for_each = local.all_vm_collection
  virtual_machine_id         = lookup(azurerm_windows_virtual_machine.win_vm,each.key,null)!=null?lookup(azurerm_windows_virtual_machine.win_vm,each.key,null).id:lookup(azurerm_linux_virtual_machine.linux_vm,each.key,null).id
  name                       = format("%s-%s",each.key,local.encrypt_name)
  publisher                  = local.vm_encrypt_publisher
  type                       = each.value.type=="linux_vitual_machine"? local.vm_linux_encrypt_type:local.vm_win_encrypt_type
  type_handler_version       = each.value.type=="linux_vitual_machine"? local.vm_linux_encrypt_type_handler_version:local.vm_win_encrypt_type_handler_version
  auto_upgrade_minor_version = local.vm_encrypt_auto_upgrade_minor_version

  settings = jsonencode({
        "EncryptionOperation":      local.vm_encrypt_operation,
        "KeyVaultURL":              data.azurerm_key_vault.vm_keyvault[each.value.keyvault].vault_uri,
        "KeyVaultResourceId":       data.azurerm_key_vault.vm_keyvault[each.value.keyvault].id,							
        "KeyEncryptionAlgorithm":   local.vm_encrypt_algorithm,
        "VolumeType":               local.vm_encrypt_volume_type
    })
  
  lifecycle {
  ignore_changes = [
    virtual_machine_id
  ]
}

  tags = merge(lookup(each.value,"tags",{}), local.management.tags)
}


#-------------------------------------------------------------------------------------------------------------------------------
#_________________________________________ Domain join WINDOWS VM's ______________________________________________________                                     
#-------------------------------------------------------------------------------------------------------------------------------

# resource "azurerm_virtual_machine_extension" "domain_join_windows_vm" {
#   for_each = local.all_windows_vm

#   name                 = format("%s_%s",each.key,"join-domain")
#   virtual_machine_id         = azurerm_windows_virtual_machine.win_vm[each.key].id
#   publisher            = "Microsoft.Compute"
#   type                 = "JsonADDomainExtension"
#   type_handler_version = "1.3"

#   # NOTE: the `OUPath` field is intentionally blank, to put it in the Computers OU
#   settings = jsonencode({
#         "Name": var.active_directory_domain,
#         "OUPath": "OU=wlprodeusaclm01,DC=wella,DC=team",
#         "User": "${var.active_directory_domain}\\${var.active_directory_username}",
#         "Restart": "true",
#         "Options": "3"
#     })

#   protected_settings = jsonencode({
#         "Password": "${var.active_directory_password}"
#     })
# }

#-------------------------------------------------------------------------------------------------------------------------------
#_________________________________________ Domain join LINUX VM's ______________________________________________________                                     
#-------------------------------------------------------------------------------------------------------------------------------

# resource "azurerm_virtual_machine_extension" "domain_join_linux_vm" {
#   for_each = local.all_linux_vm
#   name                 = format("%s_%s",each.key,"join-domain")
#   virtual_machine_id         = azurerm_windows_virtual_machine.win_vm[each.key].id
#   publisher            = "Microsoft.Compute"
#   type                 = "JsonADDomainExtension"
#   type_handler_version = "1.3"

#   # NOTE: the `OUPath` field is intentionally blank, to put it in the Computers OU
#   settings = jsonencode({
#         "Name": var.active_directory_domain,
#         "OUPath": "OU=Servers,DC=wella,DC=team",
#         "User": "${var.active_directory_domain}\\${var.active_directory_username}",
#         "Restart": "true",
#         "Options": "3"
#     })

#   protected_settings = jsonencode({
#         "Password": "${var.active_directory_password}"
#     })
# }