terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "pet_vpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "pet-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.pet_vpc.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "sb-publica-pet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.pet_vpc.id
  cidr_block        = "10.0.0.128/25"
  availability_zone = "us-east-1a"

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
  depends_on = [aws_internet_gateway.igw]
  domain     = "vpc"

  tags = {
    Name = "eip-nat-pet"
  }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

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
  subnet_id      = aws_subnet.public_subnet.id
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
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.rt_private.id
}

resource "aws_security_group" "sg_pet" {
  name        = "pet-sg"
  description = "security group for pet project"
  vpc_id      = aws_vpc.pet_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
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
    Name = "sg-pet"
  }
}

locals {
  ami = "ami-04b70fa74e45c3917"
}

resource "aws_instance" "public_ec2" {
  ami                         = local.ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_pet.id]
  key_name                    = "ssh-pet"

  tags = {
    Name = "ec2-publica-pet"
  }
}

resource "aws_instance" "front1" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_pet.id]
  key_name               = "ssh-pet"

  tags = {
    Name = "ec2-frontv1-pet"
  }
}

resource "aws_instance" "front2" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_pet.id]
  key_name               = "ssh-pet"

  tags = {
    Name = "ec2-frontv2-pet"
  }
}

resource "aws_instance" "back1" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_pet.id]
  key_name               = "ssh-pet"

  tags = {
    Name = "ec2-backv1-pet"
  }
}

resource "aws_instance" "back2" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_pet.id]
  key_name               = "ssh-pet"

  tags = {
    Name = "ec2-backv2-pet"
  }
}

resource "aws_instance" "bd" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.sg_pet.id]
  key_name               = "ssh-pet"

  tags = {
    Name = "ec2-bd-pet"
  }
}

output "vpc_id" {
  value = aws_vpc.pet_vpc.id
}