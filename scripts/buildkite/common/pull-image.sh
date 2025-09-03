#!/bin/bash
# 通用镜像拉取脚本 - 简化版本
# 所有项目都可以直接使用，无需修改

set -euo pipefail

echo "--- Docker 镜像拉取"

# 检查 Docker 服务
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装或不在 PATH 中"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker 服务未运行或无权限访问"
    exit 1
fi

echo "✅ Docker 服务正常"

# 获取认证信息
echo "获取 GitHub Container Registry 认证信息..."
GHCR_TOKEN=$(buildkite-agent secret get "GHCR_TOKEN" 2>/dev/null || echo "")
GITHUB_USERNAME="${GITHUB_USERNAME:-${GITHUB_REPOSITORY%/*}}"

if [[ -z "$GHCR_TOKEN" ]]; then
    echo "❌ GHCR_TOKEN 未配置，请在 Buildkite Secrets 中设置"
    exit 1
fi

# 登录到 GitHub Container Registry
echo "登录到 GitHub Container Registry..."
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin

if [[ $? -ne 0 ]]; then
    echo "❌ Docker 登录失败"
    exit 1
fi
echo "✅ Docker 登录成功"

# 获取镜像标签
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-}"
if [[ -z "$DOCKER_IMAGE_TAG" ]]; then
    echo "❌ DOCKER_IMAGE_TAG 环境变量未设置"
    exit 1
fi

echo "准备拉取镜像: ${DOCKER_IMAGE_TAG}"

# 拉取镜像
echo "开始拉取 Docker 镜像..."
if docker pull "$DOCKER_IMAGE_TAG"; then
    echo "✅ 镜像拉取成功: ${DOCKER_IMAGE_TAG}"
    
    # 保存镜像信息到 meta-data
    buildkite-agent meta-data set "full_image_name" "$DOCKER_IMAGE_TAG"
    echo "镜像信息已保存到 meta-data"
    
    # 显示镜像信息
    echo "镜像详情:"
    docker images --filter "reference=${DOCKER_IMAGE_TAG}" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
else
    echo "❌ 镜像拉取失败: ${DOCKER_IMAGE_TAG}"
    exit 1
fi

echo "✅ 镜像拉取流程完成"