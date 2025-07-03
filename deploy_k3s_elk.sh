#!/bin/bash
# deploy_k3s_elk.sh - 完整部署 K3s + ELK Stack

set -e

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

progress "Auto K3s + ELK Stack Deployment"

progress "Step 1️⃣: 建立 VM Template"
bash "$(dirname "$0")/01_build_template.sh"

progress "Step 2️⃣: 複製並建立 K3s 節點"
bash "$(dirname "$0")/02_clone_k3s_nodes.sh"

progress "Step 3️⃣: 安裝 K3s Cluster"
bash "$(dirname "$0")/03_install_k3s.sh"

progress "Step 4️⃣: 安裝 Elasticsearch + Kibana"
bash "$(dirname "$0")/04_install_elk_stack.sh"

progress "Step 5️⃣: 安裝 Logstash"
bash "$(dirname "$0")/05_install_logstash.sh"

progress "Step 6️⃣: 在 K3s 安裝 Filebeat"
bash "$(dirname "$0")/07_install_k3s_filebeat.sh"

progress "Step 7️⃣: 在 K3s 安裝 Metricbeat"
bash "$(dirname "$0")/08_install_k3s_metricbeat.sh"

progress "Step 8️⃣: 在 Proxmox 主機安裝 Beats"
bash "$(dirname "$0")/06_install_beats_on_proxmox.sh"

progress "🎉 部署完成！"

echo "📋 部署摘要："
echo "  • K3s: 1 Master + 3 Worker 節點"
echo "  • ELK: Elasticsearch + Logstash + Kibana"
echo "  • Beats: 多層次監控 (Proxmox + K3s)"
echo "  • DaemonSets: Filebeat + Metricbeat (每個節點)"
echo "  • DaemonSets: Filebeat + Metricbeat (每個節點)"

echo ""
echo "🔗 服務連接："
echo "  • Kibana: http://$(get_ip_by_vmid 101):30561"
echo "  • Elasticsearch: http://$(get_ip_by_vmid 101):30920"

echo ""
echo "📊 Index Patterns (在 Kibana 建立)："
echo "  • filebeat-proxmox-* (Proxmox 日誌)"
echo "  • metricbeat-proxmox-* (Proxmox 指標)"  
echo "  • auditbeat-proxmox-* (安全審計)"
echo "  • k3s-logs-* (K3s 容器日誌)"
echo "  • k3s-metrics-* (K3s 系統指標)"
echo "  • k3s-metrics-* (K3s 系統指標)"

echo ""
echo "🎉 部署成功！開始使用 ELK Stack 監控您的基礎設施"
