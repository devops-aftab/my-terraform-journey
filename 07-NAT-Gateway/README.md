# Lab 07: AWS NAT Gateway Lab

An isolated, zero-exposure network setup using Terraform.

##  Deployment Instructions

Follow these commands in your standard Windows Command Prompt (CMD):

```cmd
:: 1. Initialize the workspace and download providers
terraform init

:: 2. Review and dry-run structural updates
terraform plan

:: 3. Spin up the infrastructure
terraform apply -auto-approve