module "ecr" {
  source = "../../modules/ecr"

  name_prefix = "staging"
  repository_name = "repo"
}