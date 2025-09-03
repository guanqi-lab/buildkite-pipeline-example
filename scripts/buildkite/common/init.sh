#!/bin/bash
# 初始化脚本 - 简化版本
# 设置必要的环境和权限

set -euo pipefail

echo "--- 开始初始化流程"

# 显示环境信息
echo "--- 环境信息"
echo "环境类型: ${DEPLOY_ENVIRONMENT:-未知}"
echo "配置前缀: $(buildkite-agent meta-data get 'config_prefix' --default 'PROD_')"
echo "Agent队列: $(buildkite-agent meta-data get 'agent_queue' --default 'default')"
echo "Git分支: ${BUILDKITE_BRANCH:-unknown}"
echo "构建号: ${BUILDKITE_BUILD_NUMBER:-0}"

# 环境预检查
echo "--- 环境预检查"

echo "检查必要的命令工具..."

# 检查buildkite-agent是否可用
if ! command -v buildkite-agent &> /dev/null; then
    echo "❌ buildkite-agent命令不可用"
    exit 1
fi
echo "✅ buildkite-agent 可用"

# 检查配置文件输出目录权限
CONFIG_OUTPUT_FILE="${CONFIG_OUTPUT_FILE:-/tmp/env}"
CONFIG_DIR=$(dirname "$CONFIG_OUTPUT_FILE")

if [[ ! -d "$CONFIG_DIR" ]]; then
    echo "配置文件目录不存在，尝试创建: $CONFIG_DIR"
    if ! mkdir -p "$CONFIG_DIR"; then
        echo "❌ 无法创建配置文件目录: $CONFIG_DIR"
        exit 1
    fi
    echo "✅ 配置文件目录创建成功"
fi

if [[ ! -w "$CONFIG_DIR" ]]; then
    echo "❌ 配置文件目录不可写: $CONFIG_DIR"
    exit 1
fi
echo "✅ 配置文件目录权限正常: $CONFIG_DIR"

echo "✅ 环境预检查通过"

# 设置脚本权限
echo "--- 设置脚本执行权限"

echo "查找并设置脚本执行权限..."
find scripts/buildkite/ -name "*.sh" -type f -exec chmod +x {} \;

echo "✅ 脚本权限设置完成"

# 显示初始化信息
echo "--- 初始化信息"

echo "Buildkite构建信息:"
echo "  构建号: ${BUILDKITE_BUILD_NUMBER:-未知}"
echo "  分支: ${BUILDKITE_BRANCH:-未知}"
echo "  提交: ${BUILDKITE_COMMIT:-未知}"
echo "  环境: ${DEPLOY_ENVIRONMENT:-未知}"
echo "  队列: ${AGENT_QUEUE:-未知}"

echo "✅ 初始化信息显示完成"

echo "✅ 初始化流程完成"

