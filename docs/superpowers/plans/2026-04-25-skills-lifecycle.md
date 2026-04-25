# Skills Lifecycle Enhancement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add versioning, security checks, dependency declarations, and experience feedback to HiClaw's skills system so OPC users get safer installs and smarter tool usage over time.

**Architecture:** Five incremental changes to Manager-side scripts and agent config files. No controller/bridge/sync code changes. The registry schema upgrade preserves backward compatibility. The find-skills install flow gains pre-install checks (security, deps, MCP). Tool Memory feedback leverages the existing ReMe pipeline by adding AGENTS.md guidance.

**Tech Stack:** Bash (scripts), Markdown (SKILL.md, AGENTS.md), JSON (workers-registry.json)

**Spec:** `docs/superpowers/specs/2026-04-25-skills-lifecycle-design.md`

---

## File Structure

### Modified Files
| File | Change |
|---|---|
| `manager/agent/skills/worker-management/scripts/push-worker-skills.sh` | Registry read/write upgrade (array→object), version tracking |
| `manager/agent/copaw-worker-agent/skills/find-skills/SKILL.md` | Document new frontmatter fields, install checks, verification template |
| `manager/agent/copaw-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh` | Add pre-install checks + post-install metadata |
| `manager/agent/hermes-worker-agent/skills/find-skills/SKILL.md` | Mirror copaw find-skills SKILL.md changes |
| `manager/agent/hermes-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh` | Mirror copaw find-skills script changes |
| `manager/agent/copaw-worker-agent/AGENTS.md` | Add Tool Memory write guidance |
| `manager/agent/hermes-worker-agent/AGENTS.md` | Add Tool Memory write guidance |
| `manager/agent/workers-registry.json` | Upgrade schema to version 2 |

---

### Task 1: Upgrade workers-registry.json Schema

**Files:**
- Modify: `manager/agent/workers-registry.json`
- Modify: `manager/agent/skills/worker-management/scripts/push-worker-skills.sh`

- [ ] **Step 1: Upgrade the empty registry template to version 2**

In `manager/agent/workers-registry.json`, replace the entire content:

```json
{
  "version": 2,
  "updated_at": "",
  "workers": {}
}
```

- [ ] **Step 2: Add backward-compatible registry reader to push-worker-skills.sh**

In `manager/agent/skills/worker-management/scripts/push-worker-skills.sh`, find the `_get_worker_skills()` function (around line 75). It currently reads skills as a simple list. Replace it with a version that handles both old (array) and new (object) formats.

Find:
```bash
_get_worker_skills() {
    local worker="$1"
    jq -r ".workers[\"${worker}\"].skills // [] | .[]" "$REGISTRY"
}
```

Replace with:
```bash
_get_worker_skills() {
    local worker="$1"
    local skills_val
    skills_val=$(jq -r ".workers[\"${worker}\"].skills // empty" "$REGISTRY")
    if [ -z "$skills_val" ]; then
        return 0
    fi
    # Handle both old format (array of strings) and new format (object with version info)
    jq -r '
        .workers["'"${worker}"'"].skills |
        if type == "array" then .[]
        elif type == "object" then keys[]
        else empty end
    ' "$REGISTRY"
}
```

- [ ] **Step 3: Update the skill-add logic to write version info**

Find the section where a skill is added to the registry (around line 194-217, inside the `--add-skill` handler). After the skill is pushed to MinIO, the registry is updated. Change the registry update to write the new object format.

Find the `jq` command that adds a skill to the registry (it adds a string to the skills array). Replace it so it writes an object entry instead.

Find:
```bash
jq --arg w "$WORKER" --arg s "$SKILL" \
    '.workers[$w].skills = ((.workers[$w].skills // []) + [$s] | unique)' \
    "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
```

Replace with:
```bash
# Extract version from SKILL.md frontmatter if available
local skill_version="unknown"
local skill_md="${WORKER_SKILLS_DIR}/${SKILL}/SKILL.md"
if [ -f "$skill_md" ]; then
    skill_version=$(grep -m1 '^version:' "$skill_md" | sed 's/^version:[[:space:]]*//' | tr -d '"'"'" || echo "unknown")
    [ -z "$skill_version" ] && skill_version="unknown"
fi
local install_date
install_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)

jq --arg w "$WORKER" --arg s "$SKILL" --arg v "$skill_version" --arg d "$install_date" \
    '.workers[$w].skills[$s] = {"version": $v, "source": "manual", "installed_at": $d}' \
    "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
```

- [ ] **Step 4: Update the skill-remove logic for new format**

Find the `jq` command that removes a skill from the registry. Change it to delete a key from the object instead of filtering an array.

Find:
```bash
jq --arg w "$WORKER" --arg s "$SKILL" \
    '.workers[$w].skills = [.workers[$w].skills[] | select(. != $s)]' \
    "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
```

Replace with:
```bash
jq --arg w "$WORKER" --arg s "$SKILL" \
    'del(.workers[$w].skills[$s])' \
    "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
```

- [ ] **Step 5: Update builtin skill initialization to use new format**

Find where builtin skills are initialized for a new worker (around line 252-270). Update to write object format with `"source": "builtin"`.

Find the section that initializes default skills for a worker (it creates the skills array). Replace the initialization to write objects:

```bash
# Initialize builtin skills for new worker
for skill in "${BUILTIN_SKILLS[@]}"; do
    jq --arg w "$WORKER" --arg s "$skill" \
        '.workers[$w].skills[$s] = {"version": "1.0.0", "source": "builtin"}' \
        "$REGISTRY" > "$REGISTRY.tmp" && mv "$REGISTRY.tmp" "$REGISTRY"
done
```

- [ ] **Step 6: Verify push-worker-skills.sh syntax**

Run: `bash -n manager/agent/skills/worker-management/scripts/push-worker-skills.sh && echo "Syntax OK"`

Expected: `Syntax OK`

- [ ] **Step 7: Commit**

```bash
git add manager/agent/workers-registry.json \
       manager/agent/skills/worker-management/scripts/push-worker-skills.sh
git commit -m "feat(skills): upgrade workers-registry to v2 schema with version tracking"
```

---

### Task 2: Add Pre-Install Checks to find-skills Script

**Files:**
- Modify: `manager/agent/copaw-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh`
- Modify: `manager/agent/hermes-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh`

- [ ] **Step 1: Add pre-install check functions to copaw hiclaw-find-skill.sh**

In `manager/agent/copaw-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh`, add these functions before the command dispatch section (before line 451, the `case "$CMD"` block):

```bash
# ── Pre-install checks ──────────────────────────────────────────────────────

_parse_frontmatter_field() {
    # Extract a YAML frontmatter field value from a SKILL.md file
    # Usage: _parse_frontmatter_field <file> <field>
    local file="$1" field="$2"
    sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | grep -m1 "^${field}:" | sed "s/^${field}:[[:space:]]*//" | tr -d '"'"'"
}

_parse_frontmatter_list() {
    # Extract a YAML frontmatter list field from a SKILL.md file
    # Usage: _parse_frontmatter_list <file> <field>
    local file="$1" field="$2"
    sed -n '/^---$/,/^---$/p' "$file" 2>/dev/null | \
        sed -n "/^${field}:/,/^[^[:space:]-]/p" | \
        grep '^  *- ' | sed 's/^  *- //' | tr -d '"'"'"
}

_check_source_safety() {
    # Display source safety info
    local source="$1"
    if echo "$source" | grep -qi 'skills\.sh'; then
        echo -e "${GREEN}✓ Source: skills.sh (Snyk security audit)${RESET}"
    elif echo "$source" | grep -qi 'nacos'; then
        echo -e "${YELLOW}● Source: Nacos enterprise registry${RESET}"
    else
        echo -e "${RED}⚠ Source: unknown — review scripts before use${RESET}"
    fi
}

_check_dependencies() {
    # Check if required skills are installed
    local skill_md="$1" worker_skills_dir="$2"
    local deps
    deps=$(_parse_frontmatter_list "$skill_md" "requires")
    [ -z "$deps" ] && return 0

    local missing=0
    echo "Dependency check:"
    while IFS= read -r dep; do
        if [ -d "${worker_skills_dir}/${dep}" ]; then
            echo -e "  ${GREEN}✓ ${dep} — installed${RESET}"
        else
            echo -e "  ${RED}✗ ${dep} — NOT installed${RESET}"
            missing=1
        fi
    done <<< "$deps"
    return $missing
}

_check_mcp_servers() {
    # Check if required MCP servers are available
    local skill_md="$1"
    local servers
    servers=$(_parse_frontmatter_list "$skill_md" "mcpServers")
    [ -z "$servers" ] && return 0

    local mcporter_config="${HOME}/config/mcporter.json"
    [ ! -f "$mcporter_config" ] && mcporter_config="${HOME}/mcporter-servers.json"

    echo "MCP server check:"
    while IFS= read -r server; do
        if [ -f "$mcporter_config" ] && jq -e ".mcpServers[\"${server}\"]" "$mcporter_config" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓ ${server} — registered${RESET}"
        else
            echo -e "  ${YELLOW}⚠ ${server} — not registered. Register with: setup-mcp-server.sh${RESET}"
        fi
    done <<< "$servers"
}

_check_script_safety() {
    # Basic static check for suspicious patterns in scripts
    local scripts_dir="$1"
    [ ! -d "$scripts_dir" ] && return 0

    local suspicious_patterns='curl.*|.*sh\|wget.*|.*sh\|rm[[:space:]].*-rf[[:space:]]*/\|eval[[:space:]]\|base64.*-d'
    local findings
    findings=$(grep -rn "$suspicious_patterns" "$scripts_dir" 2>/dev/null || true)
    if [ -n "$findings" ]; then
        echo -e "${YELLOW}⚠ Suspicious patterns found in scripts:${RESET}"
        echo "$findings" | head -5
        [ "$(echo "$findings" | wc -l)" -gt 5 ] && echo "  ... and more"
    fi
}

_write_source_metadata() {
    # Write source block into installed SKILL.md frontmatter
    local skill_md="$1" registry="$2" checksum="$3"
    local install_date
    install_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Only write if file exists and has frontmatter
    [ ! -f "$skill_md" ] && return 0
    if ! head -1 "$skill_md" | grep -q '^---$'; then
        return 0
    fi

    # Append source block before closing ---
    local tmpfile="${skill_md}.tmp"
    awk -v reg="$registry" -v date="$install_date" -v sum="$checksum" '
    BEGIN { in_fm=0; count=0 }
    /^---$/ { count++; if (count==2) {
        print "source:"
        print "  registry: \"" reg "\""
        print "  installed_at: \"" date "\""
        print "  checksum: \"" sum "\""
    }}
    { print }
    ' "$skill_md" > "$tmpfile" && mv "$tmpfile" "$skill_md"
}

_run_preinstall_checks() {
    # Run all pre-install checks for a skill
    local skill_dir="$1" source_registry="$2"
    local skill_md="${skill_dir}/SKILL.md"

    [ ! -f "$skill_md" ] && return 0

    echo ""
    echo "── Pre-install checks ──"

    # Source safety
    _check_source_safety "$source_registry"

    # Version info
    local version
    version=$(_parse_frontmatter_field "$skill_md" "version")
    [ -n "$version" ] && echo "Version: ${version}" || echo "Version: not specified"

    # Dependencies
    _check_dependencies "$skill_md" "$(dirname "$(dirname "$skill_dir")")" || \
        echo -e "${YELLOW}⚠ Missing dependencies — install them first for full functionality${RESET}"

    # MCP servers
    _check_mcp_servers "$skill_md"

    # Script safety
    _check_script_safety "${skill_dir}/scripts"

    echo "────────────────────────"
    echo ""
}
```

- [ ] **Step 2: Wire pre-install checks into the install command**

In the same file, find the `install)` case in the command dispatch (around line 470-477). Modify it to call the pre-install checks before running the actual install.

Find:
```bash
    install)
        shift
        run_skills_install "$@"
        ;;
```

Replace with:
```bash
    install)
        shift
        # Download to temp dir first for pre-install checks
        local skill_name="${1:-}"
        if [ -n "$skill_name" ]; then
            local tmp_check_dir
            tmp_check_dir=$(mktemp -d)
            trap 'rm -rf "$tmp_check_dir"' EXIT

            # Detect source registry
            local source_registry
            source_registry=$(detect_backend)

            # Try to fetch SKILL.md for pre-install checks
            if command -v skills >/dev/null 2>&1; then
                skills info "$skill_name" --output-dir "$tmp_check_dir" 2>/dev/null || true
            fi

            if [ -f "${tmp_check_dir}/SKILL.md" ]; then
                _run_preinstall_checks "$tmp_check_dir" "$source_registry"
            fi

            rm -rf "$tmp_check_dir"
            trap - EXIT
        fi

        # Proceed with actual install
        run_skills_install "$@"

        # Post-install: write source metadata
        if [ -n "$skill_name" ]; then
            local installed_skill_md
            local script_dir
            script_dir=$(get_script_path)
            installed_skill_md="$(dirname "$(dirname "$script_dir")")/../${skill_name}/SKILL.md"
            if [ -f "$installed_skill_md" ]; then
                local checksum
                checksum=$(sha256sum "$installed_skill_md" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
                _write_source_metadata "$installed_skill_md" "$(detect_backend)" "sha256:${checksum}"
            fi
        fi
        ;;
```

- [ ] **Step 3: Verify copaw script syntax**

Run: `bash -n manager/agent/copaw-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh && echo "Syntax OK"`

Expected: `Syntax OK`

- [ ] **Step 4: Copy changes to hermes find-skills script**

The hermes version is identical. Copy the copaw version over:

```bash
cp manager/agent/copaw-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh \
   manager/agent/hermes-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh
```

- [ ] **Step 5: Verify hermes script syntax**

Run: `bash -n manager/agent/hermes-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh && echo "Syntax OK"`

Expected: `Syntax OK`

- [ ] **Step 6: Commit**

```bash
git add manager/agent/copaw-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh \
       manager/agent/hermes-worker-agent/skills/find-skills/scripts/hiclaw-find-skill.sh
git commit -m "feat(skills): add pre-install safety, dependency, and MCP checks to find-skills"
```

---

### Task 3: Update find-skills SKILL.md Documentation

**Files:**
- Modify: `manager/agent/copaw-worker-agent/skills/find-skills/SKILL.md`
- Modify: `manager/agent/hermes-worker-agent/skills/find-skills/SKILL.md`

- [ ] **Step 1: Add frontmatter fields documentation to copaw find-skills SKILL.md**

In `manager/agent/copaw-worker-agent/skills/find-skills/SKILL.md`, find the "Skill resources" section at the end of the file (around line 172). Before it, add:

```markdown

## SKILL.md Frontmatter Reference

Skills can declare optional metadata in their YAML frontmatter:

```yaml
---
name: my-skill
description: Use when the user needs...
version: "1.0.0"          # Semantic version (checked for updates)
requires:                   # Skills that must be installed first
  - file-sync
  - mcporter
mcpServers:                 # MCP servers this skill needs
  - github
---
```

All fields except `name` and `description` are optional. The `source` block is written automatically at install time — do not add it manually.

## Verification (Recommended)

Skill authors should include a verification section:

```markdown
## Verification

1. Run: `bash scripts/my-script.sh --help`
   Expected: Usage information displayed
```
```

- [ ] **Step 2: Apply same changes to hermes find-skills SKILL.md**

In `manager/agent/hermes-worker-agent/skills/find-skills/SKILL.md`, add the same documentation block before the "Skill resources" section (around line 172). The content is identical.

- [ ] **Step 3: Commit**

```bash
git add manager/agent/copaw-worker-agent/skills/find-skills/SKILL.md \
       manager/agent/hermes-worker-agent/skills/find-skills/SKILL.md
git commit -m "docs(skills): document frontmatter extension and verification template"
```

---

### Task 4: Add Tool Memory Guidance to Worker AGENTS.md

**Files:**
- Modify: `manager/agent/copaw-worker-agent/AGENTS.md`
- Modify: `manager/agent/hermes-worker-agent/AGENTS.md`

- [ ] **Step 1: Add Tool Memory guidance to copaw AGENTS.md**

In `manager/agent/copaw-worker-agent/AGENTS.md`, find the Memory section (around line 47-69). After the existing memory content, add:

```markdown

### Tool & Skill Experience

After completing a task that involved running skill scripts or using MCP tools, write a brief experience note to `memory/tool-guide/`:

- **File name**: `<skill-name>.md` (e.g., `memory/tool-guide/git-delegation.md`)
- **Content**: What worked, what failed, parameter tips, time taken
- **Format**: Append new entries — do not overwrite previous notes

These notes are aggregated by the Manager into `shared/vault/agent-shared/tool-guide.md` and shared with all agents, so future tasks benefit from past experience.
```

- [ ] **Step 2: Add the same guidance to hermes AGENTS.md**

In `manager/agent/hermes-worker-agent/AGENTS.md`, find the Memory section (around line 59-80). After the existing memory content, add the same block:

```markdown

### Tool & Skill Experience

After completing a task that involved running skill scripts or using MCP tools, write a brief experience note to `memory/tool-guide/`:

- **File name**: `<skill-name>.md` (e.g., `memory/tool-guide/git-delegation.md`)
- **Content**: What worked, what failed, parameter tips, time taken
- **Format**: Append new entries — do not overwrite previous notes

These notes are aggregated by the Manager into `shared/vault/agent-shared/tool-guide.md` and shared with all agents, so future tasks benefit from past experience.
```

- [ ] **Step 3: Commit**

```bash
git add manager/agent/copaw-worker-agent/AGENTS.md \
       manager/agent/hermes-worker-agent/AGENTS.md
git commit -m "feat(skills): add Tool Memory experience feedback guidance to worker agents"
```

---

### Task 5: Add Version Field to Existing Built-in Skills

**Files:**
- Modify: All existing SKILL.md files under `manager/agent/copaw-worker-agent/skills/`
- Modify: All existing SKILL.md files under `manager/agent/hermes-worker-agent/skills/`

- [ ] **Step 1: Add version to copaw built-in skill frontmatters**

For each SKILL.md under `manager/agent/copaw-worker-agent/skills/`, add `version: "1.0.0"` to the YAML frontmatter. The skills are: file-sync, task-progress, project-participation, mcporter, find-skills.

For each file, find:
```yaml
---
name: <skill-name>
description: <...>
```

Replace with:
```yaml
---
name: <skill-name>
version: "1.0.0"
description: <...>
```

Apply to all 5 skill SKILL.md files:
```bash
for skill_md in manager/agent/copaw-worker-agent/skills/*/SKILL.md; do
    if ! grep -q '^version:' "$skill_md"; then
        sed -i '/^name:/a version: "1.0.0"' "$skill_md"
    fi
done
```

- [ ] **Step 2: Add version to hermes built-in skill frontmatters**

```bash
for skill_md in manager/agent/hermes-worker-agent/skills/*/SKILL.md; do
    if ! grep -q '^version:' "$skill_md"; then
        sed -i '/^name:/a version: "1.0.0"' "$skill_md"
    fi
done
```

- [ ] **Step 3: Verify frontmatter is valid**

```bash
for f in manager/agent/copaw-worker-agent/skills/*/SKILL.md manager/agent/hermes-worker-agent/skills/*/SKILL.md; do
    echo "=== $f ===" && head -5 "$f"
done
```

Expected: Each file shows `---`, `name:`, `version: "1.0.0"`, `description:`, `---`

- [ ] **Step 4: Commit**

```bash
git add manager/agent/copaw-worker-agent/skills/*/SKILL.md \
       manager/agent/hermes-worker-agent/skills/*/SKILL.md
git commit -m "feat(skills): add version 1.0.0 to all built-in skill frontmatters"
```

---

## Summary

| Task | Description | Files Changed |
|---|---|---|
| 1 | Registry schema upgrade (array→object, version tracking) | workers-registry.json, push-worker-skills.sh |
| 2 | Pre-install checks (security, deps, MCP, static analysis) | hiclaw-find-skill.sh (copaw + hermes) |
| 3 | Frontmatter docs + verification template | find-skills SKILL.md (copaw + hermes) |
| 4 | Tool Memory feedback guidance in AGENTS.md | AGENTS.md (copaw + hermes) |
| 5 | Version field on existing built-in skills | 10+ SKILL.md files |
