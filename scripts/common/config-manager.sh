#!/bin/bash
# 配置管理器 - 优化版
# 自动读取Buildkite Secrets中的环境特定配置并生成配置文件

set -euo pipefail

# =================== 配置变量 ===================

# 默认配置文件路径
CONFIG_FILE="/tmp/env"

# 预定义的配置键列表 (可根据项目需求修改)
CONFIG_KEYS=(
    # 可根据项目需要添加更多配置项
    "ENV_NAME"
)

# 加载通用工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# =================== 配置生成函数 ===================

# 生成应用配置文件
generate_app_config() {
    local config_prefix="$1"  # 如 PROD_ 或 TEST_
    local config_file="${2:-$CONFIG_FILE}"
    
    log_info "开始生成应用配置文件..."
    log_info "配置前缀: ${config_prefix}"
    log_info "配置文件: ${config_file}"
    
    # 确保配置文件目录存在
    local config_dir=$(dirname "$config_file")
    if [[ ! -d "$config_dir" ]]; then
        log_info "创建配置文件目录: $config_dir"
        mkdir -p "$config_dir"
    fi
    
    # 清空配置文件
    > "$config_file"
    
    # 处理环境特定配置
    log_info "处理环境特定配置 (${config_prefix}*)..."
    local found_count=0
    local total_count=${#CONFIG_KEYS[@]}
    
    for config_key in "${CONFIG_KEYS[@]}"; do
        local prefixed_key="${config_prefix}${config_key}"
        
        log_info "尝试获取配置: ${prefixed_key}"
        if buildkite-agent secret get "$prefixed_key" &>/dev/null; then
            local value=$(buildkite-agent secret get "$prefixed_key" 2>/dev/null)
            if [[ -n "$value" ]]; then
                echo "${config_key}=${value}" >> "$config_file"
                log_info "✓ 找到配置: ${config_key}"
                ((found_count++))
            else
                log_warning "  配置为空: ${config_key} (${prefixed_key})"
            fi
        else
            log_info "  跳过配置: ${config_key} (${prefixed_key} 不存在)"
        fi
    done
    
    # 显示结果统计
    log_info "配置处理完成: 找到 ${found_count}/${total_count} 个配置项"
    
    # 验证配置文件
    if [[ -f "$config_file" ]]; then
        # 将配置文件路径写入 meta-data 供其他脚本使用
        buildkite-agent meta-data set "config_file_path" "$config_file"
        
        if [[ -s "$config_file" ]]; then
            log_success "配置文件生成成功: $config_file"
            log_info "配置文件内容预览:"
            while IFS='=' read -r key value; do
                [[ -n "$key" ]] && log_info "  ${key}=***"
            done < "$config_file"
            log_info "配置文件路径已保存到 meta-data: config_file_path=$config_file"
        else
            log_warning "配置文件为空，但已创建: $config_file"
            log_info "这可能表示没有找到任何环境特定配置，这是正常情况"
            log_info "配置文件路径已保存到 meta-data: config_file_path=$config_file"
        fi
    else
        log_error "配置文件创建失败: $config_file"
        log_error "请检查目录权限: $(dirname "$config_file")"
        exit 1
    fi
}

# =================== 主流程 ===================

main() {
    start_step "配置管理"
    
    # 显示环境信息
    show_environment
    
    # 获取配置前缀 - 优先从环境变量，回退到 meta-data
    local config_prefix="${CONFIG_PREFIX:-$(buildkite-agent meta-data get "config_prefix" --default "PROD_" 2>/dev/null || echo "PROD_")}"
    
    # 获取配置文件路径 (支持环境变量覆盖)
    local config_file="${CONFIG_FILE}"
    
    log_info "使用配置前缀: $config_prefix"
    log_info "使用配置文件路径: $config_file"
    
    # 生成应用配置
    generate_app_config "$config_prefix" "$config_file"
    
    log_success "配置管理完成"
}

# 如果脚本被直接执行，则运行主流程
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi