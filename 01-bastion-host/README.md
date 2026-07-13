# Lab 01: Secure Bastion Host Architecture

This project builds an isolated custom VPC with a public subnet containing a bastion host and a private subnet containing a backend server.

## Key Architecture & Lessons Learned

### 1. Security Group Isolation
Learned the difference between using `security_groups` and `vpc_security_group_ids` when launching instances inside a non-default VPC.

### 2. Dynamic AMI Lookup via Data Sources
Instead of hardcoding a stagnant AWS AMI ID, I implemented a dynamic filter:
* **Automated Updates:** Queries the official Canonical account for the latest patched version.
* **Environment Agility:** Code remains reusable across different AWS regions.
* **Security:** Ensures instances launch with the latest security updates.

### 3. Automated Bootstrapping
Utilized "Heredoc" syntax (`<<-EOF ... EOF`)  to inject bash scripts and automate the installation of the Apache web server on launch.