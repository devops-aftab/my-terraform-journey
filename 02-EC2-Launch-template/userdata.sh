#!/bin/bash
# Update the OS packages
dnf update -y

# Install Apache Web Server
dnf install -y httpd

# Start and enable Apache so it survives reboots
systemctl start httpd
systemctl enable httpd

# Create a simple landing page
echo "<h1>Hello from your EC2 Launch Template Lab! </h1>" > /var/www/html/index.html