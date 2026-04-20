variable "name_prefix" {
  description = "Prefix for all resource names (staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
}

variable "nat_public_subnet_ids" {
  description = "List of public subnet IDs where NAT GWs will be placed. Min 1 entry."
  type        = list(string)

  validation {
    condition     = length(var.nat_public_subnet_ids) >= 1
    error_message = "At least one NAT Gateway is required."
  }
}