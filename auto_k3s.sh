#!/bin/bash
# auto_k3s.sh
# 用於 Proxmox VE 自動部署 K3s Master + Worker 節點

set -e

TEMPLATE_ID=9000
STORAGE="local-lvm"
BRIDGE="vmbr0"
WORKDIR="/var/lib/vz/template/iso/k3s-images"
QCOW2_IMG="$WORKDIR/ubuntu-24.04-cloudimg.qcow2"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"

# ⏱️ 進度顯示器
progress() {
  echo -e "\n========== $1 ==========\n"
}

# 1️⃣ 準備映像檔
progress "準備 Ubuntu Cloud Image"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [[ ! -f "$QCOW2_IMG" ]]; then
  wget -O ubuntu.img "$IMG_URL"
  qemu-img convert -O qcow2 ubuntu.img "$QCOW2_IMG"
  rm -f ubuntu.img
fi

# 2️⃣ 建立 Template
progress "建立 Template (VMID=$TEMPLATE_ID)"
qm destroy $TEMPLATE_ID --purge || true
qm create $TEMPLATE_ID --name ubuntu-k3s-template --memory 2048 --cores 2 \
  --net0 virtio,bridge=$BRIDGE --ostype l26 --scsihw virtio-scsi-pci \
  --agent enabled=1 --machine q35
qm importdisk $TEMPLATE_ID "$QCOW2_IMG" "$STORAGE"
qm set $TEMPLATE_ID --scsi0 "$STORAGE:vm-$TEMPLATE_ID-disk-0" --boot order=scsi0
qm set $TEMPLATE_ID --ide2 "$STORAGE:cloudinit" --serial0 socket --vga serial0
qm template $TEMPLATE_ID

# 3️⃣ 建立 k3s-master
progress "建立 k3s-master"
VMID_MASTER=9100
qm clone $TEMPLATE_ID $VMID_MASTER --name k3s-master
qm set $VMID_MASTER --memory 2048 --cores 2 \
  --net0 virtio,bridge=$BRIDGE \
  --ipconfig0 ip=dhcp --ciuser ubuntu --cipassword ubuntu
qm set $VMID_MASTER --cicustom "user=local-lvm:snippets/k3s-master.yml"

# 產生 Cloud-Init Snippet for master
cat <<EOF > /tmp/k3s-master.yml
#cloud-config
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh-authorized-keys:
      - $(cat ~/.ssh/id_rsa.pub)
runcmd:
  - apt-get update
  - apt-get install -y curl
  - curl -sfL https://get.k3s.io | sh -
EOF

pvesm set $STORAGE --content snippets
pvesm upload /tmp/k3s-master.yml "$STORAGE:snippets/k3s-master.yml"
qm start $VMID_MASTER
sleep 30

# 4️⃣ 抓取 Master IP 和 TOKEN
progress "等待 master 啟動並取得 token"
IP_MASTER=$(qm guest exec $VMID_MASTER -- ip -4 addr show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1)
TOKEN=$(qm guest exec $VMID_MASTER -- sudo cat /var/lib/rancher/k3s/server/node-token | tail -n1)

echo "📡 Master IP   : $IP_MASTER"
echo "🔑 K3S Token   : $TOKEN"

# 5️⃣ 建立 worker snippet
cat <<EOF > /tmp/k3s-worker.yml
#cloud-config
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh-authorized-keys:
      - $(cat ~/.ssh/id_rsa.pub)
runcmd:
  - apt-get update
  - apt-get install -y curl
  - curl -sfL https://get.k3s.io | K3S_URL=https://$IP_MASTER:6443 K3S_TOKEN=$TOKEN sh -
EOF

pvesm upload /tmp/k3s-worker.yml "$STORAGE:snippets/k3s-worker.yml"

# 6️⃣ 建立 k3s-worker
progress "建立 k3s-worker-1"
VMID_WORKER=9101
qm clone $TEMPLATE_ID $VMID_WORKER --name k3s-worker-1
qm set $VMID_WORKER --memory 2048 --cores 2 \
  --net0 virtio,bridge=$BRIDGE \
  --ipconfig0 ip=dhcp --ciuser ubuntu --cipassword ubuntu
qm set $VMID_WORKER --cicustom "user=local-lvm:snippets/k3s-worker.yml"
qm start $VMID_WORKER

# ✅ 完成
progress "✅ K3s Cluster 建立完成"
echo "Master: $IP_MASTER"
