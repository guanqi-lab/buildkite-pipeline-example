#!/bin/bash
set -euo pipefail

# 函数：将 Git SSH URL 转换为 HTTPS URL
convert_git_url_to_https() {
  local git_url="$1"
  
  # 如果已经是 HTTPS URL，直接返回去掉 .git 后缀
  if [[ "$git_url" =~ ^https:// ]]; then
    echo "${git_url%.git}"
    return
  fi
  
  # 转换 SSH 格式到 HTTPS 格式
  # git@github.com:user/repo.git -> https://github.com/user/repo
  if [[ "$git_url" =~ git@([^:]+):(.+)\.git$ ]]; then
    local host="${BASH_REMATCH[1]}"
    local path="${BASH_REMATCH[2]}"
    echo "https://$host/$path"
  else
    # 如果格式不匹配，返回原始 URL（去掉 .git 后缀）
    echo "${git_url%.git}"
  fi
}

# 函数：安全地执行 git 命令并返回结果
safe_git_command() {
  local git_cmd="$1"
  local default_value="${2:-Unknown}"
  
  if command -v git &> /dev/null && [[ -d .git ]]; then
    eval "$git_cmd" 2>/dev/null || echo "$default_value"
  else
    echo "$default_value"
  fi
}

# 函数：获取环境特定配置
get_env_config() {
  local config_name="$1"
  local default_value="${2:-}"
  
  # 从 meta-data 获取环境前缀
  local env_prefix=$(buildkite-agent meta-data get "env_prefix" --default "PROD")
  local prefixed_name="${env_prefix}_${config_name}"
  
  # 优先获取带前缀的配置，如果不存在则获取通用配置
  local result=$(buildkite-agent secret get "$prefixed_name" 2>/dev/null || buildkite-agent secret get "$config_name" 2>/dev/null || echo "$default_value")
  echo "$result"
}

# 函数：获取共用密钥
get_shared_secret() {
  local secret_name="$1"
  buildkite-agent secret get "$secret_name"
}

# 从 Buildkite Secrets 获取 Lark 凭证（使用共用配置）
LARK_WEBHOOK_URL=$(get_shared_secret "LARK_WEBHOOK_URL")
LARK_SIGNING_SECRET=$(get_shared_secret "LARK_SIGNING_SECRET")

# 获取环境信息
DEPLOY_ENVIRONMENT=$(buildkite-agent meta-data get "deploy_environment" --default "production")
ENV_NAME=$(buildkite-agent meta-data get "env_name" --default "生产环境")
ENV_EMOJI=$(buildkite-agent meta-data get "env_emoji" --default "🚀")

echo "--- :通知环境: ${ENV_EMOJI} ${ENV_NAME}"

# 检查部署状态
# 从 meta-data 读取部署状态，如果不存在则默认为失败
DEPLOY_STATUS=$(buildkite-agent meta-data get "deploy_status" --default "1")
echo "--- :从 meta-data 读取部署状态: $DEPLOY_STATUS"

if [[ "$DEPLOY_STATUS" == "0" ]]; then
  STATUS="SUCCESS"
  # 根据环境设置不同的成功主题色
  if [[ "${DEPLOY_ENVIRONMENT}" == "test" ]]; then
    HEADER_COLOR="blue"  # 测试环境使用蓝色
  else
    HEADER_COLOR="green" # 生产环境使用绿色
  fi
  STATUS_EMOJI="✅"  # Unicode emoji for success
  MESSAGE_TITLE="${ENV_EMOJI} ${ENV_NAME} Deployment Succeeded"
else
  STATUS="FAILED"
  HEADER_COLOR="red"
  STATUS_EMOJI="❌"  # Unicode emoji for failure
  MESSAGE_TITLE="${ENV_EMOJI} ${ENV_NAME} Deployment Failed"
fi

# 获取构建上下文信息
FULL_IMAGE_NAME=$(buildkite-agent meta-data get "full_image_name")
echo "--- :FULL_IMAGE_NAME: $FULL_IMAGE_NAME"

# 获取 Git 仓库信息并转换 URL 格式
REPO_URL=$(convert_git_url_to_https "${BUILDKITE_REPO:-}")
echo "--- :转换后的仓库URL: $REPO_URL"

# 获取仓库名称，优先使用 GitHub Actions 传递的环境变量
REPO_NAME="${GITHUB_REPOSITORY:-${BUILDKITE_PIPELINE_SLUG:-Unknown Repository}}"
echo "--- :仓库名称: $REPO_NAME"

# 获取 commit 详细信息
COMMIT_AUTHOR_NAME=$(safe_git_command "git show -s --format='%an' '${BUILDKITE_COMMIT:-HEAD}'" "${BUILDKITE_BUILD_AUTHOR_EMAIL:-Unknown}")
COMMIT_MESSAGE="${BUILDKITE_MESSAGE:-$(safe_git_command "git show -s --format='%s' '${BUILDKITE_COMMIT:-HEAD}'" "No commit message")}"
COMMIT_TIMESTAMP=$(safe_git_command "git show -s --format='%ci' '${BUILDKITE_COMMIT:-HEAD}'" "Unknown")
COMMIT_SHORT_SHA="${BUILDKITE_COMMIT:0:7}"

echo "--- :Commit作者: $COMMIT_AUTHOR_NAME"
echo "--- :Commit信息: $COMMIT_MESSAGE"
echo "--- :Commit时间: $COMMIT_TIMESTAMP"

TIMESTAMP=$(date +%s)

# 构造 Lark 消息卡片 JSON 负载
# 使用 'heredoc' 语法简化多行字符串处理
read -r -d '' PAYLOAD << EOM || true
{
  "timestamp": "${TIMESTAMP}",
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
        "fields": [
          {
            "is_short": false,
            "text": {
              "content": "**仓库 Repository:**\\n[${REPO_NAME}](${REPO_URL})",
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
        ],
        "tag": "div"
      },
      {
        "tag": "hr"
      },
      {
        "fields": [
          {
            "is_short": true,
            "text": {
              "content": "**分支 Branch:**\\n${BUILDKITE_BRANCH}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": true,
            "text": {
              "content": "**状态 Status:**\\n${STATUS}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": false,
            "text": {
              "content": "**提交 Commit:**\\n[${COMMIT_SHORT_SHA}](${REPO_URL}/commit/${BUILDKITE_COMMIT})",
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
        "fields": [
          {
            "is_short": false,
            "text": {
              "content": "**提交作者 Author:**\\n${COMMIT_AUTHOR_NAME}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": false,
            "text": {
              "content": "**提交时间 Commit Time:**\\n${COMMIT_TIMESTAMP}",
              "tag": "lark_md"
            }
          },
          {
            "is_short": false,
            "text": {
              "content": "**提交信息 Commit Message:**\\n${COMMIT_MESSAGE}",
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
        "fields": [
          {
            "is_short": false,
            "text": {
              "content": "**Docker镜像 Image:**\\n\`${FULL_IMAGE_NAME}\`",
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
        "actions": [
          {
            "tag": "button",
            "text": {
              "content": "查看构建 View Build",
              "tag": "lark_md"
            },
            "url": "${BUILDKITE_BUILD_URL}",
            "type": "default"
          },
          {
            "tag": "button",
            "text": {
              "content": "查看提交 View Commit",
              "tag": "lark_md"
            },
            "url": "${REPO_URL}/commit/${BUILDKITE_COMMIT}",
            "type": "default"
          }
        ],
        "tag": "action"
      }
    ]
  }
}
EOM

# 发送 POST 请求到 Lark Webhook
echo "--- :发送 Lark 通知中..."

if [[ -z "$LARK_WEBHOOK_URL" ]]; then
  echo "⚠️  警告：LARK_WEBHOOK_URL 未设置，跳过通知发送"
  exit 0
fi

# 使用 curl 发送请求并检查结果
HTTP_STATUS=$(curl -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "${PAYLOAD}" "${LARK_WEBHOOK_URL}" -s -o /tmp/lark_response.log)

if [[ "$HTTP_STATUS" -ge 200 && "$HTTP_STATUS" -lt 300 ]]; then
  echo "✅ Lark 通知发送成功！(HTTP $HTTP_STATUS)"
else
  echo "❌ Lark 通知发送失败！(HTTP $HTTP_STATUS)"
  echo "响应内容："
  cat /tmp/lark_response.log 2>/dev/null || echo "无响应内容"
  # 不要因为通知失败而让整个构建失败
  echo "⚠️  通知发送失败，但不影响构建状态"
fi

# 清理临时文件
rm -f /tmp/lark_response.log