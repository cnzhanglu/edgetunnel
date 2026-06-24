#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

WRANGLER=(npx wrangler)
KV_TITLE="edgetunnel-cf-chihuo-kv"
WORKER_NAME="edgetunnel-cf-chihuo"
WRANGLER_TOML="$ROOT_DIR/wrangler.toml"

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  echo "错误: 请设置 CLOUDFLARE_API_TOKEN 环境变量"
  echo "  在 Cloudflare 控制台 → 我的个人资料 → API 令牌 → 创建令牌"
  echo "  权限建议: Account - Workers Scripts Edit, Workers KV Storage Edit, Workers Routes Edit"
  exit 1
fi

if [[ -z "${ADMIN:-}" ]]; then
  if [[ -f .dev.vars ]]; then
    # shellcheck disable=SC1091
    source <(grep -E '^ADMIN=' .dev.vars | sed 's/^/export /')
  fi
fi

if [[ -z "${ADMIN:-}" ]]; then
  echo "错误: 请设置 ADMIN 环境变量，或在 .dev.vars 中配置 ADMIN=你的管理密码"
  exit 1
fi

echo "==> 检查 Cloudflare 认证"
"${WRANGLER[@]}" whoami

echo "==> 确保 KV 命名空间存在: ${KV_TITLE}"
KV_ID=""
if KV_JSON="$("${WRANGLER[@]}" kv namespace list --json 2>/dev/null)"; then
  KV_ID="$(echo "$KV_JSON" | node -e "
    const list = JSON.parse(require('fs').readFileSync(0,'utf8'));
    const hit = list.find(n => n.title === process.argv[1]);
    if (hit) process.stdout.write(hit.id);
  " "$KV_TITLE" 2>/dev/null || true)"
fi

if [[ -z "$KV_ID" ]]; then
  echo "    创建 KV 命名空间..."
  KV_ID="$("${WRANGLER[@]}" kv namespace create "$KV_TITLE" --json | node -e "process.stdout.write(JSON.parse(require('fs').readFileSync(0,'utf8')).id)")"
fi
echo "    KV id: ${KV_ID}"

echo "==> 写入 KV 绑定到 wrangler.toml"
node - "$WRANGLER_TOML" "$KV_ID" <<'NODE'
const fs = require('fs');
const [file, kvId] = process.argv.slice(2);
let content = fs.readFileSync(file, 'utf8');

const kvBlock = `[[kv_namespaces]]\nbinding = "KV"\nid = "${kvId}"\n`;

if (/\[\[kv_namespaces\]\]/.test(content)) {
  content = content.replace(
    /\[\[kv_namespaces\]\][\s\S]*?(?=\n\[|\n#|\n*$)/,
    kvBlock.trim() + '\n\n'
  );
} else {
  content = content.replace(
    /(# KV 命名空间[\s\S]*?)(# 如需手动配置[\s\S]*?\n)?/,
    `$1\n${kvBlock}`
  );
}

fs.writeFileSync(file, content);
NODE

echo "==> 部署 Worker: ${WORKER_NAME}"
"${WRANGLER[@]}" deploy --name "$WORKER_NAME"

echo "==> 设置 ADMIN 密钥（生产环境 Secret）"
printf '%s' "$ADMIN" | "${WRANGLER[@]}" secret put ADMIN

echo ""
echo "部署完成!"
echo "  管理后台: https://cf.chihuo.fun/admin"
echo "  登录密码: （你设置的 ADMIN）"
echo ""
echo "上游代码更新后请在本仓库拉取最新代码，再运行: npm run deploy"
