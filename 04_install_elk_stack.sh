#!/bin/bash
# 安裝 ELK Stack: Elasticsearch、Kibana 在 K3s 集群中部署

set -e

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

echo "🚀 執行階段：04_install_elk_stack.sh - 安裝 Elasticsearch + Kibana"
echo "================================================="

MASTER_VMID=101

# 檢查必要工具
check_required_tools

# 取得 Master 節點 IP
MASTER_IP=$(get_ip_by_vmid $MASTER_VMID)
if [[ -z "$MASTER_IP" ]]; then
  echo "❌ 無法取得 Master VM IP"
  exit 1
fi

echo "🌐 k3s-master IP: $MASTER_IP"

# 在 k3s-master 上安裝 ELK Stack
ssh_exec "$MASTER_IP" ubuntu <<'EOF'
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🔧 安裝 Helm（如尚未安裝）..."
if ! command -v helm &>/dev/null; then
  curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "🔧 加入 Elastic Helm Repo 並更新..."
helm repo add elastic https://helm.elastic.co || true
helm repo update

echo "🔧 建立 logging 命名空間（如尚未存在）..."
kubectl create ns logging || true

echo "🚀 安裝 Elasticsearch..."
helm upgrade --install elasticsearch elastic/elasticsearch -n logging \
  --set replicas=1 \
  --set minimumMasterNodes=1 \
  --set resources.requests.memory="1Gi",resources.requests.cpu="500m" \
  --set volumeClaimTemplate.resources.requests.storage=4Gi

echo "⏳ 等待 Elasticsearch 初始化中（60秒）..."
sleep 60

echo "🚀 安裝 Kibana..."
helm upgrade --install kibana elastic/kibana -n logging \
  --set service.type=NodePort \
  --set service.nodePort=30561 \
  --set env.ELASTICSEARCH_HOSTS=http://elasticsearch-master.logging.svc.cluster.local:9200

echo "✅ ELK Stack (E+K) 安裝完成！"
kubectl get pods -n logging
EOF

echo "✅ 階段完成：04_install_elk_stack.sh"
echo ""
