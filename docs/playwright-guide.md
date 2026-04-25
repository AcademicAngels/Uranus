# Playwright Web Browsing Guide for HiClaw Agents

## Overview

Playwright 让 HiClaw Agent 能够浏览网页——读取文档、测试 Web 应用、抓取数据。

支持两种模式：

- **CLI 模式（推荐）**：Agent 通过命令行调用 Playwright，输出保存到磁盘，按需读取。
- **MCP 模式（备选）**：Playwright 作为 MCP Server 运行，将浏览器状态实时推入 Agent 上下文。

---

## CLI 模式（推荐）

### 为什么推荐 CLI？

Microsoft 在 2026 年明确建议编码 Agent 优先使用 CLI 而非 MCP：

- **Token 消耗**：CLI 每次会话约 27,000 tokens；MCP 约 114,000 tokens（**节省 4 倍**）
- CLI 将快照和截图保存为 YAML 文件到磁盘，Agent 只读取需要的部分
- MCP 在每一步都将完整的 Accessibility Tree 推入上下文，成本显著更高

### 适用场景

- Hermes / CoPaw Agent（有文件系统访问权限）
- 批量抓取、研究型任务（低成本，可批量操作）

### 前置条件

Node.js 已预装在所有 HiClaw worker 容器中，无需额外安装。

### 使用方式

Agent 执行 `npx @playwright/mcp` 命令，读取输出文件：

```bash
# 查看可用命令
npx @playwright/mcp --help

# 导航到页面并保存快照
npx @playwright/mcp snapshot --url https://example.com --output /tmp/snapshot.yaml

# 截图
npx @playwright/mcp screenshot --url https://example.com --output /tmp/screenshot.png
```

Agent 随后读取 `/tmp/snapshot.yaml` 或 `/tmp/screenshot.png`，只获取所需内容。

---

## MCP 模式（备选）

### 工作方式

Playwright 作为 MCP Server 运行，在每一步将浏览器的完整 Accessibility Tree 推入 Agent 上下文，提供实时浏览器状态反馈。

### 适用场景

- OpenClaw Agent（文件系统访问受限）
- 需要实时浏览器交互的任务（即时状态反馈）

### 启动与注册

```bash
# 启动 Playwright MCP Server
npx @playwright/mcp --port 3000 &

# 从 Manager Agent 注册到 HiClaw
bash skills/mcp-server-management/scripts/setup-mcp-proxy.sh \
    playwright http://localhost:3000/mcp sse
```

注册后，所有 Worker 在下次同步周期自动获得访问权限。

---

## 选型参考

| 场景 | 推荐模式 | 原因 |
|---|---|---|
| Hermes / CoPaw Agent | CLI | 有文件系统，Token 减少 4 倍 |
| OpenClaw Agent | MCP | 文件系统访问受限 |
| 实时浏览器交互 | MCP | 即时状态反馈 |
| 抓取 / 研究任务 | CLI | 成本更低，支持批量操作 |

---

## 安全注意事项

- `--allowed-origins`：限制浏览器可访问的站点白名单
- `--blocked-origins`：屏蔽特定站点
- **Playwright MCP 本身不是安全边界**——恶意页面可通过 `browser_evaluate` 执行任意 JS
- 生产环境：在沙箱容器中运行 Playwright，参考 [沙箱能力分析](../manager/agent/skills/)

---

## 验证

```bash
# 测试 CLI 模式
npx @playwright/mcp --help

# 测试 MCP 模式（已注册后）
mcporter call playwright browser_navigate '{"url": "https://example.com"}'
```
