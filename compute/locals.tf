locals {

  deployment = merge({
    storage_accounts     = {}
    key_vault            = {}
    application_insights = {}
    log_analytics        = {}
    network              = {}
    load_balancer        = {}

  }, var.deployment)


  management = merge({ tags = {} },
  var.management)
} 