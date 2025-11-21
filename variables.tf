variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "AZ to use"
  type        = string
  default     = "us-east-1a"
}

variable "key_name" {
  description = "Name for the AWS key pair (public key must be uploaded via public_key_path)"
  type        = string
  default     = "ssh-pet"
}

variable "public_key_path" {
  description = "Local path to the public key file (e.g. ~/.ssh/id_rsa.pub)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vpc_cidr" {
  default = "10.0.0.0/24"
}

variable "public_subnet_cidr" {
  default = "10.0.0.0/25"
}

variable "private_subnet_cidr" {
  default = "10.0.0.128/25"
}

variable "instance_type" {
  description = "EC2 instance type for all instances (t2.micro as requested)"
  default     = "t2.micro"
}