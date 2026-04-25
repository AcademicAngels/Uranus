# Skills System Lifecycle Enhancement Design

**Date:** 2026-04-25
**Status:** Draft
**Scope:** Skills versioning, security validation, dependency declaration, Tool Memory feedback, verification docs

## Problem Statement

HiClaw's Skills infrastructure is strong (SKILL.md format, Manager-controlled distribution, skills.sh marketplace), but lacks lifecycle management: no versioning, no security audit at install time, no dependency declarations, and no learning from skill execution experience.

## Constraints

- Target: individual developers / personal use (OPC)
- All new frontmatter fields are optional — existing skills work unchanged
- No DAG engine or complex dependency resolution — just install-time checks
- Security checks are warnings, not blockers
- Tool Memory feedback uses the existing ReMe + memory-aggregation pipeline (no new infrastructure)

## Design

### 1. SKILL.md Frontmatter Extension

Extend the frontmatter schema with optional fields:

```yaml
---
name: my-skill
description: Use when...
version: "1.0.0"                    # semver version number
requires:                            # prerequisite skills
  - file-sync
  - mcporter
mcpServers:                          # required MCP servers
  - github
source:                              # auto-populated at install time
  registry: "skills.sh"
  installed_at: "2026-04-25"
  checksum: "sha256:abc123..."
---
```

Field semantics:
- `version`: Semantic versioning (MAJOR.MINOR.PATCH). Compared during `skills check` to detect updates.
- `requires`: List of skill names that must be installed before this skill. Checked at install time; missing dependencies produce a warning and prompt, not a hard block.
- `mcpServers`: List of MCP server names (matching Higress route names) this skill expects. Checked at install time; missing servers produce a warning.
- `source`: Metadata block written by the install script. Not author-provided. Records where the skill came from, when it was installed, and a content hash for integrity verification.

All fields are optional. Skills without these fields are treated as version "0.0.0" with no dependencies and unknown source.

### 2. workers-registry.json Schema Upgrade

Current format:

```json
{
  "workers": {
    "alice": {
      "skills": ["file-sync", "mcporter"],
      "room_id": "!abc:hiclaw.io",
      "runtime": "copaw"
    }
  }
}
```

New format:

```json
{
  "workers": {
    "alice": {
      "skills": {
        "file-sync": {"version": "1.0.0", "source": "builtin"},
        "git-delegation": {"version": "1.2.0", "source": "skills.sh", "installed_at": "2026-04-25"}
      },
      "room_id": "!abc:hiclaw.io",
      "runtime": "copaw"
    }
  }
}
```

Backward compatibility: When reading, if `skills` is an array of strings (old format), convert to object format with `version: "unknown"` and `source: "legacy"`. Write always uses new format.

### 3. find-skills Install Flow Enhancement

The enhanced install flow adds three checks before installing a skill:

```
Search → Display results with security info → Pre-install checks → Install → Post-install metadata
```

#### Pre-install checks

1. **Source validation**: Display whether the source is skills.sh (Snyk-audited), Nacos (enterprise), or unknown. Unknown sources get a warning.
2. **Dependency check**: Parse `requires` from the skill's SKILL.md. For each required skill, check if it's installed on the target worker. Missing dependencies: warn and list what's needed.
3. **MCP server check**: Parse `mcpServers` from SKILL.md. For each required server, check if it's registered in Higress. Missing servers: warn and suggest registration command.
4. **Script static check**: Scan `scripts/` directory for suspicious patterns (`curl.*|.*sh`, `wget.*|.*sh`, `rm.*-rf.*/`, `eval`, `base64.*-d`). Display warnings if found. Never block installation.

#### Post-install metadata

After successful installation, write `source` block into the installed SKILL.md's frontmatter (or append if not present). Update workers-registry.json with version and source info.

### 4. Tool Memory Experience Feedback

Leverage the existing memory system pipeline (already implemented):

```
Worker executes skill script
    → ReMe Tool Memory records: skill name, version, result, duration
    → Written to agents/{worker}/memory/tool-guide/
    → sync.py push to MinIO (existing)
    → Hermes memory-aggregation skill aggregates (existing)
    → shared/vault/agent-shared/tool-guide.md updated
    → All agents pull on next sync cycle (existing)
```

Implementation: Add guidance to Worker AGENTS.md templates instructing the agent to write skill execution summaries to `memory/tool-guide/` after completing skill-driven tasks. No new code — the pipeline is already wired.

### 5. Verification Documentation Template

Add an optional `## Verification` section to the SKILL.md convention:

```markdown
## Verification

To verify this skill works correctly:

1. Run: `bash scripts/example.sh --help`
   Expected: Usage information displayed
2. Run: `bash scripts/example.sh test`
   Expected: "OK" output
```

Update the find-skills SKILL.md to document this as a recommended practice for skill authors.

## Files to Modify

| File | Change |
|------|--------|
| `manager/agent/skills/worker-management/scripts/push-worker-skills.sh` | Registry format upgrade + version tracking |
| `manager/agent/copaw-worker-agent/skills/find-skills/SKILL.md` | Document new frontmatter fields + install checks |
| `manager/agent/copaw-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh` | Add pre-install checks (deps, MCP, security) |
| `manager/agent/hermes-worker-agent/skills/find-skills/SKILL.md` | Same as copaw find-skills |
| `manager/agent/hermes-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh` | Same as copaw |
| `manager/agent/copaw-worker-agent/AGENTS.md` | Add Tool Memory write guidance |
| `manager/agent/hermes-worker-agent/AGENTS.md` | Add Tool Memory write guidance |
| `manager/agent/workers-registry.json` | Upgrade to new schema |

## What This Design Does NOT Include

- No DAG-based dependency resolution engine
- No automatic skill installation of dependencies (just warnings)
- No blocking on security warnings (just display)
- No skill sandboxing or containerization
- No skill marketplace hosting (uses existing skills.sh and Nacos)
- No CRD changes for per-worker skill config
