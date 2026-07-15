# variables.tf
variable "aws_region" {
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  type        = string
  default     = "t2.micro"
}

variable "asg_min_size" {
  type        = number
  default     = 1
}

variable "asg_max_size" {
  type        = number
  default     = 3
}

variable "asg_desired_capacity" {
  type        = number
  default     = 2
}