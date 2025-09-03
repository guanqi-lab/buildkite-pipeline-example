#!/bin/bash
# 配置管理器 - 简化版本
# 自动读取Buildkite Secrets中的环境特定配置并生成配置文件

set -euo pipefail

echo "--- 配置管理"

# 获取配置文件路径 (支持环境变量覆盖)
CONFIG_FILE="${CONFIG_OUTPUT_FILE:-/tmp/env}"
echo "配置文件路径: $CONFIG_FILE"

# 获取配置前缀 - 优先从环境变量，回退到 meta-data
CONFIG_PREFIX="${CONFIG_PREFIX:-$(buildkite-agent meta-data get "config_prefix" --default "PROD_" 2>/dev/null || echo "PROD_")}"
echo "配置前缀: $CONFIG_PREFIX"

# 配置键列表 (支持从环境变量读取，逗号分隔)
if [[ -n "${CONFIG_KEYS:-}" ]]; then
    # 从环境变量读取配置键 (GitHub Actions传递的逗号分隔字符串)
    IFS=',' read -ra CONFIG_KEYS_ARRAY <<< "$CONFIG_KEYS"
fi

echo "配置键: ${CONFIG_KEYS_ARRAY[*]}"

# 确保配置文件目录存在
CONFIG_DIR=$(dirname "$CONFIG_FILE")
if [[ ! -d "$CONFIG_DIR" ]]; then
    echo "创建配置文件目录: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
fi

# 清空配置文件
> "$CONFIG_FILE"

# 处理环境特定配置
echo "--- 处理环境特定配置 (${CONFIG_PREFIX}*)"

for config_key in "${CONFIG_KEYS_ARRAY[@]}"; do
    prefixed_key="${CONFIG_PREFIX}${config_key}"
    
    echo "尝试获取配置: ${prefixed_key}"
    if buildkite-agent secret get "$prefixed_key" &>/dev/null; then
        value=$(buildkite-agent secret get "$prefixed_key" 2>/dev/null)
        if [[ -n "$value" ]]; then
            echo "${config_key}=${value}" >> "$CONFIG_FILE"
            echo "✅ 找到配置: ${config_key}"
        else
            echo "⚠️  配置为空: ${config_key} (${prefixed_key})"
        fi
    else
        echo "ℹ️  跳过配置: ${config_key} (${prefixed_key} 不存在)"
    fi
done

# 验证配置文件
if [[ -f "$CONFIG_FILE" ]]; then
    # 将配置文件路径写入 meta-data 供其他脚本使用
    buildkite-agent meta-data set "config_file_path" "$CONFIG_FILE"
    
    if [[ -s "$CONFIG_FILE" ]]; then
        echo "✅ 配置文件生成成功: $CONFIG_FILE"
        echo "配置文件内容预览:"
        while IFS='=' read -r key value; do
            [[ -n "$key" ]] && echo "  ${key}=***"
        done < "$CONFIG_FILE"
    else
        echo "⚠️  配置文件为空，但已创建: $CONFIG_FILE"
        echo "这可能表示没有找到任何环境特定配置，这是正常情况"
    fi
    
    echo "配置文件路径已保存到 meta-data: config_file_path=$CONFIG_FILE"
    echo "✅ 配置管理完成"
else
    echo "❌ 配置文件创建失败: $CONFIG_FILE"
    echo "请检查目录权限: $(dirname "$CONFIG_FILE")"
    exit 1
fi