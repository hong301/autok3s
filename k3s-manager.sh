#!/bin/bash
# K3s 叢集管理工具

set -e

source $(dirname "$0")/config.sh

# 設定 VM 密碼
VM_PASSWORD="$CIPASSWORD"

# 顯示使用說明
show_help() {
    echo "K3s 叢集管理工具"
    echo "用法: $0 [命令] [選項]"
    echo ""
    echo "可用命令:"
    echo "  status      顯示叢集狀態"
    echo "  get-token   取得 master 節點的 token"
    echo "  join        協助 worker 節點加入叢集"
    echo "  list-nodes  列出所有 K3s 節點"
    echo "  cleanup     清理指定的 VM"
    echo "  backup      備份 K3s 配置"
    echo "  logs        查看 K3s 服務日誌"
    echo ""
    echo "範例:"
    echo "  $0 status 100                    # 檢查 VM 100 的 K3s 狀態"
    echo "  $0 get-token 100                 # 取得 VM 100 的 join token"
    echo "  $0 join 101 100                  # 讓 VM 101 加入 VM 100 的叢集"
    echo "  $0 cleanup 100-110               # 清理 VM 100 到 110"
    echo "  $0 list-nodes 100                # 列出 VM 100 叢集的所有節點"
}

# 取得 VM IP
get_vm_ip() {
    local vm_id=$1
    local timeout=30
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if qm guest cmd $vm_id network-get-interfaces 2>/dev/null | grep -q "ip-address"; then
            local ip=$(qm guest cmd $vm_id network-get-interfaces 2>/dev/null | \
                      jq -r '.[] | select(.name != "lo") | ."ip-addresses"[]? | select(."ip-address-type" == "ipv4") | ."ip-address"' 2>/dev/null | \
                      grep -v "127.0.0.1" | head -1)
            
            if [[ -n "$ip" && "$ip" != "null" ]]; then
                echo "$ip"
                return 0
            fi
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    return 1
}

# 檢查 VM 狀態
check_vm_status() {
    local vm_id=$1
    
    if ! qm status $vm_id &>/dev/null; then
        echo "[ERROR] VM $vm_id 不存在"
        return 1
    fi
    
    local status=$(qm status $vm_id | awk '{print $2}')
    if [[ "$status" != "running" ]]; then
        echo "[ERROR] VM $vm_id 狀態: $status (需要 running)"
        return 1
    fi
    
    return 0
}

# 命令處理
case "${1:-help}" in
    status)
        if [[ -z "$2" ]]; then
            echo "[ERROR] 請指定 VM ID"
            echo "用法: $0 status <VM_ID>"
            exit 1
        fi
        
        VM_ID=$2
        if ! check_vm_status $VM_ID; then
            exit 1
        fi
        
        VM_IP=$(get_vm_ip $VM_ID)
        if [[ -z "$VM_IP" ]]; then
            echo "[ERROR] 無法取得 VM $VM_ID 的 IP"
            exit 1
        fi
        
        echo "VM $VM_ID 狀態檢查 (IP: $VM_IP):"
        echo "=================================="
        
        # 檢查 SSH 連接
        if sshpass -p "$VM_PASSWORD" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$VM_IP "echo 'SSH OK'" 2>/dev/null; then
            echo "✅ SSH 連接: 正常"
        else
            echo "❌ SSH 連接: 失敗"
            exit 1
        fi
        
        # 檢查 K3s 服務
        if sshpass -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ubuntu@$VM_IP "sudo systemctl is-active k3s" 2>/dev/null | grep -q "active"; then
            echo "✅ K3s 服務: 執行中"
            
            # 檢查 kubectl
            if sshpass -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ubuntu@$VM_IP "kubectl get nodes" 2>/dev/null; then
                echo "✅ kubectl: 正常"
            else
                echo "❌ kubectl: 失敗"
            fi
        else
            echo "❌ K3s 服務: 未運行或未安裝"
        fi
        ;;
    
    get-token)
        if [[ -z "$2" ]]; then
            echo "[ERROR] 請指定 Master VM ID"
            echo "用法: $0 get-token <MASTER_VM_ID>"
            exit 1
        fi
        
        MASTER_ID=$2
        if ! check_vm_status $MASTER_ID; then
            exit 1
        fi
        
        MASTER_IP=$(get_vm_ip $MASTER_ID)
        if [[ -z "$MASTER_IP" ]]; then
            echo "[ERROR] 無法取得 Master VM $MASTER_ID 的 IP"
            exit 1
        fi
        
        echo "取得 Master 節點 token (VM $MASTER_ID, IP: $MASTER_IP):"
        TOKEN=$(sshpass -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null)
        
        if [[ -n "$TOKEN" ]]; then
            echo "Token: $TOKEN"
            echo ""
            echo "Worker 節點加入命令:"
            echo "curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$TOKEN sh -"
        else
            echo "[ERROR] 無法取得 token，請確認 K3s master 已正確安裝"
            exit 1
        fi
        ;;
    
    join)
        if [[ -z "$2" || -z "$3" ]]; then
            echo "[ERROR] 請指定 Worker VM ID 和 Master VM ID"
            echo "用法: $0 join <WORKER_VM_ID> <MASTER_VM_ID>"
            exit 1
        fi
        
        WORKER_ID=$2
        MASTER_ID=$3
        
        if ! check_vm_status $WORKER_ID || ! check_vm_status $MASTER_ID; then
            exit 1
        fi
        
        WORKER_IP=$(get_vm_ip $WORKER_ID)
        MASTER_IP=$(get_vm_ip $MASTER_ID)
        
        if [[ -z "$WORKER_IP" || -z "$MASTER_IP" ]]; then
            echo "[ERROR] 無法取得 VM IP"
            exit 1
        fi
        
        echo "讓 Worker VM $WORKER_ID 加入 Master VM $MASTER_ID 的叢集..."
        
        # 取得 token
        TOKEN=$(sshpass -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null)
        if [[ -z "$TOKEN" ]]; then
            echo "[ERROR] 無法取得 Master token"
            exit 1
        fi
        
        # 在 worker 節點執行加入命令
        echo "執行加入命令..."
        if sshpass -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ubuntu@$WORKER_IP "curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER_IP:6443 K3S_TOKEN=$TOKEN sh -" 2>/dev/null; then
            echo "✅ Worker 節點已成功加入叢集"
            
            # 等待一下然後檢查狀態
            sleep 10
            echo ""
            echo "叢集節點狀態:"
            sshpass -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "kubectl get nodes" 2>/dev/null || echo "無法取得節點狀態"
        else
            echo "❌ Worker 節點加入失敗"
            exit 1
        fi
        ;;
    
    list-nodes)
        if [[ -z "$2" ]]; then
            echo "[ERROR] 請指定 Master VM ID"
            echo "用法: $0 list-nodes <MASTER_VM_ID>"
            exit 1
        fi
        
        MASTER_ID=$2
        if ! check_vm_status $MASTER_ID; then
            exit 1
        fi
        
        MASTER_IP=$(get_vm_ip $MASTER_ID)
        if [[ -z "$MASTER_IP" ]]; then
            echo "[ERROR] 無法取得 Master VM IP"
            exit 1
        fi
        
        echo "K3s 叢集節點列表 (Master: VM $MASTER_ID):"
        echo "========================================="
        sshpass -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "kubectl get nodes -o wide" 2>/dev/null || echo "無法取得節點列表"
        ;;
    
    cleanup)
        if [[ -z "$2" ]]; then
            echo "[ERROR] 請指定要清理的 VM ID 或範圍"
            echo "用法: $0 cleanup <VM_ID> 或 $0 cleanup <START_ID>-<END_ID>"
            exit 1
        fi
        
        VM_RANGE=$2
        
        if [[ "$VM_RANGE" == *"-"* ]]; then
            # 範圍清理
            START_ID=$(echo $VM_RANGE | cut -d'-' -f1)
            END_ID=$(echo $VM_RANGE | cut -d'-' -f2)
            
            echo "清理 VM 範圍: $START_ID 到 $END_ID"
            read -p "確定要刪除這些 VM 嗎? (y/N): " confirm
            
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                for vm_id in $(seq $START_ID $END_ID); do
                    if qm status $vm_id &>/dev/null; then
                        echo "清理 VM $vm_id..."
                        qm stop $vm_id &>/dev/null || true
                        sleep 2
                        qm destroy $vm_id &>/dev/null || true
                        rm -f /var/lib/vz/snippets/k3s-user-data-${vm_id}.yaml
                        echo "VM $vm_id 已清理"
                    fi
                done
                echo "範圍清理完成"
            else
                echo "取消清理"
            fi
        else
            # 單一 VM 清理
            VM_ID=$2
            
            if ! qm status $VM_ID &>/dev/null; then
                echo "[ERROR] VM $VM_ID 不存在"
                exit 1
            fi
            
            echo "清理 VM $VM_ID"
            read -p "確定要刪除 VM $VM_ID 嗎? (y/N): " confirm
            
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                qm stop $VM_ID &>/dev/null || true
                sleep 2
                qm destroy $VM_ID &>/dev/null || true
                rm -f /var/lib/vz/snippets/k3s-user-data-${VM_ID}.yaml
                echo "VM $VM_ID 已清理"
            else
                echo "取消清理"
            fi
        fi
        ;;
    
    logs)
        if [[ -z "$2" ]]; then
            echo "[ERROR] 請指定 VM ID"
            echo "用法: $0 logs <VM_ID>"
            exit 1
        fi
        
        VM_ID=$2
        if ! check_vm_status $VM_ID; then
            exit 1
        fi
        
        VM_IP=$(get_vm_ip $VM_ID)
        if [[ -z "$VM_IP" ]]; then
            echo "[ERROR] 無法取得 VM IP"
            exit 1
        fi
        
        echo "K3s 服務日誌 (VM $VM_ID, IP: $VM_IP):"
        echo "===================================="
        sshpass -p "$VM_PASSWORD" ssh -o StrictHostKeyChecking=no ubuntu@$VM_IP "sudo journalctl -u k3s -f --no-pager" 2>/dev/null || echo "無法取得日誌"
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        echo "[ERROR] 未知命令: $1"
        show_help
        exit 1
        ;;
esac
