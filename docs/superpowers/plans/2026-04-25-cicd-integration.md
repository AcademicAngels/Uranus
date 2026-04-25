# CI/CD Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add GitHub Actions workflow and check-run tools to the MCP template and skill docs so agents can trigger CI, check status, and read failure logs.

**Architecture:** Two-file modification. Append 5 new tool definitions to the existing GitHub MCP YAML template. Append a CI/CD section to the existing github-operations SKILL.md. Both follow existing patterns in each file.

**Tech Stack:** YAML (MCP template), Markdown (skill docs)

**Spec:** `docs/superpowers/specs/2026-04-25-cicd-integration-design.md`

---

## File Structure

### Modified Files
| File | Change |
|---|---|
| `manager/agent/skills/mcp-server-management/references/mcp-github.yaml` | Append 5 workflow/check-run tool definitions |
| `manager/agent/worker-skills/github-operations/SKILL.md` | Append CI/CD operations section |

---

### Task 1: Add GitHub Actions Tools to MCP Template

**Files:**
- Modify: `manager/agent/skills/mcp-server-management/references/mcp-github.yaml` (append after line 1680)

- [ ] **Step 1: Append 5 workflow/check-run tool definitions**

Append the following YAML to the end of `manager/agent/skills/mcp-server-management/references/mcp-github.yaml`. These follow the exact same pattern as the existing tools in the file (requestTemplate with GitHub API URL, Bearer auth, headers):

```yaml

# ── GitHub Actions / CI/CD tools ─────────────────────────────────────────

- name: list_workflow_runs
  description: "List recent workflow runs for a repository. Use to check CI/CD status after pushing code."
  args:
  - name: owner
    type: string
    required: true
    description: "Repository owner"
  - name: repo
    type: string
    required: true
    description: "Repository name"
  - name: branch
    type: string
    required: false
    description: "Filter by branch name"
  - name: status
    type: string
    required: false
    description: "Filter by status (completed, in_progress, queued)"
  - name: per_page
    type: number
    required: false
    description: "Results per page (default 10, max 100)"
  requestTemplate:
    url: "https://api.github.com/repos/{{.args.owner}}/{{.args.repo}}/actions/runs?per_page={{.args.per_page | default 10}}{{if .args.branch}}&branch={{.args.branch}}{{end}}{{if .args.status}}&status={{.args.status}}{{end}}"
    method: GET
    headers:
    - key: Authorization
      value: "Bearer {{.config.accessToken}}"
    - key: Accept
      value: "application/vnd.github+json"
    - key: X-GitHub-Api-Version
      value: "2022-11-28"
    - key: User-Agent
      value: "higress-mcp"

- name: get_workflow_run
  description: "Get details of a specific workflow run including status, conclusion, and logs URL."
  args:
  - name: owner
    type: string
    required: true
    description: "Repository owner"
  - name: repo
    type: string
    required: true
    description: "Repository name"
  - name: run_id
    type: number
    required: true
    description: "Workflow run ID"
  requestTemplate:
    url: "https://api.github.com/repos/{{.args.owner}}/{{.args.repo}}/actions/runs/{{.args.run_id}}"
    method: GET
    headers:
    - key: Authorization
      value: "Bearer {{.config.accessToken}}"
    - key: Accept
      value: "application/vnd.github+json"
    - key: X-GitHub-Api-Version
      value: "2022-11-28"
    - key: User-Agent
      value: "higress-mcp"

- name: trigger_workflow_dispatch
  description: "Trigger a workflow_dispatch event to start a GitHub Actions workflow manually."
  args:
  - name: owner
    type: string
    required: true
    description: "Repository owner"
  - name: repo
    type: string
    required: true
    description: "Repository name"
  - name: workflow_id
    type: string
    required: true
    description: "Workflow file name (e.g., build.yml) or workflow ID"
  - name: ref
    type: string
    required: true
    description: "Branch or tag to run the workflow on"
  requestTemplate:
    url: "https://api.github.com/repos/{{.args.owner}}/{{.args.repo}}/actions/workflows/{{.args.workflow_id}}/dispatches"
    method: POST
    body: |
      {
        "ref": "{{.args.ref}}"
      }
    headers:
    - key: Authorization
      value: "Bearer {{.config.accessToken}}"
    - key: Accept
      value: "application/vnd.github+json"
    - key: X-GitHub-Api-Version
      value: "2022-11-28"
    - key: User-Agent
      value: "higress-mcp"

- name: list_check_runs
  description: "List check runs (CI checks) for a specific commit SHA or branch ref."
  args:
  - name: owner
    type: string
    required: true
    description: "Repository owner"
  - name: repo
    type: string
    required: true
    description: "Repository name"
  - name: ref
    type: string
    required: true
    description: "Commit SHA or branch name"
  requestTemplate:
    url: "https://api.github.com/repos/{{.args.owner}}/{{.args.repo}}/commits/{{.args.ref}}/check-runs"
    method: GET
    headers:
    - key: Authorization
      value: "Bearer {{.config.accessToken}}"
    - key: Accept
      value: "application/vnd.github+json"
    - key: X-GitHub-Api-Version
      value: "2022-11-28"
    - key: User-Agent
      value: "higress-mcp"

- name: get_check_run
  description: "Get details of a specific check run including status, conclusion, and output summary."
  args:
  - name: owner
    type: string
    required: true
    description: "Repository owner"
  - name: repo
    type: string
    required: true
    description: "Repository name"
  - name: check_run_id
    type: number
    required: true
    description: "Check run ID"
  requestTemplate:
    url: "https://api.github.com/repos/{{.args.owner}}/{{.args.repo}}/check-runs/{{.args.check_run_id}}"
    method: GET
    headers:
    - key: Authorization
      value: "Bearer {{.config.accessToken}}"
    - key: Accept
      value: "application/vnd.github+json"
    - key: X-GitHub-Api-Version
      value: "2022-11-28"
    - key: User-Agent
      value: "higress-mcp"
```

- [ ] **Step 2: Commit**

```bash
git add manager/agent/skills/mcp-server-management/references/mcp-github.yaml
git commit --author="吉尔伽美什 <>" -m "feat(mcp): add GitHub Actions workflow and check-run tools to MCP template"
```

---

### Task 2: Add CI/CD Section to github-operations Skill

**Files:**
- Modify: `manager/agent/worker-skills/github-operations/SKILL.md` (append before the final "Typical Workflow" section)

- [ ] **Step 1: Add CI/CD operations section**

In `manager/agent/worker-skills/github-operations/SKILL.md`, find the `## Typical Workflow` section (near line 397). Insert the following section **before** it:

```markdown

## CI/CD Operations

Check CI status and manage GitHub Actions workflows via MCP tools.

### Check CI Status After Pushing Code

```
mcporter call mcp-github list_check_runs owner=MyOrg repo=my-project ref=feature/my-branch
```

### View Recent Workflow Runs

```
mcporter call mcp-github list_workflow_runs owner=MyOrg repo=my-project branch=main status=completed per_page=5
```

### Get Details of a Failed Run

```
mcporter call mcp-github get_workflow_run owner=MyOrg repo=my-project run_id=12345678
```

### Trigger a Workflow Manually

```
mcporter call mcp-github trigger_workflow_dispatch owner=MyOrg repo=my-project workflow_id=build.yml ref=main
```

### Typical CI/CD Agent Workflow

1. **Push code** → Use `git-delegation` skill
2. **Check CI status** → `list_check_runs` for the commit SHA
3. **CI failed?** → `get_workflow_run` to read failure details
4. **Fix the issue** → Edit code, commit, push again
5. **CI passed?** → Proceed to create/merge PR

```

- [ ] **Step 2: Update the Typical Workflow section**

Also update the existing `## Typical Workflow` section at the end of the file to include the CI/CD step. Find:

```markdown
## Typical Workflow

1. **Clone & modify** → Use `git-delegation` skill
2. **Push changes** → Use `git-delegation` skill
3. **Create PR** → Use `create_pull_request` (this skill)
4. **Review PR** → Use `add_issue_comment`, `create_pull_request_review_comment` (this skill)
5. **Merge PR** → Use `merge_pull_request` (this skill)
```

Replace with:

```markdown
## Typical Workflow

1. **Clone & modify** → Use `git-delegation` skill
2. **Push changes** → Use `git-delegation` skill
3. **Check CI** → Use `list_check_runs` to verify CI passes (this skill)
4. **Create PR** → Use `create_pull_request` (this skill)
5. **Review PR** → Use `add_issue_comment`, `create_pull_request_review_comment` (this skill)
6. **Merge PR** → Use `merge_pull_request` (this skill)
```

- [ ] **Step 3: Commit**

```bash
git add manager/agent/worker-skills/github-operations/SKILL.md
git commit --author="吉尔伽美什 <>" -m "docs(skills): add CI/CD operations to github-operations skill"
```

---

## Summary

| Task | File | Description |
|---|---|---|
| 1 | mcp-github.yaml | Add 5 GitHub Actions tools (workflow runs, check runs, dispatch) |
| 2 | github-operations/SKILL.md | Add CI/CD section + update typical workflow |
