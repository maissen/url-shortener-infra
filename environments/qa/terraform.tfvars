environment = "qa"

region = "us-east-2"

vpc_cidr = "10.0.0.0/16"

azs = [
  "us-east-2a",
  "us-east-2b",
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24",
]

private_subnet_cidrs = [
  "10.0.11.0/24",
  "10.0.12.0/24",
]

nat_subnet_indices = [0, 1]

container_name = "app"
container_port = 3000

image_tag                      = "latest"
ecr_repo_url                   = "767397762089.dkr.ecr.us-east-2.amazonaws.com/app"
desired_count                  = 1
enable_alb_deletion_protection = true

app_name = "url-shortener"

alert_emails = ["maissen.developer500@gmail.com"]