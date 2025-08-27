# --- CONFIGURATION ---
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"  
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Import Block --- 
# import {
#   to = aws_security_group.launch-wizard-1
#   id = "sg-09a743b4a5d3c5829"
# }
# import {
#   to = aws_instance.stock_ec2
#   id = "i-093d5e0986b9a3a7d"
# }

# --- Resource Definitions ---
# 1. Security Group (使用從 generated.tf 觀察到的、更精確的結構)
resource "aws_security_group" "launch-wizard-1" {
  name        = "launch-wizard-1"
  description = "launch-wizard-1 created 2025-07-23T09:17:10.159Z"
  vpc_id      = "vpc-06ac0e2382703b038" 

  ingress {
    description = "SSH"
    from_port   = 22 
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "Airflow UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MinIO"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Metabase"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Spark Master UI"
    from_port   = 8082
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Spark Worker UI"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Docker Proxy"
    from_port   = 2376
    to_port     = 2376
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. EC2 Instance
resource "aws_instance" "stock_ec2" {
  ami           = var.ec2_ami # Ubuntu 22.04 for arm64
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_key_name          # 確保這個 Key Pair 存在於您的 AWS 帳號中
  vpc_security_group_ids = [aws_security_group.launch-wizard-1.id] # 將設置的 Security Group 套用在這個 EC2
  availability_zone = var.aws_az #  EBS volume and EC2 instance must be in the same AZ

  tags = {
    Name = "stock-ec2"
  }
  user_data = ""
}

resource "aws_instance" "stock_ec2_terraform" {
  ami           = var.ec2_ami # Ubuntu 22.04 for arm64
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_key_name
  vpc_security_group_ids = [aws_security_group.launch-wizard-1.id]

  tags = {
    Name = "stock-ec2-terraform"
  }
  
  # Render the user_data script from an external file
  user_data = templatefile("${path.module}/infra/scripts/docker_install_script.sh", {})  
}

# 3. EBS Volume
resource "aws_ebs_volume" "docker_ebs" {
  availability_zone = var.aws_az
  size              = 15
  type              = "gp2"

  tags = {
    Name = "docker-ebs"
  }
}

# 4. 將 EBS Volume 掛載到 EC2 Instance
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.docker_ebs.id
  instance_id = aws_instance.stock_ec2_terraform.id
}

# 5. 使用 null_resource 在 EBS 掛載完成後執行初始化腳本
# 若在 TFC 環境運行，ssh_private_key 不是 null，就使用它。否則(在本地環境)，就使用 ssh_private_key_path
locals {
  ssh_private_key = var.ssh_private_key != null ? var.ssh_private_key : file(pathexpand(var.ssh_private_key_path))
}
resource "null_resource" "init_docker_ebs" {
  depends_on = [
    aws_volume_attachment.ebs_att
  ]

  provisioner "remote-exec" {
    inline = [
      "sudo bash /home/ubuntu/stock-with-cicd/terraform/infra/scripts/init_script.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"                        # Ubuntu AMI 預設使用者
      private_key = local.ssh_private_key             # 使用私鑰來連接 EC2
      host        = aws_instance.stock_ec2_terraform.public_ip
    }
  }
}

