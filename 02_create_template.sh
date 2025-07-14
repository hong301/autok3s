#!/bin/bash
# Proxmox VM 範本建立腳本 - 從 Ubuntu Cloud Image 建立 K3s 範本

set -e

source $(dirname "$0")/config.sh

TEMPLATE_ID=9000
IMAGE_FILE="/var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img"

# 防呆：檢查是否為 root 權限
if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] 此腳本需要 root 權限執行"
   exit 1
fi

# 防呆：檢查是否在 Proxmox 環境
if ! command -v qm &> /dev/null; then
    echo "[ERROR] 找不到 qm 命令，請確認在 Proxmox VE 環境中執行"
    exit 1
fi

# 防呆：檢查 config.sh 是否存在
if [[ ! -f "$(dirname "$0")/config.sh" ]]; then
    echo "[ERROR] 找不到 config.sh 檔案"
    exit 1
fi

# 防呆：檢查 Ubuntu Cloud Image 是否存在
if [[ ! -f "$IMAGE_FILE" ]]; then
    echo "[ERROR] 找不到 Ubuntu Cloud Image: $IMAGE_FILE"
    echo "[INFO] 請先執行 01_download_image.sh 下載映像檔"
    exit 1
fi

# 防呆：檢查 VM ID 是否已被使用
if qm status $TEMPLATE_ID &>/dev/null; then
    echo "[ERROR] VM ID $TEMPLATE_ID 已被使用"
    echo "[INFO] 請刪除現有 VM 或選擇不同的 ID"
    echo "       刪除指令: qm destroy $TEMPLATE_ID"
    exit 1
fi

# 防呆：檢查儲存是否存在
if ! pvesm status | grep -q "$STORAGE"; then
    echo "[ERROR] 儲存 '$STORAGE' 不存在"
    echo "[INFO] 可用儲存:"
    pvesm status | awk 'NR>1 {print "  - " $1}'
    exit 1
fi

# 防呆：檢查網路橋接是否存在
if ! ip link show "$NET_BRIDGE" &>/dev/null; then
    echo "[ERROR] 網路橋接 '$NET_BRIDGE' 不存在"
    echo "[INFO] 可用網路介面:"
    ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print "  - " $2}' | head -10
    exit 1
fi

echo "🔧 建立 K3s VM 範本 (ID: $TEMPLATE_ID)"
echo "========================================"
echo "儲存: $STORAGE"
echo "網路: $NET_BRIDGE"
echo "映像檔: $IMAGE_FILE"
echo ""

# 1. 建立新 VM
echo "[1/6] 建立 VM $TEMPLATE_ID..."
if ! qm create $TEMPLATE_ID \
    --name "ubuntu-k3s-template" \
    --ostype l26 \
    --memory 4096 \
    --cores 4 \
    --net0 "virtio,bridge=$NET_BRIDGE" \
    --serial0 socket \
    --vga serial0; then
    echo "[ERROR] 建立 VM 失敗"
    exit 1
fi

# 2. 匯入磁碟映像檔
echo "[2/6] 匯入磁碟映像檔..."
if ! qm disk import $TEMPLATE_ID "$IMAGE_FILE" $STORAGE; then
    echo "[ERROR] 匯入磁碟失敗"
    qm destroy $TEMPLATE_ID &>/dev/null || true
    exit 1
fi

# 3. 設定開機磁碟
echo "[3/6] 設定開機磁碟..."
if ! qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${TEMPLATE_ID}-disk-0; then
    echo "[ERROR] 設定開機磁碟失敗"
    qm destroy $TEMPLATE_ID &>/dev/null || true
    exit 1
fi

# 4. 設定 Cloud-Init
echo "[4/6] 設定 Cloud-Init..."
if ! qm set $TEMPLATE_ID --ide2 ${STORAGE}:cloudinit; then
    echo "[ERROR] 設定 Cloud-Init 失敗"
    qm destroy $TEMPLATE_ID &>/dev/null || true
    exit 1
fi

if ! qm set $TEMPLATE_ID --boot c --bootdisk scsi0; then
    echo "[ERROR] 設定開機順序失敗"
    qm destroy $TEMPLATE_ID &>/dev/null || true
    exit 1
fi

# 5. 啟用 QEMU Guest Agent
echo "[5/6] 啟用 QEMU Guest Agent..."
if ! qm set $TEMPLATE_ID --agent enabled=1; then
    echo "[ERROR] 啟用 QEMU Guest Agent 失敗"
    qm destroy $TEMPLATE_ID &>/dev/null || true
    exit 1
fi

# 設定基本的 Cloud-Init 參數
if ! qm set $TEMPLATE_ID \
    --ciuser "$CIUSER" \
    --cipassword "$CIPASSWORD" \
    --ipconfig0 ip=dhcp \
    --nameserver 8.8.8.8; then
    echo "[ERROR] 設定 Cloud-Init 參數失敗"
    qm destroy $TEMPLATE_ID &>/dev/null || true
    exit 1
fi

# 6. 轉換為範本
echo "[6/6] 轉換為範本..."
if ! qm template $TEMPLATE_ID; then
    echo "[ERROR] 轉換範本失敗"
    qm destroy $TEMPLATE_ID &>/dev/null || true
    exit 1
fi

echo ""
echo "✅ VM 範本建立完成！"
echo "========================"
echo "範本 ID: $TEMPLATE_ID"
echo "範本名稱: ubuntu-k3s-template"
echo "配置:"
echo "  - CPU: 4 cores"
echo "  - 記憶體: 4096 MB"
echo "  - 儲存: $STORAGE"
echo "  - 網路: $NET_BRIDGE"
echo "  - QEMU Guest Agent: 已啟用"
echo "  - Cloud-Init: 已配置"
echo ""
echo "💡 後續步驟:"
echo "執行 03_deploy_k3s.sh 來部署 K3s 叢集"
echo "每個從此範本建立的 VM 將會自動升級到 4CPU/4GB/20GB 配置"
