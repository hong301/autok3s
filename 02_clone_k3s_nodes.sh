#!/bin/bash
# 02_clone_k3s_nodes.sh - 建立 1 master + 3 worker VM，自定 SSH 金鑰與密碼（cloud-init）

set -e

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
PLAIN_PASSWORD="FsI!^@#Zg"  # 🔐 <<<<< 這裡改你想要的密碼
HASHED_PASS=$(mkpasswd -m sha-512 "$PLAIN_PASSWORD")

echo "🔐 使用固定密碼：$PLAIN_PASSWORD"

# VMID 名稱 記憶體MiB 核心數
VM_LIST=(
  "101 k3s-master 16384 4"
  "102 k3s-worker1 8192 2"
  "103 k3s-worker2 8192 2"
  "104 k3s-worker3 8192 2"
)

for ENTRY in "${VM_LIST[@]}"; do
  read -r VMID NAME MEM CORES <<< "$ENTRY"

  echo "🌀 建立 VM $VMID ($NAME) ..."
  qm clone "$TEMPLATE_ID" "$VMID" --name "$NAME"

  qm set "$VMID" \
    --memory "$MEM" \
    --cores "$CORES" \
    --net0 virtio,bridge=$BRIDGE \
    --ciuser ubuntu \
    --cipassword "$PLAIN_PASSWORD" \
    --sshkey "$SSH_KEY_PATH"

  if [[ "$NAME" == *"master"* ]]; then
    qm resize "$VMID" scsi0 20G
  else
    qm resize "$VMID" scsi0 10G
  fi

  qm start "$VMID"
  echo "✅ VM $VMID ($NAME) 啟動完成"
done

echo "⏳ 等待 60 秒讓 Cloud-Init 完成密碼與網路設定 ..."
sleep 60

echo "🔍 檢查 VM 的 qemu-guest-agent 狀態..."
for ENTRY in "${VM_LIST[@]}"; do
  read -r VMID NAME _ <<< "$ENTRY"
  if qm guest cmd "$VMID" qemu-agent-command --command '{"execute": "guest-ping"}' &>/dev/null; then
    echo "✅ VM $VMID ($NAME) guest-agent 正常"
  else
    echo "❌ VM $VMID ($NAME) guest-agent 未啟用，請手動安裝與啟動"
  fi
done
