#!/bin/bash
set -euo pipefail

# 函数：获取环境特定配置
get_env_config() {
  local config_name="$1"
  local default_value="${2:-}"
  
  # 从 meta-data 获取环境前缀
  local env_prefix=$(buildkite-agent meta-data get "env_prefix" --default "PROD")
  local prefixed_name="${env_prefix}_${config_name}"
  
  # 优先获取带前缀的配置，如果不存在则获取通用配置
  local result=$(buildkite-agent secret get "$prefixed_name" 2>/dev/null || buildkite-agent secret get "$config_name" 2>/dev/null || echo "$default_value")
  echo "$result"
}

# 函数：获取共用密钥
get_shared_secret() {
  local secret_name="$1"
  buildkite-agent secret get "$secret_name"
}

echo "--- :key: Authenticating with GitHub Container Registry"

# 获取环境信息
ENV_NAME=$(buildkite-agent meta-data get "env_name" --default "生产环境")
ENV_EMOJI=$(buildkite-agent meta-data get "env_emoji" --default "🚀")
echo "部署环境: ${ENV_EMOJI} ${ENV_NAME}"

# 使用共用的 GitHub Container Registry 凭证
SECRET_GHCR_TOKEN=$(get_shared_secret "GHCR_TOKEN")
if [[ -z "$SECRET_GHCR_TOKEN" ]]; then
  echo "Error: GHCR_PAT secret not found in Buildkite Secrets."
  exit 1
fi

# 使用 --password-stdin 以非交互方式安全地登录
echo "$SECRET_GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

echo "--- :docker: Pulling Docker image"

# IMAGE_TAG 环境变量由 GitHub Actions 触发时传入
if [[ -z "${DOCKER_IMAGE_TAG:-}" ]]; then
  echo "Error: IMAGE_TAG environment variable is not set."
  exit 1
fi

# 构造完整的镜像名称
echo "Image to pull: $DOCKER_IMAGE_TAG"

# 拉取镜像
docker pull "$DOCKER_IMAGE_TAG"

echo "--- :buildkite: Storing image name in build metadata"
# 将完整的镜像名称存入 meta-data，供后续部署步骤使用
buildkite-agent meta-data set "full_image_name" "$DOCKER_IMAGE_TAG"