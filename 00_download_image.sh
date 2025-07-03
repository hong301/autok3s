#!/bin/bash
# 下載 Ubuntu 22.04 Cloud Image 並放入 Proxmox ISO 模板目錄

set -e
IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
SAVE_DIR="/var/lib/vz/template/iso"
SAVE_FILE="${SAVE_DIR}/ubuntu-22.04-server-cloudimg-amd64.img"

if [ -f "$SAVE_FILE" ]; then
    echo "✅ 已存在: $SAVE_FILE，略過下載"
    exit 0
fi

echo "⬇️ 下載 Ubuntu 22.04 Cloud Image..."
wget -O "$SAVE_FILE" "$IMG_URL"

echo "✅ 下載完成：$SAVE_FILE"
# 檢查檔案大小是否合理
if [ ! -s "$SAVE_FILE" ]; then
    echo "❌ 下載的檔案大小為 0，請檢查網路連線或 URL 是否正確"
    exit 1
fi