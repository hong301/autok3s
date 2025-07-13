# Proxmox K3s 自動部署系統

這是一個完整的 Proxmox VE 環境下 K3s Kubernetes 叢集自動化部署解決方案。

## 🚀 特色功能

- **全自動化部署**: 從 Ubuntu Cloud Image 下載到 K3s 叢集建立，一鍵完成
- **智能範本管理**: 自動建立並管理 VM 範本 (包含 Cloud-Init 和 QEMU Guest Agent)
- **靈活的部署模式**: 支援單一節點或批次建立多節點叢集
- **完整的錯誤處理**: 豐富的防呆機制和自動清理功能
- **叢集管理工具**: 內建狀態檢查、節點加入、日誌查看等管理功能
- **中文友善**: 全中文介面和錯誤提示

## 📋 系統需求

- **Proxmox VE 7.0+** (已測試 7.x 和 8.x)
- **最少 2GB 可用儲存空間** (用於下載 Ubuntu Cloud Image)
- **網路連接** (下載映像檔和 K3s)
- **Root 權限** (所有腳本必須以 root 身份執行)

## 📁 檔案結構

```
autok3s/
├── config.sh              # 🔧 中央配置檔案
├── 01_download_image.sh    # ⬇️ Ubuntu Cloud Image 下載器
├── 02_create_template.sh   # 📋 VM 範本建立器
├── 03_deploy_k3s.sh        # 🎯 主要部署腳本
├── k3s-manager.sh          # 🛠️ 叢集管理工具
└── README.md               # 📖 使用說明
```

## ⚙️ 初始設定

### 1. 編輯配置檔案

```bash
# 編輯配置設定
nano config.sh
```

預設配置:
```bash
STORAGE="local-lvm"     # Proxmox 儲存名稱
NET_BRIDGE="vmbr0"      # 網路橋接名稱
CIUSER="ubuntu"         # Cloud-Init 使用者名稱
CIPASSWORD="ubuntu123"  # Cloud-Init 密碼 (建議修改)
```

### 2. 檢查儲存和網路設定

```bash
# 查看可用儲存
pvesm status

# 查看網路介面
ip link show
```

## 🚀 快速開始

### 完整部署流程

```bash
# 1. 下載 Ubuntu Cloud Image
./01_download_image.sh

# 2. 建立 VM 範本
./02_create_template.sh

# 3. 部署 K3s 叢集
./03_deploy_k3s.sh --mode single --start-id 100 --name k3s-master
```

### 建立 Master + Workers 叢集

```bash
# 建立 1 個 master + 3 個 worker 節點
./03_deploy_k3s.sh --mode batch --start-id 100 --count 4 --name k3s-cluster
```

## 📖 詳細使用說明

### 01_download_image.sh - 映像檔下載器

**功能**: 下載最新的 Ubuntu 22.04 LTS Cloud Image

```bash
./01_download_image.sh
```

**特色**:
- ✅ 自動檢查網路連通性
- ✅ 驗證儲存空間是否足夠
- ✅ 支援斷點續傳
- ✅ 自動清理失敗的下載

### 02_create_template.sh - 範本建立器

**功能**: 從 Cloud Image 建立 VM 範本 (ID: 9000)

```bash
./02_create_template.sh
```

**範本特色**:
- 🔧 已啟用 QEMU Guest Agent
- 🔧 配置 Cloud-Init 支援
- 🔧 網路設定為 DHCP
- 🔧 優化的硬體配置 (2 CPU, 2GB RAM)

### 03_deploy_k3s.sh - 主部署腳本

**功能**: 從範本複製並部署 K3s 叢集

#### 單一節點部署

```bash
# 部署 Master 節點
./03_deploy_k3s.sh --mode single --start-id 100 --name k3s-master

# 部署 Worker 節點
./03_deploy_k3s.sh --mode single --start-id 101 --name k3s-worker
```

#### 批次部署

```bash
# 建立 1 master + 2 workers
./03_deploy_k3s.sh --mode batch --start-id 100 --count 3 --name k3s-cluster
```

#### 參數說明

| 參數 | 短參數 | 說明 | 預設值 |
|------|--------|------|--------|
| `--mode` | `-m` | 部署模式 (single/batch) | single |
| `--start-id` | `-i` | 起始 VM ID | 100 |
| `--count` | `-c` | 批次建立數量 | 1 |
| `--name` | `-n` | VM 名稱前綴 | k3s-node |
| `--template` | `-t` | 範本 ID | 9000 |

### k3s-manager.sh - 叢集管理工具

**功能**: 提供完整的 K3s 叢集管理功能

#### 檢查叢集狀態

```bash
# 檢查指定 VM 的 K3s 狀態
./k3s-manager.sh status 100
```

#### 取得加入 Token

```bash
# 從 Master 節點取得 join token
./k3s-manager.sh get-token 100
```

#### 加入 Worker 節點

```bash
# 讓 VM 101 加入 VM 100 的叢集
./k3s-manager.sh join 101 100
```

#### 查看叢集節點

```bash
# 列出所有叢集節點
./k3s-manager.sh list-nodes 100
```

#### 查看服務日誌

```bash
# 即時查看 K3s 服務日誌
./k3s-manager.sh logs 100
```

#### 清理 VM

```bash
# 清理單一 VM
./k3s-manager.sh cleanup 100

# 清理 VM 範圍
./k3s-manager.sh cleanup 100-110
```

## 🎯 使用範例

### 情境 1: 建立開發環境 (單節點)

```bash
# 1. 準備環境
./01_download_image.sh
./02_create_template.sh

# 2. 建立單節點 K3s
./03_deploy_k3s.sh -m single -i 100 -n dev-k3s

# 3. 等待 3 分鐘後檢查狀態
./k3s-manager.sh status 100
```

### 情境 2: 建立生產環境 (多節點)

```bash
# 1. 建立 1 master + 3 workers
./03_deploy_k3s.sh -m batch -i 100 -c 4 -n prod-k3s

# 2. 等待 5 分鐘後自動加入所有 worker
for i in {2..4}; do
    worker_id=$((100 + i - 1))
    ./k3s-manager.sh join $worker_id 100
    sleep 30
done

# 3. 檢查最終叢集狀態
./k3s-manager.sh list-nodes 100
```

### 情境 3: 段階式建立叢集

```bash
# 1. 先建立 master
./03_deploy_k3s.sh -m single -i 100 -n k3s-master

# 2. 等待 master 準備完成
sleep 180
./k3s-manager.sh status 100

# 3. 逐個添加 worker
for i in {101..103}; do
    ./03_deploy_k3s.sh -m single -i $i -n k3s-worker-$((i-100))
    sleep 60
    ./k3s-manager.sh join $i 100
done
```

## 🔧 高級配置

### 自訂 Cloud-Init 配置

如需客製化安裝，可修改 `03_deploy_k3s.sh` 中的 Cloud-Init 配置：

```yaml
# Master 節點額外配置
runcmd:
  - curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
  - kubectl create namespace monitoring
  - helm install prometheus prometheus-community/prometheus
```

### 網路配置

```bash
# 使用靜態 IP (修改 03_deploy_k3s.sh)
qm set $vm_id --ipconfig0 ip=192.168.1.100/24,gw=192.168.1.1
```

### 儲存配置

```bash
# 使用不同儲存 (修改 config.sh)
STORAGE="ceph-storage"  # 替換為你的儲存名稱
```

## 🛠️ 故障排除

### 常見問題及解決方案

#### 1. VM 無法啟動

```bash
# 檢查 VM 狀態
qm status <VM_ID>

# 查看啟動錯誤
qm start <VM_ID>
```

#### 2. 無法取得 VM IP

```bash
# 手動查看 VM IP
qm guest cmd <VM_ID> network-get-interfaces

# 檢查 QEMU Guest Agent
qm agent <VM_ID> ping
```

#### 3. K3s 安裝失敗

```bash
# SSH 進入 VM 檢查
ssh ubuntu@<VM_IP>

# 查看 cloud-init 日誌
sudo cat /var/log/cloud-init-output.log

# 檢查 K3s 服務
sudo systemctl status k3s
```

#### 4. Worker 節點無法加入

```bash
# 檢查 master 狀態
./k3s-manager.sh status <MASTER_ID>

# 重新取得 token
./k3s-manager.sh get-token <MASTER_ID>

# 手動加入
ssh ubuntu@<WORKER_IP> "curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<TOKEN> sh -"
```

### 日誌位置

- **Cloud-Init 日誌**: `/var/log/cloud-init-output.log`
- **K3s 服務日誌**: `sudo journalctl -u k3s`
- **系統日誌**: `/var/log/syslog`

## 🔐 安全建議

1. **修改預設密碼**: 更改 `config.sh` 中的 `CIPASSWORD`
2. **使用 SSH 金鑰**: 建議配置 SSH 公鑰認證
3. **防火牆設定**: 限制 K3s API 服務器存取 (6443 port)
4. **定期更新**: 保持系統和 K3s 版本更新

```bash
# 設定 SSH 金鑰 (在 Cloud-Init 配置中)
ssh_authorized_keys:
  - ssh-rsa AAAAB3NzaC1yc2E... your-public-key
```

## 📊 性能調優

### VM 資源配置

```bash
# 調整 CPU 和記憶體 (在 02_create_template.sh 中)
qm set 9000 --cores 4 --memory 4096  # 4 CPU, 4GB RAM
```

### K3s 優化配置

```bash
# 在 Cloud-Init 中添加 K3s 參數
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb
```

## 🆘 支援與貢獻

### 已知限制

- 目前僅支援 Ubuntu 22.04 LTS
- 需要 root 權限執行
- VM ID 範圍限制 100-999999

### 未來改進

- [ ] 支援 CentOS/RHEL 系統
- [ ] Web UI 管理介面
- [ ] 自動備份和還原
- [ ] 監控和警報整合

## 📜 版本紀錄

- **v1.0**: 初始版本，支援基本 K3s 部署
- **v1.1**: 添加批次部署和管理工具
- **v1.2**: 改進錯誤處理和中文化界面

## 📞 技術支援

如遇到問題，請提供以下資訊：
- Proxmox VE 版本
- 錯誤訊息和日誌
- 執行的完整命令
- 環境配置 (網路、儲存等)

---

🎉 **祝您使用愉快！** 這個工具讓 Proxmox 上的 K3s 部署變得簡單而可靠。
