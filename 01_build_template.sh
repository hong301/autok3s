#!/bin/bash
# 01_build_template.sh - 建立乾淨黃金映像 Template（不包含 cloud-init 使用者設定）

set -e

IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_NAME="ubuntu-2204-template.qcow2"
TEMPLATE_ID=9000
STORAGE="local-lvm"
BRIDGE="vmbr0"

echo "📥 檢查映像檔..."
mkdir -p /var/lib/vz/template/iso
cd /var/lib/vz/template/iso
if [[ ! -f "$IMAGE_NAME" ]]; then
  echo "⬇️ 下載 $IMAGE_NAME ..."
  wget -O "$IMAGE_NAME" "$IMAGE_URL"
else
  echo "✅ 映像已存在，跳過下載"
fi

echo "💿 匯入映像到 Proxmox..."
qm destroy $TEMPLATE_ID --purge || true
qm create $TEMPLATE_ID --name ubuntu-template --memory 2048 --cores 2 --net0 virtio,bridge=$BRIDGE --ostype l26
qm importdisk $TEMPLATE_ID "$IMAGE_NAME" $STORAGE
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$TEMPLATE_ID-disk-0
qm set $TEMPLATE_ID --boot c --bootdisk scsi0
qm set $TEMPLATE_ID --ide2 $STORAGE:cloudinit
qm set $TEMPLATE_ID --serial0 socket --vga serial0

echo "📌 設定為模板..."
qm set $TEMPLATE_ID --ciuser ubuntu
qm template $TEMPLATE_ID

echo "✅ 建立完成！TEMPLATE_ID=$TEMPLATE_ID"
