output "default_vpc_instance_public_ip" {
  value       = aws_instance.default_ec2.public_ip
  description = "Public IP of the EC2 in the Default VPC"
}

output "default_vpc_instance_private_ip" {
  value       = aws_instance.default_ec2.private_ip
  description = "Private IP of the EC2 in the Default VPC"
}

output "custom_vpc_instance_public_ip" {
  value       = aws_instance.custom_ec2.public_ip
  description = "Public IP of the EC2 in the Custom VPC"
}

output "custom_vpc_instance_private_ip" {
  value       = aws_instance.custom_ec2.private_ip
  description = "Private IP of the EC2 in the Custom VPC"
}

output "ssh_command_default_instance" {
  value       = "ssh -i tgw-key.pem ubuntu@${aws_instance.default_ec2.public_ip}"
  description = "Command to SSH into the Default VPC instance"
}

output "ssh_command_custom_instance" {
  value       = "ssh -i tgw-key.pem ubuntu@${aws_instance.custom_ec2.public_ip}"
  description = "Command to SSH into the Custom VPC instance"
}