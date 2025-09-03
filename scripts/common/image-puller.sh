#!/bin/bash
# 通用镜像拉取脚本 - 完全标准化
# 所有项目都可以直接使用，无需修改

set -euo pipefail

# 加载通用工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# =================== 主流程 ===================

start_step "Docker 镜像拉取"

# 显示环境信息
show_environment

## 检查 Docker 服务
#if ! check_docker; then
#  log_error "Docker 服务检查失败"
#  exit 1
#fi

# 获取认证信息
log_info "获取 GitHub Container Registry 认证信息..."
GHCR_TOKEN=$(get_shared_config "GHCR_TOKEN")
GITHUB_USERNAME="${GITHUB_USERNAME:-${GITHUB_REPOSITORY%/*}}"

if [[ -z "$GHCR_TOKEN" ]]; then
  log_error "GHCR_TOKEN 未配置，请在 Buildkite Secrets 中设置"
  exit 1
fi

# 登录到 GitHub Container Registry
log_info "登录到 GitHub Container Registry..."
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

if [[ $? -ne 0 ]]; then
  log_error "Docker 登录失败"
  exit 1
fi
log_success "Docker 登录成功"

# 获取镜像标签
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-}"
if [[ -z "$DOCKER_IMAGE_TAG" ]]; then
  log_error "DOCKER_IMAGE_TAG 环境变量未设置"
  exit 1
fi

log_info "准备拉取镜像: ${DOCKER_IMAGE_TAG}"

# 拉取镜像
log_info "开始拉取 Docker 镜像..."
if docker pull "$DOCKER_IMAGE_TAG"; then
  log_success "镜像拉取成功: ${DOCKER_IMAGE_TAG}"
  
  # 保存镜像信息到 meta-data
  buildkite-agent meta-data set "full_image_name" "$DOCKER_IMAGE_TAG"
  log_info "镜像信息已保存到 meta-data"
  
  # 显示镜像信息
  log_info "镜像详情:"
  docker images --filter "reference=${DOCKER_IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
else
  log_error "镜像拉取失败: ${DOCKER_IMAGE_TAG}"
  exit 1
fi

# 清理旧镜像（可选）
log_info "清理未使用的镜像..."
docker image prune -f || true

log_success "镜像拉取流程完成"