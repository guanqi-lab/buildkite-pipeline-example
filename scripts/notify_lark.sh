#!/bin/bash
set -euo pipefail

# 从 Buildkite Secrets 获取 Lark 凭证
LARK_WEBHOOK_URL=$(buildkite-agent secret get LARK_WEBHOOK_URL)
LARK_SIGNING_SECRET=$(buildkite-agent secret get LARK_SIGNING_SECRET)

# 检查部署状态
if]; then
  STATUS="SUCCESS"
  HEADER_COLOR="green"
  STATUS_EMOJI=":white_check_mark:"
  MESSAGE_TITLE="Deployment Succeeded"
else
  STATUS="FAILED"
  HEADER_COLOR="red"
  STATUS_EMOJI=":x:"
  MESSAGE_TITLE="Deployment Failed"
fi

# 获取构建上下文信息
FULL_IMAGE_NAME=$(buildkite-agent meta-data get "full_image_name")

# 生成时间戳和签名（如果启用了签名校验）
TIMESTAMP=$(date +%s)
SIGN=$(echo -n -e "${TIMESTAMP}\n${LARK_SIGNING_SECRET}" | openssl dgst -sha256 -hmac "${LARK_SIGNING_SECRET}" -binary | base64)

# 构造 Lark 消息卡片 JSON 负载
# 使用 'heredoc' 语法简化多行字符串处理
read -r -d '' PAYLOAD << EOM
{
  "timestamp": "${TIMESTAMP}",
  "sign": "${SIGN}",
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
    "elements":(${BUILDKITE_REPO}/commit/${BUILDKITE_COMMIT})",
              "tag": "lark_md"
            }
          },
          {
            "is_short": true,
            "text": {
              "content": "**Status:**\n${STATUS}",
              "tag": "lark_md"
            }
          }
        ],
        "tag": "div"
      },
      {
        "tag": "hr"
      },
      {
        "actions":,
        "tag": "action"
      }
    ]
  }
}
EOM

# 发送 POST 请求到 Lark Webhook
curl -X POST -H "Content-Type: application/json" -d "${PAYLOAD}" "${LARK_WEBHOOK_URL}"