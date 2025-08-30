#!/bin/bash
set -euo pipefail

echo "--- :buildkite: Retrieving image name from build metadata"

# 1. 从 meta-data 中获取完整的镜像名称
FULL_IMAGE_NAME=$(buildkite-agent meta-data get "full_image_name")
CONTAINER_NAME=buildkite-golang-service

if [[ -z "$FULL_IMAGE_NAME" ]]; then
  echo "Error: Could not retrieve full_image_name from metadata."
  exit 1
fi

echo "--- :docker: Starting deployment with image: $FULL_IMAGE_NAME"

# 2. 执行实际的部署命令
# 这里的命令是一个示例，需要替换为您的实际部署逻辑
# 例如，更新一个 Kubernetes Deployment
docker rm -f $CONTAINER_NAME
docker run -d -p 38080:8080 --name "$CONTAINER_NAME" --restart always "$FULL_IMAGE_NAME"