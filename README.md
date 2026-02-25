# 21x.ddns.net — Terraform Infrastructure

AWS EC2 web server with Nginx, automatic SSL via Let's Encrypt, and Elastic IP.

## What Gets Created

| Resource           | Details                                        |
|--------------------|------------------------------------------------|
| EC2 Instance       | t3.medium, Ubuntu 24.04 LTS, 16 GB gp3 disk   |
| Security Group     | Inbound SSH (22), HTTP (80), HTTPS (443)        |
| Elastic IP         | Static public IP associated with the instance   |
| Key Pair           | From your local SSH public key                  |
| Software (via cloud-init) | nginx, certbot, auto-SSL for 21x.ddns.net |

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.5
- AWS CLI configured (`aws configure` — uses the `default` profile)
- SSH key pair at `~/.ssh/id_rsa.pub` (or update `ssh_public_key_path` in `terraform.tfvars`)

## Quick Start

```bash
# 1. Edit terraform.tfvars — set your email and region
vim terraform.tfvars

# 2. Initialize Terraform
terraform init

# 3. Preview changes
terraform plan

# 4. Deploy
terraform apply

# 5. Note the Elastic IP from the output
#    → Point 21x.ddns.net DNS to that IP

# 6. SSH into the instance
ssh ubuntu@<ELASTIC_IP>

# 7. Check cloud-init progress
sudo tail -f /var/log/user_data.log

# 8. Check certbot retry status
sudo journalctl -u certbot-obtain.timer
sudo cat /var/log/certbot-obtain.log
```

## SSL Certificate Flow

The instance sets up a **systemd timer** that retries `certbot` every 5 minutes:

1. `terraform apply` creates the instance and Elastic IP
2. You update **21x.ddns.net** DNS to point to the Elastic IP
3. The timer fires, certbot verifies domain ownership via HTTP-01 challenge
4. Certificate is installed and Nginx is reloaded with HTTPS + redirect
5. The timer disables itself after success

Certbot's built-in renewal timer (`certbot.timer`) handles auto-renewal afterwards.

## Tear Down

```bash
terraform destroy
```

## Files

```
.
├── main.tf              # Provider, SG, EC2, EIP
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output values (IP, SSH command, etc.)
├── terraform.tfvars     # Your customized values (edit this)
├── scripts/
│   └── user_data.sh     # Cloud-init bootstrap script
├── .gitignore
└── README.md
```
