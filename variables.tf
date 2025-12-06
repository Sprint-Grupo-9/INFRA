variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "key_name" {
  type    = string
  default = "ssh-pet"
}

# Variable que define a AMI do Ubuntu a ser utilizada nas instâncias EC2
# Permite sobrescrever a AMI padrão com uma imagem customizada do Ubuntu 22.04
variable "ubuntu_ami" {
    type    = string
    description = "Ubuntu AMI id (override default with an Ubuntu 22.04 AMI)"
    default = "" 
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "groq_api_key" {
  type = string
  default = "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"
}

variable "domain" {
  type = string
  default = "example.com"
}

variable "backend_java_image" {
  type = string
  default = "samuelpazz/api-pet-columbia:2.1.3"
}

variable "db_name" {
  type = string
  default = "petdb"
}

variable "db_user" {
  type = string
  default = "petuser"
}

variable "db_pass" {
  type = string
  default = "petpass"
}

variable "redis_password" {
  type = string
  default = "redispass"
}

