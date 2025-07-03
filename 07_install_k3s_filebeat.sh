#!/bin/bash
# 07_install_k3s_filebeat.sh - 在 K3s 集群中安裝 Filebeat

set -e

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

MASTER_VMID=101

# 檢查必要工具
check_required_tools

progress "在 K3s 集群中安裝 Filebeat"

# 取得 Master 節點 IP
MASTER_IP=$(get_ip_by_vmid $MASTER_VMID)
if [[ -z "$MASTER_IP" ]]; then
  echo "❌ 無法取得 Master VM IP"
  exit 1
fi

echo "🌐 k3s-master IP: $MASTER_IP"

# 在 Master 節點上安裝 K3s Filebeat
ssh_exec "$MASTER_IP" ubuntu <<'EOF'
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🚀 安裝 Filebeat DaemonSet..."
helm upgrade --install filebeat elastic/filebeat -n logging \
  --set daemonset.outputs.logstash.hosts[0]="logstash.logging.svc.cluster.local:5044" \
  --set daemonset.outputs.elasticsearch.enabled=false \
  --set daemonset.filebeatConfig."filebeat.yml"="
filebeat.inputs:
- type: container
  paths:
    - /var/log/containers/*.log
  processors:
    - add_kubernetes_metadata:
        host: \${NODE_NAME}
        matchers:
        - logs_path:
            logs_path: '/var/log/containers/'
    - add_fields:
        target: service
        fields:
          type: k3s

- type: log
  paths:
    - /var/log/syslog
    - /var/log/auth.log
    - /var/log/daemon.log
  processors:
    - add_fields:
        target: service
        fields:
          type: k3s_system

output.logstash:
  hosts: ['logstash.logging.svc.cluster.local:5044']

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
"

echo "⏳ 等待 Filebeat DaemonSet 啟動..."
kubectl wait --for=condition=ready pod -l app=filebeat-filebeat -n logging --timeout=300s

echo "✅ K3s Filebeat 安裝完成！"
kubectl get pods -n logging -l app=filebeat-filebeat

EOF

echo "🎉 K3s Filebeat 部署完成！"
echo ""
echo "📊 資料收集："
echo "  • K3s 容器日誌 → Logstash → Elasticsearch"
echo "  • K3s 系統日誌 → Logstash → Elasticsearch"
