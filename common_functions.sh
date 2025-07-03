#!/bin/bash
# common_functions.sh - 共用函數庫，消除重複程式碼

# 共用設定變數
TEMPLATE_ID=9000
STORAGE="local-lvm"
BRIDGE="vmbr0"
ISO_DIR="/var/lib/vz/template/iso"

# 檢查必要工具
check_required_tools() {
  if ! command -v jq &> /dev/null; then
    echo "❌ jq 未安裝，請先安裝 jq 工具"
    exit 1
  fi
}

# 下載 Ubuntu Cloud Image
download_ubuntu_image() {
  local image_url=$1
  local save_path=$2
  local image_name=$(basename "$save_path")
  
  echo "📥 檢查映像檔..."
  mkdir -p "$(dirname "$save_path")"
  
  if [[ -f "$save_path" ]]; then
    echo "✅ 映像已存在，跳過下載: $image_name"
    return 0
  fi
  
  echo "⬇️ 下載 $image_name ..."
  wget -O "$save_path" "$image_url"
  
  echo "✅ 下載完成：$save_path"
  # 檢查檔案大小是否合理
  if [[ ! -s "$save_path" ]]; then
    echo "❌ 下載的檔案大小為 0，請檢查網路連線或 URL 是否正確"
    exit 1
  fi
}

# 根據 VM 名稱查詢 IP
get_ip_by_name() {
  local name=$1
  local vmid
  vmid=$(qm list | awk -v name="$name" '$0 ~ name {print $1}')
  [[ -z "$vmid" ]] && echo "" && return
  qm guest cmd "$vmid" network-get-interfaces \
    | jq -r '.[] | select(.name=="ens18") | .["ip-addresses"][]? | select(.["ip-address"] | test("^10\\.110\\.")) | .["ip-address"]' | head -n1
}

# 根據 VMID 查詢 IP
get_ip_by_vmid() {
  local vmid=$1
  qm guest cmd "$vmid" network-get-interfaces \
    | jq -r '.[] | select(.name=="ens18") | .["ip-addresses"][]? | select(.["ip-address"] | test("^10\\.110\\.")) | .["ip-address"]' | head -n1
}

# 建立基礎 VM Template
create_vm_template() {
  local template_id=$1
  local template_name=$2
  local image_path=$3
  local memory=${4:-2048}
  local cores=${5:-2}
  
  echo "💿 匯入映像到 Proxmox..."
  qm destroy "$template_id" --purge || true
  qm create "$template_id" --name "$template_name" --memory "$memory" --cores "$cores" --net0 virtio,bridge=$BRIDGE --ostype l26
  qm importdisk "$template_id" "$image_path" "$STORAGE"
  qm set "$template_id" --scsihw virtio-scsi-pci --scsi0 "$STORAGE:vm-$template_id-disk-0"
  qm set "$template_id" --boot c --bootdisk scsi0
  qm set "$template_id" --ide2 "$STORAGE:cloudinit"
  qm set "$template_id" --serial0 socket --vga serial0
  qm set "$template_id" --agent enabled=1
  
  echo "📌 設定為模板..."
  qm template "$template_id"
  
  echo "✅ 模板建立完成！TEMPLATE_ID=$template_id"
}

# SSH 連線執行指令
ssh_exec() {
  local ip=$1
  local user=${2:-ubuntu}
  shift 2
  ssh -o StrictHostKeyChecking=no "$user@$ip" "$@"
}

# 進度顯示函數
progress() {
  echo -e "\n🟩 $1"
}

# 等待 VM 啟動並取得 IP
wait_for_vm_ip() {
  local vmid=$1
  local timeout=${2:-300}  # 預設等待 5 分鐘
  local counter=0
  
  echo "⏳ 等待 VM $vmid 取得 IP 位址..."
  while [[ $counter -lt $timeout ]]; do
    local ip=$(get_ip_by_vmid "$vmid")
    if [[ -n "$ip" ]]; then
      echo "✅ VM $vmid IP: $ip"
      echo "$ip"
      return 0
    fi
    sleep 5
    ((counter += 5))
  done
  
  echo "❌ VM $vmid 在 $timeout 秒內未取得 IP"
  return 1
}
