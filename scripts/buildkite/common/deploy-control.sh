#!/bin/bash
# 部署编排器 - 简化版本
# 协调整个部署流程

set -euo pipefail

echo "--- 部署编排器启动"

# 获取项目根目录
PROJECT_ROOT="${1:-$(pwd)}"
echo "项目根目录: $PROJECT_ROOT"

# 1. 配置准备阶段
echo "--- 配置准备"

# 确保配置管理器有执行权限
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_MANAGER_SCRIPT="${SCRIPT_DIR}/config.sh"

if [[ ! -x "$CONFIG_MANAGER_SCRIPT" ]]; then
    echo "设置配置管理器执行权限..."
    chmod +x "$CONFIG_MANAGER_SCRIPT"
fi

# 调用配置管理器
echo "调用配置管理器..."
if "$CONFIG_MANAGER_SCRIPT"; then
    echo "✅ 配置准备完成"
else
    echo "❌ 配置准备失败"
    buildkite-agent meta-data set "deploy_status" "failed"
    exit 1
fi

# 2. 执行业务部署脚本
echo "--- 业务部署执行"

# 支持从环境变量读取自定义部署脚本路径
DEPLOY_SCRIPT="${PROJECT_ROOT}/${DEPLOY_SCRIPT:-scripts/buildkite/deploy.sh}"

# 检查部署脚本是否存在
if [[ ! -f "$DEPLOY_SCRIPT" ]]; then
    echo "❌ 部署脚本不存在: $DEPLOY_SCRIPT"
    echo "请确保项目根目录下存在相应的部署脚本文件"
    buildkite-agent meta-data set "deploy_status" "failed"
    exit 1
fi

# 确保脚本有执行权限
if [[ ! -x "$DEPLOY_SCRIPT" ]]; then
    echo "设置部署脚本执行权限..."
    chmod +x "$DEPLOY_SCRIPT"
fi

# 执行部署脚本
echo "执行业务部署脚本: $DEPLOY_SCRIPT"

# 在项目根目录下执行部署脚本
cd "$PROJECT_ROOT"

if "$DEPLOY_SCRIPT"; then
    echo "✅ 业务部署执行成功"
    buildkite-agent meta-data set "deploy_status" "success"
    
    # 显示部署摘要
    DEPLOY_ENV=$(buildkite-agent meta-data get "deploy_environment" --default "production")
    IMAGE_NAME=$(buildkite-agent meta-data get "full_image_name" --default "unknown")
    
    echo ""
    echo "════════════════════════════════════════"
    echo "          部署成功摘要"
    echo "════════════════════════════════════════"
    echo " 环境: ${DEPLOY_ENV}"
    echo " 镜像: ${IMAGE_NAME}"
    echo " 时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo " 状态: ✅ 成功"
    echo "════════════════════════════════════════"
    echo ""
else
    echo "❌ 业务部署执行失败"
    buildkite-agent meta-data set "deploy_status" "failed"
    exit 1
fi

echo "✅ 部署编排完成"