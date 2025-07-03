# ☸️ Auto K3s + ELK Cluster on Proxmox VE

一鍵在 **Proxmox VE** 上部署完整的 K3s + ELK Stack 監控解決方案。

## 🎯 功能特色

- ☸️ **K3s 集群**: 1 Master + 3 Worker 節點
- 🔍 **完整 ELK Stack**: Elasticsearch + Logstash + Kibana
- 📊 **多層次監控**: Proxmox 主機 + K3s 容器
- 🛡️ **安全審計**: Filebeat + Metricbeat + Auditbeat
- 🔧 **模組化設計**: 可單獨執行或一鍵部署

---

## 🚀 快速開始

```bash
git clone https://github.com/hong301/autok3s.git
cd autok3s && chmod +x deploy_k3s_elk.sh
sudo ./deploy_k3s_elk.sh
```

**約 5-8 分鐘完成部署！**

---

## 📁 專案結構

```
autok3s/
├── common_functions.sh           # 🔧 共用函數庫
├── 01_build_template.sh          # 🏗️ 建立 VM Template
├── 02_clone_k3s_nodes.sh         # 🖥️ 建立 K3s 節點
├── 03_install_k3s.sh             # ☸️ 安裝 K3s Cluster
├── 04_install_elk_stack.sh       # 🔍 安裝 E + K
├── 05_install_logstash.sh        # 🔄 安裝 Logstash
├── 06_install_beats_on_proxmox.sh # 📊 Proxmox Beats
├── 07_install_k3s_filebeat.sh    # 📝 K3s Filebeat
└── deploy_k3s_elk.sh             # 🚀 **一鍵部署**
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
│  │                                       │  │
│  │  📝 Filebeat → 🔄 Logstash → 🔍 ES   │  │
│  │                      ↓                │  │
│  │                 📊 Kibana             │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## 🌐 服務連接

| 服務           | 連接埠  | URL 範例                          |
|----------------|---------|-----------------------------------|
| Kibana         | 30561   | http://\<Master_IP\>:30561       |
| Elasticsearch  | 30920   | http://\<Master_IP\>:30920       |
| Logstash       | 30544   | \<Master_IP\>:30544               |

---

## 📊 Index Patterns

在 Kibana 中建立以下 Index Pattern：
- `filebeat-proxmox-*` - Proxmox 系統日誌
- `metricbeat-proxmox-*` - Proxmox 系統指標  
- `auditbeat-proxmox-*` - Proxmox 安全審計
- `k3s-logs-*` - K3s 容器日誌

---

## 🔧 分步驟部署

```bash
./01_build_template.sh          # 建立 Template
./02_clone_k3s_nodes.sh         # 建立 VM
./03_install_k3s.sh             # 安裝 K3s
./04_install_elk_stack.sh       # 安裝 E+K
./05_install_logstash.sh        # 安裝 Logstash
./07_install_k3s_filebeat.sh    # K3s Filebeat
./06_install_beats_on_proxmox.sh # Proxmox Beats
```

---

## 🛠️ 環境需求

- ✅ Proxmox VE (已設定 local-lvm 儲存)
- ✅ 網路連線 (下載套件和映像)
- ✅ SSH 金鑰: `~/.ssh/id_rsa.pub`
- ✅ Root 權限或 sudo

---

## 🔧 故障排除

### VM 無法取得 IP
```bash
qm guest cmd <VMID> qemu-agent-command --command '{"execute": "guest-ping"}'
ssh ubuntu@<VM_IP> "sudo systemctl start qemu-guest-agent"
```

### K3s 問題
```bash
ssh ubuntu@<Master_IP> "sudo systemctl status k3s"
ssh ubuntu@<Master_IP> "sudo journalctl -u k3s -f"
```

### ELK 問題
```bash
ssh ubuntu@<Master_IP> "kubectl get pods -n logging"
ssh ubuntu@<Master_IP> "kubectl logs -n logging <pod-name>"
curl -X GET "http://<Master_IP>:30920/_cat/indices?v"
```

### 清理環境
```bash
# 刪除所有 VM
for vmid in 101 102 103 104 9000; do qm destroy $vmid --purge; done
rm -f /var/lib/vz/template/iso/ubuntu-*
```

---

## 🎯 延伸功能

- [ ] X-Pack Security (用戶認證)
- [ ] HTTPS/TLS 加密
- [ ] Grafana 整合
- [ ] 自動告警
- [ ] 資料生命週期管理
- [ ] 多節點 Elasticsearch

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
