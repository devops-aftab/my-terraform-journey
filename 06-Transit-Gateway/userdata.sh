#!/bin/bash
apt-get update -y
apt-get install -y apache2
systemctl start apache2
systemctl enable apache2

# Write a simple page identifying the host and private IP
echo "<h1>Hello from host: $(hostname) ($(hostname -I | awk '{print $1}'))</h1>" > /var/www/html/index.html