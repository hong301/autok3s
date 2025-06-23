#!/bin/bash
# auto_k3s_cluster.sh - 自動部署 K3s Master + Worker 並在 Master 安裝 ELK (NodePort 暴露)

set -e

TEMPLATE_ID=9000
STORAGE="local-lvm"
BRIDGE="vmbr0"
WORKDIR="/var/lib/vz/template/iso/k3s-images"
QCOW2_IMG="$WORKDIR/ubuntu-24.04-cloudimg.qcow2"
IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"

VMID_MASTER=9100
VMID_WORKER=9101

progress() {
  echo -e "\n========== $1 =========="
}

# 1️⃣ 映像檔處理
progress "準備 Cloud Image"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [[ ! -f "$QCOW2_IMG" ]]; then
  wget -O ubuntu.img "$IMG_URL"
  qemu-img convert -O qcow2 ubuntu.img "$QCOW2_IMG"
  rm -f ubuntu.img
fi

# 2️⃣ 建立 Template
progress "建立 Template"
qm destroy $TEMPLATE_ID --purge || true
qm create $TEMPLATE_ID --name ubuntu-k3s-template --memory 2048 --cores 2 \
  --net0 virtio,bridge=$BRIDGE --ostype l26 --scsihw virtio-scsi-pci \
  --agent enabled=1 --machine q35
qm importdisk $TEMPLATE_ID "$QCOW2_IMG" "$STORAGE"
qm set $TEMPLATE_ID --scsi0 "$STORAGE:vm-$TEMPLATE_ID-disk-0" --boot order=scsi0
qm set $TEMPLATE_ID --ide2 "$STORAGE:cloudinit" --serial0 socket --vga serial0
qm template $TEMPLATE_ID

# 3️⃣ 建立 ELK + K3s master cloud-init
progress "準備 k3s-master.yml"
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
  - apt-get install -y curl gpg
  - curl -sfL https://get.k3s.io | sh -
  # 安裝 ELK Stack
  - curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic.gpg
  - echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" > /etc/apt/sources.list.d/elastic-8.x.list
  - apt-get update
  - apt-get install -y elasticsearch kibana filebeat metricbeat
  - echo "network.host: 0.0.0.0" >> /etc/elasticsearch/elasticsearch.yml
  - echo "server.host: \"0.0.0.0\"" >> /etc/kibana/kibana.yml
  - systemctl enable elasticsearch --now
  - systemctl enable kibana --now
  - systemctl enable filebeat --now
  - systemctl enable metricbeat --now
EOF

pvesm set $STORAGE --content snippets || true
pvesm upload /tmp/k3s-master.yml "$STORAGE:snippets/k3s-master.yml"

# 4️⃣ 建立 Master VM
progress "建立 k3s-master VM"
qm clone $TEMPLATE_ID $VMID_MASTER --name k3s-master
qm set $VMID_MASTER --memory 4096 --cores 2 \
  --net0 virtio,bridge=$BRIDGE \
  --ipconfig0 ip=dhcp --ciuser ubuntu --cipassword ubuntu \
  --cicustom "user=$STORAGE:snippets/k3s-master.yml"
qm start $VMID_MASTER

# ⏳ 等待啟動與 token 準備
sleep 40
TOKEN=$(qm guest exec $VMID_MASTER -- sudo cat /var/lib/rancher/k3s/server/node-token | tail -n1)
IP_MASTER=$(qm guest exec $VMID_MASTER -- ip -4 addr show eth0 | grep inet | awk '{print $2}' | cut -d/ -f1)

# 5️⃣ 建立 Worker YAML
progress "準備 k3s-worker.yml"
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

# 6️⃣ 建立 Worker VM
progress "建立 k3s-worker-1 VM"
qm clone $TEMPLATE_ID $VMID_WORKER --name k3s-worker-1
qm set $VMID_WORKER --memory 2048 --cores 2 \
  --net0 virtio,bridge=$BRIDGE \
  --ipconfig0 ip=dhcp --ciuser ubuntu --cipassword ubuntu \
  --cicustom "user=$STORAGE:snippets/k3s-worker.yml"
qm start $VMID_WORKER

# ✅ 完成
progress "✅ K3s + ELK 環境部署完成"
echo "Master IP : $IP_MASTER"
echo "Kibana    : http://$IP_MASTER:5601"
echo "Elastic   : http://$IP_MASTER:9200"
