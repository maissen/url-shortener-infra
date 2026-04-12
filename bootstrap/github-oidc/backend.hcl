bucket         = "maiss-terraform-state-bucket"
key            = "oidc/terraform.tfstate"
region         = "us-east-2"
dynamodb_table = "terraform-locks"
encrypt        = true