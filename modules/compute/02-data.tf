#----------------------------------------------------------
# Resource Group, VNet, Subnet selection & Random Resources
#----------------------------------------------------------

data "azurerm_resource_group" "rg" {
  for_each = local.all_rg
  name = each.key
}

#azurerm_storage_account.vm-sa.*.primary_blob_endpoint
data "azurerm_subnet" "vm_subnet" {
    for_each = local.all_subnet
  name                 = each.value.subnet
  virtual_network_name = each.value.virtual_network
  resource_group_name  = each.value.resource_group_name
}


data "azurerm_availability_set" "vm_availability_set" {
  for_each = local.all_availability_set
  name                         = each.key
  resource_group_name          = each.value.resource_group_name

  depends_on = [ azurerm_availability_set.availability_set ]
}

data "azurerm_key_vault" "vm_keyvault" {
  for_each = local.all_keyvault
  name                      = each.key
  resource_group_name       = each.value.resource_group_name
}

data "azurerm_log_analytics_workspace" "logws" {
  for_each = local.all_log_analytics_ws
  name                = each.key
  resource_group_name = each.value.resource_group_name
}

data "azurerm_storage_account" "storeacc" {
 
for_each = local.all_storage_account_collection  
  name                     = each.value.storage_account
  resource_group_name      = each.value.resource_group_name
}
