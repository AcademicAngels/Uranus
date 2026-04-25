# CI/CD Integration Design

**Date:** 2026-04-25
**Status:** Draft
**Scope:** Add GitHub Actions workflow tools to MCP template and update github-operations skill

## Problem Statement

HiClaw agents can manage PRs and Issues via the GitHub MCP Server, but cannot interact with CI/CD pipelines. OPC developers need agents that can trigger workflows, check CI status, read failure logs, and automatically fix and re-push code.

## Constraints

- Zero code changes — only YAML template and Markdown skill documentation
- Zero fork risk — modifying files in manager/agent/ (not upstream controller/bridge)
- Must work with existing MCP registration flow (setup-mcp-server.sh)

## Design

### 1. Extend GitHub MCP Template

**File:** `manager/agent/skills/mcp-server-management/references/mcp-github.yaml`

Add these tools after the existing PR/Issue tools:

| Tool | GitHub API | Purpose |
|---|---|---|
| `list_workflow_runs` | `GET /repos/{owner}/{repo}/actions/runs` | List recent CI runs |
| `get_workflow_run` | `GET /repos/{owner}/{repo}/actions/runs/{run_id}` | Get run details (status, conclusion, logs URL) |
| `trigger_workflow_dispatch` | `POST /repos/{owner}/{repo}/actions/workflows/{workflow_id}/dispatches` | Trigger a workflow |
| `list_check_runs` | `GET /repos/{owner}/{repo}/commits/{ref}/check-runs` | List checks for a commit |
| `get_check_run` | `GET /repos/{owner}/{repo}/check-runs/{check_run_id}` | Get check details and output |

### 2. Update github-operations Skill

**File:** `manager/agent/worker-skills/github-operations/SKILL.md`

Add a CI/CD section documenting:
- How to check CI status after pushing code
- How to read failure logs
- How to trigger a workflow dispatch
- The typical Agent workflow: push → check CI → read failure → fix → re-push

## Files to Modify

| File | Change |
|---|---|
| `manager/agent/skills/mcp-server-management/references/mcp-github.yaml` | Add 5 workflow/check-run tool definitions |
| `manager/agent/worker-skills/github-operations/SKILL.md` | Add CI/CD operations section |

## What This Design Does NOT Include

- No new MCP server (uses existing GitHub MCP)
- No code changes
- No GitLab CI support (GitHub only for now)
- No automatic CI trigger on push (agent decides when to check)
