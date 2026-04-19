resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  oidc_arn = aws_iam_openid_connect_provider.github.arn
  oidc_sub = "token.actions.githubusercontent.com:sub"
  oidc_aud = "token.actions.githubusercontent.com:aud"

  envs = ["qa", "staging", "prod"]

  env_prefix = {
    qa      = var.name_prefix_qa
    staging = var.name_prefix_staging
    prod    = var.name_prefix_prod
  }

  ecs_cluster = {
    for env in local.envs :
    env => "${local.env_prefix[env]}-${var.ecs_cluster_name}"
  }

  ecs_service = {
    for env in local.envs :
    env => "${local.env_prefix[env]}-${var.ecs_service_name}"
  }

  ecs_task_def = {
    for env in local.envs :
    env => "${local.env_prefix[env]}-${var.ecs_task_def_name}"
  }
}

# BACKEND ASSUME ROLE
data "aws_iam_policy_document" "assume_backend" {
  for_each = toset(local.envs)

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = local.oidc_aud
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = local.oidc_sub
      values   = ["repo:${var.backend_github_repo}:environment:${each.key}"]
    }
  }
}

# TERRAFORM ASSUME ROLE
data "aws_iam_policy_document" "assume_terraform" {
  for_each = toset(local.envs)

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }

    condition {
      test     = "StringEquals"
      variable = local.oidc_aud
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = local.oidc_sub
      values   = ["repo:${var.terraform_github_repo}:*"]
    }
  }
}

# BACKEND ROLE
resource "aws_iam_role" "backend" {
  for_each = toset(local.envs)

  name               = "gh-actions-backend-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume_backend[each.key].json
}

resource "aws_iam_role_policy" "backend" {
  for_each = toset(local.envs)

  name = "gh-actions-backend-${each.key}-policy"
  role = aws_iam_role.backend[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR auth
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },

      # ECR push (scoped)
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:BatchGetImage"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.ecr_repo_name}"
      },

      # ECS deploy
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions"
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:cluster/${local.ecs_cluster[each.key]}",
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:service/${local.ecs_cluster[each.key]}/${local.ecs_service[each.key]}",
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:task-definition/${local.ecs_task_def[each.key]}:*"
        ]
      },

      # Pass role to ECS tasks
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::${local.account_id}:role/${local.env_prefix[each.key]}-*"
      }
    ]
  })
}

# TERRAFORM ROLE (ADMIN)
resource "aws_iam_role" "terraform" {
  for_each = toset(local.envs)

  name               = "gh-actions-terraform-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume_terraform[each.key].json
}

# ATTACH FULL ADMIN ACCESS (AS REQUESTED)
resource "aws_iam_role_policy_attachment" "terraform_admin" {
  for_each = toset(local.envs)

  role       = aws_iam_role.terraform[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}