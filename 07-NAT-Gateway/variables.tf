variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "AWS Deployment Region"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the custom VPC"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR block for the Public Subnet"
}

variable "private_subnet_cidr" {
  type        = string
  default     = "10.0.2.0/24"
  description = "CIDR block for the Private Subnet"
}

variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "EC2 Instance classification size"
}