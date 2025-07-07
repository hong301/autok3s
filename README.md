# ☸️ Auto K3s + ELK Cluster on Proxmox VE

一鍵在 **Proxmox VE** 上部署完整的 K3s + ELK Stack 監控解決方案。

## 🎯 功能特色

- ☸️ **K3s 集群**: 1 Master + 3 Worker 節點
- 🔍 **完整 ELK Stack**: Elasticsearch + Logstash + Kibana
- 📊 **多層次監控**: Proxmox 主機 + K3s 容器雙重監控
- 🛡️ **安全審計**: Filebeat + Metricbeat + Auditbeat
- 🔧 **模組化設計**: 可單獨執行或一鍵部署
- 🚀 **DaemonSet 部署**: 每個節點自動部署監控代理

---

## 🚀 快速開始

### 🔍 **第一步：自我檢測**
```bash
git clone https://github.com/hong301/autok3s.git
cd autok3s && chmod +x *.sh
./self_check.sh
```

### 🚀 **第二步：一鍵部署**
```bash
sudo ./deploy_k3s_elk.sh
```

**約 8-10 分鐘完成部署！**

---

## 📁 專案結構

```
autok3s/
├── common_functions.sh           # 🔧 共用函數庫
├── 01_build_template.sh          # 🏗️ 建立 VM Template
├── 02_clone_k3s_nodes.sh         # 🖥️ 建立 K3s 節點 (1M+3W)
├── 03_install_k3s.sh             # ☸️ 安裝 K3s Cluster
├── 04_install_elk_stack.sh       # 🔍 安裝 Elasticsearch + Kibana
├── 05_install_logstash.sh        # 🔄 安裝 Logstash
├── 06_install_beats_on_proxmox.sh # 📊 Proxmox 主機 Beats
├── 07_install_k3s_filebeat.sh    # 📝 K3s Filebeat DaemonSet
├── 08_install_k3s_metricbeat.sh  # 📈 K3s Metricbeat DaemonSet
├── deploy_k3s_elk.sh             # 🚀 **一鍵部署腳本**
├── self_check.sh                 # 🔍 **專案自我檢測**
├── meta-data & user-data         # Cloud-init 設定檔
└── README.md                     # 📖 專案說明
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

### � **預檢查（推薦）**
```bash
# 專案自我檢測
./self_check.sh
```
- ✅ 檢查專案完整性
- ✅ 驗證語法正確性  
- ✅ 確認環境準備度
- ✅ 檢測潛在問題

### �🚀 **一鍵部署**
```bash
sudo ./deploy_k3s_elk.sh
```

### 🔧 **分步驟執行**
```bash
# 步驟 1: 建立 VM Template
sudo ./01_build_template.sh

# 步驟 2: 建立 K3s 節點 (1M+3W)  
sudo ./02_clone_k3s_nodes.sh

# 步驟 3: 安裝 K3s 集群
sudo ./03_install_k3s.sh

# 步驟 4: 安裝 Elasticsearch + Kibana
sudo ./04_install_elk_stack.sh

# 步驟 5: 安裝 Logstash
sudo ./05_install_logstash.sh

# 步驟 6: 安裝 K3s Filebeat (DaemonSet)
sudo ./07_install_k3s_filebeat.sh

# 步驟 7: 安裝 K3s Metricbeat (DaemonSet)
sudo ./08_install_k3s_metricbeat.sh

# 步驟 8: 安裝 Proxmox 主機 Beats
sudo ./06_install_beats_on_proxmox.sh
```

每個步驟都會顯示執行進度和階段完成狀態。

---

## 🛠️ 環境需求

### 📋 硬體需求
- **CPU**: 最少 8 核心 (推薦 12+ 核心)
- **記憶體**: 最少 16GB (推薦 32GB+)
- **儲存**: 最少 100GB 可用空間
- **網路**: 穩定的網路連線

### 📋 軟體需求
- ✅ **Proxmox VE** (已設定 local-lvm 儲存)
- ✅ **SSH 金鑰**: `~/.ssh/id_rsa.pub`
- ✅ **Root 權限** 或 sudo 存取
- ✅ **網路連線** (下載套件和映像)

### 📋 VM 資源配置
- **Master**: 4 CPU, 8GB RAM, 32GB 儲存
- **Worker**: 2 CPU, 4GB RAM, 32GB 儲存
- **總計**: 10 CPU, 20GB RAM, 128GB 儲存

---

## 🔧 故障排除

### 🔍 **預部署檢查**
```bash
# 1. 執行自我檢測
./self_check.sh

# 2. 確認檢測結果
#    - ✅ 全部通過：可直接部署
#    - ⚠️  有警告：檢查警告項目
#    - ❌ 有錯誤：修復後再檢測
```

### 🔍 **VM 無法取得 IP**
```bash
# 檢查 guest-agent 狀態
qm guest cmd <VMID> qemu-agent-command --command '{"execute": "guest-ping"}'

# 重啟 guest-agent
ssh ubuntu@<VM_IP> "sudo systemctl restart qemu-guest-agent"
```

### 🔍 K3s 問題
```bash
# 檢查 K3s 狀態
ssh ubuntu@<Master_IP> "sudo systemctl status k3s"
ssh ubuntu@<Master_IP> "sudo journalctl -u k3s -f"

# 檢查節點狀態
ssh ubuntu@<Master_IP> "kubectl get nodes -o wide"
```

### 🔍 ELK 問題
```bash
# 檢查 Pod 狀態
ssh ubuntu@<Master_IP> "kubectl get pods -n logging"
ssh ubuntu@<Master_IP> "kubectl logs -n logging <pod-name>"

# 檢查 Elasticsearch 索引
curl -X GET "http://<Master_IP>:30920/_cat/indices?v"

# 檢查 Kibana 連線
curl -X GET "http://<Master_IP>:30561/api/status"
```

### 🔍 Beats 問題
```bash
# 檢查 Proxmox 主機 Beats 狀態
systemctl status filebeat metricbeat auditbeat

# 檢查 K3s DaemonSet 狀態
ssh ubuntu@<Master_IP> "kubectl get ds -n logging"
```

### 🧹 清理環境
```bash
# 刪除所有 VM
for vmid in 101 102 103 104 9000; do qm destroy $vmid --purge; done

# 清理下載的映像
rm -f /var/lib/vz/template/iso/ubuntu-*

# 清理 SSH known_hosts
ssh-keygen -R <VM_IP>
```

---

## 🎯 延伸功能

### 🔒 安全增強
- [ ] X-Pack Security (用戶認證)
- [ ] HTTPS/TLS 加密
- [ ] 網路隔離與防火牆

### 📊 監控增強
- [ ] Grafana 整合
- [ ] 自動告警 (Watcher)
- [ ] 效能調優

### 🔧 營運增強
- [ ] 資料生命週期管理 (ILM)
- [ ] 多節點 Elasticsearch
- [ ] 備份與災難恢復

---

## 🤝 貢獻

歡迎提交 Issue 和 Pull Request！

1. Fork 專案
2. 建立功能分支: `git checkout -b feature/your-feature`
3. 提交變更: `git commit -am 'Add feature'`
4. 推送: `git push origin feature/your-feature`
5. 建立 Pull Request

---

## 📄 授權

MIT License - 查看 [LICENSE](LICENSE) 了解詳情。

---

**🙏 致謝**: [K3s](https://k3s.io/) | [Elastic Stack](https://www.elastic.co/) | [Proxmox VE](https://www.proxmox.com/)
