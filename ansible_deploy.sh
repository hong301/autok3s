#!/bin/bash
# 🚀 Ansible 版本快速部署腳本

set -e

echo "🚀 Auto K3s + ELK Ansible 部署"
echo "==============================="

# 檢查 Ansible 安裝
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible 未安裝，請先安裝 Ansible"
    echo "💡 安裝指令: pip install ansible"
    exit 1
fi

# 檢查必要的 Python 套件
echo "📦 檢查 Python 套件..."
pip install -q ansible kubernetes proxmoxer requests

# 執行自我檢測
echo "🔍 執行專案自我檢測..."
ansible-playbook playbooks/self_check.yml

# 詢問是否繼續部署
read -p "🚀 是否繼續執行部署？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 部署已取消"
    exit 0
fi

# 開始部署
echo "🚀 開始 Ansible 部署..."
ansible-playbook deploy.yml --ask-become-pass

echo "🎉 部署完成！"
