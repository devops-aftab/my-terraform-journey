# Lab 06: Minimalist AWS Transit Gateway Routing

This is a high-impact, zero-bloat lab designed to verify transit-routing functionality between isolated networks.

We deploy one instance in the **Default VPC** and one in a **Custom VPC** (`10.2.0.0/16`), bridging them over an **AWS Transit Gateway (TGW)**.

---

##  Directory Structure
* `providers.tf`: Provider constraints and SSH/file-writer handlers.
* `variables.tf`: Minimal parameters.
* `userdata.sh`: Bootstraps Apache on Ubuntu to facilitate `curl` diagnostics.
* `main.tf`: Defines single-subnet VPC configurations, key generation, security policies, instances, and TGW bindings.
* `outputs.tf`: Direct, copy-pasteable SSH commands and IP registers.

---

## How to Execute and Run Diagnostics

### 1. Initialize and Spin up
```bash
terraform init
terraform apply -auto-approve