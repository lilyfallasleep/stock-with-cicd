output "ec2_instance_ip" {
  value = aws_instance.stock_ec2_terraform.public_ip
}

output "ec2_instance_dns" {
  value = aws_instance.stock_ec2_terraform.public_dns
}