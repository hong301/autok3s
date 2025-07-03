#!/bin/bash
# 安裝 K3s master 與多台 agent，自動偵測 DHCP IP 並完成 Cluster 加入

set -e

MASTER_VMID=101
WORKER_VMIDS=(102 103 104)

get_ip_by_name() {
  local name=$1
  local vmid
  vmid=$(qm list | awk -v name="$name" '$0 ~ name {print $1}')
  [[ -z "$vmid" ]] && echo "" && return
  qm guest cmd "$vmid" network-get-interfaces \
    | jq -r '.[] | select(.name=="ens18") | .["ip-addresses"][]? | select(.["ip-address"] | test("^10\\.110\\.")) | .["ip-address"]' | head -n1
}

# 檢查 jq 工具
if ! command -v jq &> /dev/null; then
  echo "❌ jq 未安裝，請先安裝 jq 工具"
  exit 1
fi

# 取得 master IP
MASTER_IP=$(get_ip $MASTER_VMID)
if [[ -z "$MASTER_IP" ]]; then
  echo "❌ 無法取得 Master VM IP，請確認 qemu-guest-agent 有啟用"
  exit 1
fi
echo "✅ Master IP: $MASTER_IP"

# 安裝 Master 節點
echo "🚀 安裝 K3s master (${MASTER_IP}) ..."
ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP <<'EOF'
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-name=k3s-master --write-kubeconfig-mode 644" sh -
EOF

# 擷取 token
echo "🔑 擷取 Token ..."
TOKEN=$(ssh ubuntu@$MASTER_IP "sudo cat /var/lib/rancher/k3s/server/node-token")

# 安裝 Worker 節點
for VMID in "${WORKER_VMIDS[@]}"; do
  AGENT_IP=$(get_ip $VMID)
  if [[ -z "$AGENT_IP" ]]; then
    echo "⚠️  無法取得 VM $VMID 的 IP，略過該節點"
    continue
  fi

  echo "✅ Worker $VMID IP: $AGENT_IP"
  echo "📡 安裝 K3s agent 並加入 cluster (${AGENT_IP}) ..."
  ssh -o StrictHostKeyChecking=no ubuntu@$AGENT_IP <<EOF
curl -sfL https://get.k3s.io | K3S_URL="https://${MASTER_IP}:6443" K3S_TOKEN="${TOKEN}" INSTALL_K3S_EXEC="--node-name=k3s-worker${VMID}" sh -
EOF
done

# 顯示完成資訊
echo "🎉 K3s Cluster 安裝完成！"
echo "🌐 Master 節點: $MASTER_IP"
echo "🌐 Worker 節點:"
for VMID in "${WORKER_VMIDS[@]}"; do
  IP=$(get_ip $VMID)
  [[ -n "$IP" ]] && echo "  - $IP"
done
echo "🔗 使用 kubectl 連接到 K3s Cluster:"
echo "  kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get nodes"
echo "📦 若需本機操作:"
echo "  scp ubuntu@$MASTER_IP:/etc/rancher/k3s/k3s.yaml ~/.kube/config"
