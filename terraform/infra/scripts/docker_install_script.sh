#!/bin/bash

# 設置非互動式環境變數
export DEBIAN_FRONTEND=noninteractive
export APT_LISTCHANGES_FRONTEND=none

# STEP1. Prepare the environment: Install
# STEP1-1. Add Docker's official GPG key:
echo "更新套件列表..."
sudo apt-get update -y
echo "安裝必要套件..."
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
echo "下載 Docker GPG 金鑰..."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo "新增 Docker 套件來源..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y

# STEP1-2. Docker Installation
# 安裝 Docker 套件
echo "安裝 Docker 套件..."
sudo apt-get install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# 確認安裝版本
docker -v || echo "Docker command not available, please check"

# STEP1-3. Docker Compose Installation
# 安裝最新版本的 Docker Compos
echo "安裝 Docker Compose 套件..."
sudo apt-get install -y docker-compose-plugin
# 確認安裝版本
docker compose version || echo "Docker Compose command not available, please check"
# 將當前用戶加入 Docker 群組
sudo usermod -aG docker ${USER}
# Enable and start the Docker service，讓群組權限生效
sudo systemctl enable docker
sudo systemctl restart docker

# 檢查目前使用者，你應該會看到 docker 出現在 groups 裡
echo "注意：Docker 群組權限可能需要重新登入才會生效"
id