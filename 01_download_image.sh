#!/bin/bash
# 下載 Ubuntu Cloud Image

set -e

IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
# Proxmox 標準 ISO/Image 存放目錄
IMAGE_DIR="/var/lib/vz/template/iso"
IMAGE_NAME="ubuntu-22.04-server-cloudimg-amd64.img"
IMAGE_PATH="$IMAGE_DIR/$IMAGE_NAME"

echo "開始下載 Ubuntu Cloud Image..."

# 防呆：檢查是否為 root 權限
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] 此腳本需要 root 權限執行"
   exit 1
fi

# 防呆：檢查網路連接
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo "[ERROR] 無法連接到網際網路，請檢查網路設定"
    exit 1
fi

# 建立目錄
mkdir -p "$IMAGE_DIR"

# 防呆：檢查目錄權限
if [[ ! -w "$IMAGE_DIR" ]]; then
    echo "[ERROR] 無法寫入目錄: $IMAGE_DIR"
    exit 1
fi

# 防呆：檢查磁碟空間 (至少需要 1GB)
AVAILABLE_SPACE=$(df "$IMAGE_DIR" | awk 'NR==2 {print $4}')
REQUIRED_SPACE=1048576  # 1GB in KB
if [[ $AVAILABLE_SPACE -lt $REQUIRED_SPACE ]]; then
    echo "[ERROR] 磁碟空間不足，需要至少 1GB 可用空間"
    echo "[INFO] 可用空間: $(( AVAILABLE_SPACE / 1024 ))MB"
    exit 1
fi

# 防呆：檢查檔案是否已存在
if [[ -f "$IMAGE_PATH" ]]; then
    echo "[INFO] 映像檔已存在: $IMAGE_PATH"
    echo "[INFO] 檔案大小: $(du -h "$IMAGE_PATH" | cut -f1)"
    exit 0
fi

# 下載映像
echo "正在下載: $IMAGE_NAME"
echo "來源: $IMAGE_URL"
if wget -O "$IMAGE_PATH" "$IMAGE_URL"; then
    echo "[SUCCESS] 下載完成: $IMAGE_PATH"
else
    echo "[ERROR] 下載失敗"
    rm -f "$IMAGE_PATH"  # 清理失敗的下載
    exit 1
fi

# 檢查檔案大小
if [[ -s "$IMAGE_PATH" ]]; then
    echo "[INFO] 檔案大小: $(du -h "$IMAGE_PATH" | cut -f1)"
    echo "[INFO] 檔案路徑: $IMAGE_PATH"
else
    echo "[ERROR] 下載的檔案為空"
    rm -f "$IMAGE_PATH"
    exit 1
fi

echo "[SUCCESS] Ubuntu Cloud Image 下載完成！"
