#!/bin/bash
# 通用工具函数库 - 完全标准化
# 所有项目都可以直接使用，无需修改

set -euo pipefail

# =================== 环境配置函数 ===================

# 获取环境特定配置 (支持前缀优先级)
get_env_config() {
  local key="$1"
  local default="${2:-}"
  
  # 从 meta-data 获取配置前缀
  local config_prefix=$(buildkite-agent meta-data get "config_prefix" --default "PROD_")
  local prefixed_key="${config_prefix}${key}"
  
  # 配置优先级: PREFIX_KEY -> KEY -> default
  local result=$(buildkite-agent secret get "$prefixed_key" 2>/dev/null || \
                 buildkite-agent secret get "$key" 2>/dev/null || \
                 echo "$default")
  echo "$result"
}

# 获取共享配置
get_shared_config() {
  local key="$1"
  local default="${2:-}"
  buildkite-agent secret get "$key" 2>/dev/null || echo "$default"
}

# 获取环境信息
get_env_info() {
  local field="$1"
  local default="${2:-}"
  
  # 从 deploy_environment 推导环境信息
  local deploy_env=$(buildkite-agent meta-data get "deploy_environment" --default "production")
  
  case "$field" in
    "name")
      if [[ "$deploy_env" == "test" ]]; then
        echo "test"
      else
        echo "production"
      fi
      ;;
    "prefix")
      if [[ "$deploy_env" == "test" ]]; then
        echo "test"
      else
        echo "prod"
      fi
      ;;
    *)
      echo "$default"
      ;;
  esac
}

# =================== 容器管理函数 ===================

# 标准容器命名
get_container_name() {
  local service_name="${1:-app}"
  local env_prefix=$(get_env_info "prefix" "prod")
  echo "${env_prefix,,}-${service_name}"  # 转小写前缀
}

# 健康检查
health_check() {
  local container_name="$1"
  local max_wait="${2:-30}"
  local check_interval="${3:-1}"
  
  echo "⏳ 等待容器启动 (最多 ${max_wait} 秒)..."
  for i in $(seq 1 $max_wait); do
    if docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
      echo "✅ 容器 ${container_name} 启动成功"
      return 0
    fi
    sleep $check_interval
    echo -n "."
  done
  
  echo ""
  echo "❌ 容器 ${container_name} 启动失败或超时"
  docker logs "$container_name" 2>&1 | tail -20
  return 1
}

# 容器清理
cleanup_container() {
  local container_name="$1"
  
  if docker ps -a --format "table {{.Names}}" | grep -q "^${container_name}$"; then
    echo "🧹 清理旧容器: ${container_name}"
    docker rm -f "$container_name" 2>/dev/null || true
  else
    echo "📦 容器 ${container_name} 不存在，跳过清理"
  fi
}

# =================== 部署状态函数 ===================

# 设置部署状态
set_deploy_status() {
  local status="$1"  # success/failed
  buildkite-agent meta-data set "deploy_status" "$status"
  
  if [[ "$status" == "success" ]]; then
    echo "✅ 部署状态: 成功"
  else
    echo "❌ 部署状态: 失败"
  fi
}

# 获取部署状态
get_deploy_status() {
  buildkite-agent meta-data get "deploy_status" --default "unknown"
}

# =================== 日志和监控函数 ===================

# 彩色日志输出
log_info() {
  echo -e "\033[0;34m[INFO]\033[0m $1"
}

log_success() {
  echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

log_error() {
  echo -e "\033[0;31m[ERROR]\033[0m $1"
}

log_warning() {
  echo -e "\033[0;33m[WARNING]\033[0m $1"
}

# 步骤标记
start_step() {
  local step_name="$1"
  echo ""
  echo "--- 🔧 ${step_name}"
  echo ""
}

# =================== Git 相关函数 ===================

# 获取 Git 信息
get_git_info() {
  local info_type="$1"
  local default="${2:-unknown}"
  
  case "$info_type" in
    "branch")
      git branch --show-current 2>/dev/null || echo "$default"
      ;;
    "commit")
      git rev-parse HEAD 2>/dev/null || echo "$default"
      ;;
    "commit_short")
      git rev-parse --short HEAD 2>/dev/null || echo "$default"
      ;;
    "author")
      git log -1 --pretty=format:'%an' 2>/dev/null || echo "$default"
      ;;
    "message")
      git log -1 --pretty=format:'%s' 2>/dev/null || echo "$default"
      ;;
    "timestamp")
      git log -1 --pretty=format:'%ci' 2>/dev/null || echo "$default"
      ;;
    *)
      echo "$default"
      ;;
  esac
}

# =================== Docker 相关函数 ===================

# Docker 镜像标签生成
generate_image_tag() {
  local prefix="${1:-}"
  local branch=$(get_git_info "branch" "main")
  local commit=$(get_git_info "commit_short" "unknown")
  local date=$(date +%Y%m%d)
  
  if [[ -n "$prefix" ]]; then
    echo "${prefix}-${date}.${branch}.${commit}"
  else
    echo "${date}.${branch}.${commit}"
  fi
}

# 检查 Docker 服务
check_docker() {
  if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装或不在 PATH 中"
    return 1
  fi
  
  if ! docker info &> /dev/null; then
    log_error "Docker 服务未运行或无权限访问"
    return 1
  fi
  
  log_success "Docker 服务正常"
  return 0
}

# =================== 网络检测函数 ===================

# 端口检查
check_port() {
  local port="$1"
  local host="${2:-localhost}"
  
  if nc -z "$host" "$port" 2>/dev/null; then
    log_warning "端口 ${port} 已被占用"
    return 1
  else
    log_info "端口 ${port} 可用"
    return 0
  fi
}

# =================== 环境检测函数 ===================

# 显示当前环境信息
show_environment() {
  echo "╔════════════════════════════════════════╗"
  echo "║          环境信息                      ║"
  echo "╠════════════════════════════════════════╣"
  echo "║ 环境类型: $(get_env_info 'name' '未知')        "
  echo "║ 配置前缀: $(buildkite-agent meta-data get 'config_prefix' --default 'PROD_')"
  echo "║ Agent队列: $(buildkite-agent meta-data get 'agent_queue' --default 'default')"
  echo "║ Git分支: ${BUILDKITE_BRANCH:-unknown}          "
  echo "║ 构建号: ${BUILDKITE_BUILD_NUMBER:-0}           "
  echo "╚════════════════════════════════════════╝"
}

# =================== 导出所有函数 ===================
# 确保所有函数都可以在子shell中使用
export -f get_env_config
export -f get_shared_config
export -f get_env_info
export -f get_container_name
export -f health_check
export -f cleanup_container
export -f set_deploy_status
export -f get_deploy_status
export -f log_info
export -f log_success
export -f log_error
export -f log_warning
export -f start_step
export -f get_git_info
export -f generate_image_tag
export -f check_docker
export -f check_port
export -f show_environment