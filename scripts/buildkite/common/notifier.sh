#!/bin/bash
# 通用通知脚本 - 简化版本
# 支持 Lark/飞书通知

set -euo pipefail

echo "--- 发送部署通知"

# 获取部署状态
DEPLOY_STATUS=$(buildkite-agent meta-data get "deploy_status" --default "unknown")
echo "部署状态: ${DEPLOY_STATUS}"

# 获取 Lark Webhook URL
echo "获取 Lark Webhook URL..."
if buildkite-agent secret get "LARK_WEBHOOK_URL" &>/dev/null; then
    LARK_WEBHOOK_URL=$(buildkite-agent secret get "LARK_WEBHOOK_URL")
    echo "✅ 成功获取 LARK_WEBHOOK_URL"
else
    echo "⚠️  LARK_WEBHOOK_URL secret 未配置，跳过通知"
    exit 0
fi

# 获取环境信息
DEPLOY_ENV=$(buildkite-agent meta-data get "deploy_environment" --default "production")
IMAGE_NAME=$(buildkite-agent meta-data get "full_image_name" --default "unknown")

# 设置环境特定配置
case "$DEPLOY_ENV" in
    "test")
        ENV_NAME="测试环境"
        ENV_EMOJI="🧪"
        ENV_COLOR="blue"
        ;;
    "production")
        ENV_NAME="生产环境"
        ENV_EMOJI="🚀"
        ENV_COLOR="green"
        ;;
    *)
        ENV_NAME="未知环境"
        ENV_EMOJI="❓"
        ENV_COLOR="gray"
        ;;
esac

# 根据状态设置颜色和图标
if [[ "$DEPLOY_STATUS" == "success" ]]; then
    HEADER_COLOR="$ENV_COLOR"
    STATUS_EMOJI="✅"
    MESSAGE_TITLE="${ENV_EMOJI} ${ENV_NAME} 部署成功"
else
    HEADER_COLOR="red"
    STATUS_EMOJI="❌"
    MESSAGE_TITLE="${ENV_EMOJI} ${ENV_NAME} 部署失败"
fi

# 获取 Git 信息
BRANCH="${BUILDKITE_BRANCH:-unknown}"
COMMIT="${BUILDKITE_COMMIT:-unknown}"
COMMIT_SHORT="${COMMIT:0:7}"
AUTHOR="${BUILDKITE_BUILD_AUTHOR:-unknown}"
MESSAGE="${BUILDKITE_MESSAGE:-unknown}"
REPO="${GITHUB_REPOSITORY:-unknown}"

# 构建 Lark 消息
echo "构建通知消息..."
LARK_MESSAGE=$(cat <<EOF
{
  "msg_type": "interactive",
  "card": {
    "config": {
      "wide_screen_mode": true
    },
    "header": {
      "template": "${HEADER_COLOR}",
      "title": {
        "content": "${STATUS_EMOJI} ${MESSAGE_TITLE}",
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
              "content": "**仓库 Repository:**\\n${REPO}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": false,
            "text": {
              "content": "**环境 Environment:**\\n${ENV_EMOJI} ${ENV_NAME}",
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
              "content": "**分支 Branch:**\\n${BRANCH}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": true,
            "text": {
              "content": "**提交 Commit:**\\n${COMMIT_SHORT}",
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
              "content": "**作者 Author:**\\n${AUTHOR}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": false,
            "text": {
              "content": "**提交信息 Message:**\\n${MESSAGE}",
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
              "content": "**镜像 Image:**\\n\`${IMAGE_NAME}\`",
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
)

# 发送 Lark 通知
echo "发送 Lark 通知..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$LARK_MESSAGE" \
    "$LARK_WEBHOOK_URL")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "✅ Lark 通知发送成功"
else
    echo "❌ Lark 通知发送失败 (HTTP ${HTTP_CODE})"
    echo "响应: ${BODY}"
fi

echo "✅ 通知流程完成"