resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  oidc_arn    = aws_iam_openid_connect_provider.github.arn
  oidc_sub    = "token.actions.githubusercontent.com:sub"
  oidc_aud    = "token.actions.githubusercontent.com:aud"

  envs = ["qa", "staging", "prod"]

  env_prefix = {
    qa      = var.name_prefix_qa
    staging = var.name_prefix_staging
    prod    = var.name_prefix_prod
  }
}

# Assume-role policy factory
data "aws_iam_policy_document" "assume" {
  for_each = toset(["qa", "staging", "prod"])

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
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

# BACKEND roles
resource "aws_iam_role" "backend" {
  for_each = toset(local.envs)

  name               = "gh-actions-backend-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume[each.key].json

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
      # ECR push
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
          "ecr:BatchGetImage",
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${local.env_prefix[each.key]}-*"
      },
      # ECS update
      {
        Sid    = "ECSUpdate"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions",
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:cluster/${local.env_prefix[each.key]}-*",
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:service/${local.env_prefix[each.key]}-*/*",
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:task-definition/${local.env_prefix[each.key]}-*:*",
        ]
      },
      # PassRole so ECS can assume the task execution role
      {
        Sid    = "PassTaskExecutionRole"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = "arn:aws:iam::${local.account_id}:role/${local.env_prefix[each.key]}-*"
      },
    ]
  })
}

# TERRAFORM roles
resource "aws_iam_role" "terraform" {
  for_each = toset(local.envs)

  name               = "gh-actions-terraform-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume[each.key].json

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
      # S3 for remote state
      {
        Sid    = "TFStateBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.tf_state_bucket}",
          "arn:aws:s3:::${var.tf_state_bucket}/${each.key}/*",
        ]
      },
      # DynamoDB for state locking
      {
        Sid    = "TFStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.tf_lock_table}"
      },
      # DynamoDB – backend's tables (storage module)
      {
        Sid      = "DynamoDBManage"
        Effect   = "Allow"
        Action   = ["dynamodb:*"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.env_prefix[each.key]}-*"
      },
      # ECR full CRUD scoped to env's repositories
      {
        Sid      = "ECRManage"
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${local.env_prefix[each.key]}-*"
      },
      # ECR auth token
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      # ECS with full CRUD scoped to env's clusters/services/task defs
      {
        Sid    = "ECSManage"
        Effect = "Allow"
        Action = ["ecs:*"]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:cluster/${local.env_prefix[each.key]}-*",
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:service/${local.env_prefix[each.key]}-*/*",
          "arn:aws:ecs:${var.aws_region}:${local.account_id}:task-definition/${local.env_prefix[each.key]}-*:*",
        ]
      },
      # IAM with full CRUD on task/execution roles env-scoped
      {
        Sid      = "IAMTaskRoles"
        Effect   = "Allow"
        Action   = ["iam:*"]
        Resource = "arn:aws:iam::${local.account_id}:role/${local.env_prefix[each.key]}-*"
      },
      # EC2 and VPC with networking CRUD for the env's resources
      {
        Sid      = "VPCManage"
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },
      # CloudWatch Logs with full CRUD scoped to the env's log groups
      {
        Sid      = "LogsManage"
        Effect   = "Allow"
        Action   = ["logs:*"]
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:log-group:/ecs/${local.env_prefix[each.key]}-*"
      },
      # SSM parameter reads
      {
        Sid      = "SSMRead"
        Effect   = "Allow"
        Action   = ["ssm:*"]
        Resource = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/${local.env_prefix[each.key]}/*"
      },
    ]
  })
}
