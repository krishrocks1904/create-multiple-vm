locals{

management = merge({tags     = {}},
       var.management)
  deployment =  merge({virtual_machines={}}, var.deployment)

#-----------------------------------------------------------------------
# 
#-----------------------------------------------------------------------

  all_vm_collection = { for k,v in local.deployment.virtual_machines : k => v
  }

#---------------------------------------------------------------------------------------------------
#  Collect all unique keyvault
#---------------------------------------------------------------------------------------------------
  all_keyvault ={ for entry in distinct([ for v in local.all_vm_collection : {
      keyvault = v.keyvault
      resource_group_name = lookup(v,"keyvault_resource_group_name",v.resource_group_name)
    }]): entry.keyvault=>entry}

  
#---------------------------------------------------------------------------------------------------
#  Collect all unique subnets
#---------------------------------------------------------------------------------------------------
  all_subnet ={ for entry in distinct([ for v in local.all_vm_collection : {
      virtual_network = v.virtual_network
      subnet = v.subnet
      resource_group_name = lookup(v,"vnet_resource_group_name",v.resource_group_name)
    }]): format("%s-%s",entry.virtual_network,entry.subnet)=>entry}            

  
#---------------------------------------------------------------------------------------------------
#  Collect all unique availability_set
#---------------------------------------------------------------------------------------------------
    all_availability_set ={ for entry in distinct([ for v in local.all_vm_collection : {
      availability_set = v.availability_set
      resource_group_name = lookup(v,"availability_set_resource_group_name",v.resource_group_name)
    }if lookup(v, "availability_set",null) != null]): entry.availability_set=>entry}  


#---------------------------------------------------------------------------------------------------
#  Collect all unique log_analytics_workspace
#---------------------------------------------------------------------------------------------------
  all_log_analytics_ws ={ for entry in distinct([ for key,val in local.all_vm_collection : {
      log_analytics_workspace = val.log_analytics_workspace
      virtual_machine = key
      resource_group_name = lookup(val,"log_analytics_workspace_resource_group_name",val.resource_group_name)
    }if lookup(val, "log_analytics_workspace",null) != null]): entry.log_analytics_workspace=>entry}  


#---------------------------------------------------------------------------------------------------
#  Collect all unique storage_account
#---------------------------------------------------------------------------------------------------
vm_storage_accounts = { for k,v in local.all_vm_collection : k => v
    if v.type == "windows_vitual_machine" && lookup(v, "boot_diagnostic_storage_account",null) != null
    }

all_storage_account_collection ={ for entry in distinct([ for v in local.vm_storage_accounts : {
      storage_account = v.boot_diagnostic_storage_account
      resource_group_name = lookup(v,"storage_account_resource_group_name",v.resource_group_name)
    }]): entry.storage_account=>entry}  

#---------------------------------------------------------------------------------------------------
#  Collect all unique resource_group_name
#---------------------------------------------------------------------------------------------------
  all_rg ={ for entry in distinct(flatten([ for v in local.all_vm_collection:[
    {
      resource_group_name = lookup(v,"availability_set_resource_group_name",v.resource_group_name)
    },
    {
      resource_group_name = v.resource_group_name
    },
    {
      resource_group_name = lookup(v,"keyvault_resource_group_name",v.resource_group_name)
    },
    {
      resource_group_name = lookup(v,"storage_account_resource_group_name",v.resource_group_name)
    },
    {
      resource_group_name = lookup(v,"vnet_resource_group_name",v.resource_group_name)
    }
    ]])): entry.resource_group_name=>entry
  }
}


# data "azurerm_resource_group" "resource_group_management" {
#   for_each = local.all_rg
#   name = each.key
# }