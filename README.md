# ☸️ Auto K3s + ELK Cluster on Proxmox VE

本專案可在 **Proxmox VE** 上全自動部署一組：

- K3s 輕量 Kubernetes 叢集（Master + Worker）
- Master 節點同時部署完整 ELK Stack：
  - Elasticsearch（9200）
  - Kibana（5601）
  - Filebeat / Metricbeat（Log 與 Metrics 收集）

---

## 🧰 功能特色

- ✅ 自動下載並轉換 Ubuntu Cloud Image（支援 Cloud-Init）
- ✅ 建立支援 Cloud-Init 的 VM Template（VMID=9000）
- ✅ 自動建立 K3s Master 與 Worker VM
- ✅ Master 安裝 ELK Stack，並透過 NodePort 暴露服務
- ✅ Filebeat / Metricbeat 自動安裝、啟動，收集系統資訊

---

## 📁 專案結構

```
autok3s/
├── auto_k3s_cluster.sh       # 主腳本：自動化部署 ELK + K3s
├── README.md                 # 本說明文件
```

---

## 🛠️ 環境需求

- ✅ Proxmox VE（已建立 local-lvm 儲存）
- ✅ 能上網下載套件（wget、apt）
- ✅ 已產生 SSH 金鑰：`~/.ssh/id_rsa.pub`
- ✅ 使用者具備 root 權限（或 `sudo`）

---

## 🚀 快速開始

1️⃣ 下載並設定

```bash
git clone https://github.com/hong301/autok3s.git
cd autok3s
chmod +x auto_k3s_cluster.sh
```

2️⃣ 執行主腳本（建議使用 root 或 `sudo`）

```bash
sudo ./auto_k3s_cluster.sh
```

3️⃣ 等待約 1~2 分鐘，自動完成以下操作：

- 建立 Ubuntu Template
- 建立 Master + Worker VM
- Master 自動安裝 K3s + ELK Stack
- Worker 自動加入 Master 成為 Node

---

## 📦 預設組態

| 元件             | 安裝位置   | 備註                              |
|------------------|------------|-----------------------------------|
| K3s Master        | `k3s-master` VM | 使用 Cloud-Init 自動安裝         |
| Worker Node       | `k3s-worker-1` VM | 自動取得 Token 並加入 K3s Master |
| Elasticsearch     | Master VM  | NodePort 開放 `9200`              |
| Kibana            | Master VM  | NodePort 開放 `5601`              |
| Filebeat / Metricbeat | Master VM | 預設啟動，收集系統日誌與效能     |

---

## 🌐 服務連接資訊

| 服務         | 預設 Port | URL 範例                     |
|--------------|-----------|------------------------------|
| Elasticsearch | `9200`    | http://<Master IP>:9200     |
| Kibana        | `5601`    | http://<Master IP>:5601     |

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
http://<Master_IP>:5601
```

首次不需帳密，進入 Kibana UI 後可連接至 Elasticsearch，並建立 Index Pattern 來查看 Filebeat/Metricbeat 資料。

---

## 🧾 延伸規劃

- [ ] 多 Worker 節點自動建立
- [ ] 加入 Logstash / Beats 自定管線
- [ ] 設定 Kibana 視覺化 Dashboard 自動導入
- [ ] 啟用 Elasticsearch 安全（帳密登入）

---