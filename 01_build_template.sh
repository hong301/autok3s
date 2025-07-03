#!/bin/bash
# 01_build_template.sh - 建立乾淨黃金映像 Template（不包含 cloud-init 使用者設定）

set -e

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

echo "🚀 執行階段：01_build_template.sh - 建立 VM 模板"
echo "================================================="

# 檢查並安裝必要工具
check_required_tools

IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_NAME="ubuntu-2204-template.qcow2"
IMAGE_PATH="$ISO_DIR/$IMAGE_NAME"

# 下載映像檔
download_ubuntu_image "$IMAGE_URL" "$IMAGE_PATH"

# 建立 VM Template
create_vm_template "$TEMPLATE_ID" "ubuntu-template" "$IMAGE_PATH"

echo "📌 設定 cloud-init 預設使用者..."
qm set $TEMPLATE_ID --ciuser ubuntu

echo "✅ 階段完成：01_build_template.sh"
echo ""

echo "✅ 建立完成！TEMPLATE_ID=$TEMPLATE_ID"
