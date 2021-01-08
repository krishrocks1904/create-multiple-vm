resource "azurerm_availability_set" "availability_set" {

 for_each = {
    for k,v in local.deployment.virtual_machines : k=> v
    if v.type == "availability_set"
  }
  name                         = each.key
  location                     = each.value.location
  resource_group_name          = each.value.resource_group_name
  platform_fault_domain_count  = each.value.fault_domain_count
  platform_update_domain_count = each.value.update_domain_count
  managed                      = each.value.use_managed_disk

  tags = merge(lookup(each.value,"tags",{}), local.management.tags)
}

data "azurerm_availability_set" "availability_set" {
 
 for_each = {
    for k,v in local.deployment.virtual_machines : k=> v
    if v.type == "availability_set"
  }
  name                         = each.key
  resource_group_name          = each.value.resource_group_name

  depends_on = [ azurerm_availability_set.availability_set ]
}