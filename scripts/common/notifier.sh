#!/bin/bash
# 通用通知脚本 - 完全标准化
# 支持 Lark/飞书通知

set -euo pipefail

# 加载通用工具函数
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# =================== 通知模板配置 ===================

# 定义环境特定的UI样式
get_env_ui_config() {
  local deploy_env="$1"
  
  case "$deploy_env" in
    "test")
      echo "name:测试环境|emoji:🧪|color:blue"
      ;;
    "production")
      echo "name:生产环境|emoji:🚀|color:green"
      ;;
    *)
      echo "name:未知环境|emoji:❓|color:gray"
      ;;
  esac
}

# 解析UI配置字符串
parse_ui_config() {
  local config="$1"
  local field="$2"
  
  echo "$config" | tr '|' '\n' | grep "^${field}:" | cut -d':' -f2
}

# =================== 通知函数 ===================

# 构建 Lark 消息卡片
build_lark_message() {
  local status="$1"
  
  # 获取环境信息
  local deploy_env=$(buildkite-agent meta-data get "deploy_environment" --default "production")
  local ui_config=$(get_env_ui_config "$deploy_env")
  
  # 解析UI配置
  local env_name=$(parse_ui_config "$ui_config" "name")
  local env_emoji=$(parse_ui_config "$ui_config" "emoji")
  local env_color=$(parse_ui_config "$ui_config" "color")
  
  local image_name=$(buildkite-agent meta-data get "full_image_name" --default "unknown")
  
  # 根据状态设置颜色和图标
  local header_color="$env_color"
  local status_emoji="✅"
  local message_title="${env_emoji} ${env_name} 部署成功"
  
  if [[ "$status" != "success" ]]; then
    header_color="red"
    status_emoji="❌"
    message_title="${env_emoji} ${env_name} 部署失败"
  fi
  
  # 获取 Git 信息
  local branch="${BUILDKITE_BRANCH:-$(get_git_info 'branch')}"
  local commit="${BUILDKITE_COMMIT:-$(get_git_info 'commit')}"
  local commit_short="${commit:0:7}"
  local author="${BUILDKITE_BUILD_AUTHOR:-$(get_git_info 'author')}"
  local message="${BUILDKITE_MESSAGE:-$(get_git_info 'message')}"
  local repo="${GITHUB_REPOSITORY:-unknown}"
  
  # 构建 JSON 消息
  cat <<EOF
{
  "msg_type": "interactive",
  "card": {
    "config": {
      "wide_screen_mode": true
    },
    "header": {
      "template": "${header_color}",
      "title": {
        "content": "${status_emoji} ${message_title}",
        "tag": "plain_text"
      }
    },
    "elements": [
      {
        "tag": "div",
        "fields": [
          {
            "is_short": false,
            "text": {
              "content": "**仓库 Repository:**\\n${repo}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": false,
            "text": {
              "content": "**环境 Environment:**\\n${env_emoji} ${env_name}",
              "tag": "lark_md"
            }
          }
        ]
      },
      {
        "tag": "hr"
      },
      {
        "tag": "div",
        "fields": [
          {
            "is_short": true,
            "text": {
              "content": "**分支 Branch:**\\n${branch}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": true,
            "text": {
              "content": "**提交 Commit:**\\n${commit_short}",
              "tag": "lark_md"
            }
          }
        ]
      },
      {
        "tag": "div",
        "fields": [
          {
            "is_short": false,
            "text": {
              "content": "**作者 Author:**\\n${author}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": false,
            "text": {
              "content": "**提交信息 Message:**\\n${message}",
              "tag": "lark_md"
            }
          }
        ]
      },
      {
        "tag": "hr"
      },
      {
        "tag": "div",
        "fields": [
          {
            "is_short": false,
            "text": {
              "content": "**镜像 Image:**\\n\`${image_name}\`",
              "tag": "lark_md"
            }
          }
        ]
      },
      {
        "tag": "action",
        "actions": [
          {
            "tag": "button",
            "text": {
              "content": "查看构建",
              "tag": "lark_md"
            },
            "url": "${BUILDKITE_BUILD_URL:-#}",
            "type": "default"
          }
        ]
      }
    ]
  }
}
EOF
}

# 发送 Lark 通知
send_lark_notification() {
  local webhook_url="$1"
  local message="$2"
  
  local response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$message" \
    "$webhook_url")
  
  local http_code=$(echo "$response" | tail -n1)
  local body=$(echo "$response" | head -n-1)
  
  if [[ "$http_code" == "200" ]]; then
    log_success "Lark 通知发送成功"
    return 0
  else
    log_error "Lark 通知发送失败 (HTTP ${http_code})"
    log_error "响应: ${body}"
    return 1
  fi
}

# =================== 主流程 ===================

start_step "发送部署通知"

# 显示环境信息
show_environment

# 获取部署状态
DEPLOY_STATUS=$(get_deploy_status)
log_info "部署状态: ${DEPLOY_STATUS}"

# 获取 Lark Webhook URL - 直接从 buildkite secret 获取
log_info "获取 Lark Webhook URL..."
if buildkite-agent secret get "LARK_WEBHOOK_URL" &>/dev/null; then
    LARK_WEBHOOK_URL=$(buildkite-agent secret get "LARK_WEBHOOK_URL")
    log_info "✓ 成功获取 LARK_WEBHOOK_URL"
else
    log_warning "LARK_WEBHOOK_URL secret 未配置，跳过通知"
    exit 0
fi

# 构建消息
log_info "构建通知消息..."
LARK_MESSAGE=$(build_lark_message "$DEPLOY_STATUS")

# 发送通知
log_info "发送 Lark 通知..."
if send_lark_notification "$LARK_WEBHOOK_URL" "$LARK_MESSAGE"; then
  log_success "通知发送完成"
else
  log_warning "通知发送失败，但不影响构建状态"
fi