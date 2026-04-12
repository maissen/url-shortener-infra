bucket         = "maiss-terraform-state-bucket"
key            = "staging/terraform.tfstate"
region         = "us-east-2"
dynamodb_table = "terraform-locks"
encrypt        = true