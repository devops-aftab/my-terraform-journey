output "launch_template_id" {
  description = "The ID of the EC2 Launch Template"
  value       = aws_launch_template.my_template.id
}

output "launch_template_latest_version" {
  description = "The latest version number of the launch template"
  value       = aws_launch_template.my_template.latest_version
}

output "security_group_id" {
  description = "The ID of the security group attached to the template"
  value       = aws_security_group.web_sg.id
}