# cf.chihuo.fun 部署说明

本 fork（`cnzhanglu/edgetunnel`）已配置：

| 项目 | 说明 |
|------|------|
| **Worker 名称** | `edgetunnel-cf-chihuo` |
| **访问域名** | `https://cf.chihuo.fun` |
| **管理后台** | `https://cf.chihuo.fun/admin` |
| **上游同步** | GitHub Actions 每 6 小时从 `cmliu/edgetunnel` 同步到本仓库 `main` |
| **CF 部署** | 手动执行，上游更新后自行重新部署 |

## 首次部署

### 1. 准备 Cloudflare API Token

在 [Cloudflare API 令牌](https://dash.cloudflare.com/profile/api-tokens) 创建令牌，建议权限：

- Account → Workers Scripts → Edit
- Account → Workers KV Storage → Edit
- Account → Workers Routes → Edit
- Zone → Zone → Read（绑定自定义域需要）

### 2. 配置管理密码

```bash
cp .dev.vars.example .dev.vars
# 编辑 .dev.vars，设置 ADMIN=你的强密码
```

### 3. 部署

```bash
export CLOUDFLARE_API_TOKEN="你的API令牌"
npm install
npm run deploy
```

部署脚本会自动：

1. 创建 KV 命名空间（`edgetunnel-cf-chihuo-kv`）并绑定为 `KV`
2. 部署 Worker 到 `cf.chihuo.fun`
3. 将 `ADMIN` 写入 Worker Secret

### 4. 验证

访问 `https://cf.chihuo.fun/admin`，使用 `ADMIN` 密码登录。

## 上游更新后重新部署

GitHub 仓库会自动同步上游代码，**Cloudflare 不会自动部署**。上游有更新时：

```bash
git pull origin main
export CLOUDFLARE_API_TOKEN="你的API令牌"
npm run deploy
```

## 上游自动同步

工作流文件：`.github/workflows/sync.yml`

- 定时：每 6 小时检查 `cmliu/edgetunnel` 的 `main` 分支
- 手动：GitHub → Actions → **Upstream Sync** → Run workflow

若因上游 workflow 变更导致同步失败，请在 GitHub 仓库页面点击 **Sync fork** 手动同步一次。
