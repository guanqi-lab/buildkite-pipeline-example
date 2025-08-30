#!/bin/bash
set -euo pipefail

echo "--- :key: Authenticating with GitHub Container Registry"

# 从 Buildkite Secrets 安全地获取 GitHub PAT
# 确保您已在 Buildkite 集群中创建了名为 GHCR_PAT 的 Secret
SECRET_GHCR_TOKEN=$(buildkite-agent secret get GHCR_TOKEN)
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