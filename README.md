# Proxmox K3s 自動部署系統

這是一個完整的 Proxmox VE 環境下 K3s Kubernetes 叢集自動化部署解決方案，內建 **ELK Stack** 支援。

## 🚀 特色功能

- **全自動化部署**: 從 Ubuntu Cloud Image 下載到 K3s 叢集建立，一鍵完成
- **智能範本管理**: 自動建立並管理 VM 範本 (包含 Cloud-Init 和 QEMU Guest Agent)
- **靈活的部署模式**: 支援單一節點或批次建立多節點叢集
- **ELK Stack 整合準備**: 預留 Elasticsearch, Logstash, Kibana 日誌分析平台 (未來功能)
- **完整的錯誤處理**: 豐富的防呆機制和自動清理功能
- **叢集管理工具**: 內建狀態檢查、節點加入、日誌查看等管理功能
- **中文友善**: 全中文介面和錯誤提示

## 📋 系統需求

- **Proxmox VE 7.0+** (已測試 7.x 和 8.x)
- **最少 2GB 可用儲存空間** (用於下載 Ubuntu Cloud Image)
- **建議配置** (K3s 叢集):
  - Master 節點: 4 CPU, 4GB RAM, 20GB 磁碟
  - Worker 節點: 2 CPU, 2GB RAM, 15GB 磁碟
- **網路連接** (下載映像檔和 K3s)
- **Root 權限** (所有腳本必須以 root 身份執行)

**ELK Stack 資源需求** (未來功能):
  - Master 節點: 建議升級至 4 CPU, 8GB RAM, 30GB 磁碟
  - Worker 節點: 2 CPU, 4GB RAM, 20GB 磁碟

## 📁 檔案結構

```
autok3s/
├── config.sh                  # � 中央配置檔案
├── 01_download_image.sh        # ⬇️ Ubuntu Cloud Image 下載器
├── 02_create_template.sh       # 📋 VM 範本建立器
├── 03_deploy_k3s.sh            # 🎯 主要部署腳本
├── k3s-manager.sh              # 🛠️ 叢集管理工具
├── elk-config.sh.backup        # 📊 ELK Stack 配置檔案 (預留)
├── elk-manager.sh.backup       # 📊 ELK Stack 管理工具 (預留)
└── README.md                   # 📖 使用說明
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

### 完整 K3s 叢集部署

```bash
# 1. 下載 Ubuntu Cloud Image
./01_download_image.sh

# 2. 建立 VM 範本
./02_create_template.sh

# 3. 部署 K3s 叢集 (1 master + 2 workers)
./03_deploy_k3s.sh --mode batch --start-id 100 --count 3 --name k3s-cluster

# 4. 等待叢集就緒並檢查狀態
./k3s-manager.sh status 100

# 5. 檢查所有節點
ssh ubuntu@<MASTER_IP> 'kubectl get nodes'
```

### 基本 K3s 單節點部署

```bash
# 建立 1 個 master 節點
./03_deploy_k3s.sh --mode single --start-id 100 --name k3s-master

# 檢查部署狀態
./k3s-manager.sh status 100
```

### 未來功能預告：ELK Stack 整合

> 📊 **ELK Stack 支援已準備就緒，等待 K3s 叢集穩定後可啟用**
> 
> ELK Stack（Elasticsearch, Logstash, Kibana）將提供完整的日誌管理和監控功能。相關代碼已預留在腳本中，待 K3s 部署驗證完成後即可啟用。

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

### elk-manager.sh - ELK Stack 管理工具

**功能**: 提供 ELK Stack 的安裝與管理功能

#### 安裝 ELK Stack

```bash
# 安裝 ELK Stack 至指定 VM
./elk-manager.sh install 100
```

#### 檢查 ELK 狀態

```bash
# 檢查 ELK 服務狀態
./elk-manager.sh status 100
```

#### 查看日誌

```bash
# 查看 Logstash 處理的日誌
./elk-manager.sh logs 100
```

## 📊 ELK Stack 管理

### 部署 ELK Stack

K3s 叢集建立完成後，可以使用內建的 ELK Stack 進行日誌管理：

```bash
# 部署完整 ELK Stack
./elk-manager.sh -m 100 deploy

# 或使用 IP 地址
./elk-manager.sh -i 192.168.1.100 deploy
```

### ELK Stack 管理操作

```bash
# 檢查 ELK 狀態
./elk-manager.sh -m 100 status

# 查看服務日誌
./elk-manager.sh -m 100 logs elasticsearch
./elk-manager.sh -m 100 logs kibana
./elk-manager.sh -m 100 logs fluent-bit

# 啟動端口轉發 (在本地存取 Kibana)
./elk-manager.sh -m 100 port-forward

# 移除 ELK Stack
./elk-manager.sh -m 100 remove
```

### ELK Stack 存取

部署完成後可以透過以下方式存取：

- **Kibana**: `http://<MASTER_IP>:30601`
- **Elasticsearch**: `http://<MASTER_IP>:9200`

### ELK 配置調整

編輯 `elk-config.sh` 來調整 ELK Stack 配置：

```bash
# 編輯 ELK 配置
nano elk-config.sh

# 主要配置項目：
ELASTICSEARCH_REPLICAS=1        # ES 副本數
ELASTICSEARCH_STORAGE="10Gi"    # ES 儲存空間
KIBANA_NODE_PORT="30601"        # Kibana 存取端口
LOG_RETENTION_DAYS=30           # 日誌保留天數
```

## 🐛 故障排除

### 常見問題

#### 1. 範本建立失敗

```bash
# 檢查儲存空間
df -h

# 檢查下載的映像檔
ls -la /var/lib/vz/template/iso/

# 手動清理
./01_download_image.sh  # 重新下載
```

#### 2. Cloud-Init 初始化失敗

```bash
# SSH 進入 VM 檢查 Cloud-Init 狀態
ssh ubuntu@<VM_IP>
sudo cloud-init status
sudo cat /var/log/cloud-init-output.log
```

#### 3. K3s 安裝失敗

```bash
# 檢查 K3s 服務狀態
ssh ubuntu@<VM_IP>
sudo systemctl status k3s
sudo journalctl -u k3s -f
```

#### 4. Worker 節點加入失敗

```bash
# 檢查 master 狀態
./k3s-manager.sh status <MASTER_ID>

# 重新取得 token
./k3s-manager.sh get-token <MASTER_ID>

# 手動加入
ssh ubuntu@<WORKER_IP> "curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<TOKEN> sh -"
```

#### 5. ELK Stack 部署失敗

```bash
# 檢查叢集狀態
./k3s-manager.sh status <MASTER_ID>

# 檢查 ELK 狀態
./elk-manager.sh -m <MASTER_ID> status

# 查看詳細日誌
./elk-manager.sh -m <MASTER_ID> logs elasticsearch
./elk-manager.sh -m <MASTER_ID> logs kibana

# 重新部署
./elk-manager.sh -m <MASTER_ID> remove
./elk-manager.sh -m <MASTER_ID> deploy
```

#### 6. ELK 資源不足

```bash
# 增加 Master 節點資源
qm set <MASTER_ID> --cores 6 --memory 12288

# 或編輯 elk-config.sh 降低資源需求
ELASTICSEARCH_MEMORY_REQUEST="1Gi"
ELASTICSEARCH_MEMORY_LIMIT="2Gi"
```

### 日誌位置

- **Cloud-Init 日誌**: `/var/log/cloud-init-output.log`
- **K3s 服務日誌**: `sudo journalctl -u k3s`
- **ELK 部署日誌**: SSH 到 Master 查看 `/opt/k3s-elk/` 目錄
- **Kubernetes 日誌**: `kubectl logs -n elk-stack <pod-name>`
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

### ELK Stack 優化配置

```yaml
# 在 elk-config.sh 中調整 ELK 參數
ES_JAVA_OPTS="-Xms1g -Xmx1g"
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
- **v1.3**: 新增 ELK Stack 整合與管理工具

## 📞 技術支援

如遇到問題，請提供以下資訊：
- Proxmox VE 版本
- 錯誤訊息和日誌
- 執行的完整命令
- 環境配置 (網路、儲存等)

---

🎉 **祝您使用愉快！** 這個工具讓 Proxmox 上的 K3s 部署變得簡單而可靠。
