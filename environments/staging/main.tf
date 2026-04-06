module "networking" {
  source = "../../modules/networking"

  name_prefix          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix     = var.environment
  repository_name = var.ecr_repo_name
}

module "compute" {
  source = "../../modules/compute"

  name_prefix = var.environment

  log_region = var.region
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids

  container_name = var.container_name
  container_port = var.container_port

  image = "${module.ecr.repository_url}:${var.image_tag}"
  desired_count  = var.desired_count
}