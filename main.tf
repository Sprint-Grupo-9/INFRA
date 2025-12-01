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
  tags = { Name = "pet-vpc" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.pet_vpc.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { Name = "sb-publica-pet" }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.pet_vpc.id
  cidr_block        = "10.0.0.128/25"
  availability_zone = "us-east-1a"
  tags = { Name = "sb-privada-pet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.pet_vpc.id
  tags = { Name = "ig-pet" }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
  depends_on = [aws_internet_gateway.igw]
  tags = { Name = "eip-nat-pet" }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = { Name = "nat-gateway-pet" }
}

resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.pet_vpc.id
  tags = { Name = "rt-publica-pet" }
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
  tags = { Name = "rt-privada-pet" }
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lb-sg" }
}

resource "aws_security_group" "frontend_sg" {
  name   = "frontend-sg"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "frontend-sg" }
}

resource "aws_security_group" "backend_sg" {
  name   = "backend-sg"
  vpc_id = aws_vpc.pet_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
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

  tags = { Name = "backend-sg" }
}

resource "aws_security_group" "postgres_sg" {
  name   = "postgres-sg"
  vpc_id = aws_vpc.pet_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "postgres-sg" }
}

resource "aws_security_group" "rabbitmq_sg" {
  name   = "rabbitmq-sg"
  vpc_id = aws_vpc.pet_vpc.id

  ingress {
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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

  tags = { Name = "rabbitmq-sg" }
}

locals {
  ami = "ami-04b70fa74e45c3917"
}

resource "aws_instance" "public_ec2" {
  ami                         = local.ami
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.lb_sg.id]
  key_name                    = "ssh-pet"
  tags = { Name = "ec2-publica-pet" }
}

resource "aws_instance" "front1" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  key_name               = "ssh-pet"
  tags = { Name = "ec2-frontv1-pet" }
}

resource "aws_instance" "front2" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  key_name               = "ssh-pet"
  tags = { Name = "ec2-frontv2-pet" }
}

resource "aws_instance" "back1" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = "ssh-pet"
  tags = { Name = "ec2-backv1-pet" }
}

resource "aws_instance" "back2" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  key_name               = "ssh-pet"
  tags = { Name = "ec2-backv2-pet" }
}

resource "aws_instance" "bd" {
  ami                    = local.ami
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  key_name               = "ssh-pet"
  tags = { Name = "ec2-bd-pet" }
}

output "public_instance_ip" {
  value = aws_instance.public_ec2.public_ip
}

output "front_private_ips" {
  value = [aws_instance.front1.private_ip, aws_instance.front2.private_ip]
}

output "back_private_ips" {
  value = [aws_instance.back1.private_ip, aws_instance.back2.private_ip]
}

output "bd_private_ip" {
  value = aws_instance.bd.private_ip
}
