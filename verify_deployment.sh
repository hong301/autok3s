#!/bin/bash
# K3s 部署驗證腳本

echo "=== K3s 叢集部署驗證腳本 ==="

# 設定 VM IP 地址
MASTER_IP="10.110.0.X"
WORKER1_IP="10.110.0.X"
WORKER2_IP="10.110.0.X"

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local status=$1
    local message=$2
    if [[ "$status" == "OK" ]]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [[ "$status" == "WARN" ]]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    elif [[ "$status" == "ERROR" ]]; then
        echo -e "${RED}❌ $message${NC}"
    else
        echo -e "${BLUE}ℹ️  $message${NC}"
    fi
}

check_vm_status() {
    echo -e "${BLUE}=== 1. VM 狀態檢查 ===${NC}"
    
    for vm_id in 100 101 102; do
        if qm status $vm_id &>/dev/null; then
            status=$(qm status $vm_id | awk '{print $2}')
            if [[ "$status" == "running" ]]; then
                print_status "OK" "VM $vm_id 狀態: $status"
            else
                print_status "ERROR" "VM $vm_id 狀態: $status"
            fi
        else
            print_status "ERROR" "VM $vm_id 不存在"
        fi
    done
}

check_ssh_connectivity() {
    echo -e "\n${BLUE}=== 2. SSH 連線檢查 ===${NC}"
    
    local nodes=("$MASTER_IP:Master" "$WORKER1_IP:Worker-1" "$WORKER2_IP:Worker-2")
    
    for node in "${nodes[@]}"; do
        local ip=${node%:*}
        local name=${node#*:}
        
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$ip "echo 'SSH OK'" &>/dev/null; then
            print_status "OK" "$name ($ip) SSH 密鑰連線正常"
        else
            print_status "ERROR" "$name ($ip) SSH 密鑰連線失敗"
        fi
    done
}

check_k3s_services() {
    echo -e "\n${BLUE}=== 3. K3s 服務狀態檢查 ===${NC}"
    
    # 檢查 Master 節點
    print_status "INFO" "檢查 Master 節點 K3s 服務..."
    if ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "systemctl is-active --quiet k3s"; then
        print_status "OK" "Master 節點 K3s 服務運行正常"
    else
        print_status "ERROR" "Master 節點 K3s 服務異常"
    fi
    
    # 檢查 Worker 節點
    for ip in "$WORKER1_IP" "$WORKER2_IP"; do
        local name=$(ssh -o StrictHostKeyChecking=no ubuntu@$ip "hostname")
        if ssh -o StrictHostKeyChecking=no ubuntu@$ip "systemctl is-active --quiet k3s-agent"; then
            print_status "OK" "$name K3s Agent 服務運行正常"
        else
            print_status "ERROR" "$name K3s Agent 服務異常"
        fi
    done
}

check_cluster_nodes() {
    echo -e "\n${BLUE}=== 4. 叢集節點狀態檢查 ===${NC}"
    
    local nodes_output
    nodes_output=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "kubectl get nodes --no-headers" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local ready_count=$(echo "$nodes_output" | grep -c "Ready")
        local total_count=$(echo "$nodes_output" | wc -l)
        
        print_status "INFO" "叢集節點詳情:"
        while IFS= read -r line; do
            local node_name=$(echo "$line" | awk '{print $1}')
            local status=$(echo "$line" | awk '{print $2}')
            local role=$(echo "$line" | awk '{print $3}')
            
            if [[ "$status" == "Ready" ]]; then
                print_status "OK" "  節點 $node_name ($role): $status"
            else
                print_status "ERROR" "  節點 $node_name ($role): $status"
            fi
        done <<< "$nodes_output"
        
        if [[ $ready_count -eq 3 ]]; then
            print_status "OK" "所有 3 個節點都處於 Ready 狀態"
        else
            print_status "WARN" "只有 $ready_count/$total_count 個節點處於 Ready 狀態"
        fi
    else
        print_status "ERROR" "無法取得叢集節點資訊"
    fi
}

check_system_pods() {
    echo -e "\n${BLUE}=== 5. 系統 Pods 狀態檢查 ===${NC}"
    
    local pods_output
    pods_output=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "kubectl get pods -n kube-system --no-headers" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local running_count=$(echo "$pods_output" | grep -c "Running\|Completed")
        local total_count=$(echo "$pods_output" | wc -l)
        
        print_status "INFO" "系統 Pods 狀態:"
        while IFS= read -r line; do
            local pod_name=$(echo "$line" | awk '{print $1}')
            local ready=$(echo "$line" | awk '{print $2}')
            local status=$(echo "$line" | awk '{print $3}')
            
            if [[ "$status" == "Running" || "$status" == "Completed" ]]; then
                print_status "OK" "  $pod_name: $status ($ready)"
            else
                print_status "WARN" "  $pod_name: $status ($ready)"
            fi
        done <<< "$pods_output"
        
        print_status "INFO" "$running_count/$total_count 個系統 Pods 運行正常"
    else
        print_status "ERROR" "無法取得系統 Pods 資訊"
    fi
}

check_cert_manager() {
    echo -e "\n${BLUE}=== 6. cert-manager 狀態檢查 ===${NC}"
    
    local cert_pods
    cert_pods=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "kubectl get pods -n cert-manager --no-headers" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$cert_pods" ]]; then
        local running_count=$(echo "$cert_pods" | grep -c "Running")
        local total_count=$(echo "$cert_pods" | wc -l)
        
        print_status "INFO" "cert-manager Pods 狀態:"
        while IFS= read -r line; do
            local pod_name=$(echo "$line" | awk '{print $1}')
            local ready=$(echo "$line" | awk '{print $2}')
            local status=$(echo "$line" | awk '{print $3}')
            
            if [[ "$status" == "Running" ]]; then
                print_status "OK" "  $pod_name: $status ($ready)"
            else
                print_status "WARN" "  $pod_name: $status ($ready)"
            fi
        done <<< "$cert_pods"
        
        if [[ $running_count -eq $total_count ]]; then
            print_status "OK" "cert-manager 所有組件運行正常"
        else
            print_status "WARN" "cert-manager 部分組件異常"
        fi
    else
        print_status "WARN" "cert-manager 未安裝或異常"
    fi
}

check_helm() {
    echo -e "\n${BLUE}=== 7. Helm 配置檢查 ===${NC}"
    
    if ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "command -v helm" &>/dev/null; then
        local helm_version
        helm_version=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "helm version --short" 2>/dev/null)
        print_status "OK" "Helm 已安裝: $helm_version"
        
        local repos
        repos=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "helm repo list --output table" 2>/dev/null)
        if [[ $? -eq 0 ]] && [[ -n "$repos" ]]; then
            print_status "OK" "Helm repositories 已配置"
            echo "$repos" | while IFS= read -r line; do
                if [[ "$line" != "NAME"* ]]; then
                    print_status "INFO" "  $line"
                fi
            done
        else
            print_status "WARN" "Helm repositories 未配置"
        fi
    else
        print_status "ERROR" "Helm 未安裝"
    fi
}

check_cluster_info() {
    echo -e "\n${BLUE}=== 8. 叢集資訊總覽 ===${NC}"
    
    local cluster_info
    cluster_info=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "kubectl cluster-info" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        print_status "OK" "叢集資訊:"
        echo "$cluster_info" | while IFS= read -r line; do
            print_status "INFO" "  $line"
        done
    else
        print_status "ERROR" "無法取得叢集資訊"
    fi
}

generate_summary() {
    echo -e "\n${BLUE}=== 9. 部署摘要 ===${NC}"
    
    local summary_output
    summary_output=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "
        echo '叢集版本:'
        kubectl version --short 2>/dev/null | head -2
        echo ''
        echo '節點摘要:'
        kubectl get nodes -o wide
        echo ''
        echo '資源使用:'
        kubectl top nodes 2>/dev/null || echo '  metrics-server 可能未完全就緒'
    " 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        echo "$summary_output"
    else
        print_status "WARN" "無法生成完整摘要"
    fi
}

# 主執行流程
main() {
    echo -e "${GREEN}開始 K3s 叢集驗證...${NC}\n"
    
    check_vm_status
    check_ssh_connectivity
    check_k3s_services
    check_cluster_nodes
    check_system_pods
    check_cert_manager
    check_helm
    check_cluster_info
    generate_summary
    
    echo -e "\n${GREEN}=== 驗證完成 ===${NC}"
    print_status "INFO" "使用以下命令連線到 Master 節點: ssh ubuntu@$MASTER_IP"
    print_status "INFO" "使用 kubectl 命令: ssh ubuntu@$MASTER_IP 'kubectl get all --all-namespaces'"
}

# 執行主函數
main
