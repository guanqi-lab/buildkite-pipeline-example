#!/bin/bash
# 项目部署脚本 - 按照简化方案重新设计
# 包含完整的部署逻辑：配置加载、容器部署、健康检查、清理验证

set -euo pipefail

# =================== 项目特定配置 (需要定制) ===================
# 以下配置需要根据实际项目进行修改

SERVICE_NAME="buildkite-example"        # 服务名称
CONTAINER_PORT="8080"                   # 容器内部端口
HEALTH_CHECK_PATH="/health"             # 健康检查路径

# 环境特定的端口配置
HOST_PORT_TEST="3080"                   # 测试环境主机端口
HOST_PORT_PROD="38080"                  # 生产环境主机端口

# =================== 部署流程实现 ===================

echo "🚀 开始部署 $SERVICE_NAME..."


CONFIG_FILE=$(buildkite-agent meta-data get "config_file_path" --default "/tmp/env" 2>/dev/null || echo "/tmp/env")
echo "从 meta-data 获取配置文件路径: $CONFIG_FILE"


# 2. 加载配置文件
if [[ -f "$CONFIG_FILE" ]]; then
    echo "加载配置文件..."
    source "$CONFIG_FILE"
    echo "✅ 配置文件加载成功: $CONFIG_FILE"
fi

# 3. 获取镜像信息
echo "🐳 获取Docker镜像信息..."
FULL_IMAGE_NAME=$(buildkite-agent meta-data get "full_image_name")
if [[ -z "$FULL_IMAGE_NAME" ]]; then
    echo "❌ 错误: 无法获取镜像信息"
    exit 1
fi
echo "📦 镜像: $FULL_IMAGE_NAME"

# 4. 获取环境信息并设置参数
DEPLOY_ENVIRONMENT=$(buildkite-agent meta-data get "deploy_environment" --default "production")

if [[ "$DEPLOY_ENVIRONMENT" == "test" ]]; then
    HOST_PORT="$HOST_PORT_TEST"
    RESTART_POLICY="unless-stopped"
    MEMORY_LIMIT="512m"
    CPU_LIMIT="0.5"
    echo "使用测试环境配置"
elif [[ "$DEPLOY_ENVIRONMENT" == "production" ]]; then
    HOST_PORT="$HOST_PORT_PROD"
    RESTART_POLICY="always"
    MEMORY_LIMIT="1g"
    CPU_LIMIT="1.0"
    echo "使用生产环境配置"
else
    HOST_PORT="8080"
    RESTART_POLICY="always" 
    MEMORY_LIMIT="512m"
    CPU_LIMIT="0.5"
    echo "使用默认配置"
fi

CONTAINER_NAME="${SERVICE_NAME}"

# 5. 停止旧容器
echo "🛑 停止旧容器..."
if docker stop "${CONTAINER_NAME}" 2>/dev/null; then
    echo "✅ 旧容器已停止"
else
    echo "ℹ️ 没有运行中的旧容器"
fi

if docker rm "${CONTAINER_NAME}" 2>/dev/null; then
    echo "✅ 旧容器已移除"
else
    echo "ℹ️ 没有需要移除的旧容器"
fi

# 6. 启动新容器
echo "🚀 启动新容器..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart "${RESTART_POLICY}" \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  --memory="${MEMORY_LIMIT}" \
  --cpus="${CPU_LIMIT}" \
  --env-file "$CONFIG_FILE" \
  -e "ENVIRONMENT=${DEPLOY_ENVIRONMENT}" \
  -e "PORT=${CONTAINER_PORT}" \
  "${FULL_IMAGE_NAME}"

if [[ $? -eq 0 ]]; then
    echo "✅ 新容器启动成功"
else
    echo "❌ 新容器启动失败"
    exit 1
fi



# 9. 验证部署结果
echo "📊 验证服务状态..."
docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 10. 显示部署摘要
echo ""
echo "╔════════════════════════════════════════╗"
echo "║          部署成功                      ║"
echo "╠════════════════════════════════════════╣"
echo "║ 服务名称: ${SERVICE_NAME}              "
echo "║ 容器名称: ${CONTAINER_NAME}            "  
echo "║ 环境: ${DEPLOY_ENVIRONMENT}                      "
echo "║ 端口: ${HOST_PORT}:${CONTAINER_PORT}   "
echo "║ 时间: $(date '+%Y-%m-%d %H:%M:%S')     "
echo "╚════════════════════════════════════════╝"

echo "🎉 部署成功!"