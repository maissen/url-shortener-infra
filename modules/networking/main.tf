# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

# NAT gw
# one EIP per desired NAT GW
resource "aws_eip" "nat_eip" {
  count  = length(var.nat_subnet_indices)
  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  }
}

resource "time_sleep" "wait_for_eip" {
  depends_on      = [aws_eip.nat_eip]
  create_duration = "120s"
}

# NAT GWs one per entry in nat_subnet_indices
resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.nat_subnet_indices)
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[var.nat_subnet_indices[count.index]].id

  tags = {
    Name = "${var.name_prefix}-nat-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw, time_sleep.wait_for_eip]
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-${count.index + 1}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.name_prefix}-private-${count.index + 1}"
  }
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

# Route to Internet
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}


# Associate public subnets with public rt
resource "aws_route_table_association" "public_assoc" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# private route table
resource "aws_route_table" "private" {
  count  = length(var.nat_subnet_indices)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.name_prefix}-private-rt-${count.index + 1}"
  }
}

# Route to Internet
resource "aws_route" "private_internet" {
  count                  = length(var.nat_subnet_indices)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
}

# Associate private subnets with private rt
resource "aws_route_table_association" "private_assoc" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index % length(var.nat_subnet_indices)].id
}