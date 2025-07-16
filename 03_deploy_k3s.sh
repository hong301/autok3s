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
    echo "[進度 1/6] 從範本 $TEMPLATE_ID 複製 VM..."
    if ! qm clone $TEMPLATE_ID $vm_id --name $vm_name --full; then
        echo "[ERROR] 複製範本失敗"
        return 1
    fi
    echo "[SUCCESS] VM 複製完成"
    
    # 2. 依節點類型升級硬體配置
    echo "[進度 2/6] 設定硬體配置..."
    if [[ "$node_type" == "master" ]]; then
        echo "升級 Master 硬體配置 (CPU: 4, 記憶體: 4GB, 磁碟: 20GB)..."
        if ! qm set $vm_id --cores 4 --memory 4096; then
            echo "[ERROR] 設定 Master CPU 和記憶體失敗"
            cleanup_failed_vm $vm_id
            return 1
        fi
        DISK_EXPAND="+18G"  # 擴展到 20GB
        echo "[SUCCESS] Master 硬體配置完成"
        
        # ELK Stack 配置 (預留，暫時註解)
        # echo "升級 Master 硬體配置 (CPU: 4, 記憶體: 8GB, 磁碟: 30GB) - 適合 ELK Stack..."
        # if ! qm set $vm_id --cores 4 --memory 8192; then
        #     echo "[ERROR] 設定 Master CPU 和記憶體失敗"
        #     cleanup_failed_vm $vm_id
        #     return 1
        # fi
        # DISK_EXPAND="+28G"  # 擴展到 30GB
    else
        echo "升級 Worker 硬體配置 (CPU: 2, 記憶體: 2GB, 磁碟: 15GB)..."
        if ! qm set $vm_id --cores 2 --memory 2048; then
            echo "[ERROR] 設定 Worker CPU 和記憶體失敗"
            cleanup_failed_vm $vm_id
            return 1
        fi
        DISK_EXPAND="+13G"  # 擴展到 15GB
        echo "[SUCCESS] Worker 硬體配置完成"
    fi
    
    # 擴展磁碟空間
    echo "[進度 3/6] 擴展磁碟空間..."
    if ! qm disk resize $vm_id scsi0 $DISK_EXPAND; then
        echo "[WARNING] 磁碟擴展失敗，繼續使用預設大小"
    else
        echo "[SUCCESS] 磁碟擴展完成"
    fi
    
    # 3. 設定網路、cloud-init 參數
    echo "[進度 4/6] 設定 VM 網路參數..."
    if ! qm set $vm_id --net0 virtio,bridge=$NET_BRIDGE; then
        echo "[ERROR] 設定網路失敗"
        cleanup_failed_vm $vm_id
        return 1
    fi
    echo "[SUCCESS] 網路設定完成"
    
    # 清除可能的舊 ciuser/cipassword 設定，使用 Cloud-Init YAML 完全控制
    echo "清除舊的 Cloud-Init 設定..."
    qm set $vm_id --delete ciuser,cipassword 2>/dev/null || true
    
    if ! qm set $vm_id --ipconfig0 ip=dhcp; then
        echo "[ERROR] 設定 Cloud-Init 參數失敗"
        cleanup_failed_vm $vm_id
        return 1
    fi
    echo "[SUCCESS] Cloud-Init 基本設定完成"
    
    # 啟用 QEMU Guest Agent
    echo "啟用 QEMU Guest Agent..."
    qm set $vm_id --agent enabled=1
    echo "[SUCCESS] Guest Agent 設定完成"
    
    # 3. 設定 cloud-init 自動安裝 K3s
    echo "[進度 5/6] 建立 Cloud-Init 配置檔案..."
    if [[ "$node_type" == "master" ]]; then
        # Master 節點配置 - 使用簡潔的 Cloud-Init YAML
        cat > k3s-user-data-${vm_id}.yaml <<EOF
#cloud-config
hostname: $vm_name
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    plain_text_passwd: "Password"
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDfWp/8zoAlxO4N8fUnXoknIltAZk35so+JRcB+G95Z00NllcGKJT4ViRhaKX+Y728/abqu9y7twx/ywRGUnce9JqL+L1acv3aiKVcQDn2b5TyyZ73roU7KG3J3c3eGIKQ+dSO1/Ya498KPIh8grQMAjBYXBtBTqsFhOFxjacVCzKnS1QX0Rs8ryfyNB8L8B7rcoD5gB/WmMxuUINZAc6nZaN/4gbonb7FALNDt/FN916qu6wikA5/8rj2Iml09X6PDptPD6N8FBsZSzRas5NPpBt0++4zKmVyUAL2OatIvcnUIL16lREezFq6ENDsZGsM+tGL05pU+1AvLMeZmdp86isd7Zr71Y6wq4GD9L75PuyKyIhTBVHQ25mMgH/0Fduqr2n6ebEjZUsis/hkZMl0etvvwwnKQP10fm5sQFEkAxYw10xzeCtivQhvAdekeHmcDAFMgWiTj0ELfmyMEr/Xdot9bo3fC1FdkiZVXQT2WVAbgB15RHUKK2joMiA4gLmEuJ4ltCFSHC2ovCco58KbN93saM9LUw1Gt+Kb6gAmzz+zLBq7fc1/QET3dk6WhwnrkGBxGHZ9QYfZnP+AFHZywQq7gM+Yd0/ixipQJKGfraxFPBCX5yKuMBJenOtg9GQj+s3jZsOv3NMIX1JMrM7EjNxyYC8ovJSaRqHNjn5KPNw== root@devops

# 強制啟用密碼和密鑰雙重認證
ssh_pwauth: true

chpasswd:
  expire: false

package_update: true
packages:
  - curl
  - qemu-guest-agent
  - jq
  - htop

runcmd:
  # 建立 SSH 配置覆蓋目錄並強制啟用密碼驗證
  - mkdir -p /etc/ssh/sshd_config.d
  - echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/99-enable-password-auth.conf
  - echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config.d/99-enable-password-auth.conf
  - echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config.d/99-enable-password-auth.conf
  - echo 'UsePAM yes' >> /etc/ssh/sshd_config.d/99-enable-password-auth.conf
  # 額外的 SSH 配置修改（雙重保險）
  - sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
  - sed -i 's/^PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  # 重啟 SSH 服務並檢查狀態
  - systemctl restart ssh
  - sleep 5
  - systemctl status ssh --no-pager
  # 驗證 SSH 配置
  - sshd -T | grep -i passwordauthentication
  - echo "SSH Password Authentication Status:" > /tmp/ssh-config-status
  - sshd -T | grep -i passwordauthentication >> /tmp/ssh-config-status
  # 啟用 Guest Agent
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  # 擴展磁碟
  - resize2fs /dev/sda1 || true
  # 安裝 K3s
  - curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
  # 等待 K3s 服務完全啟動
  - sleep 30
  # 啟用並立即啟動 k3s-setup 服務
  - systemctl enable k3s-setup
  - systemctl start k3s-setup

write_files:
  - path: /tmp/get-join-command.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      echo "curl -sfL https://get.k3s.io | K3S_URL=https://\$(hostname -I | awk '{print \$1}'):6443 K3S_TOKEN=\$(cat /var/lib/rancher/k3s/server/node-token) sh -"
  - path: /etc/systemd/system/k3s-setup.service
    permissions: '0644'
    content: |
      [Unit]
      Description=K3s Post-Installation Setup
      After=k3s.service
      Wants=k3s.service
      
      [Service]
      Type=oneshot
      RemainAfterExit=yes
      ExecStart=/opt/k3s-setup.sh
      User=root
      
      [Install]
      WantedBy=multi-user.target
  - path: /opt/k3s-setup.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      echo "Starting K3s post-installation setup..." > /tmp/k3s-setup.log
      
      # 等待 K3s 服務完全啟動
      for i in {1..60}; do
        if systemctl is-active --quiet k3s && [ -f /etc/rancher/k3s/k3s.yaml ]; then
          echo "K3s service is ready" >> /tmp/k3s-setup.log
          break
        fi
        echo "Waiting for K3s to be ready... ($i/60)" >> /tmp/k3s-setup.log
        sleep 5
      done
      
      # 檢查 K3s 是否真的準備好了
      if ! systemctl is-active --quiet k3s || [ ! -f /etc/rancher/k3s/k3s.yaml ]; then
        echo "ERROR: K3s failed to start properly" >> /tmp/k3s-setup.log
        exit 1
      fi
      
      # 設定 kubectl 配置給 ubuntu 使用者
      mkdir -p /home/ubuntu/.kube
      cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
      chown ubuntu:ubuntu /home/ubuntu/.kube/config
      echo "kubectl config copied" >> /tmp/k3s-setup.log
      
      # 等待 K3s API 可用
      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
      for i in {1..30}; do
        if kubectl get nodes &>/dev/null; then
          echo "K3s API is ready" >> /tmp/k3s-setup.log
          break
        fi
        echo "Waiting for K3s API... ($i/30)" >> /tmp/k3s-setup.log
        sleep 10
      done
      
      # 安裝 Helm
      if ! command -v helm &> /dev/null; then
        snap install helm --classic
        echo "Helm installed" >> /tmp/k3s-setup.log
      fi
      
      # 基礎設定
      kubectl create namespace cert-manager || true
      kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml || true
      
      # 設定 Helm repositories
      helm repo add jetstack https://charts.jetstack.io || true
      helm repo update || true
      echo "Helm repositories configured" >> /tmp/k3s-setup.log
      
      # 安裝 cert-manager
      helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace || true
      echo "cert-manager installation attempted" >> /tmp/k3s-setup.log
      
      # 記錄完成狀態
      echo "K3s Master installation completed" > /tmp/k3s-install-status
      if [ -f /var/lib/rancher/k3s/server/node-token ]; then
        echo "Node token: $(cat /var/lib/rancher/k3s/server/node-token)" >> /tmp/k3s-install-status
      fi
      echo "Setup completed at $(date)" >> /tmp/k3s-setup.log
EOF

# ELK Stack 配置 (預留，暫時註解)
# #cloud-config
# hostname: $vm_name
# package_update: true
# package_upgrade: true
# packages:
#   - curl
#   - snapd
#   - qemu-guest-agent
#   - jq
#   - htop
#   - git
#   - unzip
#   - wget
#   - apt-transport-https
#   - ca-certificates
#   - gnupg
#   - lsb-release
# runcmd:
#   - systemctl enable qemu-guest-agent
#   - systemctl start qemu-guest-agent
#   - resize2fs /dev/sda1 || true
#   # 優化系統參數for ELK Stack
#   - echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
#   - echo 'fs.file-max=65536' >> /etc/sysctl.conf
#   - sysctl -p
#   # 安裝 K3s
#   - curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
#   - mkdir -p /home/ubuntu/.kube
#   - cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
#   - chown ubuntu:ubuntu /home/ubuntu/.kube/config
#   - sleep 30
#   - export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
#   # 基礎設定
#   - kubectl create namespace cert-manager || true
#   - kubectl create namespace elk-stack || true
#   - kubectl create namespace logging || true
#   - kubectl create namespace monitoring || true
#   - kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml || true
#   # 安裝 Helm
#   - snap install helm --classic
#   - helm repo add jetstack https://charts.jetstack.io
#   - helm repo add elastic https://helm.elastic.co
#   - helm repo add fluent https://fluenbit.io/helm-charts
#   - helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#   - helm repo update
#   # 安裝 cert-manager (ELK 需要)
#   - helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace || true
#   # 創建 ELK 部署腳本
#   - mkdir -p /opt/k3s-elk
#   - echo "K3s Master installation completed" > /tmp/k3s-install-status
#   - echo "Node token: \$(cat /var/lib/rancher/k3s/server/node-token)" >> /tmp/k3s-install-status
#   - echo "ELK namespace created: elk-stack" >> /tmp/k3s-install-status
# write_files:
#   - path: /tmp/get-join-command.sh
#     permissions: '0755'
#     content: |
#       #!/bin/bash
#       echo "curl -sfL https://get.k3s.io | K3S_URL=https://\$(hostname -I | awk '{print \$1}'):6443 K3S_TOKEN=\$(cat /var/lib/rancher/k3s/server/node-token) sh -"
#   - path: /opt/k3s-elk/deploy-elk.sh
#     permissions: '0755'
#     content: |
#       #!/bin/bash
#       # K3s ELK Stack 部署腳本
#       [ELK deployment script content...]
#   - path: /opt/k3s-elk/elk-values.yaml
#     permissions: '0644'
#     content: |
#       # ELK Stack Helm Values
#       [ELK values content...]
# EOF
    else
        # Worker 節點配置 - 使用簡潔的 Cloud-Init YAML
        cat > k3s-user-data-${vm_id}.yaml <<EOF
#cloud-config
hostname: $vm_name
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    plain_text_passwd: "Password"
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDfWp/8zoAlxO4N8fUnXoknIltAZk35so+JRcB+G95Z00NllcGKJT4ViRhaKX+Y728/abqu9y7twx/ywRGUnce9JqL+L1acv3aiKVcQDn2b5TyyZ73roU7KG3J3c3eGIKQ+dSO1/Ya498KPIh8grQMAjBYXBtBTqsFhOFxjacVCzKnS1QX0Rs8ryfyNB8L8B7rcoD5gB/WmMxuUAL2OatIvcnUIL16lREezFq6ENDsZGsM+tGL05pU+1AvLMeZmdp86isd7Zr71Y6wq4GD9L75PuyKyIhTBVHQ25mMgH/0Fduqr2n6ebEjZUsis/hkZMl0etvvwwnKQP10fm5sQFEkAxYw10xzeCtivQhvAdekeHmcDAFMgWiTj0ELfmyMEr/Xdot9bo3fC1FdkiZVXQT2WVAbgB15RHUKK2joMiA4gLmEuJ4ltCFSHC2ovCco58KbN93saM9LUw1Gt+Kb6gAmzz+zLBq7fc1/QET3dk6WhwnrkGBxGHZ9QYfZnP+AFHZywQq7gM+Yd0/ixipQJKGfraxFPBCX5yKuMBJenOtg9GQj+s3jZsOv3NMIX1JMrM7EjNxyYC8ovJSaRqHNjn5KPNw== root@devops

# 強制啟用密碼驗證
ssh_pwauth: true

chpasswd:
  expire: false

package_update: true
packages:
  - curl
  - qemu-guest-agent
  - jq
  - htop

runcmd:
  # 建立 SSH 配置覆蓋目錄並強制啟用密碼驗證
  - mkdir -p /etc/ssh/sshd_config.d
  - echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/99-enable-password-auth.conf
  - echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config.d/99-enable-password-auth.conf
  - echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config.d/99-enable-password-auth.conf
  - echo 'UsePAM yes' >> /etc/ssh/sshd_config.d/99-enable-password-auth.conf
  # 額外的 SSH 配置修改（雙重保險）
  - sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
  - sed -i 's/^PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  # 重啟 SSH 服務並檢查狀態
  - systemctl restart ssh
  - sleep 5
  - systemctl status ssh --no-pager
  # 驗證 SSH 配置
  - sshd -T | grep -i passwordauthentication
  - echo "SSH Password Authentication Status:" > /tmp/ssh-config-status
  - sshd -T | grep -i passwordauthentication >> /tmp/ssh-config-status
  # 啟用 Guest Agent
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
  # 擴展磁碟
  - resize2fs /dev/sda1 || true
  # Worker 已準備就緒，等待加入叢集
  - echo "K3s Worker node ready for manual join" > /tmp/k3s-install-status
  - echo "Run join command from master node" >> /tmp/k3s-install-status
  - echo "SSH PasswordAuthentication enabled" >> /tmp/k3s-install-status

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
      echo "Worker joined cluster successfully."
EOF

# ELK 支援配置 (預留，暫時註解)
# #cloud-config
# hostname: $vm_name
# package_update: true
# package_upgrade: true
# packages:
#   - curl
#   - snapd
#   - qemu-guest-agent
#   - jq
#   - htop
#   - git
#   - unzip
#   - wget
# runcmd:
#   - systemctl enable qemu-guest-agent
#   - systemctl start qemu-guest-agent
#   - resize2fs /dev/sda1 || true
#   # 優化日誌相關設定
#   - echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
#   - sysctl -p
#   # 設定日誌輪轉
#   - echo '/var/log/*.log { daily rotate 7 compress delaycompress missingok notifempty create 644 root root }' > /etc/logrotate.d/custom
#   - echo "K3s Worker node ready for manual join" > /tmp/k3s-install-status
#   - echo "Run join command from master node" >> /tmp/k3s-install-status
#   - echo "Optimized for ELK logging" >> /tmp/k3s-install-status
# EOF
    fi

    # 將 user-data 複製到 snippets 目錄
    echo "複製 Cloud-Init 配置到 Proxmox snippets 目錄..."
    if ! cp k3s-user-data-${vm_id}.yaml /var/lib/vz/snippets/; then
        echo "[ERROR] 複製 user-data 失敗"
        rm -f k3s-user-data-${vm_id}.yaml
        cleanup_failed_vm $vm_id
        return 1
    fi
    echo "[SUCCESS] Cloud-Init 配置檔案複製完成"
    
    echo "設定 VM 使用自訂 Cloud-Init 配置..."
    if ! qm set $vm_id --cicustom "user=local:snippets/k3s-user-data-${vm_id}.yaml"; then
        echo "[ERROR] 設定 Cloud-Init 自訂檔案失敗"
        rm -f k3s-user-data-${vm_id}.yaml
        rm -f /var/lib/vz/snippets/k3s-user-data-${vm_id}.yaml
        cleanup_failed_vm $vm_id
        return 1
    fi
    echo "[SUCCESS] VM Cloud-Init 自訂配置設定完成"
    
    # 清理本地的 user-data 檔案
    rm -f k3s-user-data-${vm_id}.yaml
    
    # 4. 啟動新 VM（不等待完成）
    echo "[進度 6/6] 啟動 VM $vm_id..."
    if ! qm start $vm_id; then
        echo "[ERROR] 啟動 VM 失敗"
        cleanup_failed_vm $vm_id
        return 1
    fi
    
    echo "[SUCCESS] ✅ VM $vm_id ($vm_name) 已建立並啟動。"
    echo "[INFO] 🔄 VM 正在初始化，Cloud-Init 正在配置系統..."
    echo "[INFO] 📝 登入資訊: ssh ubuntu@<VM_IP> (密碼: Password)"
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
                echo "3. 檢查部署狀態: ./k3s-manager.sh status $START_ID"
            else
                echo ""
                echo "📝 K3s Worker 節點已準備就緒！"
                echo "要加入叢集，請在此 VM 中執行:"
                echo "ssh ubuntu@<VM_IP> 'sudo /tmp/join-cluster.sh <MASTER_IP> <TOKEN>'"
                echo "或使用管理工具: ./k3s-manager.sh join $START_ID <MASTER_ID>"
            fi
        else
            exit 1
        fi
        ;;
    batch)
        echo "開始批次建立 $COUNT 台 VM（並行部署）..."
        CREATED_VMS=()
        FAILED=false
        
        # 第一階段：快速建立所有 VM
        echo "第一階段：並行建立所有 VM..."
        for i in $(seq 1 $COUNT); do
            vm_id=$((START_ID + i - 1))
            vm_name="${BASE_NAME}-${i}"
            
            # 第一台設為 master，其餘為 worker
            if [[ $i -eq 1 ]]; then
                NODE_TYPE="master"
            else
                NODE_TYPE="worker"
            fi
            
            echo "[$i/$COUNT] 開始建立 VM $vm_id ($vm_name) - $NODE_TYPE 節點..."
            
            if create_vm $vm_id $vm_name $NODE_TYPE; then
                CREATED_VMS+=($vm_id)
                echo "✅ VM $vm_id ($NODE_TYPE) 建立成功"
            else
                echo "❌ VM $vm_id 建立失敗"
                FAILED=true
                break
            fi
            
            # 短暫延遲避免系統負載過高
            sleep 2
        done
        
        if [[ "$FAILED" == "true" ]]; then
            echo "[WARNING] 部分 VM 建立失敗"
            echo "[INFO] 已成功建立的 VM: ${CREATED_VMS[*]}"
            exit 1
        fi
        
        echo ""
        echo "🎉 批次部署完成！已建立 $COUNT 台 VM (ID: $START_ID - $((START_ID + COUNT - 1)))"
        echo "📊 硬體配置:"
        echo "   - Master: 4 CPU, 4GB RAM, 20GB 磁碟"
        echo "   - Worker: 2 CPU, 2GB RAM, 15GB 磁碟"
        echo ""
        
        # 第二階段：等待和檢查 VM 狀態
        echo "第二階段：等待 VM 初始化完成..."
        echo "正在等待所有 VM 啟動並取得 IP 地址..."
        
        # 等待 30 秒讓 VM 初始化
        for i in {1..30}; do
            echo -n "."
            sleep 1
        done
        echo ""
        
        # 嘗試取得所有 VM 的 IP
        echo "檢查 VM IP 地址："
        for vm_id in "${CREATED_VMS[@]}"; do
            echo -n "VM $vm_id: "
            if ip=$(qm guest cmd $vm_id network-get-interfaces 2>/dev/null | \
                    jq -r '.[] | select(.name != "lo") | ."ip-addresses"[]? | select(."ip-address-type" == "ipv4") | ."ip-address"' 2>/dev/null | \
                    grep -v "127.0.0.1" | head -1); then
                if [[ -n "$ip" && "$ip" != "null" ]]; then
                    echo "$ip"
                else
                    echo "等待中..."
                fi
            else
                echo "等待中..."
            fi
        done
        
        echo ""
        echo "📋 第三階段：自動配置完整 K3s 叢集..."
        echo "等待 Master 節點完成 K3s 安裝..."
        
        # 等待 Master 節點的 K3s 完全準備就緒
        MASTER_ID=${CREATED_VMS[0]}
        echo "等待 Master 節點 (VM $MASTER_ID) K3s 服務啟動..."
        
        # 等待更長時間讓 Master 節點完成初始化
        sleep 120  # 等待 2 分鐘
        
        # 檢查 Master 節點狀態並自動加入 Worker 節點
        echo "檢查 Master 節點狀態並自動加入 Worker 節點..."
        
        # 等待並自動加入所有 Worker 節點
        if [[ ${#CREATED_VMS[@]} -gt 1 ]]; then
            echo "開始自動加入 Worker 節點到叢集..."
            
            for ((j=2; j<=COUNT; j++)); do
                worker_id=$((START_ID + j - 1))
                echo "[$((j-1))/$((COUNT-1))] 自動加入 Worker 節點 VM $worker_id..."
                
                # 使用 k3s-manager 自動加入
                if ./k3s-manager.sh join $worker_id $MASTER_ID; then
                    echo "✅ Worker 節點 VM $worker_id 已成功加入叢集"
                else
                    echo "⚠️  Worker 節點 VM $worker_id 加入失敗，可稍後手動重試"
                fi
                
                # 短暫延遲
                sleep 10
            done
            
            echo ""
            echo "🎉 完整 K3s 叢集自動部署完成！"
            echo ""
            echo "📊 最終叢集狀態檢查："
            ./k3s-manager.sh list-nodes $MASTER_ID
        else
            echo "✅ 單節點 Master 部署完成！"
        fi
        
        echo ""
        echo "🛠️  如需手動管理叢集："
        for ((j=2; j<=COUNT; j++)); do
            worker_id=$((START_ID + j - 1))
            echo "./k3s-manager.sh join $worker_id $MASTER_ID  # 重新加入 Worker $worker_id"
        done
        echo "./k3s-manager.sh status $MASTER_ID            # 檢查 Master 狀態"
        echo "./k3s-manager.sh list-nodes $MASTER_ID        # 列出所有節點"
        echo ""
        echo "📊 如需部署 ELK Stack (未來功能)："
        echo "echo '等待 K3s 叢集穩定運行後，可考慮加入 ELK Stack 進行日誌管理'"
        # echo "ssh ubuntu@<MASTER_IP> 'sudo /opt/k3s-elk/deploy-elk.sh'"
        # echo ""
        # echo "🌐 ELK 存取方式："
        # echo "- Kibana: http://<MASTER_IP>:30601"
        # echo "- Elasticsearch: http://<MASTER_IP>:9200"
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
echo "- SSH 登入資訊: ubuntu / Password"
