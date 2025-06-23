# 🚀 Auto K3s Cluster on Proxmox VE

自動化在 Proxmox VE 上部署 **K3s Master + Worker** 節點，只需一條指令，從建立 Template 到完成 Join，全程自動化。

## 🧰 特色功能

- ✅ 自動下載 Ubuntu Cloud Image 並轉換為 `.qcow2`
- ✅ 自動建立 Cloud-Init Template（VMID=9000）
- ✅ 自動建立 Master 節點並安裝 K3s Server
- ✅ 自動取得 K3s Token 與 IP
- ✅ 自動建立 Worker 並加入 Master
- ✅ 使用 `cloud-init` 設定 SSH Key、runcmd 指令

---

## 📁 專案結構

autok3s/
├── auto_k3s.sh # 主腳本：自動建立 K3s 環境
├── README.md # 本說明文件

---

## 🛠️ 執行條件

- ✅ 已安裝 Proxmox VE
- ✅ 已配置 `local-lvm` 儲存空間
- ✅ 使用者已有 SSH 公鑰：`~/.ssh/id_rsa.pub`
- ✅ 具 sudo 權限（可透過 root 或 `sudo -i`）

---

## 🚀 快速開始

1️⃣ 儲存腳本

```bash
git clone https://github.com/hong301/autok3s.git
cd autok3s
chmod +x auto_k3s.sh

2️⃣ 執行自動建構流程（在 Proxmox VE 上執行）

sudo ./auto_k3s_cluster.sh


🧪 建立結果
建立 VM：

k3s-master（VMID=9100）

k3s-worker-1（VMID=9101）

Master 會自動安裝 K3s

Worker 會自動使用 token 加入 Master

🧾 驗證方法

# SSH 進入 master 機器
ssh ubuntu@<master-ip>

# 驗證節點狀態
kubectl get nodes

你應該會看到：

NAME            STATUS   ROLES                  AGE   VERSION
k3s-master      Ready    control-plane,master   1m    v1.xx.x+k3s
k3s-worker-1    Ready    <none>                 30s   v1.xx.x+k3s
