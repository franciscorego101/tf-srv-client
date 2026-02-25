##############################################################################
# Terraform AWS Infrastructure for 21x.ddns.net
# - t3.medium Ubuntu instance with 16GB disk
# - Elastic IP
# - Security Group (SSH, HTTP, HTTPS)
# - Automated: system update, nginx, certbot, SSL certificate
##############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "default"
}

# ---------------------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------------------

# Latest Ubuntu 24.04 LTS AMI (HVM, SSD, amd64)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# ---------------------------------------------------------------------------
# Security Group
# ---------------------------------------------------------------------------

resource "aws_security_group" "web_server" {
  name        = "${var.instance_name}-sg"
  description = "Allow SSH, HTTP, and HTTPS inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# ---------------------------------------------------------------------------
# SSH Key Pair
# ---------------------------------------------------------------------------

resource "aws_key_pair" "deployer" {
  key_name   = "${var.instance_name}-key"
  public_key = file(var.ssh_public_key_path)
}

# ---------------------------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------------------------

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web_server.id]

  root_block_device {
    volume_size           = var.disk_size_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Cloud-init user_data runs on first boot as root
  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    domain_name   = var.domain_name
    certbot_email = var.certbot_email
  })

  tags = {
    Name = var.instance_name
  }
}

# ---------------------------------------------------------------------------
# Elastic IP
# ---------------------------------------------------------------------------

resource "aws_eip" "web" {
  domain = "vpc"

  tags = {
    Name = "${var.instance_name}-eip"
  }
}

resource "aws_eip_association" "web" {
  instance_id   = aws_instance.web.id
  allocation_id = aws_eip.web.id
}
