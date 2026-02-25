variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance and related resources"
  type        = string
  default     = "myluxsrv.myddns.me"
}

variable "domain_name" {
  description = "Domain name for the server and SSL certificate"
  type        = string
  default     = "myluxsrv.myddns.me"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "disk_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 16
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for the key pair"
  type        = string
  default     = "/home/farego/Documentos/terraform_guide/terraform_key.pub"
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH into the instance (restrict to your IP for security)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "certbot_email" {
  description = "Email address for Let's Encrypt certificate registration"
  type        = string
  default     = "admin@myluxsrv.myddns.me"
}
