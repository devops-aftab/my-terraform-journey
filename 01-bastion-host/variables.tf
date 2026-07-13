variable "aws_region" {
  type        = string
  default     = "ap-south-1"
  description = "The AWS region to deploy resources in"
}

variable "key_name" {
  type        = string
  default     = "my-key"
  description = "The name of the SSH key pair"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Base CIDR block for the VPC"
}

variable "public_subnet_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "CIDR block for the public subnet"
}

variable "private_subnet_cidr" {
  type        = string
  default     = "10.0.1.0/24"
  description = "CIDR block for the private subnet"
}

variable "availability_zone" {
  type        = string
  default     = "ap-south-1a"
  description = "The AZ to deploy subnets into"
}

variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "EC2 instance size"
}