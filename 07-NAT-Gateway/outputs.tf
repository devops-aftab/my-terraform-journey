output "public_instance_public_ip" {
  value       = aws_instance.public_instance.public_ip
  description = "Public IP of the Bastion/Jump Host"
}

output "private_instance_private_ip" {
  value       = aws_instance.private_instance.private_ip
  description = "Private IP of the Isolated Instance"
}

output "ssh_to_public" {
  value       = "ssh -i nat-key.pem ubuntu@${aws_instance.public_instance.public_ip}"
  description = "Connect to the Public Instance"
}

output "copy_key_to_public" {
  value       = "scp -i nat-key.pem nat-key.pem ubuntu@${aws_instance.public_instance.public_ip}:/home/ubuntu/"
  description = "Copy the private key onto the Public Instance so you can jump to the Private Instance"
}

output "ssh_from_public_to_private" {
  value       = "ssh -i nat-key.pem ubuntu@${aws_instance.private_instance.private_ip}"
  description = "Run this command INSIDE the Public instance to jump into the Private instance"
}