#!/bin/bash
# 安裝 ELK Stack: Elasticsearch、Kibana、Filebeat 全部透過 elk-master（唯一 K3s 節點）部署

set -e

MASTER_NAME="elk-master"
AGENT_NAME="elk-agent"

# 根據 VM 名稱查詢 IP
get_ip_by_name() {
  local name=$1
  local vmid
  vmid=$(qm list | awk -v name="$name" '$0 ~ name {print $1}')
  [[ -z "$vmid" ]] && echo "" && return
  qm guest cmd "$vmid" network-get-interfaces \
    | jq -r '.[] | select(.name=="ens18") | .["ip-addresses"][]? | select(.["ip-address"] | test("^10\\.110\\.")) | .["ip-address"]' | head -n1
}
if ! command -v jq &> /dev/null; then
  echo "❌ jq 未安裝，請先安裝 jq 工具"
  exit 1
fi

MASTER_IP=$(get_ip_by_name "$MASTER_NAME")
AGENT_IP=$(get_ip_by_name "$AGENT_NAME")

if [[ -z "$MASTER_IP" || -z "$AGENT_IP" ]]; then
  echo "❌ 無法取得 VM IP，請確認 qemu-guest-agent 有啟用"
  exit 1
fi

echo "🌐 elk-master IP: $MASTER_IP"
echo "🌐 elk-agent IP: $AGENT_IP"

# 在 elk-master 上安裝 ELK Stack
ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP <<'EOF'
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
  --set env.ELASTICSEARCH_HOSTS=http://elasticsearch-master.logging.svc.cluster.local:9200

echo "🚀 安裝 Filebeat..."
helm upgrade --install filebeat elastic/filebeat -n logging \
  --set daemonset.elasticsearch.hosts[0]="http://elasticsearch-master.logging.svc.cluster.local:9200"

echo "✅ ELK Stack 安裝完成！"
kubectl get pods -n logging
EOF
