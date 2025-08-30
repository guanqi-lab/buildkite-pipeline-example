#!/bin/bash
set -euo pipefail # 遇到错误立即退出

echo "--- :key: Authenticating with GitHub Container Registry"

# 1. 从安全存储中检索 PAT
# 假设使用 Buildkite Secrets
export GHCR_TOKEN=$(buildkite-agent secret get GHCR_PAT)
if]; then
  echo "Error: GHCR_PAT secret not found in Buildkite Secrets."
  exit 1
fi

# 2. 执行非交互式 Docker 登录
# 使用 --password-stdin 避免密码出现在进程列表或日志中
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
# $GITHUB_USERNAME 是一个需要在 Buildkite 流水线环境变量中预设的变量

echo "--- :docker: Pulling Docker image"

# 3. 构造完整的镜像名称
# IMAGE_TAG 变量由 GitHub Action 触发时传入
if]; then
  echo "Error: IMAGE_TAG environment variable is not set."
  exit 1
fi
FULL_IMAGE_NAME="ghcr.io/your-org/your-repo:${IMAGE_TAG}"
echo "Image to pull: $FULL_IMAGE_NAME"

# 4. 拉取镜像
docker pull "$FULL_IMAGE_NAME"

echo "--- :buildkite: Storing image name in build metadata"

# 5. 将完整的镜像名称存入 meta-data，供后续步骤使用
buildkite-agent meta-data set "full_image_name" "$FULL_IMAGE_NAME"