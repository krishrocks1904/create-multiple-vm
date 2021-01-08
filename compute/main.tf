module "compute" {
  source     = "../../modules/compute"
  deployment = local.deployment
  management = local.management
}