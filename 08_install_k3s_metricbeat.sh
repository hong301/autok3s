#!/bin/bash
# 08_install_k3s_metricbeat.sh - 在 K3s 集群中安裝 Metricbeat DaemonSet

set -e

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

echo "🚀 執行階段：08_install_k3s_metricbeat.sh - 在 K3s 安裝 Metricbeat"
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

# 在 k3s-master 上安裝 Metricbeat DaemonSet
ssh_exec "$MASTER_IP" ubuntu <<'EOF'
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🚀 部署 Metricbeat DaemonSet..."

# 建立 Metricbeat 配置
cat <<METRICBEAT_YAML | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: metricbeat-config
  namespace: logging
data:
  metricbeat.yml: |-
    metricbeat.config.modules:
      path: /usr/share/metricbeat/modules.d/*.yml
      reload.enabled: false
    
    metricbeat.modules:
    - module: system
      metricsets:
        - cpu
        - load
        - memory
        - network
        - process
        - process_summary
        - socket_summary
        - filesystem
        - diskio
      enabled: true
      period: 10s
      processes: ['.*']
    
    - module: kubernetes
      metricsets:
        - node
        - system
        - pod
        - container
        - volume
      enabled: true
      period: 10s
      hosts: ["https://kubernetes.default.svc:443"]
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      ssl.certificate_authorities:
        - /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    
    - module: docker
      metricsets:
        - container
        - cpu
        - diskio
        - event
        - healthcheck
        - info
        - memory
        - network
      enabled: true
      period: 10s
      hosts: ["unix:///var/run/docker.sock"]
    
    output.logstash:
      hosts: ["logstash.logging.svc.cluster.local:5044"]
    
    processors:
      - add_host_metadata: ~
      - add_fields:
          target: service
          fields:
            type: k3s_metrics
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: metricbeat
  namespace: logging
spec:
  selector:
    matchLabels:
      app: metricbeat
  template:
    metadata:
      labels:
        app: metricbeat
    spec:
      serviceAccountName: metricbeat
      terminationGracePeriodSeconds: 30
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: metricbeat
        image: docker.elastic.co/beats/metricbeat:8.11.0
        args: [
          "-c", "/etc/metricbeat.yml",
          "-e",
          "-system.hostfs=/hostfs",
        ]
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        securityContext:
          runAsUser: 0
          privileged: true
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi
        volumeMounts:
        - name: config
          mountPath: /etc/metricbeat.yml
          readOnly: true
          subPath: metricbeat.yml
        - name: data
          mountPath: /usr/share/metricbeat/data
        - name: dockersock
          mountPath: /var/run/docker.sock
        - name: proc
          mountPath: /hostfs/proc
          readOnly: true
        - name: cgroup
          mountPath: /hostfs/sys/fs/cgroup
          readOnly: true
        - name: modules
          mountPath: /usr/share/metricbeat/modules.d
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: cgroup
        hostPath:
          path: /sys/fs/cgroup
      - name: dockersock
        hostPath:
          path: /var/run/docker.sock
      - name: config
        configMap:
          defaultMode: 0640
          name: metricbeat-config
      - name: modules
        configMap:
          defaultMode: 0640
          name: metricbeat-modules
      - name: data
        hostPath:
          path: /var/lib/metricbeat-data
          type: DirectoryOrCreate
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: metricbeat-modules
  namespace: logging
data:
  system.yml: |-
    - module: system
      period: 10s
      metricsets:
        - cpu
        - load
        - memory
        - network
        - process
        - process_summary
        - socket_summary
        - filesystem
        - diskio
      processes: ['.*']
      process.include_top_n:
        by_cpu: 5
        by_memory: 5
      process.cmdline.cache.enabled: true
      process.cgroups.enabled: true
      process.env.whitelist: []
      process.include_cpu_ticks: false
      filesystem.ignore_types: []
  kubernetes.yml: |-
    - module: kubernetes
      period: 10s
      metricsets:
        - node
        - system
        - pod
        - container
        - volume
      hosts: ["https://kubernetes.default.svc:443"]
      bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
      ssl.certificate_authorities:
        - /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metricbeat
  namespace: logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: metricbeat
rules:
- apiGroups: [""]
  resources:
  - nodes
  - namespaces
  - events
  - pods
  - services
  - persistentvolumes
  - persistentvolumeclaims
  verbs: ["get", "list", "watch"]
- apiGroups: ["extensions"]
  resources:
  - replicasets
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources:
  - statefulsets
  - deployments
  - replicasets
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources:
  - jobs
  - cronjobs
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - nodes/stats
  verbs: ["get"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metricbeat
subjects:
- kind: ServiceAccount
  name: metricbeat
  namespace: logging
roleRef:
  kind: ClusterRole
  name: metricbeat
  apiGroup: rbac.authorization.k8s.io
METRICBEAT_YAML

echo "⏳ 等待 Metricbeat DaemonSet 啟動..."
sleep 30

echo "🔍 檢查 Metricbeat 狀態..."
kubectl get pods -n logging -l app=metricbeat

echo "🎉 K3s Metricbeat 部署完成！"
echo ""
echo "📊 資料收集："
echo "  • K3s 節點指標 → Logstash → Elasticsearch"
echo "  • 容器資源使用量 → Logstash → Elasticsearch"
echo "  • 系統效能指標 → Logstash → Elasticsearch"
EOF

echo "✅ 階段完成：08_install_k3s_metricbeat.sh"
echo ""
