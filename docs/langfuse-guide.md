# Langfuse 可观测性指南（OPC 开发者）

本指南面向 OPC（Operator / Platform / Consumer）开发者，说明如何在 HiClaw 环境中使用 Langfuse 对 Agent 进行追踪、调试和成本分析。

---

## 1. Langfuse 与 Hermes Web UI：如何选择

| 场景 | 推荐工具 | 原因 |
|---|---|---|
| 1–2 个 Agent，单独调试 | **Hermes Web UI**（内置，无需配置） | 开箱即用，按 Agent 查看 Token 用量和成本，零配置 |
| 3 个以上 Agent 协作 | **Langfuse** | 跨 Agent 追踪、全局成本归因、Manager→Worker 调用链可视化 |
| 同时运行两者 | 两者兼容，可并行使用 | 互不干扰，按需取用 |

**结论：** 小规模单 Agent 调试首选 Hermes Web UI；多 Agent 协作、生产环境成本审计或需要 P95/P99 延迟分析时，启用 Langfuse。

---

## 2. Langfuse 在 HiClaw 中能看到什么

| 可见性 | 具体内容 | OPC 价值 |
|---|---|---|
| **LLM 调用详情** | 输入/输出内容、模型名称、Token 数量、延迟 | 识别哪个 Agent 消耗 Token 最多，定位高成本调用 |
| **工具调用链** | MCP 工具调用（GitHub、mcpvault 等）的参数和返回结果 | 调试工具选择错误，查看工具实际入参和出参 |
| **Agent 会话追踪** | Manager→Worker 任务分配以 Trace Span 树展示 | 定位多 Agent 协作中的性能瓶颈 |
| **错误追踪** | 失败的 LLM 调用、超时、工具异常 | 快速定位"Agent 卡住"的根因 |
| **成本归因** | 按 Agent / Session / 模型统计 Token 成本 | 决策哪些任务使用昂贵模型、哪些用廉价模型 |
| **延迟分布** | P50 / P95 / P99 响应时间 | 发现慢查询，优化高延迟 Agent |

### Langfuse 无法看到的内容

- Agent 内部思考过程（CoT 推理链，未通过 OTEL 暴露）
- Matrix 聊天消息内容（Matrix 协议不经过 OTEL）
- MinIO 文件操作（对象存储操作不产生 OTEL Span）

---

## 3. 安装 Langfuse（自托管）

### 前置条件

- Docker
- Docker Compose

### 启动步骤

```bash
# 克隆 Langfuse 仓库
git clone https://github.com/langfuse/langfuse.git
cd langfuse

# 启动（PostgreSQL + ClickHouse + Langfuse Server）
docker compose up -d
```

启动完成后，打开浏览器访问 [http://localhost:3000](http://localhost:3000)，首次访问时创建账号即可。

### 资源需求

Langfuse v3 额外占用约 **500MB–1GB 内存**（PostgreSQL + ClickHouse + Langfuse Server 合计）。ClickHouse 是主要内存消耗方，可在 Langfuse 设置中调整数据保留策略来降低占用。

---

## 4. 配置 HiClaw 将追踪数据发送到 Langfuse

HiClaw 已原生支持标准 OTEL 环境变量。hermes 和 copaw 的 entrypoint 脚本会自动将 `HICLAW_CMS_ENDPOINT` 映射为 `OTEL_EXPORTER_OTLP_ENDPOINT`，**无需修改任何 HiClaw 代码**。

### Docker 部署

在运行 HiClaw 安装器之前设置以下环境变量，或将其添加到 `hiclaw-manager.env`：

```bash
# 启用 CMS 追踪
export HICLAW_CMS_TRACES_ENABLED=true

# Langfuse OTEL 接收端点
export HICLAW_CMS_ENDPOINT=http://host.docker.internal:3000/api/public/otel

# Langfuse 公钥（从 Langfuse Settings > API Keys 获取）
export HICLAW_CMS_LICENSE_KEY=pk-lf-...

# 以下两项留空（Langfuse 不需要）
export HICLAW_CMS_PROJECT=
export HICLAW_CMS_WORKSPACE=
```

> **说明：** `host.docker.internal` 在 Docker 容器内部解析为宿主机地址。如果 Langfuse 部署在其他主机上，将其替换为对应主机的 IP 地址。

### K8s / Helm 部署

在 `values.yaml` 中添加以下配置：

```yaml
controller:
  env:
    HICLAW_CMS_TRACES_ENABLED: "true"
    HICLAW_CMS_ENDPOINT: "http://langfuse-server:3000/api/public/otel"
    HICLAW_CMS_LICENSE_KEY: "pk-lf-..."
```

其中 `langfuse-server` 为 Langfuse 服务在 K8s 集群内的 Service 名称，根据实际部署调整。

---

## 5. 验证配置是否生效

1. 打开 Langfuse 控制台：[http://localhost:3000](http://localhost:3000)
2. 向任意 Agent 发送一个任务
3. 追踪数据应在数秒内出现在控制台的 **Traces** 页面
4. 在 Traces 列表中查找服务名称：
   - Worker Agent：`hiclaw-worker-{name}`
   - Manager Agent：`hiclaw-manager`

如果追踪正常出现，说明配置已生效。

---

## 6. 常见问题排查

### 没有追踪数据出现

- 确认 `HICLAW_CMS_TRACES_ENABLED=true` 已正确设置
- 从容器内部验证端点可达性：
  ```bash
  docker exec -it <hiclaw-container> curl -v http://host.docker.internal:3000/api/public/otel
  ```
- 检查 Langfuse API Key 是否正确（必须为公钥，以 `pk-lf-` 开头）

### 服务名称不正确

如果需要自定义服务名称标识，设置：

```bash
export HICLAW_CMS_SERVICE_NAME=my-hiclaw-instance
```

### 内存占用过高

ClickHouse 是 Langfuse v3 的主要内存消耗方。进入 Langfuse 控制台 **Settings > Data Retention**，缩短数据保留天数（如从 90 天改为 30 天）可显著降低内存和磁盘占用。
