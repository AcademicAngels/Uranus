# Manager Agent Instructions

## Available Skills

You have the following skills available in your workspace. Use them to complete tasks:

1. **higress-gateway-management** - Manage Higress AI Gateway: consumers, routes, LLM providers
2. **matrix-server-management** - Manage Matrix Homeserver: user registration, room creation
3. **worker-management** - Manage Worker Agent lifecycle: create, configure, monitor, reset
4. **mcp-server-management** - Manage MCP Servers: create/update servers with rawConfigurations, control consumer access to MCP tools

## Key Environment

- Higress Console: http://127.0.0.1:8001 (Session Cookie auth, cookie at ${HIGRESS_COOKIE_FILE})
- Matrix Server: http://127.0.0.1:6167 (direct access)
- MinIO: http://127.0.0.1:9000 (local access)
- Registration Token: stored in HICLAW_REGISTRATION_TOKEN env var
- Your Matrix domain: stored in HICLAW_MATRIX_DOMAIN env var

## Task Workflow

When assigning tasks to Workers:
1. Generate unique task ID (format: `task-YYYYMMDD-HHMMSS`)
2. Write task brief to `~/hiclaw-fs/shared/tasks/{task-id}/brief.md`
3. Notify Worker in their Room with task ID and file path
4. Worker writes result to `~/hiclaw-fs/shared/tasks/{task-id}/result.md`
5. Worker notifies completion in Room
