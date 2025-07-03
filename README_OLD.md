# ☸️ Auto K3s + ELK Cluster on Proxmox VE

本專案可在 **Proxmox VE** 上全自動部署一組：

- K3s 輕量 Kubernetes 叢集（Master + Worker）
- 完整 ELK Stack：
  - Elasticsearch（資料儲存）
  - Logstash（日誌處理和轉換）
  - Kibana（視覺化介面）
- 全面的 Beats 收集器：
  - Filebeat（日誌收集）
  - Metricbeat（指標收集）
  - Auditbeat（安全審計）

---

## 🧰 功能特色

- ✅ 自動下載並轉換 Ubuntu Cloud ## 📦 預設組態

| 元件             | 安裝位置          | 連接埠 | 備註                              |
|------------------|-------------------|--------|-----------------------------------|
| K3s Master       | `k3s-master` VM   | 6443   | Kubernetes API Server            |
| K3s Worker       | `k3s-worker*` VM  | -      | 工作節點                          |
| Elasticsearch    | K3s Cluster       | 30920  | 資料儲存（NodePort）              |
| Logstash         | K3s Cluster       | 30544  | 日誌處理（Beats 輸入）            |
| Logstash HTTP    | K3s Cluster       | 30880  | HTTP 輸入接口                     |
| Kibana           | K3s Cluster       | 30561  | 視覺化介面（NodePort）            |
| Filebeat         | Proxmox + K3s     | -      | 日誌收集器                        |
| Metricbeat       | Proxmox Host      | -      | 指標收集器                        |
| Auditbeat        | Proxmox Host      | -      | 安全審計收集器                    |

### 📊 建立的索引

| 索引模式 | 資料來源 | 內容 |
|----------|----------|------|
| `filebeat-proxmox-*` | Proxmox 主機 | 系統日誌、PVE 日誌 |
| `metricbeat-proxmox-*` | Proxmox 主機 | 系統指標、效能資料 |
| `auditbeat-proxmox-*` | Proxmox 主機 | 安全審計、檔案異動 |
| `k3s-logs-*` | K3s 節點 | 容器日誌、K3s 日誌 |Cloud-Init）
- ✅ 建立支援 Cloud-Init 的 VM Template（VMID=9000）
- ✅ 自動建立 K3s Master 與 Worker VM
- ✅ 完整 ELK Stack：Elasticsearch + Logstash + Kibana
- ✅ 多層次 Beats 收集器：Filebeat + Metricbeat + Auditbeat
- ✅ 在 Proxmox 主機和 K3s 節點上部署 Beats
- ✅ 智能日誌處理和富化（透過 Logstash）
- ✅ 模組化設計，消除重複程式碼
- ✅ 完整的監控和安全審計解決方案

---

## 📁 專案結構

```
autok3s/
├── common_functions.sh           # 🔧 共用函數庫
├── 00_download_image.sh          # ⬇️ 下載 Ubuntu Cloud Image
├── 01_build_template.sh          # 🏗️ 建立 VM Template
├── 02_clone_k3s_nodes.sh         # 🖥️ 建立 K3s 節點 VM
├── 03_install_k3s.sh             # ☸️ 安裝 K3s Cluster
├── 04_install_elk_stack.sh       # 🔍 安裝 Elasticsearch + Kibana
├── 05_install_logstash.sh        # 🔄 安裝 Logstash
├── 06_install_beats_on_proxmox.sh # 📊 Proxmox 主機 Beats
├── 07_install_k3s_filebeat.sh    # � K3s 集群 Filebeat
├── deploy_k3s_elk.sh             # 🚀 **一鍵部署腳本**
└── README.md                     # 📖 說明文件
```

## 🔄 重構說明

本專案採用模組化設計，建立了 `common_functions.sh` 共用函數庫來消除重複程式碼：

#### ✅ 主要改進：
- **統一函數**: 下載映像、VM 管理、IP 取得、SSH 連線
- **消除重複**: 相同功能只寫一次，多處使用
- **易於維護**: 修改一處即可影響所有相關腳本
- **提高可讀性**: 腳本更簡潔，邏輯更清晰

---

## 🛠️ 環境需求

- ✅ Proxmox VE（已建立 local-lvm 儲存）
- ✅ 能上網下載套件（wget、apt）
- ✅ 已產生 SSH 金鑰：`~/.ssh/id_rsa.pub`
- ✅ 使用者具備 root 權限（或 `sudo`）

---

## 🚀 快速開始

### 一鍵部署（推薦）

```bash
git clone https://github.com/hong301/autok3s.git
cd autok3s
chmod +x deploy_k3s_elk.sh
sudo ./deploy_k3s_elk.sh
```

### 分步驟部署

```bash
# 1. 建立 VM Template
./01_build_template.sh

# 2. 複製並建立 K3s 節點
./02_clone_k3s_nodes.sh

# 3. 安裝 K3s Cluster
./03_install_k3s.sh

# 4. 安裝 ELK Stack
./04_install_elk_stack.sh
```

### 部署完成後

約 **5-8 分鐘**後，系統自動完成：
- ✅ 建立 Ubuntu Template + 4 台 VM (1 Master + 3 Worker)
- ✅ 部署 K3s Cluster
- ✅ 安裝完整 ELK Stack (Elasticsearch + Logstash + Kibana)
- ✅ 配置多層次日誌收集 (Proxmox + K3s)

### 🏗️ 最終架構

```
┌─────────────────────────────────────────────┐
│               Proxmox VE Host               │
│  📊 Filebeat + Metricbeat + Auditbeat      │
│                     │                       │
│  ┌─────────────────┼─────────────────────┐  │
│  │            K3s Cluster                │  │
│  │                                       │  │
│  │  📝 Filebeat → 🔄 Logstash → 🔍 ES   │  │
│  │                      ↓                │  │
│  │                 📊 Kibana             │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## � 使用範例

### 基本使用流程

```bash
# 1. 建立 VM Template
./01_build_template.sh

# 2. 複製並建立 K3s 節點
./02_clone_k3s_nodes.sh

# 3. 安裝 K3s Cluster
./03_install_k3s.sh

# 4. 安裝 ELK Stack
./04_install_elk_stack.sh

# 或者直接使用整合腳本
./k3s.sh
```

### 自定義配置

```bash
# 使用共用函數庫開發自定義腳本
source "$(dirname "$0")/common_functions.sh"

# 下載不同版本的 Ubuntu 映像
download_ubuntu_image "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" "/path/to/save"

# 建立自定義 VM Template
create_vm_template "9001" "my-template" "/path/to/image"

# 取得 VM IP
IP=$(get_ip_by_vmid "101")
echo "VM IP: $IP"

# 執行遠端命令
ssh_exec "$IP" "ubuntu" "sudo apt update && sudo apt upgrade -y"
```

## 🔧 故障排除

### 常見問題

1. **VM 無法取得 IP**
   ```bash
   # 檢查 qemu-guest-agent 狀態
   qm guest cmd <VMID> qemu-agent-command --command '{"execute": "guest-ping"}'
   
   # 手動啟動 qemu-guest-agent
   ssh ubuntu@<VM_IP> "sudo systemctl start qemu-guest-agent"
   ```

2. **SSH 連線失敗**
   ```bash
   # 檢查 SSH 金鑰
   ls -la ~/.ssh/id_rsa.pub
   
   # 重新生成 SSH 金鑰
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

3. **K3s 安裝失敗**
   ```bash
   # 檢查 K3s 服務狀態
   ssh ubuntu@<Master_IP> "sudo systemctl status k3s"
   
   # 查看 K3s 日誌
   ssh ubuntu@<Master_IP> "sudo journalctl -u k3s -f"
   ```

4. **Logstash 處理失敗**
   ```bash
   # 檢查 Logstash Pod 狀態
   ssh ubuntu@<Master_IP> "kubectl get pods -n logging -l app=logstash"
   
   # 查看 Logstash 日誌
   ssh ubuntu@<Master_IP> "kubectl logs -n logging -l app=logstash"
   
   # 檢查 Logstash 配置
   ssh ubuntu@<Master_IP> "kubectl get configmap logstash-config -n logging -o yaml"
   ```

5. **Beats 無法連接到 Logstash**
   ```bash
   # 檢查 Logstash 服務
   ssh ubuntu@<Master_IP> "kubectl get svc -n logging logstash-nodeport"
   
   # 測試 Logstash 連接
   telnet <Master_IP> 30544
   
   # 檢查 Beats 狀態
   systemctl status filebeat metricbeat auditbeat
   ```

6. **索引未建立**
   ```bash
   # 檢查 Elasticsearch 索引
   curl -X GET "http://<Master_IP>:30920/_cat/indices?v"
   
   # 檢查 Logstash 處理統計
   curl -X GET "http://<Master_IP>:30880/_node/stats"
   ```

### 清理環境

```bash
# 刪除所有 VM
qm destroy 101 --purge
qm destroy 102 --purge
qm destroy 103 --purge
qm destroy 104 --purge

# 刪除 Template
qm destroy 9000 --purge

# 清理映像檔
rm -f /var/lib/vz/template/iso/ubuntu-*
```

---

## �📦 預設組態

| 元件             | 安裝位置   | 備註                              |
|------------------|------------|-----------------------------------|
| K3s Master        | `k3s-master` VM | 使用 Cloud-Init 自動安裝         |
| Worker Node       | `k3s-worker-1` VM | 自動取得 Token 並加入 K3s Master |
| Elasticsearch     | Master VM  | NodePort 開放 `9200`              |
| Kibana            | Master VM  | NodePort 開放 `5601`              |
| Filebeat / Metricbeat | Master VM | 預設啟動，收集系統日誌與效能     |

---

## 🌐 服務連接資訊

| 服務          | 預設 Port | URL 範例                              | 說明 |
|---------------|-----------|---------------------------------------|------|
| Elasticsearch | `30920`   | http://\<Master_IP\>:30920            | 搜索 API |
| Kibana        | `30561`   | http://\<Master_IP\>:30561            | 視覺化界面 |
| Logstash      | `30544`   | \<Master_IP\>:30544                   | Beats 輸入 |
| Logstash HTTP | `30880`   | http://\<Master_IP\>:30880            | HTTP 輸入 |

### 🔐 預設登入資訊

- **Kibana**: 無需登入（開發環境）
- **Elasticsearch**: 無需認證（開發環境）

> ⚠️ **生產環境建議**: 啟用 Elasticsearch 安全功能和 HTTPS

---

## 🧪 驗證 K3s 節點狀態

```bash
# SSH 進入 master VM
ssh ubuntu@<Master_IP>

# 查詢節點列表
sudo kubectl get nodes
```

你應該會看到：

```
NAME             STATUS   ROLES                  AGE   VERSION
k3s-master       Ready    control-plane,master   2m    v1.x.x+k3s
k3s-worker-1     Ready    <none>                 1m    v1.x.x+k3s
```

---

## 📈 檢視 Kibana UI

在瀏覽器中開啟：

```
http://<Master_IP>:30561
```

### 🎯 建立 Index Pattern

1. 進入 Kibana → Stack Management → Index Patterns
2. 建立以下 Index Pattern：
   - `filebeat-proxmox-*` - Proxmox 系統日誌
   - `metricbeat-proxmox-*` - Proxmox 系統指標
   - `auditbeat-proxmox-*` - Proxmox 安全審計
   - `k3s-logs-*` - K3s 容器日誌

### 📊 建議的 Dashboard

- **系統監控**: CPU、記憶體、磁碟使用率
- **網路監控**: 網路流量、連接狀態
- **日誌分析**: 錯誤日誌、警告訊息
- **安全審計**: 登入嘗試、檔案異動
- **K3s 監控**: Pod 狀態、資源使用

---

## 🧾 延伸規劃

- [ ] 啟用 Elasticsearch 安全功能（X-Pack Security）
- [ ] 設定 HTTPS 和 TLS 加密
- [ ] 新增 Heartbeat 監控服務可用性
- [ ] 整合 Grafana 進行指標視覺化
- [ ] 設定自動化告警和通知
- [ ] 實作日誌輪轉和資料生命週期管理
- [ ] 新增多節點 Elasticsearch 集群支援
- [ ] 實作備份和災難恢復機制
- [ ] 整合 APM (Application Performance Monitoring)
- [ ] 支援自定義 Logstash 管道和 Grok 模式

---

## 🤝 貢獻指南

歡迎提交 Issue 和 Pull Request！

### 開發指南

1. **Fork** 本專案
2. 建立功能分支：`git checkout -b feature/your-feature`
3. 提交變更：`git commit -am 'Add some feature'`
4. 推送到分支：`git push origin feature/your-feature`
5. 建立 **Pull Request**

### 編碼規範

- 使用 `common_functions.sh` 中的共用函數
- 遵循現有的命名規則和註釋風格
- 所有新功能都要包含錯誤處理
- 添加適當的進度顯示和日誌輸出

---

## 📄 授權

本專案採用 MIT 授權 - 查看 [LICENSE](LICENSE) 文件了解詳情。

---

## 🙏 致謝

- [K3s](https://k3s.io/) - 輕量級 Kubernetes 發行版
- [Elastic Stack](https://www.elastic.co/) - 搜索和分析引擎
- [Proxmox VE](https://www.proxmox.com/) - 虛擬化平台
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/) - 雲端映像

---