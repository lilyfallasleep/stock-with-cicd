# --- CONFIGURATION ---
# 默認使用本地存儲 state
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # 與 infra 目錄保持相同版本最佳
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Resource Definitions ---
# 1. S3 Bucket
resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = var.s3_bucket_name

  # 防止意外刪除 S3 bucket
  lifecycle {
    prevent_destroy = true
  }
}
# 1-1. S3 啟用版本控制：出現問題時能恢復成舊版，每次更新都會建立新版
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.terraform_state_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}
# 1-2. S3 加密：寫入到這個 S3 的所有資料都會啟用 server 端的加密
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.terraform_state_bucket.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# # 2. DynamoDB Table （使用新功能 S3 State Locking 取代）
# resource "aws_dynamodb_table" "terraform_state_locks" {
#   name         = var.dynamodb_table_name
#   billing_mode = "PAY_PER_REQUEST"
#   hash_key     = "LockID"
  
#   attribute {
#     name = "LockID"
#     type = "S"
#   }

#   lifecycle {
#     prevent_destroy = true
#   }
# }