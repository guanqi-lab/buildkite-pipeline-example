#!/bin/bash
# 部署编排器 - 完全标准化
# 协调整个部署流程，业务无需关心

set -euo pipefail

# 加载通用工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# =================== 部署编排函数 ===================

# 执行部署流程
execute_deployment() {
    local project_root="$1"
    
    log_info "开始执行部署编排流程..."
    
    # 1. 配置准备阶段
    prepare_configuration
    
    # 2. 执行业务部署脚本
    execute_business_deploy "$project_root"
    
    # 3. 部署状态处理
    handle_deployment_result $?
}

# 配置准备阶段
prepare_configuration() {
    start_step "配置准备"
    
    # 调用配置管理器
    log_info "调用配置管理器..."
    if "${SCRIPT_DIR}/config-manager.sh"; then
        log_success "配置准备完成"
    else
        log_error "配置准备失败"
        set_deploy_status "failed"
        exit 1
    fi
}

# 执行业务部署脚本
execute_business_deploy() {
    local project_root="$1"
    local deploy_script="${project_root}/scripts/deploy.sh"
    
    start_step "业务部署执行"
    
    # 检查部署脚本是否存在
    if [[ ! -f "$deploy_script" ]]; then
        log_error "部署脚本不存在: $deploy_script"
        log_error "请确保项目根目录下存在 scripts/deploy.sh 文件"
        set_deploy_status "failed"
        exit 1
    fi
    
    # 检查脚本权限
    if [[ ! -x "$deploy_script" ]]; then
        log_info "设置部署脚本执行权限..."
        chmod +x "$deploy_script"
    fi
    
    # 执行部署脚本
    log_info "执行业务部署脚本: $deploy_script"
    
    # 设置环境变量供部署脚本使用
    export CONFIG_FILE="/tmp/app.env"
    export DEPLOY_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    
    # 在项目根目录下执行部署脚本
    cd "$project_root"
    
    if "$deploy_script"; then
        log_success "业务部署执行成功"
        return 0
    else
        log_error "业务部署执行失败"
        return 1
    fi
}

# 处理部署结果
handle_deployment_result() {
    local exit_code="$1"
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "部署流程执行成功"
        set_deploy_status "success"
        
        # 显示部署摘要
        show_deployment_summary
    else
        log_error "部署流程执行失败"
        set_deploy_status "failed"
        
        # 显示故障排查提示
        show_troubleshooting_tips
        exit 1
    fi
}

# 显示部署摘要
show_deployment_summary() {
    local deploy_env=$(buildkite-agent meta-data get "deploy_environment" --default "production")
    local image_name=$(buildkite-agent meta-data get "full_image_name" --default "unknown")
    
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║          部署成功摘要                  ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ 环境: ${deploy_env}                    "
    echo "║ 镜像: ${image_name}                    "
    echo "║ 时间: $(date '+%Y-%m-%d %H:%M:%S')     "
    echo "║ 状态: ✅ 成功                         "
    echo "╚════════════════════════════════════════╝"
    echo ""
}

# 显示故障排查提示
show_troubleshooting_tips() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║          故障排查提示                  ║"
    echo "╠════════════════════════════════════════╣"
    echo "║ 1. 检查配置文件: cat /tmp/app.env      "
    echo "║ 2. 检查容器状态: docker ps -a         "
    echo "║ 3. 查看容器日志: docker logs <name>   "
    echo "║ 4. 检查端口占用: netstat -tlnp        "
    echo "║ 5. 手动测试健康检查接口                "
    echo "╚════════════════════════════════════════╝"
    echo ""
}

# 预检查环境
pre_check_environment() {
    log_info "执行环境预检查..."
    
    # 检查Docker是否可用
    if ! check_docker; then
        log_error "环境预检查失败：Docker不可用"
        exit 1
    fi
    
    # 检查必要的buildkite-agent命令
    if ! command -v buildkite-agent &> /dev/null; then
        log_error "环境预检查失败：buildkite-agent命令不可用"
        exit 1
    fi
    
    # 检查配置目录
    if [[ ! -d "/tmp" ]]; then
        log_error "环境预检查失败：/tmp目录不存在"
        exit 1
    fi
    
    log_success "环境预检查通过"
}

# =================== 主流程 ===================

main() {
    # 获取项目根目录
    local project_root="${1:-$(pwd)}"
    
    log_info "部署编排器启动"
    log_info "项目根目录: $project_root"
    
    # 显示环境信息
    show_environment
    
    # 环境预检查
    pre_check_environment
    
    # 执行部署流程
    execute_deployment "$project_root"
    
    log_success "部署编排完成"
}

# 如果脚本被直接执行，则运行主流程
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi