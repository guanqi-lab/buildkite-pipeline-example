#!/bin/bash
set -euo pipefail

echo "--- :key: Authenticating with GitHub Container Registry"

# 从 Buildkite Secrets 安全地获取 GitHub PAT
# 确保您已在 Buildkite 集群中创建了名为 GHCR_PAT 的 Secret
GHCR_TOKEN=$(buildkite-agent secret get GHCR_PAT)
if]; then
  echo "Error: GHCR_PAT secret not found in Buildkite Secrets."
  exit 1
fi

# 使用 --password-stdin 以非交互方式安全地登录
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

echo "--- :docker: Pulling Docker image"

# IMAGE_TAG 环境变量由 GitHub Actions 触发时传入
if]; then
  echo "Error: IMAGE_TAG environment variable is not set."
  exit 1
fi

# 构造完整的镜像名称
FULL_IMAGE_NAME="ghcr.io/${GITHUB_USERNAME}/${GITHUB_REPO_NAME}:${IMAGE_TAG}"
echo "Image to pull: $FULL_IMAGE_NAME"

# 拉取镜像
docker pull "$FULL_IMAGE_NAME"

echo "--- :buildkite: Storing image name in build metadata"
# 将完整的镜像名称存入 meta-data，供后续部署步骤使用
buildkite-agent meta-data set "full_image_name" "$FULL_IMAGE_NAME"