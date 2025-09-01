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

echo "--- :buildkite: Retrieving image name from build metadata"

# 获取环境信息
DEPLOY_ENVIRONMENT=$(buildkite-agent meta-data get "deploy_environment" --default "production")
ENV_NAME=$(buildkite-agent meta-data get "env_name" --default "生产环境")
ENV_EMOJI=$(buildkite-agent meta-data get "env_emoji" --default "🚀")

echo "部署环境: ${ENV_EMOJI} ${ENV_NAME}"

# 1. 从 meta-data 中获取完整的镜像名称
FULL_IMAGE_NAME=$(buildkite-agent meta-data get "full_image_name")

# 2. 根据环境设置不同的部署配置
if [[ "${DEPLOY_ENVIRONMENT}" == "test" ]]; then
    # 测试环境：快速部署配置
    CONTAINER_NAME="test-buildkite-service"
    PORT_MAPPING="3080:8080"
    RESTART_POLICY="unless-stopped"
    echo "🧪 使用测试环境部署配置"
elif [[ "${DEPLOY_ENVIRONMENT}" == "production" ]]; then
    # 生产环境：稳定部署配置
    CONTAINER_NAME="prod-buildkite-service"
    PORT_MAPPING="38080:8080"
    RESTART_POLICY="always"
    echo "🚀 使用生产环境部署配置"
else
    # 默认配置
    CONTAINER_NAME="buildkite-service"
    PORT_MAPPING="8080:8080"
    RESTART_POLICY="always"
    echo "⚙️ 使用默认部署配置"
fi

if [[ -z "$FULL_IMAGE_NAME" ]]; then
  echo "Error: Could not retrieve full_image_name from metadata."
  exit 1
fi

echo "--- :docker: Starting deployment with image: $FULL_IMAGE_NAME"
echo "容器配置: $CONTAINER_NAME (端口: $PORT_MAPPING, 重启策略: $RESTART_POLICY)"

# 3. 执行实际的部署命令，捕获退出状态
DEPLOY_STATUS=0
# 这里的命令是一个示例，需要替换为您的实际部署逻辑
# 例如，更新一个 Kubernetes Deployment
docker rm -f $CONTAINER_NAME || true
if docker run -d -p "$PORT_MAPPING" --name "$CONTAINER_NAME" --restart "$RESTART_POLICY" "$FULL_IMAGE_NAME"; then
  DEPLOY_STATUS=0
  echo "✅ Deployment successful"
else
  DEPLOY_STATUS=1
  echo "❌ Deployment failed"
fi

# 3. 保存部署状态到 meta-data 供通知步骤使用
buildkite-agent meta-data set "deploy_status" "$DEPLOY_STATUS"

# 4. 根据部署状态退出
exit $DEPLOY_STATUS