#!/bin/bash
# K3s 部署修復腳本

echo "=== K3s 部署修復腳本 ==="

# VM IP 地址
MASTER_IP="10.110.0.70"
WORKER1_IP="10.110.0.71"
WORKER2_IP="10.110.0.72"

# SSH 公鑰
SSH_PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDfWp/8zoAlxO4N8fUnXoknIltAZk35so+JRcB+G95Z00NllcGKJT4ViRhaKX+Y728/abqu9y7twx/ywRGUnce9JqL+L1acv3aiKVcQDn2b5TyyZ73roU7KG3J3c3eGIKQ+dSO1/Ya498KPIh8grQMAjBYXBtBTqsFhOFxjacVCzKnS1QX0Rs8ryfyNB8L8B7rcoD5gB/WmMxuUINZAc6nZaN/4gbonb7FALNDt/FN916qu6wikA5/8rj2Iml09X6PDptPD6N8FBsZSzRas5NPpBt0++4zKmVyUAL2OatIvcnUIL16lREezFq6ENDsZGsM+tGL05pU+1AvLMeZmdp86isd7Zr71Y6wq4GD9L75PuyKyIhTBVHQ25mMgH/0Fduqr2n6ebEjZUsis/hkZMl0etvvwwnKQP10fm5sQFEkAxYw10xzeCtivQhvAdekeHmcDAFMgWiTj0ELfmyMEr/Xdot9bo3fC1FdkiZVXQT2WVAbgB15RHUKK2joMiA4gLmEuJ4ltCFSHC2ovCco58KbN93saM9LUw1Gt+Kb6gAmzz+zLBq7fc1/QET3dk6WhwnrkGBxGHZ9QYfZnP+AFHZywQq7gM+Yd0/ixipQJKGfraxFPBCX5yKuMBJenOtg9GQj+s3jZsOv3NMIX1JMrM7EjNxyYC8ovJSaRqHNjn5KPNw== root@devops"

# 修復函數
fix_ssh_keys() {
    local ip=$1
    local node_name=$2
    
    echo "修復 $node_name ($ip) 的 SSH 密鑰..."
    
    # 使用密碼方式重新設置 SSH 密鑰
    sshpass -p "FsI!^@#Zg" ssh -o StrictHostKeyChecking=no ubuntu@$ip "
        echo '$SSH_PUB_KEY' > ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        chmod 700 ~/.ssh
        echo 'SSH 密鑰已重新設置'
    " || echo "❌ $node_name SSH 密鑰設置失敗"
    
    # 測試 SSH 密鑰連線
    if ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no ubuntu@$ip "echo 'SSH 密鑰連線成功'" 2>/dev/null; then
        echo "✅ $node_name SSH 密鑰連線成功"
    else
        echo "❌ $node_name SSH 密鑰連線失敗"
    fi
}

fix_master_setup() {
    echo "修復 Master 節點的 k3s-setup..."
    
    ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
        echo '檢查 k3s-setup 服務狀態...'
        sudo systemctl status k3s-setup --no-pager || true
        
        echo '手動執行 k3s-setup 腳本...'
        sudo /opt/k3s-setup.sh
        
        echo '檢查 Helm repositories...'
        helm repo list || echo '沒有 repositories'
        
        echo '重新設置 Helm repositories...'
        helm repo add jetstack https://charts.jetstack.io || true
        helm repo update || true
        
        echo '檢查 cert-manager 狀態...'
        kubectl get pods -n cert-manager
        
        echo '如果 cert-manager 未安裝，嘗試安裝...'
        helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace || echo 'cert-manager 可能已存在'
    "
}

# 安裝 sshpass（如果需要）
if ! command -v sshpass &> /dev/null; then
    echo "安裝 sshpass..."
    apt update && apt install -y sshpass
fi

echo "1. 修復 SSH 密鑰認證..."
fix_ssh_keys $MASTER_IP "Master"
fix_ssh_keys $WORKER1_IP "Worker-1"
fix_ssh_keys $WORKER2_IP "Worker-2"

echo ""
echo "2. 修復 Master 節點設置..."
fix_master_setup

echo ""
echo "3. 檢查最終狀態..."
ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
    echo '=== 最終叢集狀態 ==='
    kubectl get nodes -o wide
    echo ''
    echo '=== cert-manager 狀態 ==='
    kubectl get pods -n cert-manager
    echo ''
    echo '=== Helm repositories ==='
    helm repo list
"

echo ""
echo "=== 修復完成 ==="
