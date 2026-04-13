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

  # Consistent naming
  ecr_repo = {
    for env in local.envs :
    env => "${local.env_prefix[env]}-${var.ecr_repo_name}"
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

# =========================
# Assume Role Policies
# =========================

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
      test     = "StringLike"
      variable = local.oidc_sub
      values = [
        "repo:${var.backend_github_repo}:ref:refs/heads/main",
        "repo:${var.backend_github_repo}:ref:refs/heads/releases/*"
      ]
    }
  }
}

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
      values = [
        "repo:${var.terraform_github_repo}:ref:refs/heads/main"
      ]
    }
  }
}

# =========================
# Backend Roles (CI/CD)
# =========================

resource "aws_iam_role" "backend" {
  for_each = toset(local.envs)

  name               = "gh-actions-backend-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume_backend[each.key].json

  tags = {
    Environment = each.key
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "backend" {
  for_each = toset(local.envs)

  name = "gh-actions-backend-${each.key}-policy"
  role = aws_iam_role.backend[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR login
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },

      # ECR push (env-scoped)
      {
        Sid    = "ECRPush"
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
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${local.ecr_repo[each.key]}"
      },

      # ECS update (env-scoped)
      {
        Sid    = "ECSUpdate"
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

      # Allow passing task execution roles
      {
        Sid    = "PassTaskExecutionRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = "arn:aws:iam::${local.account_id}:role/${local.env_prefix[each.key]}-*"
      }
    ]
  })
}

# =========================
# Terraform Roles (Infra)
# =========================

resource "aws_iam_role" "terraform" {
  for_each = toset(local.envs)

  name               = "gh-actions-terraform-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume_terraform[each.key].json

  tags = {
    Environment = each.key
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "terraform" {
  for_each = toset(local.envs)

  name = "gh-actions-terraform-${each.key}-policy"
  role = aws_iam_role.terraform[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Terraform state (S3)
      {
        Sid    = "TFStateBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.tf_state_bucket}",
          "arn:aws:s3:::${var.tf_state_bucket}/${each.key}/*"
        ]
      },

      # Terraform locking (DynamoDB)
      {
        Sid    = "TFStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.tf_lock_table}"
      },

      # DynamoDB tables (env scoped)
      {
        Sid      = "DynamoDBManage"
        Effect   = "Allow"
        Action   = ["dynamodb:*"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.env_prefix[each.key]}-*"
      },

      # ECR full access (env scoped)
      {
        Sid      = "ECRManage"
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${local.ecr_repo[each.key]}"
      },

      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },

      # ECS full access (env scoped)
      {
        Sid    = "ECSManage"
        Effect = "Allow"
        Action = ["ecs:*"]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:cluster/${local.ecs_cluster[each.key]}",
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:service/${local.ecs_cluster[each.key]}/${local.ecs_service[each.key]}",
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:task-definition/${local.ecs_task_def[each.key]}:*"
        ]
      },

      # IAM roles (env scoped)
      {
        Sid      = "IAMTaskRoles"
        Effect   = "Allow"
        Action   = ["iam:*"]
        Resource = "arn:aws:iam::${local.account_id}:role/${local.env_prefix[each.key]}-*"
      },

      # EC2 / VPC (broad, acceptable for now)
      {
        Sid      = "VPCManage"
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },

      # Logs
      {
        Sid      = "LogsManage"
        Effect   = "Allow"
        Action   = ["logs:*"]
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/ecs/${local.env_prefix[each.key]}-*"
      },

      # SSM
      {
        Sid      = "SSMRead"
        Effect   = "Allow"
        Action   = ["ssm:*"]
        Resource = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${local.env_prefix[each.key]}/*"
      }
    ]
  })
}