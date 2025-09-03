#!/bin/bash
# 通知脚本 - 调用通用通知模块
# 项目可以直接使用，无需修改

set -euo pipefail

# 调用通用通知脚本
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/common/notifier.sh"