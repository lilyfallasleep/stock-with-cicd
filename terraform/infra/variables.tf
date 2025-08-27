variable "aws_region" { # Region 代號，代表大阪區域
  description = "AWS region"
  default     = "ap-northeast-3"
}

variable "aws_az" { # AZ 代號，代表大阪區域下的某一個可用區
  description = "AWS availability zone"
  default     = "ap-northeast-3c"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  default     = "t4g.large"
}

variable "ec2_ami" {
  description = "AMI ID for EC2 instance"
  default     = "ami-0acb06356c7915dd0"   # Ubuntu 22.04 LTS
}

variable "ec2_key_name" {
  description = "EC2 key pair name"
  default     = "aws-ec2-key"
  type        = string
}

variable "ssh_private_key" {
  description = "private key(content) for SSH access to the EC2 instance. Used by Terraform Cloud."
  type        = string
  sensitive   = true 
}

variable "ssh_private_key_path" {
  description = "private key(path) for SSH access to the EC2 instance. Used for local execution."
  type        = string 
  default     = null
}