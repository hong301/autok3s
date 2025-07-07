# ☸️ Auto K3s + ELK Cluster on Proxmox VE (Ansible Enterprise)

企業級 **Ansible** 解決方案，一鍵在 **Proxmox VE** 上部署完整的 K3s + ELK Stack 監控平台！

## 🎯 功能特色

- ☸️ **K3s 集群**: 1 Master + 3 Worker 節點
- 🔍 **完整 ELK Stack**: Elasticsearch + Logstash + Kibana
- 📊 **多層次監控**: Proxmox 主機 + K3s 容器雙重監控
- 🛡️ **安全審計**: Filebeat + Metricbeat + Auditbeat
- 🔧 **Ansible 驅動**: 企業級部署管理和冪等性
- 🚀 **DaemonSet 部署**: 每個節點自動部署監控代理
- 🔄 **可重複部署**: 完全冪等，支持重新執行
- 📋 **角色化管理**: 模組化 Ansible Roles 設計

---

## 🚀 快速開始

### 📦 **第零步：安裝依賴**

由於 PEP 668 限制，現代 Ubuntu/Debian 系統不允許直接使用 pip 安裝全域套件。請選擇以下其中一種方式：

#### 🎯 **推薦方式 1: 使用虛擬環境**
```bash
# 創建虛擬環境
python3 -m venv ansible-env
source ansible-env/bin/activate

# 安裝依賴
pip install -r requirements.txt
```

#### 🎯 **推薦方式 2: 使用 pipx**
```bash
# 安裝 pipx
sudo apt install pipx
# 或 pip install --user pipx

# 安裝 Ansible 和相關套件
pipx install ansible
pipx inject ansible kubernetes proxmoxer requests
```

#### 🎯 **方式 3: 使用系統套件管理器**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install ansible python3-kubernetes python3-proxmoxer python3-requests
```

#### 🎯 **方式 4: 強制安裝 (不推薦)**
```bash
# 僅在了解風險的情況下使用
pip install --break-system-packages ansible kubernetes proxmoxer requests
```

> 💡 **提示**: `ansible_deploy.sh` 腳本會自動處理依賴安裝，支援多種安裝方式！

### 🔍 **第一步：自我檢測**
```bash
git clone https://github.com/hong301/autok3s.git
cd autok3s
ansible-playbook playbooks/self_check.yml
```

### 🚀 **第二步：Ansible 一鍵部署**
```bash
# 方法 1: 使用快速部署腳本
./ansible_deploy.sh

# 方法 2: 直接執行 Ansible
ansible-playbook deploy.yml --ask-become-pass
```

**約 8-10 分鐘完成部署！**

---

## 📁 專案結構

```
autok3s/
├── ansible.cfg                       # 🔧 Ansible 配置
├── inventory/hosts.yml               # 📋 主機清單與變數
├── group_vars/all.yml               # 🌐 全域變數配置
├── deploy.yml                       # 🚀 主要部署 Playbook
├── requirements.txt                 # 📦 Python 依賴清單
├── ansible_deploy.sh               # ⚡ 快速部署腳本
├── test_deploy.sh                  # 🧪 部署測試工具
├── roles/                          # 📁 Ansible Roles
│   ├── proxmox_prepare/            # 🏗️ Proxmox 環境準備
│   ├── vm_template/                # 📋 虛擬機器模板
│   ├── k3s_vms/                   # 🖥️ K3s 虛擬機器創建
│   ├── k3s_cluster/               # ☸️ K3s 集群部署
│   ├── elk_stack/                 # 🔍 ELK Stack 部署
│   ├── logstash/                  # 📊 Logstash 配置
│   ├── beats/                     # 📈 Beats 代理
│   └── proxmox_beats/             # 🖥️ Proxmox 監控
├── playbooks/                     # 📋 輔助 Playbooks
│   ├── self_check.yml            # ✅ 自我檢測
│   └── cleanup.yml               # 🧹 清理部署
├── README.md                      # 📖 主要說明文件
├── TROUBLESHOOTING.md            # 🛠️ 故障排除指南
├── CHANGELOG.md                  # 📋 版本更新日誌
├── PROJECT_SUMMARY.md            # 📊 專案總結
├── meta-data                     # ☁️ Cloud-Init 元資料
└── user-data                     # ☁️ Cloud-Init 使用者資料
```

---

## 🏗️ 架構圖

```
┌─────────────────────────────────────────────┐
│               Proxmox VE Host               │
│  📊 Filebeat + Metricbeat + Auditbeat      │
│                     │                       │
│  ┌─────────────────┼─────────────────────┐  │
│  │            K3s Cluster                │  │
│  │   (1 Master + 3 Worker)               │  │
│  │                                       │  │
│  │  📝 Filebeat → 🔄 Logstash → 🔍 ES   │  │
│  │  📈 Metricbeat ↗     ↓                │  │
│  │                 📊 Kibana             │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

**監控資料流向**:
- **Proxmox 主機**: 系統日誌/指標 → Logstash → Elasticsearch
- **K3s 容器**: 容器日誌/指標 → Logstash → Elasticsearch
- **Kibana**: 視覺化所有監控資料

---

## 🌐 服務連接

| 服務           | 連接埠  | URL 範例                          | 功能                    |
|----------------|---------|-----------------------------------|-------------------------|
| Kibana         | 30561   | http://\<Master_IP\>:30561       | 資料視覺化與查詢         |
| Elasticsearch  | 30920   | http://\<Master_IP\>:30920       | 資料儲存與搜尋           |
| Logstash       | 30544   | \<Master_IP\>:30544               | 資料處理與轉換           |

---

## 📊 Index Patterns

在 Kibana 中建立以下 Index Pattern：

### 📋 Proxmox 主機監控
- `filebeat-proxmox-*` - Proxmox 系統日誌
- `metricbeat-proxmox-*` - Proxmox 系統指標  
- `auditbeat-proxmox-*` - Proxmox 安全審計

### 📋 K3s 集群監控
- `k3s-logs-*` - K3s 容器日誌
- `k3s-metrics-*` - K3s 系統指標

**🔍 推薦儀表板**: 可匯入 Elastic 官方儀表板模板進行快速視覺化

---

## 🔧 部署步驟詳解

### 🔍 **預檢查（推薦）**
```bash
# Ansible 專案自我檢測
ansible-playbook playbooks/self_check.yml
```
- ✅ 檢查專案完整性和 Ansible 語法
- ✅ 驗證依賴套件安裝狀況
- ✅ 確認 Proxmox 環境準備度
- ✅ 檢測潛在配置問題

### 🚀 **Ansible 一鍵部署**
```bash
# 使用快速腳本
./ansible_deploy.sh

# 或直接執行
ansible-playbook deploy.yml --ask-become-pass
```

### 🔧 **分角色執行**
```bash
# 只執行環境準備
ansible-playbook deploy.yml --tags prepare

# 只建立 VM Template
ansible-playbook deploy.yml --tags template

# 只建立 K3s 節點
ansible-playbook deploy.yml --tags vms

# 只安裝 K3s 集群
ansible-playbook deploy.yml --tags k3s

# 只部署 ELK Stack
ansible-playbook deploy.yml --tags elk

# 只安裝 Beats 監控
ansible-playbook deploy.yml --tags beats
```

### 🧹 **環境清理**
```bash
ansible-playbook playbooks/cleanup.yml
```

每個步驟都會顯示執行進度和階段完成狀態，支援冪等重複執行。

---

## 🛠️ 環境需求

### 📋 硬體需求
- **CPU**: 最少 8 核心 (推薦 12+ 核心)
- **記憶體**: 最少 16GB (推薦 32GB+)
- **儲存**: 最少 100GB 可用空間
- **網路**: 穩定的網路連線

### 📋 軟體需求
- ✅ **Proxmox VE** (已設定 local-lvm 儲存)
- ✅ **Ansible** 和 Python 套件
- ✅ **SSH 金鑰**: `~/.ssh/id_rsa.pub`
- ✅ **Root 權限** 或 sudo 存取
- ✅ **網路連線** (下載套件和映像)

### 📋 VM 資源配置
- **Master**: 4 CPU, 8GB RAM, 32GB 儲存
- **Worker**: 2 CPU, 4GB RAM, 32GB 儲存
- **總計**: 10 CPU, 20GB RAM, 128GB 儲存

### 📋 Python 依賴套件
```bash
pip install ansible kubernetes proxmoxer requests
```

---

## 🔧 故障排除

### 🔍 **快速除錯步驟**
```bash
# 1. 執行 Ansible 自我檢測
ansible-playbook playbooks/self_check.yml

# 2. 檢查 Ansible 版本
ansible --version

# 3. 詳細日誌模式執行
ansible-playbook deploy.yml -vvv
```

### 📚 **詳細故障排除指南**
請參考完整的故障排除文件：[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)

內容包括：
- Ansible 相關問題解決
- Proxmox API 認證問題
- K3s 集群部署問題  
- ELK Stack 配置問題
- 網路連線問題
- 常用除錯命令集

### 🔍 **VM 網路問題**
```bash
# 檢查 VM 狀態
ansible-playbook deploy.yml --tags vms --check

# 手動檢查 guest-agent
qm guest cmd <VMID> qemu-agent-command --command '{"execute": "guest-ping"}'
```

### 🔍 **K3s 集群問題**
```bash
# 檢查 K3s 狀態
ansible k3s_master -m shell -a "kubectl get nodes -o wide"

# 檢查服務狀態
ansible k3s_cluster -m shell -a "systemctl status k3s" --become
```

### 🔍 **ELK 服務問題**
```bash
# 檢查 Pod 狀態
ansible k3s_master -m shell -a "kubectl get pods -n logging"

# 檢查服務連線
curl -X GET "http://<Master_IP>:30920/_cluster/health"
curl -X GET "http://<Master_IP>:30561/api/status"
```

### 🔍 **Beats 監控問題**
```bash
# 檢查 Proxmox 主機 Beats
ansible proxmox -m shell -a "systemctl status filebeat metricbeat auditbeat" --become

# 檢查 K3s DaemonSet
ansible k3s_master -m shell -a "kubectl get ds -n logging"
```

### 🧹 **完全清理環境**
```bash
# 使用 Ansible 清理
ansible-playbook playbooks/cleanup.yml

# 手動清理 (如果需要)
for vmid in 101 102 103 104 9000; do qm destroy $vmid --purge 2>/dev/null; done
rm -f /var/lib/vz/template/iso/ubuntu-*
```

---

## 🎯 Ansible 版本優勢

### 🔧 **企業級管理**
- **冪等性**: 可安全重複執行，不會造成重複配置
- **角色化**: 模組化設計，易於維護和擴展
- **庫存管理**: 動態主機清單和變數管理
- **錯誤處理**: 優雅的錯誤處理和回滾機制

### 📊 **可觀測性**
- **任務追蹤**: 詳細的執行日誌和狀態回報
- **標籤支援**: 可選擇性執行特定角色或任務
- **乾執行**: --check 模式預覽變更
- **並行執行**: 多主機同時部署

### 🔄 **維運友善**
- **配置即程式碼**: YAML 格式易讀易維護
- **版本控制**: 完整的基礎設施即程式碼
- **模板系統**: Jinja2 模板動態配置
- **擴展性**: 輕鬆加入新節點或服務

---

## 🎯 延伸功能

### 🔒 安全增強
- [ ] Ansible Vault 加密敏感資料
- [ ] X-Pack Security (用戶認證)
- [ ] HTTPS/TLS 加密
- [ ] 網路隔離與防火牆

### 📊 監控增強
- [ ] Grafana 整合 Playbook
- [ ] 自動告警配置 (Watcher)
- [ ] 效能調優 Playbook
- [ ] 自動擴容機制

### 🔧 營運增強
- [ ] 資料生命週期管理 (ILM)
- [ ] 多節點 Elasticsearch 集群
- [ ] 備份與災難恢復 Playbook
- [ ] 滾動更新機制

### 🌐 多環境支援
- [ ] 開發/測試/生產環境分離
- [ ] 多 Proxmox 節點支援
- [ ] 混合雲部署支援
- [ ] GitOps 整合

---

## 📚 相關文件

- 📖 **[README.md](README.md)** - 主要說明文件 (本檔案)
- 🛠️ **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - 詳細故障排除指南
- 📋 **[CHANGELOG.md](CHANGELOG.md)** - 版本更新日誌與功能演進
- 📊 **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - 專案總結與架構說明
- 🧪 **[test_deploy.sh](test_deploy.sh)** - 部署測試工具

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

### 💡 **如何貢獻**
1. Fork 專案
2. 建立功能分支: `git checkout -b feature/your-feature`
3. 提交變更: `git commit -am 'Add feature'`
4. 推送: `git push origin feature/your-feature`
5. 建立 Pull Request

### 🧪 **開發指南**
```bash
# 語法檢查
ansible-playbook --syntax-check deploy.yml

# 乾執行測試
ansible-playbook deploy.yml --check

# 單一角色測試
ansible-playbook deploy.yml --tags prepare --check

# 使用測試工具
./test_deploy.sh
```

### 🐛 **回報問題**
- 查看 [TROUBLESHOOTING.md](TROUBLESHOOTING.md) 故障排除指南
- 使用 GitHub Issues 回報問題
- 提供詳細的環境資訊和錯誤日誌

---

## 📄 授權

MIT License - 查看 [LICENSE](LICENSE) 了解詳情。

---

## 🙏 致謝

**感謝開源社群**: [Ansible](https://www.ansible.com/) | [K3s](https://k3s.io/) | [Elastic Stack](https://www.elastic.co/) | [Proxmox VE](https://www.proxmox.com/)

**🆕 版本**: v2.0.0 - Ansible 企業級部署解決方案 ⭐ **當前版本**

> **📝 專案特色**: 企業級 Ansible 解決方案，提供冪等性、可擴展性和專業運維管理。詳見 [`CHANGELOG.md`](CHANGELOG.md)。
