#!/bin/bash
# self_check.sh - 專案自我檢測腳本

# 注意：不使用 set -e，因為我們需要處理預期的失敗情況

# 載入共用函數庫
source "$(dirname "$0")/common_functions.sh"

echo "🔍 Auto K3s + ELK 專案自我檢測"
echo "================================="

# 檢測結果計數器
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

# 檢測函數
check_pass() {
    echo "✅ $1"
    ((PASS_COUNT++))
}

check_fail() {
    echo "❌ $1"
    ((FAIL_COUNT++))
}

check_warn() {
    echo "⚠️  $1"
    ((WARN_COUNT++))
}

echo ""
echo "📂 1. 專案結構檢查"
echo "=================="

# 檢查核心腳本
REQUIRED_SCRIPTS=(
    "00_download_image.sh"
    "01_build_template.sh"
    "02_clone_k3s_nodes.sh"
    "03_install_k3s.sh"
    "04_install_elk_stack.sh"
    "05_install_logstash.sh"
    "06_install_beats_on_proxmox.sh"
    "07_install_k3s_filebeat.sh"
    "08_install_k3s_metricbeat.sh"
    "deploy_k3s_elk.sh"
    "common_functions.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [[ -f "$script" ]]; then
        check_pass "腳本存在: $script"
    else
        check_fail "腳本缺失: $script"
    fi
done

# 檢查配置文件
CONFIG_FILES=("meta-data" "user-data" "README.md")
for file in "${CONFIG_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        check_pass "配置文件存在: $file"
    else
        check_warn "配置文件缺失: $file"
    fi
done

echo ""
echo "🔧 2. 語法檢查"
echo "=============="

for script in *.sh; do
    if bash -n "$script" 2>/dev/null; then
        check_pass "語法正確: $script"
    else
        check_fail "語法錯誤: $script"
    fi
done

echo ""
echo "🔗 3. 相依性檢查"
echo "================"

# 檢查共用函數庫引用
for script in [0-9]*.sh deploy*.sh; do
    if grep -q "common_functions.sh" "$script" 2>/dev/null; then
        check_pass "已引用共用函數: $script"
    else
        check_fail "未引用共用函數: $script"
    fi
done

# 檢查必要工具調用
NEED_TOOLS_SCRIPTS=("01_build_template.sh" "02_clone_k3s_nodes.sh" "03_install_k3s.sh" "04_install_elk_stack.sh" "05_install_logstash.sh" "06_install_beats_on_proxmox.sh" "07_install_k3s_filebeat.sh" "08_install_k3s_metricbeat.sh")

for script in "${NEED_TOOLS_SCRIPTS[@]}"; do
    if grep -q "check_required_tools" "$script" 2>/dev/null; then
        check_pass "工具檢查正確: $script"
    else
        check_warn "缺少工具檢查: $script"
    fi
done

echo ""
echo "📋 4. 階段標識檢查"
echo "=================="

# 檢查階段開始標識
for script in [0-9]*.sh; do
    if grep -q "執行階段" "$script" 2>/dev/null; then
        check_pass "有開始標識: $script"
    else
        check_warn "缺少開始標識: $script"
    fi
done

# 檢查階段完成標識
for script in [0-9]*.sh; do
    if grep -q "階段完成" "$script" 2>/dev/null; then
        check_pass "有完成標識: $script"
    else
        check_warn "缺少完成標識: $script"
    fi
done

echo ""
echo "🔐 5. 檔案權限檢查"
echo "=================="

for script in *.sh; do
    if [[ -x "$script" ]]; then
        check_pass "有執行權限: $script"
    else
        check_fail "缺少執行權限: $script"
    fi
done

echo ""
echo "🌐 6. 環境檢查"
echo "=============="

# 檢查是否在 Proxmox 環境
if command -v qm &>/dev/null; then
    check_pass "Proxmox VE 環境"
else
    check_warn "非 Proxmox VE 環境 (部署時需要)"
fi

# 檢查必要工具
if command -v wget &>/dev/null; then
    check_pass "wget 已安裝"
else
    check_warn "wget 未安裝 (部署時會自動安裝)"
fi

if command -v jq &>/dev/null; then
    check_pass "jq 已安裝"
else
    check_warn "jq 未安裝 (部署時會自動安裝)"
fi

if command -v mkpasswd &>/dev/null; then
    check_pass "mkpasswd 已安裝"
else
    check_warn "mkpasswd 未安裝 (部署時會自動安裝)"
fi

# 檢查 SSH 金鑰
if [[ -f "$HOME/.ssh/id_rsa.pub" ]]; then
    check_pass "SSH 公鑰存在"
else
    check_warn "SSH 公鑰不存在 (部署前需要生成)"
fi

# 檢查網路連線
if ping -c 1 cloud-images.ubuntu.com &>/dev/null; then
    check_pass "網路連線正常"
else
    check_warn "無法連接 Ubuntu Cloud Images (部署時需要)"
fi

echo ""
echo "🚀 7. 部署流程檢查"
echo "=================="

# 檢查主部署腳本引用
EXPECTED_ORDER=("01_build_template.sh" "02_clone_k3s_nodes.sh" "03_install_k3s.sh" "04_install_elk_stack.sh" "05_install_logstash.sh" "07_install_k3s_filebeat.sh" "08_install_k3s_metricbeat.sh" "06_install_beats_on_proxmox.sh")

step=1
for script in "${EXPECTED_ORDER[@]}"; do
    if grep -q "$script" deploy_k3s_elk.sh 2>/dev/null; then
        check_pass "Step $step: $script"
    else
        check_fail "Step $step 缺失: $script"
    fi
    ((step++))
done

echo ""
echo "🔍 8. 重複內容檢查"
echo "=================="

# 檢查重複行
for script in *.sh; do
    duplicates=$(sort "$script" | uniq -d | grep -v "^$" | wc -l)
    if [[ $duplicates -eq 0 ]]; then
        check_pass "無重複內容: $script"
    else
        check_warn "發現 $duplicates 行重複內容: $script"
    fi
done

echo ""
echo "📊 9. 配置檢查"
echo "=============="

# 檢查關鍵配置
if grep -q "TEMPLATE_ID=9000" common_functions.sh 2>/dev/null; then
    check_pass "Template ID 配置正確"
else
    check_warn "Template ID 配置可能有問題"
fi

if grep -q 'STORAGE="local-lvm"' common_functions.sh 2>/dev/null; then
    check_pass "儲存配置正確"
else
    check_warn "儲存配置可能有問題"
fi

if grep -q 'BRIDGE="vmbr0"' common_functions.sh 2>/dev/null; then
    check_pass "網橋配置正確"
else
    check_warn "網橋配置可能有問題"
fi

echo ""
echo "📋 10. 檢測摘要"
echo "================"

TOTAL_CHECKS=$((PASS_COUNT + FAIL_COUNT + WARN_COUNT))

echo "🎯 檢測統計："
echo "  • 總檢查項目: $TOTAL_CHECKS"
echo "  • ✅ 通過: $PASS_COUNT"
echo "  • ❌ 失敗: $FAIL_COUNT"
echo "  • ⚠️  警告: $WARN_COUNT"

echo ""
if [[ $FAIL_COUNT -eq 0 ]]; then
    echo "🎉 檢測結果: 專案狀態良好，可以進行部署！"
    if [[ $WARN_COUNT -gt 0 ]]; then
        echo "💡 建議: 請檢查上述警告項目，確保部署環境準備完整"
    fi
    echo ""
    echo "🚀 下一步："
    echo "  1. 確保 Proxmox VE 環境準備就緒"
    echo "  2. 生成 SSH 金鑰: ssh-keygen -t rsa -b 4096"
    echo "  3. 執行部署: sudo ./deploy_k3s_elk.sh"
    exit 0
else
    echo "💥 檢測結果: 發現 $FAIL_COUNT 個關鍵問題，請修復後再部署！"
    echo ""
    echo "🔧 修復建議："
    echo "  1. 檢查缺失的腳本文件"
    echo "  2. 修復語法錯誤"
    echo "  3. 補充缺少的相依性引用"
    echo "  4. 設定正確的檔案權限: chmod +x *.sh"
    exit 1
fi
