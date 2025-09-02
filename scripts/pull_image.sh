#!/bin/bash
# 镜像拉取脚本 - 调用通用镜像拉取模块
# 项目可以直接使用，无需修改

set -euo pipefail

# 调用通用镜像拉取脚本
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/common/image-puller.sh"