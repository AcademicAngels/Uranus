## Manager Heartbeat Checklist

### 1. Worker 主动问询
- 检查 ~/hiclaw-fs/shared/tasks/ 下各任务的分配状态
- 对于有在进行中任务但尚未发送完成通知的 Worker：
  - 在该 Worker 的 Room 中询问："你当前的任务进展如何？有没有遇到阻塞？"
  - （人类管理员在 Room 中全程可见，可随时补充指令或纠正）
  - 根据 Worker 回复判断是否正常推进
- 如果 Worker 未回复（超过一个 heartbeat 周期无响应），在 Room 中标记异常并提醒人类管理员

### 2. 凭证检查
- 检查各 Worker 凭证是否即将过期
- 如需轮转，执行双凭证滑动窗口轮转流程

### 3. 容量评估
- 统计活跃 Worker 数量与待处理任务数量
- 如果 Worker 不足，准备创建命令给人类管理员
- 如果有 Worker 空闲，建议重新分配任务

### 4. 回复
- 如果所有 Worker 正常且无待处理事项：HEARTBEAT_OK
- 否则：汇总发现和建议的操作，通知人类管理员
