#!/bin/bash
# 🚀 Auto K3s + ELK Ansible 部署測試工具
# 
# 此腳本執行全面的預部署檢查和測試部署
#
# 作者: Ansible 版本重構
# 日期: $(date +"%Y-%m-%d")

set -euo pipefail

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日誌函數
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 檢查是否為 root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此腳本需要以 root 權限執行"
        exit 1
    fi
}

# 檢查 Proxmox 環境
check_proxmox() {
    log_info "檢查 Proxmox VE 環境..."
    
    if ! command -v qm &> /dev/null; then
        log_error "未檢測到 Proxmox VE 環境"
        exit 1
    fi
    
    if ! command -v pct &> /dev/null; then
        log_error "Proxmox 容器工具未找到"
        exit 1
    fi
    
    log_success "Proxmox VE 環境檢查通過"
}

# 檢查網路連線
check_network() {
    log_info "檢查網路連線..."
    
    # 檢查是否能連線到 Ubuntu Cloud Images
    if ! curl -s --head "https://cloud-images.ubuntu.com" | head -n 1 | grep -q "200 OK"; then
        log_warning "無法連線到 Ubuntu Cloud Images，可能影響映像下載"
    else
        log_success "網路連線檢查通過"
    fi
}

# 檢查系統資源
check_resources() {
    log_info "檢查系統資源..."
    
    # 檢查記憶體 (至少需要 16GB)
    total_memory=$(free -g | awk 'NR==2{printf "%.0f", $2}')
    if [[ $total_memory -lt 16 ]]; then
        log_warning "系統記憶體不足 16GB (當前: ${total_memory}GB)，可能影響部署"
    else
        log_success "記憶體檢查通過 (${total_memory}GB)"
    fi
    
    # 檢查磁碟空間 (至少需要 100GB)
    available_space=$(df -BG /var/lib/vz | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $available_space -lt 100 ]]; then
        log_warning "可用磁碟空間不足 100GB (當前: ${available_space}GB)，可能影響部署"
    else
        log_success "磁碟空間檢查通過 (${available_space}GB 可用)"
    fi
}

# 執行 Ansible 自我檢測
run_self_check() {
    log_info "執行 Ansible 專案自我檢測..."
    
    if ansible-playbook playbooks/self_check.yml; then
        log_success "Ansible 專案自我檢測通過"
    else
        log_error "Ansible 專案自我檢測失敗"
        exit 1
    fi
}

# 乾燥運行測試
dry_run_test() {
    log_info "執行 Ansible 乾燥運行測試..."
    
    if ansible-playbook deploy.yml --check --diff; then
        log_success "Ansible 乾燥運行測試通過"
    else
        log_error "Ansible 乾燥運行測試失敗"
        exit 1
    fi
}

# 實際部署
real_deployment() {
    log_info "開始實際部署..."
    log_warning "注意：這將在 Proxmox 上創建實際的虛擬機器"
    
    read -p "確定要繼續嗎? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "部署已取消"
        exit 0
    fi
    
    log_info "開始部署 K3s + ELK Stack..."
    
    if ansible-playbook deploy.yml --ask-become-pass; then
        log_success "部署完成！"
        show_deployment_summary
    else
        log_error "部署失敗"
        exit 1
    fi
}

# 顯示部署摘要
show_deployment_summary() {
    log_info "部署摘要："
    echo "========================="
    echo "🎯 K3s 集群："
    echo "   - Master: k3s-master-01 (VM ID: 101)"
    echo "   - Worker: k3s-worker-01 (VM ID: 102)"
    echo "   - Worker: k3s-worker-02 (VM ID: 103)"
    echo "   - Worker: k3s-worker-03 (VM ID: 104)"
    echo ""
    echo "🔍 ELK Stack 服務："
    echo "   - Elasticsearch: http://MASTER_IP:30920"
    echo "   - Kibana: http://MASTER_IP:30561"
    echo "   - Logstash: MASTER_IP:30544"
    echo ""
    echo "📊 監控代理："
    echo "   - Filebeat: 部署在所有節點"
    echo "   - Metricbeat: 部署在所有節點"
    echo "   - Auditbeat: 部署在所有節點"
    echo ""
    echo "🔧 下一步："
    echo "   1. 檢查虛擬機器狀態: qm list"
    echo "   2. 連線到 master: ssh ubuntu@MASTER_IP"
    echo "   3. 檢查 K3s 狀態: kubectl get nodes"
    echo "   4. 存取 Kibana: http://MASTER_IP:30561"
    echo "========================="
}

# 主要函數
main() {
    echo "🚀 Auto K3s + ELK Ansible 部署測試工具"
    echo "========================================="
    
    # 預檢查
    check_root
    check_proxmox
    check_network
    check_resources
    
    # Ansible 檢查
    run_self_check
    
    # 選擇模式
    echo ""
    echo "請選擇部署模式："
    echo "1) 僅乾燥運行測試 (推薦先執行)"
    echo "2) 實際部署"
    echo "3) 清理現有部署"
    echo ""
    read -p "請輸入選項 (1-3): " choice
    
    case $choice in
        1)
            dry_run_test
            log_success "乾燥運行測試完成，可以進行實際部署"
            ;;
        2)
            dry_run_test
            real_deployment
            ;;
        3)
            log_info "清理現有部署..."
            ansible-playbook playbooks/cleanup.yml --ask-become-pass
            log_success "清理完成"
            ;;
        *)
            log_error "無效選項"
            exit 1
            ;;
    esac
}

# 執行主要函數
main "$@"
