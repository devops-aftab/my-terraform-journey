# Lab 02: EC2 Launch Template Configuration

## Overview
This lab demonstrates how to build a reusable, version-controlled blueprint for AWS EC2 instances using a **Launch Template**. Instead of hardcoding server configurations, this project leverages infrastructure-as-code best practices to ensure scalable and repeatable deployments.

## Architecture Features
* **Dynamic AMI Discovery:** Uses a Terraform data source to automatically query and fetch the latest Amazon Linux 2023 AMI from AWS.
* **Automated Bootstrapping:** Injects an external `userdata.sh` bash script (Base64 encoded) to auto-install and enable an Apache (`httpd`) web server on instance startup.
* **Security Architecture:** Provisions a custom Security Group permitting inbound HTTP (Port 80) and SSH (Port 22) traffic, with full outbound egress.
* **Zero-Downtime Lifecycle:** Implements the `create_before_destroy` meta-argument to guarantee smooth, zero-downtime infrastructure upgrades.

