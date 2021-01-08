
variable "all_locations" {
  type = map
  default = {
    ase   = "eastasia"           #DisplayName : East Asia
    ass   = "southeastasia"      #Southeast Asia
    usc   = "centralus"          #Central US
    use   = "eastus"             # East US
    use2  = "eastus2"            #East US 2
    usw   = "westus"             #West US  sd
    usnc  = "northcentralus"     #North Central US
    ussc  = "southcentralus"     #South Central US
    uswc  = "westcentralus"      #West Central US
    eun   = "northeurope"        # North Europe
    euw   = "westeurope"         #West Europe
    wej   = "japanwest"          #Japan West
    jae   = "japaneast"          #Japan East
    brs   = "brazilsouth"        #Brazil South
    ause  = "australiaeast"      #Australia East
    ausse = "australiasoutheast" # Australia Southeast
    ins   = "southindia"         #South India
    inc   = "centralindia"       #Central India
    inw   = "westindia"          #West India
    cac   = "canadacentral"      #Canada Central
    cae   = "canadaeast"         # Canada East
    uks   = "uksouth"            # UK South
    ukw   = "ukwest"             #UK West
    usw2  = "westus2"            #West US 2
    koc   = "koreacentral"       #Korea Central
    kos   = "koreasouth"         #Korea South
    frc   = "francecentral"      #France Central
    frs   = "francesouth"        #France South

    ausc = "australiacentral"  #Australia Central
    auc2 = "australiacentral2" #Australia Central 2
    uaec = "uaecentral"        # UAE Central
    uaen = "uaenorth"          #UAE North
    san  = "southafricanorth"  #South Africa North
    saw  = "southafricawest"   #South Africa West

    swn = "switzerlandnorth"   #Switzerland North
    sww = "switzerlandwest"    #Switzerland West
    gen = "germanynorth"       # Germany North
    gwc = "germanywestcentral" # Germany West Central

    norw = "norwaywest"      #Norway West
    nore = "norwayeast"      #Norway East
    brse = "brazilsoutheast" #Brazil Southeast

  }
}


# # this map vairable is to use in name of the resources tags 
variable "environment" {
  type = map

  default = {
    dev = "Development"
    tst = "Test"
    sit = "System Integration"
    uat = "User acceptance test"
    pre = "Pre production"
    pro = "production"

    default = "Development"
  }
}

