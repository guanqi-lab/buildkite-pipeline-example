#!/bin/bash
# 项目部署脚本 - 简化版本
# 使用docker run启动容器，挂载配置文件

set -euo pipefail

echo "--- 开始部署"

# 获取配置文件路径
CONFIG_FILE="${CONFIG_OUTPUT_FILE:-$(buildkite-agent meta-data get "config_file_path" --default "/tmp/env" 2>/dev/null || echo "/tmp/env")}"
echo "配置文件路径: $CONFIG_FILE"

# 获取镜像信息
FULL_IMAGE_NAME=$(buildkite-agent meta-data get "full_image_name")
if [[ -z "$FULL_IMAGE_NAME" ]]; then
    echo "❌ 无法获取镜像信息"
    exit 1
fi
echo "镜像: $FULL_IMAGE_NAME"

# 获取环境信息
DEPLOY_ENVIRONMENT="${DEPLOY_ENVIRONMENT:-$(buildkite-agent meta-data get "deploy_environment" --default "production" 2>/dev/null || echo "production")}"
echo "部署环境: $DEPLOY_ENVIRONMENT"

# 根据环境设置端口
if [[ "$DEPLOY_ENVIRONMENT" == "test" ]]; then
    HOST_PORT="3080"
else
    HOST_PORT="38080"
fi

# 服务和容器配置
SERVICE_NAME="buildkite-example"
CONTAINER_PORT="8080"
CONTAINER_NAME="$SERVICE_NAME"

echo "服务名称: $SERVICE_NAME"
echo "主机端口: $HOST_PORT"
echo "容器端口: $CONTAINER_PORT"

# 停止并删除旧容器
echo "--- 清理旧容器"
if docker stop "$CONTAINER_NAME" 2>/dev/null; then
    echo "✅ 旧容器已停止"
else
    echo "ℹ️ 没有运行中的旧容器"
fi

if docker rm "$CONTAINER_NAME" 2>/dev/null; then
    echo "✅ 旧容器已移除"
else
    echo "ℹ️ 没有需要移除的旧容器"
fi

# 启动新容器
echo "--- 启动新容器"
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart always \
  -p "$HOST_PORT:$CONTAINER_PORT" \
  --env-file "$CONFIG_FILE" \
  -e "ENVIRONMENT=$DEPLOY_ENVIRONMENT" \
  -e "PORT=$CONTAINER_PORT" \
  "$FULL_IMAGE_NAME"

if [[ $? -eq 0 ]]; then
    echo "✅ 容器启动成功"
    
    # 显示容器状态
    echo "--- 容器状态"
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo "✅ 部署完成"
else
    echo "❌ 容器启动失败"
    exit 1
fi