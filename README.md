# Proxmox K3s 自動部署系統

這是一個完整的 Proxmox VE 環境下 K3s Kubernetes 叢集自動化部署解決方案，支援單一和批次部署模式，內建叢集管理和驗證工具。

> ⚡ **重要提醒**: 系統已配置強密碼 `FsI!^@#Zg` 和 SSH 金鑰雙重認證，部署後可使用 `ubuntu` 使用者登入所有節點。

## 📚 目錄

- [🚀 特色功能](#-特色功能)
- [📋 系統需求](#-系統需求)
- [📁 檔案結構](#-檔案結構)
- [⚙️ Proxmox VE 初始設定](#️-proxmox-ve-初始設定)
- [🚀 完整的 K3s 叢集部署流程](#-完整的-k3s-叢集部署流程)
- [🚀 快速開始 (一鍵部署)](#-快速開始-一鍵部署)
- [🏗️ 叢集架構設計](#️-叢集架構設計)
- [🔐 SSH 連線方式](#-ssh-連線方式)
- [🛠️ 管理工具](#️-管理工具)
- [📊 已安裝組件](#-已安裝組件)
- [🎯 使用範例](#-使用範例)
- [🔧 故障排除](#-故障排除)
- [📈 效能監控](#-效能監控)
- [🚨 安全性注意事項](#-安全性注意事項)
- [🔄 升級和維護](#-升級和維護)
- [📝 更新日誌](#-更新日誌)
- [📞 技術支援](#-技術支援)

## 🚀 特色功能

- **全自動化部署**: 從 Ubuntu Cloud Image 下載到 K3s 叢集建立，一鍵完成
- **智能範本管理**: 自動建立並管理 VM 範本 (包含 Cloud-Init 和 QEMU Guest Agent)
- **靈活的部署模式**: 支援單一節點或批次建立多節點叢集 (自動配置 Master + Workers)
- **完整的系統組件**: 預裝 K3s v1.32.6+k3s1, Helm v3.18.4, cert-manager v1.18.2
- **自動 SSH 配置**: 支援密碼和金鑰雙重認證，確保安全性和便利性
- **完整的錯誤處理**: 豐富的防呆機制和自動清理功能
- **叢集管理工具**: 內建狀態檢查、節點加入、部署驗證等管理功能
- **中文友善**: 全中文介面和錯誤提示

## 📋 系統需求

- **Proxmox VE 7.0+** (已測試 7.x 和 8.x)
- **最少 3GB 可用儲存空間** (用於下載 Ubuntu Cloud Image 和容器映像)
- **建議配置** (K3s 叢集):
  - Master 節點: 4 CPU, 4GB RAM, 20GB 磁碟
  - Worker 節點: 2 CPU, 2GB RAM, 15GB 磁碟
- **網路連接** (下載映像檔和 K3s 組件)
- **Root 權限** (所有腳本必須以 root 身份執行)

## 📁 檔案結構

```
autok3s/
├── config.sh                  # ⚙️ 中央配置檔案
├── 01_download_image.sh        # ⬇️ Ubuntu Cloud Image 下載器
├── 02_create_template.sh       # 📋 VM 範本建立器
├── 03_deploy_k3s.sh            # 🎯 主要部署腳本
├── k3s-manager.sh              # 🛠️ 叢集管理工具
├── verify_deployment.sh        # ✅ 部署驗證腳本
├── fix_deployment.sh           # 🔧 問題修復腳本
├── elk-config.sh.backup        # 📊 ELK Stack 配置檔案 (預留)
├── elk-manager.sh.backup       # 📊 ELK Stack 管理工具 (預留)
├── proxmox_host.pub           # 🔑 SSH 公鑰檔案
└── README.md                   # 📖 使用說明
```

## ⚙️ Proxmox VE 初始設定

### 1. Proxmox 系統準備

#### 檢查 Proxmox 版本和狀態
```bash
# 檢查 Proxmox 版本
pveversion

# 檢查節點狀態
pvecm status

# 檢查系統資源
free -h && df -h
```

#### 配置 Proxmox 儲存

```bash
# 檢查現有儲存
pvesm status

# 如需要，創建額外的 LVM 儲存
# (可選) 創建新的儲存池
# pvcreate /dev/sdX
# vgcreate data /dev/sdX
# pvesm add lvm data --vgname data --content images,vztmpl
```

#### 配置網路橋接

```bash
# 檢查現有網路配置
cat /etc/network/interfaces

# 檢查橋接狀態
ip link show
brctl show

# 如果需要創建額外的橋接網路，編輯網路配置
# nano /etc/network/interfaces
```

基本網路配置範例:
```bash
# /etc/network/interfaces
auto lo
iface lo inet loopback

auto ens18
iface ens18 inet manual

auto vmbr0
iface vmbr0 inet static
    address 192.168.1.100/24
    gateway 192.168.1.1
    bridge-ports ens18
    bridge-stp off
    bridge-fd 0
```

### 2. 準備 SSH 金鑰

```bash
# 檢查是否已有 SSH 金鑰
ls -la ~/.ssh/

# 如果沒有，生成新的 SSH 金鑰
ssh-keygen -t rsa -b 4096 -C "proxmox-k3s@$(hostname)"

# 複製公鑰到專案目錄
cp ~/.ssh/id_rsa.pub /root/PROXMOX/autok3s/proxmox_host.pub
```

### 3. 安裝必要工具

```bash
# 更新套件清單
apt update

# 安裝必要工具
apt install -y curl wget jq sshpass qemu-guest-agent

# 檢查工具版本
qm version
curl --version
jq --version
```

### 4. 編輯專案配置檔案

```bash
# 進入專案目錄
cd /root/PROXMOX/autok3s

# 編輯配置設定
nano config.sh
```

預設配置:
```bash
STORAGE="local-lvm"     # Proxmox 儲存名稱 (使用 pvesm status 查看)
NET_BRIDGE="vmbr0"      # 網路橋接名稱 (使用 ip link show 查看)
CIUSER="ubuntu"         # Cloud-Init 使用者名稱
CIPASSWORD="FsI!^@#Zg"  # Cloud-Init 密碼 (強密碼已設定)
```

### 5. 驗證 Proxmox 環境

```bash
# 檢查儲存空間
pvesm status | grep -E "(local|local-lvm)"

# 檢查網路橋接
brctl show | grep vmbr0

# 檢查可用資源
pvesh get /nodes/$(hostname)/status

# 測試 VM 操作權限
qm list
```

### 6. 防火牆設定 (如有啟用)

```bash
# 檢查防火牆狀態
pve-firewall status

# 如果防火牆啟用，確保允許必要端口
# 編輯叢集防火牆規則
# nano /etc/pve/firewall/cluster.fw

# 基本規則範例:
# [RULES]
# IN SSH(ACCEPT) -source +management
# IN 6443(ACCEPT) -comment "K3s API Server"
# IN 10250(ACCEPT) -comment "K3s Kubelet"
# IN 8472/udp(ACCEPT) -comment "K3s Flannel VXLAN"
```

## 🚀 完整的 K3s 叢集部署流程

### 第一階段：準備工作

#### 1. 下載 Ubuntu Cloud Image
```bash
# 下載最新的 Ubuntu 22.04 LTS Cloud Image
./01_download_image.sh

# 腳本會自動：
# - 下載 Ubuntu 22.04.5 LTS Cloud Image
# - 驗證檔案完整性
# - 將映像檔放置到 Proxmox 儲存中
```

#### 2. 建立 VM 範本
```bash
# 建立標準化的 VM 範本
./02_create_template.sh

# 腳本會自動：
# - 創建 VM ID 9000 作為範本
# - 配置基本硬體 (1 CPU, 2GB RAM, 2GB 磁碟)
# - 啟用 Cloud-Init 和 QEMU Guest Agent
# - 設定網路橋接
# - 將 VM 轉換為範本
```

### 第二階段：K3s 叢集部署

#### 方案 A：自動批次部署 (推薦)

```bash
# 一鍵部署完整叢集 (1 Master + 2 Workers)
./03_deploy_k3s.sh -m batch -i 100 -c 3 -n k3s-node

# 部署過程：
# 1. VM 100: k3s-node-1 (Master) - 4C/4G/20GB
# 2. VM 101: k3s-node-2 (Worker) - 2C/2G/15GB  
# 3. VM 102: k3s-node-3 (Worker) - 2C/2G/15GB
# 4. 自動安裝 K3s v1.32.6+k3s1
# 5. 自動配置 SSH 雙重認證
# 6. 自動加入 Worker 節點到叢集
# 7. 自動安裝 Helm v3.18.4
# 8. 自動部署 cert-manager v1.18.2
```

#### 方案 B：分步部署

```bash
# 步驟 1: 建立 Master 節點
./03_deploy_k3s.sh -m single -i 100 -n k3s-master

# 等待 Master 節點完成初始化 (約 3-5 分鐘)

# 步驟 2: 建立 Worker 節點
./03_deploy_k3s.sh -m single -i 101 -n k3s-worker-1
./03_deploy_k3s.sh -m single -i 102 -n k3s-worker-2

# 步驟 3: 手動加入 Worker 節點
./k3s-manager.sh join 101 100
./k3s-manager.sh join 102 100
```

### 第三階段：部署驗證

#### 1. 執行完整驗證
```bash
# 運行自動化驗證腳本
./verify_deployment.sh

# 驗證項目包括：
# ✅ VM 狀態檢查 (所有 VM 運行中)
# ✅ SSH 連線檢查 (金鑰認證正常)
# ✅ K3s 服務狀態 (Master/Agent 服務運行)
# ✅ 叢集節點狀態 (所有節點 Ready)
# ✅ 系統 Pods 狀態 (CoreDNS, Traefik 等)
# ✅ cert-manager 狀態 (SSL 憑證管理)
# ✅ Helm 配置檢查 (套件管理工具)
# ✅ 叢集資訊總覽 (API 端點, 版本資訊)
```

#### 2. 手動驗證關鍵功能
```bash
# 檢查叢集節點
ssh ubuntu@10.110.0.70 'kubectl get nodes -o wide'

# 檢查系統 Pods
ssh ubuntu@10.110.0.70 'kubectl get pods --all-namespaces'

# 檢查叢集資源使用
ssh ubuntu@10.110.0.70 'kubectl top nodes'

# 檢查 cert-manager
ssh ubuntu@10.110.0.70 'kubectl get pods -n cert-manager'

# 測試 DNS 解析
ssh ubuntu@10.110.0.70 'nslookup kubernetes.default.svc.cluster.local'
```

### 第四階段：問題修復 (如需要)

#### 1. 自動修復常見問題
```bash
# 執行自動修復腳本
./fix_deployment.sh

# 修復項目包括：
# 🔧 SSH 金鑰認證問題
# 🔧 k3s-setup 服務啟動問題  
# 🔧 Helm repository 配置
# 🔧 密碼認證設定
# 🔧 cert-manager 重新安裝
```

#### 2. 手動故障排除
```bash
# 檢查 k3s-setup 服務狀態
ssh ubuntu@10.110.0.70 'systemctl status k3s-setup'

# 查看 k3s-setup 日誌
ssh ubuntu@10.110.0.70 'cat /tmp/k3s-setup.log'

# 重新啟動服務 (如需要)
ssh ubuntu@10.110.0.70 'sudo systemctl restart k3s-setup'

# 檢查 SSH 配置
ssh ubuntu@10.110.0.70 'cat /tmp/ssh-config-status'
```

### 第五階段：叢集使用

#### 1. 部署測試應用
```bash
# 連線到 Master 節點
ssh ubuntu@10.110.0.70

# 部署 Nginx 測試應用
kubectl create deployment nginx-test --image=nginx:latest
kubectl expose deployment nginx-test --port=80 --type=NodePort

# 檢查部署狀態
kubectl get deployments
kubectl get services
kubectl get pods

# 取得服務存取端口
kubectl get svc nginx-test
```

#### 2. 設定 Ingress (使用內建 Traefik)
```bash
# 創建 Ingress 配置
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: nginx.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-test
            port:
              number: 80
EOF

# 檢查 Ingress 狀態
kubectl get ingress
```

#### 3. 使用 cert-manager 配置 SSL
```bash
# 創建 ClusterIssuer (Let's Encrypt)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

# 檢查 ClusterIssuer
kubectl get clusterissuer
```

### 第六階段：監控和維護

#### 1. 效能監控
```bash
# 檢查節點資源使用
ssh ubuntu@10.110.0.70 'kubectl top nodes'

# 檢查 Pod 資源使用  
ssh ubuntu@10.110.0.70 'kubectl top pods --all-namespaces'

# 檢查系統負載
ssh ubuntu@10.110.0.70 'htop'

# 檢查磁碟空間
ssh ubuntu@10.110.0.70 'df -h'
```

#### 2. 定期維護
```bash
# 清理未使用的容器映像
ssh ubuntu@10.110.0.70 'sudo k3s ctr images prune'

# 更新系統套件
ssh ubuntu@10.110.0.70 'sudo apt update && sudo apt upgrade -y'

# 備份 K3s 配置
ssh ubuntu@10.110.0.70 'sudo cp /etc/rancher/k3s/k3s.yaml ~/k3s-backup-$(date +%Y%m%d).yaml'
```

## 🚀 快速開始 (一鍵部署)

### 完整叢集自動部署
```bash
# 執行以下命令即可完成整個 K3s 叢集部署
./01_download_image.sh && \
./02_create_template.sh && \
./03_deploy_k3s.sh -m batch -i 100 -c 3 -n k3s-node && \
./verify_deployment.sh
```

### 分步部署 (手動控制)
```bash
# 1. 下載 Ubuntu Cloud Image
./01_download_image.sh

# 2. 建立 VM 範本
./02_create_template.sh

# 3. 部署完整 K3s 叢集 (1 Master + 2 Workers)
./03_deploy_k3s.sh -m batch -i 100 -c 3 -n k3s-node

# 4. 驗證部署狀態
./verify_deployment.sh

# 5. 如有問題，執行修復腳本
./fix_deployment.sh
```

## 🏗️ 叢集架構設計

### 網路架構
```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox VE Host                         │
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   VM 100        │  │   VM 101        │  │   VM 102        │ │
│  │  k3s-node-1     │  │  k3s-node-2     │  │  k3s-node-3     │ │
│  │  (Master)       │  │  (Worker)       │  │  (Worker)       │ │
│  │  4C/4G/20GB     │  │  2C/2G/15GB     │  │  2C/2G/15GB     │ │
│  │  10.110.0.70    │  │  10.110.0.71    │  │  10.110.0.72    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│           │                     │                     │        │
│           └─────────────────────┼─────────────────────┘        │
│                                 │                               │
│  ┌──────────────────────────────┴──────────────────────────┐   │
│  │                   vmbr0 Bridge                          │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                 │                               │
└─────────────────────────────────┼───────────────────────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │     Physical Network      │
                    │     (192.168.x.x)        │
                    └───────────────────────────┘
```

### K3s 服務架構
```
┌─────────────────────────────────────────────────────────────┐
│                 k3s-node-1 (Master)                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Control Plane Components                                │ │
│  │ • kube-apiserver                                        │ │
│  │ • kube-controller-manager                               │ │
│  │ • kube-scheduler                                        │ │
│  │ • etcd (embedded)                                       │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ System Components                                       │ │
│  │ • CoreDNS (DNS)                                         │ │
│  │ • Traefik (Ingress Controller)                          │ │
│  │ • metrics-server (Resource Metrics)                     │ │
│  │ • local-path-provisioner (Storage)                      │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Add-on Components                                       │ │
│  │ • cert-manager (SSL Certificate Management)             │ │
│  │ • Helm (Package Manager)                                │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              k3s-node-2/3 (Workers)                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Node Components                                         │ │
│  │ • kubelet                                               │ │
│  │ • kube-proxy                                            │ │
│  │ • containerd (Container Runtime)                        │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Network Components                                      │ │
│  │ • Flannel (CNI)                                         │ │
│  │ • Service Load Balancer                                 │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 端口配置
```
Master Node (k3s-node-1):
├── 6443/tcp    - Kubernetes API Server
├── 10250/tcp   - Kubelet API
├── 10251/tcp   - kube-scheduler
├── 10252/tcp   - kube-controller-manager
├── 2379-2380/tcp - etcd server client API
└── 8472/udp    - Flannel VXLAN

Worker Nodes (k3s-node-2/3):
├── 10250/tcp   - Kubelet API  
├── 30000-32767/tcp - NodePort Services
└── 8472/udp    - Flannel VXLAN

Service Ports:
├── 80/tcp      - Traefik HTTP
├── 443/tcp     - Traefik HTTPS
└── 9153/tcp    - CoreDNS Metrics
```

## 🔐 SSH 連線方式

部署完成後，系統支援多種連線方式：

```bash
# 方法1: 直接使用 SSH 金鑰 (推薦)
ssh ubuntu@<VM_IP>

# 方法2: 使用密碼登入
ssh ubuntu@<VM_IP>
# 密碼: FsI!^@#Zg

# 方法3: 使用 sshpass 自動化
sshpass -p 'FsI!^@#Zg' ssh ubuntu@<VM_IP>

# 測試範例 (假設 Master 節點 IP 為 10.110.0.70)
ssh ubuntu@10.110.0.70 'hostname && kubectl get nodes'
```

**登入資訊**:
- 使用者名稱: `ubuntu`
- 密碼: `FsI!^@#Zg`
- SSH 密碼認證: ✅ 已啟用
- SSH 金鑰認證: ✅ 已配置

## 🛠️ 管理工具

### 叢集管理 (k3s-manager.sh)

```bash
# 檢查叢集狀態
./k3s-manager.sh status 100

# 列出所有節點
./k3s-manager.sh list-nodes 100

# 手動加入 Worker 節點
./k3s-manager.sh join 101 100

# 檢查單一節點
./k3s-manager.sh check 100
```

### 部署驗證 (verify_deployment.sh)

```bash
# 完整部署驗證
./verify_deployment.sh
```

驗證項目:
- ✅ VM 狀態檢查
- ✅ SSH 連線檢查
- ✅ K3s 服務狀態
- ✅ 叢集節點狀態
- ✅ 系統 Pods 狀態
- ✅ cert-manager 狀態
- ✅ Helm 配置檢查
- ✅ 叢集資訊總覽

### 問題修復 (fix_deployment.sh)

```bash
# 自動修復常見問題
./fix_deployment.sh
```

修復項目:
- 🔧 SSH 金鑰認證問題
- 🔧 k3s-setup 服務問題
- 🔧 Helm repository 配置
- 🔧 密碼認證設定

## 📊 已安裝組件

### K3s 核心組件
- **K3s**: v1.32.6+k3s1 (包含 kubectl, containerd)
- **Go**: version go1.23.10
- **containerd**: v2.0.5-k3s1.32

### 系統服務
- **CoreDNS**: v1.12.1 (DNS 解析)
- **Traefik**: v3.3.6 (Ingress Controller)
- **metrics-server**: v0.7.2 (資源監控)
- **local-path-provisioner**: v0.0.31 (儲存供應)

### 管理工具
- **Helm**: v3.18.4 (套件管理)
- **cert-manager**: v1.18.2 (SSL 憑證管理)

### 容器映像清單
```
docker.io/rancher/klipper-helm:v0.9.7
docker.io/rancher/klipper-lb:v0.4.13
docker.io/rancher/local-path-provisioner:v0.0.31
docker.io/rancher/mirrored-coredns-coredns:1.12.1
docker.io/rancher/mirrored-library-traefik:3.3.6
docker.io/rancher/mirrored-metrics-server:v0.7.2
quay.io/jetstack/cert-manager-controller:v1.18.2
quay.io/jetstack/cert-manager-cainjector:v1.18.2
quay.io/jetstack/cert-manager-webhook:v1.18.2
```

## 🎯 使用範例

### 批次部署完整叢集

```bash
# 部署 1 Master + 2 Workers 叢集
./03_deploy_k3s.sh -m batch -i 100 -c 3 -n k3s-node

# 預期結果:
# VM 100: k3s-node-1 (Master)
# VM 101: k3s-node-2 (Worker)
# VM 102: k3s-node-3 (Worker)
```

### 檢查叢集狀態

```bash
# 驗證部署
./verify_deployment.sh

# 手動檢查
ssh ubuntu@10.110.0.70 'kubectl get nodes -o wide'
ssh ubuntu@10.110.0.70 'kubectl get pods --all-namespaces'
```

### 部署應用程式

```bash
# 連線到 Master 節點
ssh ubuntu@10.110.0.70

# 部署測試應用
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort

# 檢查服務
kubectl get services
```

## 🔧 故障排除

### 常見問題

#### 1. SSH 連線失敗
```bash
# 解決方案1: 使用修復腳本
./fix_deployment.sh

# 解決方案2: 手動重新配置 SSH
ssh ubuntu@<VM_IP> -o PreferredAuthentications=password
```

#### 2. k3s-setup 服務未運行
```bash
# 檢查服務狀態
ssh ubuntu@<VM_IP> 'systemctl status k3s-setup'

# 手動啟動服務
ssh ubuntu@<VM_IP> 'sudo systemctl start k3s-setup'
```

#### 3. Worker 節點無法加入叢集
```bash
# 使用管理工具重新加入
./k3s-manager.sh join <WORKER_ID> <MASTER_ID>

# 手動加入
ssh ubuntu@<MASTER_IP> 'sudo cat /var/lib/rancher/k3s/server/node-token'
ssh ubuntu@<WORKER_IP> 'curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<TOKEN> sh -'
```

#### 4. cert-manager 未正常運行
```bash
# 檢查 cert-manager 狀態
ssh ubuntu@<MASTER_IP> 'kubectl get pods -n cert-manager'

# 重新安裝 cert-manager
ssh ubuntu@<MASTER_IP> 'helm uninstall cert-manager -n cert-manager'
ssh ubuntu@<MASTER_IP> 'helm install cert-manager jetstack/cert-manager --namespace cert-manager'
```

### 日誌檢查

```bash
# K3s 服務日誌
ssh ubuntu@<VM_IP> 'sudo journalctl -u k3s -f'

# k3s-setup 日誌
ssh ubuntu@<VM_IP> 'cat /tmp/k3s-setup.log'

# SSH 配置狀態
ssh ubuntu@<VM_IP> 'cat /tmp/ssh-config-status'
```

## 📈 效能監控

### 查看叢集資源使用

```bash
# 節點資源使用
ssh ubuntu@<MASTER_IP> 'kubectl top nodes'

# Pod 資源使用
ssh ubuntu@<MASTER_IP> 'kubectl top pods --all-namespaces'

# 系統負載
ssh ubuntu@<VM_IP> 'htop'
```

### 建議監控指標

- **CPU 使用率**: Master < 70%, Worker < 80%
- **記憶體使用率**: Master < 80%, Worker < 85%
- **磁碟使用率**: 所有節點 < 85%
- **網路延遲**: 節點間 < 5ms

## 🚨 安全性注意事項

### 已實施的安全措施

- ✅ 強密碼設定 (`FsI!^@#Zg`)
- ✅ SSH 金鑰認證
- ✅ 密碼和金鑰雙重認證
- ✅ 防火牆友善配置
- ✅ QEMU Guest Agent 安全設定

### 建議的額外安全措施

```bash
# 更換預設密碼
ssh ubuntu@<VM_IP> 'passwd'

# 停用密碼認證 (僅使用金鑰)
ssh ubuntu@<VM_IP> 'sudo sed -i "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config'
ssh ubuntu@<VM_IP> 'sudo systemctl restart ssh'

# 設定防火牆規則
ssh ubuntu@<VM_IP> 'sudo ufw enable'
ssh ubuntu@<VM_IP> 'sudo ufw allow ssh'
ssh ubuntu@<VM_IP> 'sudo ufw allow 6443'  # K3s API
```

## 🔄 升級和維護

### K3s 升級

```bash
# 升級 K3s 到最新版本
ssh ubuntu@<MASTER_IP> 'curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644'

# 重啟 K3s 服務
ssh ubuntu@<MASTER_IP> 'sudo systemctl restart k3s'
```

### 定期維護

```bash
# 清理未使用的容器映像
ssh ubuntu@<VM_IP> 'sudo k3s ctr images prune'

# 更新系統套件
ssh ubuntu@<VM_IP> 'sudo apt update && sudo apt upgrade -y'

# 檢查磁碟空間
ssh ubuntu@<VM_IP> 'df -h'
```

## 📝 更新日誌

### v1.2.0 (當前版本)
- ✅ 完整的部署驗證系統
- ✅ 自動問題修復腳本
- ✅ SSH 雙重認證支援
- ✅ K3s v1.32.6+k3s1 支援
- ✅ cert-manager v1.18.2 整合
- ✅ Helm v3.18.4 自動安裝

### v1.1.0
- ✅ 批次部署模式
- ✅ 自動 Worker 節點加入
- ✅ 增強的錯誤處理

### v1.0.0
- ✅ 基礎單一節點部署
- ✅ VM 範本管理
- ✅ Cloud-Init 自動化

## 📞 技術支援

### 取得協助

1. **檢查日誌**: 使用 `verify_deployment.sh` 取得完整狀態
2. **使用修復工具**: 執行 `fix_deployment.sh` 自動修復
3. **手動診斷**: 使用 `k3s-manager.sh` 工具集

### 回報問題

請提供以下資訊:
- Proxmox VE 版本
- `verify_deployment.sh` 輸出結果
- 相關錯誤日誌
- VM 配置詳情

## 📄 授權

此專案採用 MIT 授權條款。

## 🎉 完整部署範例

### 從零開始的完整部署流程

```bash
# ================================
# 第一步：Proxmox 環境準備
# ================================

# 1. 檢查 Proxmox 環境
pveversion
pvesm status
ip link show

# 2. 進入專案目錄
cd /root/PROXMOX/autok3s

# 3. 確認配置檔案
cat config.sh

# ================================
# 第二步：一鍵部署 K3s 叢集
# ================================

# 執行完整自動化部署
./01_download_image.sh && \
./02_create_template.sh && \
./03_deploy_k3s.sh -m batch -i 100 -c 3 -n k3s-node && \
sleep 180 && \
./verify_deployment.sh

# ================================
# 第三步：驗證叢集功能
# ================================

# 檢查節點狀態
ssh ubuntu@10.110.0.70 'kubectl get nodes -o wide'

# 部署測試應用
ssh ubuntu@10.110.0.70 'kubectl create deployment nginx --image=nginx'
ssh ubuntu@10.110.0.70 'kubectl expose deployment nginx --port=80 --type=NodePort'

# 檢查服務
ssh ubuntu@10.110.0.70 'kubectl get all'

# ================================
# 預期結果
# ================================
# ✅ 3 台 VM 成功建立並運行
# ✅ K3s v1.32.6+k3s1 叢集部署完成
# ✅ 所有節點狀態為 Ready
# ✅ 系統 Pods 正常運行
# ✅ cert-manager 部署完成
# ✅ SSH 雙重認證配置完成
# ✅ Helm v3.18.4 可用
# ✅ 測試應用部署成功
```

### 部署後的叢集資訊

```bash
# 叢集基本資訊
Cluster Name: k3s-cluster
K3s Version: v1.32.6+k3s1
Node Count: 3 (1 Master + 2 Workers)
Container Runtime: containerd v2.0.5-k3s1.32

# 節點分佈
Master Node:  k3s-node-1 (VM 100) - 4C/4G/20GB - 10.110.0.70
Worker Node:  k3s-node-2 (VM 101) - 2C/2G/15GB - 10.110.0.71  
Worker Node:  k3s-node-3 (VM 102) - 2C/2G/15GB - 10.110.0.72

# 系統元件
DNS:          CoreDNS v1.12.1
Ingress:      Traefik v3.3.6
Metrics:      metrics-server v0.7.2
Storage:      local-path-provisioner v0.0.31
SSL Certs:    cert-manager v1.18.2
Packages:     Helm v3.18.4

# 網路配置
CNI:          Flannel (VXLAN)
Service CIDR: 10.43.0.0/16
Pod CIDR:     10.42.0.0/16
```

---

🎉 **恭喜！您的 K3s 叢集已準備就緒！** 

現在您可以：
- 📱 使用 `kubectl` 管理您的叢集
- 🚀 部署您的應用程式
- 🔐 使用 cert-manager 管理 SSL 憑證
- 📊 透過 Helm 安裝額外套件
- 🛠️ 使用內建管理工具監控叢集

如有任何問題，請參考 [故障排除](#-故障排除) 章節或使用內建的管理工具。
