terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Reference existing SSH key pair in AWS
data "aws_key_pair" "ssh_pet" {
  key_name = var.key_name
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "aws_availability_zones" "available" {}

locals {
  ami = var.ubuntu_ami != "" ? var.ubuntu_ami : "ami-04b70fa74e45c3917"
}

# ---------------------------
# VPC + Subnets + IGW + NAT
# ---------------------------

resource "aws_vpc" "pet_vpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "pet-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.pet_vpc.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "sb-publica-pet"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.pet_vpc.id
  cidr_block        = "10.0.0.128/25"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "sb-privada-pet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.pet_vpc.id

  tags = {
    Name = "ig-pet"
  }
}

resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "nat-gateway-pet"
  }
}

resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.pet_vpc.id

  tags = {
    Name = "rt-publica-pet"
  }
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.rt_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "rt_assoc_public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt_public.id
}

resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.pet_vpc.id

  tags = {
    Name = "rt-privada-pet"
  }
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.rt_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}

resource "aws_route_table_association" "rt_assoc_private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.rt_private.id
}

# ---------------------------
# Security Groups
# ---------------------------

resource "aws_security_group" "lb_sg" {
  name   = "lb-sg"
  vpc_id = aws_vpc.pet_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lb-sg"
  }
}

resource "aws_security_group" "front_sg" {
  name   = "front-sg"
  vpc_id = aws_vpc.pet_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "front-sg"
  }
}

resource "aws_security_group" "back_sg" {
  name   = "back-sg"
  vpc_id = aws_vpc.pet_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.front_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "back-sg"
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg"
  vpc_id = aws_vpc.pet_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.back_sg.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-sg"
  }
}

# ---------------------------
# Userdata Templates
# ---------------------------

locals {
  front_userdata = templatefile("${path.module}/scripts/userdata_front.sh", {
    groq_api_key   = var.groq_api_key
    domain         = var.domain
    back1_ip       = aws_instance.back1.private_ip
    back2_ip       = aws_instance.back2.private_ip
    redis_password = var.redis_password
    ssh_public_key = var.ssh_public_key
  })

  front2_userdata = templatefile("${path.module}/scripts/userdata_front2.sh", {
    groq_api_key   = var.groq_api_key
    domain         = var.domain
    back1_ip       = aws_instance.back1.private_ip
    back2_ip       = aws_instance.back2.private_ip
    redis_password = var.redis_password
    ssh_public_key = var.ssh_public_key
  })

  back_userdata = templatefile("${path.module}/scripts/userdata_back.sh", {
    db_private_ip  = aws_instance.db.private_ip
    db_name        = var.db_name
    db_user        = var.db_user
    db_pass        = var.db_pass
    backend_image  = var.backend_java_image
    ssh_public_key = var.ssh_public_key
  })

  nginx_userdata = templatefile("${path.module}/scripts/userdata_nginx.sh", {
    front1_ip      = aws_instance.front1.private_ip
    front2_ip      = aws_instance.front2.private_ip
    ssh_public_key = var.ssh_public_key
  })

  db_userdata = templatefile("${path.module}/scripts/userdata_db.sh", {
    db_name        = var.db_name
    db_user        = var.db_user
    db_pass        = var.db_pass
    ssh_public_key = var.ssh_public_key
  })
}

# ---------------------------
# Instances
# ---------------------------

# LB (public)
resource "aws_instance" "lb" {
  ami                         = local.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.lb_sg.id]
  key_name                    = var.key_name
  user_data                   = local.nginx_userdata

  tags = {
    Name = "nginx-lb"
  }
}

# Backends (private)
resource "aws_instance" "back1" {
  ami                    = local.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.back_sg.id]
  key_name               = var.key_name
  user_data              = local.back_userdata

  tags = {
    Name = "backend-1"
  }
}

resource "aws_instance" "back2" {
  ami                    = local.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.back_sg.id]
  key_name               = var.key_name
  user_data              = local.back_userdata

  tags = {
    Name = "backend-2"
  }
}

# Fronts (private)
resource "aws_instance" "front1" {
  ami                         = local.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.front_sg.id]
  key_name                    = var.key_name
  user_data                   = local.front_userdata

  depends_on = [
    aws_instance.back1,
    aws_instance.back2
  ]

  tags = {
    Name = "frontend-1"
  }
}

resource "aws_instance" "front2" {
  ami                         = local.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.front_sg.id]
  key_name                    = var.key_name
  user_data                   = local.front2_userdata

  depends_on = [
    aws_instance.back1,
    aws_instance.back2
  ]

  tags = {
    Name = "frontend-2"
  }
}

# Database (private)
resource "aws_instance" "db" {
  ami                    = local.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name               = var.key_name
  user_data              = local.db_userdata

  tags = {
    Name = "postgres-db"
  }
}
