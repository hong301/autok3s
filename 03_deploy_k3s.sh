#!/bin/bash
# Proxmox 自動化 K3s 部署腳本 - 支援單一和批次建立

set -e

source $(dirname "$0")/config.sh

# 預設參數
TEMPLATE_ID=9000
MODE="single"  # single 或 batch
START_ID=100
COUNT=1
BASE_NAME="k3s-node"

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

# 清理函數
cleanup_failed_vm() {
    local vm_id=$1
    echo "[INFO] 清理失敗的 VM $vm_id..."
    qm stop $vm_id &>/dev/null || true
    sleep 2
    qm destroy $vm_id &>/dev/null || true
    rm -f k3s-user-data-${vm_id}.yaml
    rm -f /var/lib/vz/snippets/k3s-user-data-${vm_id}.yaml
}

# 取得 VM IP 的函數
get_vm_ip() {
    local vm_id=$1
    local timeout=60
    local elapsed=0
    
    echo "等待 VM $vm_id 取得 IP 位址..."
    
    while [[ $elapsed -lt $timeout ]]; do
        # 使用 qm guest cmd 取得 IP
        if qm guest cmd $vm_id network-get-interfaces 2>/dev/null | grep -q "ip-address"; then
            local ip=$(qm guest cmd $vm_id network-get-interfaces 2>/dev/null | \
                      jq -r '.[] | select(.name != "lo") | ."ip-addresses"[]? | select(."ip-address-type" == "ipv4") | ."ip-address"' 2>/dev/null | \
                      grep -v "127.0.0.1" | head -1)
            
            if [[ -n "$ip" && "$ip" != "null" ]]; then
                echo "[INFO] VM $vm_id IP: $ip"
                return 0
            fi
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    
    echo ""
    echo "[WARNING] 無法取得 VM $vm_id 的 IP 位址"
    return 1
}

# 顯示使用說明
show_help() {
    echo "用法: $0 [選項]"
    echo "選項:"
    echo "  -m, --mode MODE        模式: single(單一) 或 batch(批次) [預設: single]"
    echo "  -i, --start-id ID      起始 VM ID [預設: 100]"
    echo "  -c, --count COUNT      批次建立數量 [預設: 1]"
    echo "  -n, --name NAME        VM 名稱前綴 [預設: k3s-node]"
    echo "  -t, --template ID      範本 ID [預設: 9000]"
    echo "  -h, --help             顯示此說明"
    echo ""
    echo "範例:"
    echo "  $0 -m single -i 100 -n k3s-master    # 建立單一 VM (ID: 100)"
    echo "  $0 -m batch -i 101 -c 3 -n k3s-worker  # 批次建立 3 台 VM (ID: 101-103)"
}

# 處理命令列參數
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -i|--start-id)
            START_ID="$2"
            shift 2
            ;;
        -c|--count)
            COUNT="$2"
            shift 2
            ;;
        -n|--name)
            BASE_NAME="$2"
            shift 2
            ;;
        -t|--template)
            TEMPLATE_ID="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "未知選項: $1"
            show_help
            exit 1
            ;;
    esac
done

# 建立單一 VM 的函數
create_vm() {
    local vm_id=$1
    local vm_name=$2
    local node_type=$3  # master 或 worker
    
    echo "正在建立 VM $vm_id ($vm_name) - $node_type 節點..."
    
    # 防呆：檢查 VM ID 是否已被使用
    if qm status $vm_id &>/dev/null; then
        echo "[ERROR] VM ID $vm_id 已被使用"
        echo "[INFO] 請選擇不同的 VM ID 或刪除現有 VM: qm destroy $vm_id"
        return 1
    fi
    
    # 防呆：檢查 snippets 目錄
    if [[ ! -d "/var/lib/vz/snippets" ]]; then
        echo "[INFO] 建立 snippets 目錄"
        mkdir -p /var/lib/vz/snippets
    fi
    
    # 1. Clone from template
    echo "從範本 $TEMPLATE_ID 複製 VM..."
    if ! qm clone $TEMPLATE_ID $vm_id --name $vm_name --full; then
        echo "[ERROR] 複製範本失敗"
        return 1
    fi
    
    # 2. 設定網路、cloud-init 參數
    echo "設定 VM 參數..."
    if ! qm set $vm_id --net0 virtio,bridge=$NET_BRIDGE; then
        echo "[ERROR] 設定網路失敗"
        cleanup_failed_vm $vm_id
        return 1
    fi
    
    if ! qm set $vm_id --ciuser $CIUSER --cipassword $CIPASSWORD --ipconfig0 ip=dhcp; then
        echo "[ERROR] 設定 Cloud-Init 參數失敗"
        cleanup_failed_vm $vm_id
        return 1
    fi
    
    if ! qm set $vm_id --hostname $vm_name; then
        echo "[ERROR] 設定主機名稱失敗"
        cleanup_failed_vm $vm_id
        return 1
    fi
    
    # 啟用 QEMU Guest Agent
    qm set $vm_id --agent enabled=1
    
    # 3. 設定 cloud-init 自動安裝 K3s
    if [[ "$node_type" == "master" ]]; then
        # Master 節點配置
        cat > k3s-user-data-${vm_id}.yaml <<EOF
#cloud-config
package_update: true
package_upgrade: true
packages:
  - curl
  - snapd
  - qemu-guest-agent
  - jq
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
  - mkdir -p /home/ubuntu/.kube
  - cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
  - chown ubuntu:ubuntu /home/ubuntu/.kube/config
  - sleep 30
  - export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  - kubectl create namespace cert-manager || true
  - kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml || true
  - snap install helm --classic
  - helm repo add jetstack https://charts.jetstack.io
  - helm repo add elk https://helm.elastic.co
  - helm repo update
  - helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace || true
  - echo "K3s Master installation completed" > /tmp/k3s-install-status
  - echo "Node token: \$(cat /var/lib/rancher/k3s/server/node-token)" >> /tmp/k3s-install-status
write_files:
  - path: /tmp/get-join-command.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      echo "curl -sfL https://get.k3s.io | K3S_URL=https://\$(hostname -I | awk '{print \$1}'):6443 K3S_TOKEN=\$(cat /var/lib/rancher/k3s/server/node-token) sh -"
EOF
    else
        # Worker 節點配置 (需要手動加入叢集)
        cat > k3s-user-data-${vm_id}.yaml <<EOF
#cloud-config
package_update: true
package_upgrade: true
packages:
  - curl
  - snapd
  - qemu-guest-agent
  - jq
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  - echo "K3s Worker node ready for manual join" > /tmp/k3s-install-status
  - echo "Run join command from master node" >> /tmp/k3s-install-status
write_files:
  - path: /tmp/join-cluster.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      # This script will be used to join the worker to the cluster
      # Usage: ./join-cluster.sh <MASTER_IP> <TOKEN>
      if [ \$# -ne 2 ]; then
          echo "Usage: \$0 <MASTER_IP> <TOKEN>"
          exit 1
      fi
      MASTER_IP=\$1
      TOKEN=\$2
      curl -sfL https://get.k3s.io | K3S_URL=https://\${MASTER_IP}:6443 K3S_TOKEN=\${TOKEN} sh -
EOF
    fi

    # 將 user-data 複製到 snippets 目錄
    if ! cp k3s-user-data-${vm_id}.yaml /var/lib/vz/snippets/; then
        echo "[ERROR] 複製 user-data 失敗"
        rm -f k3s-user-data-${vm_id}.yaml
        cleanup_failed_vm $vm_id
        return 1
    fi
    
    if ! qm set $vm_id --cicustom "user=local:snippets/k3s-user-data-${vm_id}.yaml"; then
        echo "[ERROR] 設定 Cloud-Init 自訂檔案失敗"
        rm -f k3s-user-data-${vm_id}.yaml
        rm -f /var/lib/vz/snippets/k3s-user-data-${vm_id}.yaml
        cleanup_failed_vm $vm_id
        return 1
    fi
    
    # 清理本地的 user-data 檔案
    rm -f k3s-user-data-${vm_id}.yaml
    
    # 4. 啟動新 VM
    echo "啟動 VM $vm_id..."
    if ! qm start $vm_id; then
        echo "[ERROR] 啟動 VM 失敗"
        cleanup_failed_vm $vm_id
        return 1
    fi
    
    # 等待 VM 啟動並取得 IP
    sleep 10
    get_vm_ip $vm_id
    
    echo "[SUCCESS] VM $vm_id ($vm_name) 已建立並啟動。"
    return 0
}

# 檢查範本是否存在
if ! qm status $TEMPLATE_ID &>/dev/null; then
    echo "[ERROR] 範本 VM $TEMPLATE_ID 不存在，請先執行 02_create_template.sh 建立範本。"
    exit 1
fi

# 防呆：檢查範本是否真的是範本
if ! qm config $TEMPLATE_ID | grep -q "template: 1"; then
    echo "[ERROR] VM $TEMPLATE_ID 存在但不是範本"
    echo "[INFO] 請刪除 VM $TEMPLATE_ID 並重新執行 02_create_template.sh"
    exit 1
fi

# 防呆：驗證參數
if [[ $START_ID -lt 100 || $START_ID -gt 999999 ]]; then
    echo "[ERROR] VM ID 必須在 100-999999 範圍內"
    exit 1
fi

if [[ $COUNT -lt 1 || $COUNT -gt 50 ]]; then
    echo "[ERROR] VM 數量必須在 1-50 範圍內"
    exit 1
fi

# 防呆：檢查批次建立時的 ID 範圍
if [[ "$MODE" == "batch" ]]; then
    END_ID=$((START_ID + COUNT - 1))
    if [[ $END_ID -gt 999999 ]]; then
        echo "[ERROR] VM ID 範圍超出限制 (最大: 999999)"
        echo "[INFO] 建議的起始 ID: $((999999 - COUNT + 1))"
        exit 1
    fi
    
    # 檢查是否有 ID 衝突
    for i in $(seq $START_ID $END_ID); do
        if qm status $i &>/dev/null; then
            echo "[ERROR] VM ID $i 已被使用"
            echo "[INFO] 請選擇不同的起始 ID 或刪除衝突的 VM"
            exit 1
        fi
    done
fi

# 根據模式執行
case $MODE in
    single)
        # 判斷是否為 master 節點
        if [[ "$BASE_NAME" == *"master"* ]]; then
            NODE_TYPE="master"
        else
            NODE_TYPE="worker"
        fi
        
        VM_NAME="${BASE_NAME}"
        if create_vm $START_ID $VM_NAME $NODE_TYPE; then
            echo "[SUCCESS] 單一 VM 部署完成！"
            if [[ "$NODE_TYPE" == "master" ]]; then
                echo ""
                echo "🎉 K3s Master 節點部署完成！"
                echo "等待 2-3 分鐘讓 K3s 完成安裝，然後："
                echo "1. 取得節點 token: ssh ubuntu@<VM_IP> 'sudo cat /var/lib/rancher/k3s/server/node-token'"
                echo "2. 檢查叢集狀態: ssh ubuntu@<VM_IP> 'kubectl get nodes'"
            else
                echo ""
                echo "📝 K3s Worker 節點已準備就緒！"
                echo "要加入叢集，請在此 VM 中執行:"
                echo "ssh ubuntu@<VM_IP> 'sudo /tmp/join-cluster.sh <MASTER_IP> <TOKEN>'"
            fi
        else
            exit 1
        fi
        ;;
    batch)
        echo "開始批次建立 $COUNT 台 VM..."
        CREATED_VMS=()
        FAILED=false
        
        for i in $(seq 1 $COUNT); do
            vm_id=$((START_ID + i - 1))
            vm_name="${BASE_NAME}-${i}"
            
            # 第一台設為 master，其餘為 worker
            if [[ $i -eq 1 ]]; then
                NODE_TYPE="master"
            else
                NODE_TYPE="worker"
            fi
            
            if create_vm $vm_id $vm_name $NODE_TYPE; then
                CREATED_VMS+=($vm_id)
                echo "[SUCCESS] VM $vm_id ($NODE_TYPE) 建立成功"
            else
                echo "[ERROR] VM $vm_id 建立失敗"
                FAILED=true
                break
            fi
            
            # 等待 5 秒再建立下一台
            if [[ $i -lt $COUNT ]]; then
                sleep 5
            fi
        done
        
        if [[ "$FAILED" == "true" ]]; then
            echo "[WARNING] 部分 VM 建立失敗"
            echo "[INFO] 已成功建立的 VM: ${CREATED_VMS[*]}"
            exit 1
        else
            echo ""
            echo "🎉 批次部署完成！已建立 $COUNT 台 VM (ID: $START_ID - $((START_ID + COUNT - 1)))"
            echo ""
            echo "📋 後續步驟:"
            echo "1. 等待 3-5 分鐘讓所有 VM 完成初始化"
            echo "2. Master 節點 (${CREATED_VMS[0]}) 會自動安裝 K3s"
            echo "3. Worker 節點需要手動加入叢集"
            echo ""
            echo "🔧 加入 Worker 節點的步驟:"
            echo "# 在 Master 節點取得 token"
            echo "ssh ubuntu@<MASTER_IP> 'sudo cat /var/lib/rancher/k3s/server/node-token'"
            echo ""
            echo "# 在每個 Worker 節點執行"
            for ((j=2; j<=COUNT; j++)); do
                worker_id=$((START_ID + j - 1))
                echo "ssh ubuntu@<WORKER_${j}_IP> 'sudo /tmp/join-cluster.sh <MASTER_IP> <TOKEN>'"
            done
        fi
        ;;
    *)
        echo "[ERROR] 不支援的模式: $MODE"
        show_help
        exit 1
        ;;
esac

echo ""
echo "💡 提示："
echo "- 使用 'qm list' 查看所有 VM"
echo "- 使用 'qm guest cmd <VM_ID> network-get-interfaces' 取得 VM IP"
echo "- SSH 登入資訊: ubuntu / $CIPASSWORD"
