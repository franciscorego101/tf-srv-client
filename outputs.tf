output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.web.id
}

output "elastic_ip" {
  description = "Elastic IP address — point your DNS (21x.ddns.net) to this IP"
  value       = aws_eip.web.public_ip
}

output "ami_id" {
  description = "AMI used for the instance"
  value       = data.aws_ami.ubuntu.id
}

output "ami_name" {
  description = "AMI name"
  value       = data.aws_ami.ubuntu.name
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh ubuntu@${aws_eip.web.public_ip}"
}

output "website_url" {
  description = "Website URL (HTTPS will work after DNS + certbot complete)"
  value       = "https://${var.domain_name}"
}
