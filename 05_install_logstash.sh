#!/bin/bash
# 05_install_logstash.sh - 在 K3s 集群中安裝 Logstash

set -e

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

echo "🚀 執行階段：05_install_logstash.sh - 安裝 Logstash"
echo "================================================="

MASTER_VMID=101

# 檢查必要工具
check_required_tools

progress "在 K3s 集群中安裝 Logstash"

# 取得 Master 節點 IP
MASTER_IP=$(get_ip_by_vmid $MASTER_VMID)
if [[ -z "$MASTER_IP" ]]; then
  echo "❌ 無法取得 Master VM IP"
  exit 1
fi

echo "🌐 Master IP: $MASTER_IP"

# 在 Master 節點上安裝 Logstash
ssh_exec "$MASTER_IP" ubuntu <<'EOF'
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "🚀 安裝 Logstash..."

# 創建 Logstash 配置 ConfigMap
kubectl create configmap logstash-config -n logging --from-literal=logstash.conf='
input {
  beats {
    port => 5044
    type => "beats"
  }
  
  http {
    port => 8080
    type => "http"
  }
}

filter {
  # 處理 Filebeat 日誌
  if [fields][node_type] == "proxmox_host" {
    mutate {
      add_field => { "[@metadata][index]" => "filebeat-proxmox-%{+YYYY.MM.dd}" }
      add_tag => [ "proxmox", "filebeat" ]
    }
  }
  
  # 處理 Metricbeat 指標
  if [fields][service][type] == "proxmox" and [metricset][name] {
    mutate {
      add_field => { "[@metadata][index]" => "metricbeat-proxmox-%{+YYYY.MM.dd}" }
      add_tag => [ "proxmox", "metricbeat" ]
    }
  }
  
  # 處理 K3s 日誌
  if [kubernetes] {
    mutate {
      add_field => { "[@metadata][index]" => "k3s-logs-%{+YYYY.MM.dd}" }
      add_tag => [ "k3s", "kubernetes" ]
    }
  }
  
  # 日誌解析和富化
  if [log][file][path] {
    grok {
      match => { "[log][file][path]" => "/var/log/(?<log_type>[^/]+)\.log" }
      tag_on_failure => ["_grokparsefailure_logtype"]
    }
  }
  
  # 時間戳處理
  if [@timestamp] {
    date {
      match => [ "@timestamp", "ISO8601" ]
    }
  }
  
  # 添加地理位置信息
  if [host][ip] {
    geoip {
      source => "[host][ip]"
      target => "geoip"
    }
  }
  
  # 清理不需要的字段
  mutate {
    remove_field => [ "agent", "ecs", "input" ]
  }
}

output {
  # 輸出到 Elasticsearch
  elasticsearch {
    hosts => ["elasticsearch-master.logging.svc.cluster.local:9200"]
    index => "%{[@metadata][index]}"
    template_name => "logstash-template"
    template => "/usr/share/logstash/templates/logstash-template.json"
    template_overwrite => true
  }
  
  # 調試輸出（可選）
  if [fields][debug] == "true" {
    stdout {
      codec => rubydebug
    }
  }
}
' || true

# 創建 Logstash 模板 ConfigMap
kubectl create configmap logstash-template -n logging --from-literal=logstash-template.json='{
  "index_patterns": ["logstash-*", "filebeat-*", "metricbeat-*", "auditbeat-*", "k3s-logs-*"],
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "index.refresh_interval": "5s"
  },
  "mappings": {
    "properties": {
      "@timestamp": {
        "type": "date"
      },
      "host": {
        "properties": {
          "name": {
            "type": "keyword"
          },
          "ip": {
            "type": "ip"
          }
        }
      },
      "message": {
        "type": "text",
        "analyzer": "standard"
      },
      "log_type": {
        "type": "keyword"
      },
      "geoip": {
        "properties": {
          "location": {
            "type": "geo_point"
          }
        }
      }
    }
  }
}' || true

# 部署 Logstash
cat <<LOGSTASH_YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logstash
  namespace: logging
  labels:
    app: logstash
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logstash
  template:
    metadata:
      labels:
        app: logstash
    spec:
      containers:
      - name: logstash
        image: docker.elastic.co/logstash/logstash:8.11.0
        ports:
        - containerPort: 5044
          name: beats
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        env:
        - name: LS_JAVA_OPTS
          value: "-Xmx1g -Xms1g"
        - name: PIPELINE_WORKERS
          value: "2"
        - name: PIPELINE_BATCH_SIZE
          value: "1000"
        volumeMounts:
        - name: logstash-config
          mountPath: /usr/share/logstash/pipeline/logstash.conf
          subPath: logstash.conf
        - name: logstash-template
          mountPath: /usr/share/logstash/templates/logstash-template.json
          subPath: logstash-template.json
      volumes:
      - name: logstash-config
        configMap:
          name: logstash-config
      - name: logstash-template
        configMap:
          name: logstash-template
---
apiVersion: v1
kind: Service
metadata:
  name: logstash
  namespace: logging
  labels:
    app: logstash
spec:
  selector:
    app: logstash
  ports:
  - name: beats
    port: 5044
    targetPort: 5044
    protocol: TCP
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: logstash-nodeport
  namespace: logging
  labels:
    app: logstash
spec:
  selector:
    app: logstash
  ports:
  - name: beats
    port: 5044
    targetPort: 5044
    nodePort: 30544
    protocol: TCP
  - name: http
    port: 8080
    targetPort: 8080
    nodePort: 30880
    protocol: TCP
  type: NodePort
LOGSTASH_YAML

echo "⏳ 等待 Logstash 啟動..."
kubectl wait --for=condition=ready pod -l app=logstash -n logging --timeout=300s

echo "✅ Logstash 安裝完成！"

# 顯示服務狀態
echo "📋 Logstash 服務狀態："
kubectl get pods -n logging -l app=logstash
kubectl get svc -n logging -l app=logstash

echo ""
echo "🔗 Logstash 連接資訊："
echo "  • Beats 輸入: $MASTER_IP:30544"
echo "  • HTTP 輸入: $MASTER_IP:30880"
echo "  • 內部服務: logstash.logging.svc.cluster.local:5044"

EOF

echo "🎉 Logstash 部署完成！"
echo ""
echo "📊 資料流向："
echo "  Beats → Logstash (處理/轉換) → Elasticsearch → Kibana"
echo ""
echo "🔧 下一步："
echo "  1. 更新 Beats 配置指向 Logstash"
echo "  2. 檢查 Logstash 日誌確認資料處理正常"
echo "  3. 在 Kibana 中查看處理後的索引"

echo "✅ 階段完成：05_install_logstash.sh"
echo ""
