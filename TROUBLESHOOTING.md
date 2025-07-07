# 🛠️ Troubleshooting Guide - Auto K3s + ELK Ansible 部署

## 常見問題與解決方案

### 1. Ansible 相關問題

#### ❌ 問題：`ansible-playbook: command not found`
**原因**：Ansible 未安裝或環境配置錯誤

**解決方案**：
```bash
# 安裝 pip
apt update && apt install python3-pip -y

# 安裝 Ansible 和依賴
pip3 install -r requirements.txt --break-system-packages

# 或使用 apt 安裝
apt install ansible -y
```

#### ❌ 問題：`proxmoxer` 模組錯誤
**原因**：Proxmox API 庫未安裝

**解決方案**：
```bash
pip3 install proxmoxer requests --break-system-packages
```

#### ❌ 問題：Inventory 解析錯誤
**原因**：`inventory/hosts.yml` 語法錯誤

**解決方案**：
```bash
# 檢查語法
ansible-inventory --list

# 檢查特定主機
ansible-inventory --host k3s-master-01
```

### 2. Proxmox 相關問題

#### ❌ 問題：Proxmox API 認證失敗
**原因**：API 憑證配置錯誤

**解決方案**：
1. 檢查 `group_vars/all.yml` 中的 Proxmox 配置
2. 確認使用者權限：
```bash
# 檢查使用者權限
pveum user list
pveum acl list
```

#### ❌ 問題：虛擬機器建立失敗
**原因**：資源不足或存儲配置錯誤

**解決方案**：
```bash
# 檢查節點資源
pvesh get /nodes/$(hostname)/status

# 檢查存儲
pvesh get /storage

# 檢查現有虛擬機器
qm list
```

#### ❌ 問題：雲映像下載失敗
**原因**：網路連線問題

**解決方案**：
```bash
# 手動下載映像
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img \
     -O /var/lib/vz/template/iso/ubuntu-22.04-server-cloudimg-amd64.img

# 檢查檔案
ls -la /var/lib/vz/template/iso/
```

### 3. K3s 相關問題

#### ❌ 問題：K3s 安裝失敗
**原因**：虛擬機器無法連線或資源不足

**解決方案**：
```bash
# 檢查虛擬機器狀態
qm list
qm status <VMID>

# 連線到虛擬機器
ssh ubuntu@<VM_IP>

# 檢查 K3s 狀態
sudo systemctl status k3s
```

#### ❌ 問題：Worker 節點無法加入集群
**原因**：Token 錯誤或網路問題

**解決方案**：
```bash
# 在 Master 節點上獲取正確的 Token
sudo cat /var/lib/rancher/k3s/server/node-token

# 檢查網路連通性
ping <MASTER_IP>
telnet <MASTER_IP> 6443
```

### 4. ELK Stack 相關問題

#### ❌ 問題：Elasticsearch 無法啟動
**原因**：記憶體不足或存儲問題

**解決方案**：
```bash
# 檢查 Pod 狀態
kubectl get pods -n logging

# 檢查 Pod 日誌
kubectl logs -n logging <elasticsearch-pod>

# 檢查節點資源
kubectl top nodes
```

#### ❌ 問題：Kibana 無法連線到 Elasticsearch
**原因**：服務配置錯誤

**解決方案**：
```bash
# 檢查服務狀態
kubectl get svc -n logging

# 檢查 Elasticsearch 服務
kubectl port-forward -n logging svc/elasticsearch 9200:9200
curl http://localhost:9200
```

#### ❌ 問題：Beats 無法發送資料
**原因**：配置錯誤或權限問題

**解決方案**：
```bash
# 檢查 Beats 狀態
kubectl get pods -n logging | grep beat

# 檢查 Beats 設定
kubectl describe configmap -n logging filebeat-config
```

### 5. 網路相關問題

#### ❌ 問題：節點間無法通訊
**原因**：防火牆或 Flannel 配置問題

**解決方案**：
```bash
# 檢查防火牆狀態
ufw status

# 檢查 Flannel 狀態
kubectl get pods -n kube-system | grep flannel

# 檢查網路政策
kubectl get networkpolicy --all-namespaces
```

### 6. 存儲相關問題

#### ❌ 問題：PVC 無法綁定
**原因**：存儲類別配置錯誤

**解決方案**：
```bash
# 檢查存儲類別
kubectl get storageclass

# 檢查 PV/PVC 狀態
kubectl get pv,pvc -n logging
```

## 🔧 常用除錯命令

### Ansible 除錯
```bash
# 詳細輸出模式
ansible-playbook deploy.yml -vvv

# 僅執行特定 Role
ansible-playbook deploy.yml --tags "k3s_cluster"

# 跳過特定步驟
ansible-playbook deploy.yml --skip-tags "elk_stack"

# 檢查語法
ansible-playbook deploy.yml --syntax-check

# 乾燥運行
ansible-playbook deploy.yml --check --diff
```

### Proxmox 除錯
```bash
# 檢查虛擬機器
qm list
qm config <VMID>
qm monitor <VMID>

# 檢查存儲
pvesm status
pvesm list <STORAGE>

# 檢查網路
ip route
brctl show
```

### K3s 除錯
```bash
# 檢查集群狀態
kubectl get nodes -o wide
kubectl get pods --all-namespaces
kubectl cluster-info

# 檢查服務
kubectl get svc --all-namespaces

# 檢查事件
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 系統資源除錯
```bash
# 檢查記憶體
free -h
cat /proc/meminfo

# 檢查磁碟
df -h
lsblk

# 檢查 CPU
top
htop
```

## 🚨 緊急清理命令

### 完全清理部署
```bash
# 執行清理 Playbook
ansible-playbook playbooks/cleanup.yml

# 手動清理虛擬機器
qm stop <VMID> && qm destroy <VMID>

# 清理模板
qm destroy 9000
```

### 重置網路
```bash
# 重啟網路服務
systemctl restart networking

# 重啟 Proxmox 網路
systemctl restart pve-cluster
```

## 📞 取得協助

1. **檢查日誌**：所有操作都會記錄在 Ansible 輸出中
2. **執行自我檢測**：`ansible-playbook playbooks/self_check.yml`
3. **查看官方文件**：
   - [Proxmox VE](https://pve.proxmox.com/wiki/Main_Page)
   - [K3s](https://k3s.io/)
   - [Elastic Stack](https://www.elastic.co/what-is/elk-stack)
4. **社群支援**：在相關專案 GitHub 頁面提出 Issue

## 🔄 版本歷史

- **v2.0**: Ansible 版本重構，增加企業級功能
- **v1.0**: 原始 Shell Script 版本

更多詳細資訊請參考 `README.md`。
