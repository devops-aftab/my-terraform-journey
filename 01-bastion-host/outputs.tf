output "webserver_public_ip" {
  value       = aws_instance.webserver.public_ip
  description = "The Public IP address of the webserver/bastion host"
}

output "database_private_ip" {
  value       = aws_instance.database.private_ip
  description = "The Private IP address of the database"
}