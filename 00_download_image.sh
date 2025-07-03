#!/bin/bash
# 下載 Ubuntu 22.04 Cloud Image 並放入 Proxmox ISO 模板目錄

set -e

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

echo "🚀 執行階段：00_download_image.sh - 下載 Ubuntu Cloud Image"
echo "================================================="

IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
SAVE_FILE="$ISO_DIR/ubuntu-22.04-server-cloudimg-amd64.img"

# 使用共用函數下載映像
download_ubuntu_image "$IMG_URL" "$SAVE_FILE"

echo "✅ 階段完成：00_download_image.sh"
echo ""