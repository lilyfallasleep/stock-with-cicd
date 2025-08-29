#!/bin/bash

# 腳本在錯誤時停止
set -e
# 檢查 EBS 自動掛載腳本的日誌
# exec > >(tee /var/log/ebs-mount.log) 2>&1
# echo "開始執行 EBS 掛載腳本: $(date)"

DEVICE_NAME="/dev/nvme1n1"
MOUNT_POINT="/var/lib/docker"

# 0. 確保 EBS 已建立（最多 10 次，每次 5 秒）
for i in {1..10}; do
    if [ -b "$DEVICE_NAME" ]; then
        echo "Device $DEVICE_NAME found"
        break
    fi
    echo "Waiting for $DEVICE_NAME..."
    sleep 5
done

# 1. 檢查 EBS 是否已經格式化 (如果沒有，才進行格式化)
if ! sudo blkid "$DEVICE_NAME"; then
    echo "Formatting EBS volume=$DEVICE_NAME..."
    sudo mkfs -t ext4 "$DEVICE_NAME"
else
    echo "$DEVICE_NAME is already formatted."
fi

# 2. 確保掛載點目錄 Docker 存在 (如果不存在，建立掛載目錄)
echo "Ensuring mount point $MOUNT_POINT exists..."
mkdir -p "$MOUNT_POINT"

# 2-1. 檢查 Docker 是否安裝 （如果有安裝，停止 Docker)
if which docker > /dev/null 2>&1 || [ -e /usr/bin/docker ] || systemctl list-unit-files | grep -q docker.service; then
# if command -v docker &> /dev/null; then
    echo "Stopping Docker service..."
    sudo systemctl stop docker || true
else
    echo "Install Docker..."
    chmod +x /home/ubuntu/stock-with-cicd/terraform/infra/scripts/docker_install_script.sh
    sudo /home/ubuntu/stock-with-cicd/terraform/infra/scripts/docker_install_script.sh
fi

# 3. 掛載 EBS 到 Docker 目錄 (如果沒有，才掛載)
if ! findmnt -r -n -o TARGET "$DEVICE_NAME" | grep -q "^$MOUNT_POINT$"; then
    echo "Mounting $DEVICE_NAME to $MOUNT_POINT..."
    sudo mount "$DEVICE_NAME" "$MOUNT_POINT" || true
else
    echo "$DEVICE_NAME is already mounted to $MOUNT_POINT."
fi

# 4. 設定開機自動掛載  (如果 fstab 中沒有該掛載點，才設定)
echo "Setting up auto-mount on boot..."
if ! grep -q "$MOUNT_POINT" /etc/fstab; then
    echo "$DEVICE_NAME $MOUNT_POINT ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
fi

# 5. 啟動 Docker 服務
echo "Starting Docker service..."
sudo systemctl start docker

# 6. 驗證掛載是否成功
echo 'Verifying mount...'
df -h | grep "$MOUNT_POINT"

echo "EBS volume setup complete."