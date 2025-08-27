# --- CONFIGURATION ---

# [選項1] 使用 Terraform Cloud 作為 terraform 後端配置
terraform {
  backend "remote" {
    organization = "lilyfallasleep-org"
    workspaces {
      name = "stock-with-cicd"
    }
  }
}

# [選項2] 使用 S3 Bucket 作為 terraform 後端配置
# terraform {
#   backend "s3" {
#     bucket         = "stock-with-cicd-tfstate"      # 您建立的 S3 Bucket 名稱
#     key            = "stock-cicd/terraform.tfstate" # state 檔在 S3 的路徑
#     region         = "ap-northeast-3"              # S3 所在的區域
#     # dynamodb_table = "dynamoDB_to_lock_terraform_state"
#     use_lockfile   = true                                # 啟用 state lock 功能     
#     encrypt        = true                                # 加密 state 檔
#     acl            = "private"                           # 確保私有存取
#   }
# }