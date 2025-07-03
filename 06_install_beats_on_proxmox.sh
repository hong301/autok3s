#!/bin/bash
# 06_install_beats_on_proxmox.sh - 在 Proxmox 主機上安裝 Beats

set -e

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

echo "🚀 執行階段：06_install_beats_on_proxmox.sh - 在 Proxmox 主機安裝 Beats"
echo "================================================="

MASTER_VMID=101

# 檢查必要工具
check_required_tools

progress "在 Proxmox 主機上安裝 Beats"

# 取得 Master 節點 IP
MASTER_IP=$(get_ip_by_vmid $MASTER_VMID)
if [[ -z "$MASTER_IP" ]]; then
  echo "❌ 無法取得 Master VM IP"
  exit 1
fi

echo "🌐 Master IP: $MASTER_IP"

# 安裝 Elastic repository
echo "🔧 設定 Elastic repository..."
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add -
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | tee /etc/apt/sources.list.d/elastic-8.x.list

# 更新套件列表
apt-get update

# 安裝 Filebeat
echo "🚀 安裝 Filebeat..."
apt-get install -y filebeat

# 設定 Filebeat
echo "⚙️  設定 Filebeat..."
tee /etc/filebeat/filebeat.yml > /dev/null <<FILEBEAT_CONFIG
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/*.log
    - /var/log/syslog
    - /var/log/auth.log
    - /var/log/daemon.log
    - /var/log/kern.log
    - /var/log/pve-cluster.log
    - /var/log/pveproxy/access.log
    - /var/log/pvedaemon.log
  fields:
    node_type: proxmox_host
    node_ip: $(hostname -I | awk '{print $1}')
    hostname: $(hostname)

- type: syslog
  enabled: true
  protocol.udp:
    host: "0.0.0.0:514"

filebeat.config.modules:
  path: /etc/filebeat/modules.d/*.yml
  reload.enabled: false

setup.template.settings:
  index.number_of_shards: 1

output.logstash:
  hosts: ["$MASTER_IP:30544"]

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_fields:
      target: service
      fields:
        type: proxmox

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
FILEBEAT_CONFIG

# 啟用系統模組
filebeat modules enable system

# 安裝 Metricbeat
echo "🚀 安裝 Metricbeat..."
apt-get install -y metricbeat

# 設定 Metricbeat
echo "⚙️  設定 Metricbeat..."
tee /etc/metricbeat/metricbeat.yml > /dev/null <<METRICBEAT_CONFIG
metricbeat.config.modules:
  path: /etc/metricbeat/modules.d/*.yml
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

- module: linux
  metricsets:
    - pageinfo
    - memory
    - ksm
  enabled: true
  period: 10s

output.logstash:
  hosts: ["$MASTER_IP:30544"]

processors:
  - add_host_metadata: ~
  - add_fields:
      target: service
      fields:
        type: proxmox

setup.template.settings:
  index.number_of_shards: 1

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/metricbeat
  name: metricbeat
  keepfiles: 7
  permissions: 0644
METRICBEAT_CONFIG

# 安裝 Auditbeat（安全日誌）
echo "🚀 安裝 Auditbeat..."
apt-get install -y auditbeat

# 設定 Auditbeat
echo "⚙️  設定 Auditbeat..."
tee /etc/auditbeat/auditbeat.yml > /dev/null <<AUDITBEAT_CONFIG
auditbeat.config.modules:
  path: /etc/auditbeat/modules.d/*.yml
  reload.period: 10s
  reload.enabled: false

auditbeat.modules:
- module: auditd
  enabled: true

- module: file_integrity
  enabled: true
  paths:
  - /etc
  - /bin
  - /sbin
  - /usr/bin
  - /usr/sbin
  - /var/lib/pve-cluster
  scan_at_start: true
  scan_rate_per_sec: 50 MiB
  max_file_size: 100 MiB
  hash_types: [sha1]

- module: system
  enabled: true
  datasets:
    - host
    - login
    - package
    - process
    - socket
    - user
  period: 10s

output.logstash:
  hosts: ["$MASTER_IP:30544"]

processors:
  - add_host_metadata: ~
  - add_fields:
      target: service
      fields:
        type: proxmox

setup.template.settings:
  index.number_of_shards: 1

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/auditbeat
  name: auditbeat
  keepfiles: 7
  permissions: 0644
AUDITBEAT_CONFIG

# 啟動和啟用服務
echo "🔄 啟動 Beats 服務..."
systemctl enable filebeat
systemctl start filebeat
systemctl enable metricbeat
systemctl start metricbeat
systemctl enable auditbeat
systemctl start auditbeat

# 檢查服務狀態
echo "🔍 檢查服務狀態..."
systemctl status filebeat --no-pager
systemctl status metricbeat --no-pager
systemctl status auditbeat --no-pager

echo "✅ Proxmox 主機 Beats 安裝完成！"

echo ""
echo "📋 已安裝的 Beats："
echo "  • Filebeat: 收集 Proxmox 系統日誌"
echo "  • Metricbeat: 收集 Proxmox 系統指標"
echo "  • Auditbeat: 收集安全審計日誌"

echo ""
echo "📊 索引資訊："
echo "  • Proxmox 日誌: filebeat-proxmox-YYYY.MM.DD"
echo "  • Proxmox 指標: metricbeat-proxmox-YYYY.MM.DD"
echo "  • Proxmox 安全: auditbeat-proxmox-YYYY.MM.DD"

echo "✅ 階段完成：06_install_beats_on_proxmox.sh"
echo ""
