
locals {
  
all_windows_vm = { for k,v in local.deployment.virtual_machines : k => v
    if v.type == "windows_vitual_machine"
    }
  
  all_windows_vm_disk = { for entry in flatten([
    for key, data in local.all_windows_vm : [
      for dk,disk in lookup(data, "data_disk", []) : merge({
        vm_name = key
        lun = dk+1
      },disk)
    ] if lookup(data, "data_disk", [])!= []
  ]) : "${entry.vm_name}_${entry.name}" => entry }

}

resource "random_password" "vm_user_password" {
  for_each = local.all_windows_vm
  length      = 24
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false

  keepers = {
    admin_password = "windows"
  }
}

resource "random_string" "vm_user_name" {
  for_each = local.all_windows_vm
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

resource "azurerm_key_vault_secret" "vm_user_password" {
  for_each = random_password.vm_user_password

  lifecycle {
    ignore_changes = [
      key_vault_id
    ]
  }

  name         = replace(format("vm-%s-password", each.key),"_","-") 
  value        = random_password.vm_user_password[each.key].result
  key_vault_id = data.azurerm_key_vault.vm_keyvault[lookup(local.all_windows_vm,each.key).keyvault].id
}


resource "azurerm_key_vault_secret" "vm_user_name" {
  for_each = random_string.vm_user_name

  lifecycle {
    ignore_changes = [
      key_vault_id
    ]
  }

  name         = replace(format("vm-%s-user-name", each.key),"_","-") 
  value        = random_string.vm_user_name[each.key].result
  key_vault_id = data.azurerm_key_vault.vm_keyvault[lookup(local.all_windows_vm,each.key).keyvault].id
  #tags = merge(lookup(each.value,"tags",{}), local.management.tags)
}


#-----------------------------------
# Public IP for Virtual Machine
#-----------------------------------
resource "azurerm_public_ip" "pip" {
for_each =  { for k,v in local.all_windows_vm : k => v
        if lookup(v, "enable_public_ip_address",false) 
    }
  
  name                = format("%s-pip",each.key)
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = format("%s-pip",each.key)
  tags = merge(lookup(each.value,"tags",{}), local.management.tags)
}

#---------------------------------------
# Network Interface for Virtual Machine
#---------------------------------------
resource "azurerm_network_interface" "nic" {
for_each = local.all_vm_collection

  name                          =  format("%s-nic",each.key) #var.instances_count == 1 ? lower("nic-${format("vm%s", lower(replace(var.virtual_machine_name, "/[[:^alnum:]]/", "")))}") : lower("nic-${format("vm%s%s", lower(replace(var.virtual_machine_name, "/[[:^alnum:]]/", "")), count.index + 1)}")
  location                      = each.value.location
  resource_group_name           = each.value.resource_group_name
  dns_servers                   = lookup(each.value,"dns_servers",[])
  enable_ip_forwarding          = lookup(each.value,"enable_ip_forwarding",false)
  enable_accelerated_networking = lookup(each.value,"enable_accelerated_networking",false)
  tags = merge(lookup(each.value,"tags",{}), local.management.tags)

dynamic "ip_configuration" {
    for_each = {
        for i, j in lookup(each.value,"ip_configuration",[]):"${each.key}-${j.name}"=> merge({
            index = i+1
            vm_name   = each.key
            virtual_network      = each.value.virtual_network
            subnet    = each.value.subnet
            name =  j.name
            ip_address = lookup(j,"ip_address",null)
            ip_address_allocation =lookup(j,"ip_address_allocation","Dynamic")
        },)
        if lookup(each.value,"ip_configuration",[]) !=[]
    }
content{ 
        primary                       = ip_configuration.value.index!=1? false : true
        name                          = ip_configuration.value.name
        subnet_id                     = data.azurerm_subnet.vm_subnet["${ip_configuration.value.virtual_network}-${ip_configuration.value.subnet}"].id
        private_ip_address_allocation = ip_configuration.value.ip_address ==null ? "Dynamic" : ip_configuration.value.ip_address_allocation
        private_ip_address            = ip_configuration.value.ip_address
        public_ip_address_id          = lookup(each.value, "enable_public_ip_address",false) == true ? azurerm_public_ip.pip[each.key].id:null
    }
  }

  lifecycle {
    ignore_changes = [
      ip_configuration.*.subnet_id, ip_configuration.*.public_ip_address_id
    ]
  }

}

# output vpc_arns {
#   description = "ARNs of the vpcs for each project"
#   value       = { for p in sort(keys(var.project)) : p => module.vpc[p].vpc_arn }
# }

#---------------------------------------
# Windows Virutal machine
#---------------------------------------
resource "azurerm_windows_virtual_machine" "win_vm" {
  for_each = local.all_windows_vm
  name                          = each.key
  computer_name                 = each.key
  location                      = each.value.location
  resource_group_name           = each.value.resource_group_name
  
  size                       = each.value.vm_size
  admin_username             = random_string.vm_user_name[each.key].result
  admin_password             = random_password.vm_user_password[each.key].result
  network_interface_ids      = [azurerm_network_interface.nic[each.key].id]
  source_image_id            = lookup(each.value,"source_image_id",null) 
  allow_extension_operations = true

  availability_set_id              = lookup(each.value,"availability_set",null)!=null? data.azurerm_availability_set.vm_availability_set[each.value.availability_set].id:null

  dedicated_host_id          = lookup(each.value,"dedicated_host_id",null) # default null
  license_type               = lookup(each.value,"license_type","None") # default None
  tags = merge(lookup(each.value,"tags",{}), local.management.tags)
  
  lifecycle {
    ignore_changes = [
      availability_set_id, dedicated_host_id, network_interface_ids
    ]
  }

dynamic "source_image_reference" {
    for_each = (lookup(each.value, "storage_image_reference",{}) != {} && lookup(each.value,"source_image_id",null)==null) ? [1] : []
      content {
      publisher = lookup(each.value.storage_image_reference,"publisher","MicrosoftWindowsServer") 
      offer     = lookup(each.value.storage_image_reference,"offer","WindowsServer") 
      sku       = lookup(each.value.storage_image_reference,"sku","2019-Datacenter-Core")
      version   =  lookup(each.value.storage_image_reference,"version","latest")
    }
  }

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

    # secret {
    #     key_vault_id = ""# you will have to also assign a key vault id which stores the certificate and provides the certificate url
    #     certificate {
    #         store     = "My"
    #         url       = var.certificateUrl
    #     }
    # }

    #virtual_machine_scale_set_id
}

#----------------------------------------------------------------------------------------------------------------------#
#_____________________________________________+ VM Data Disk +_________________________________________________________
#----------------------------------------------------------------------------------------------------------------------#

resource "azurerm_managed_disk" "vm_disk" {
  for_each = local.all_windows_vm_disk
  name                 = each.key
  location             = azurerm_windows_virtual_machine.win_vm[each.value.vm_name].location
  resource_group_name  = azurerm_windows_virtual_machine.win_vm[each.value.vm_name].resource_group_name
  storage_account_type = lookup(each.value,"storage_account_type","Premium_LRS")
  create_option        = lookup(each.value,"create_option","Empty")
  disk_size_gb         = each.value.disk_size_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "vm_disk_attachment" {
  for_each = local.all_windows_vm_disk

  lifecycle {
    ignore_changes = [
      virtual_machine_id, managed_disk_id
    ]
  }
  managed_disk_id    = azurerm_managed_disk.vm_disk[each.key].id
  virtual_machine_id = azurerm_windows_virtual_machine.win_vm[each.value.vm_name].id
  #The Logical Unit Number of the Data Disk, which needs to be unique within the Virtual Machine. Changing this forces a new resource to be created
  lun                = lookup(each.value,"lun","1")
  caching            = "ReadWrite"
}

# resource "azurerm_orchestrated_virtual_machine_scale_set" "example" {
#   name                = "example-VMSS"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name

#   platform_fault_domain_count = 1

#   zones = ["1"]
# }
