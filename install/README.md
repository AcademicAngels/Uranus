# HiClaw Installation

One-click installation script for HiClaw Manager and Worker Agents.

## Usage

### Install Manager

```bash
./hiclaw-install.sh manager
```

Interactive prompts will ask for:
- LLM Provider and API Key
- Admin credentials
- Domain names (optional, defaults to `*-local.hiclaw.io`)
- GitHub PAT (optional)

### Install Worker

Workers are created by the Manager Agent through conversation. The Manager provides the exact command to run:

```bash
./hiclaw-install.sh worker \
  --name alice \
  --matrix-server http://matrix-local.hiclaw.io:8080 \
  --gateway http://llm-local.hiclaw.io:8080 \
  --fs http://fs-local.hiclaw.io:8080 \
  --fs-key <ACCESS_KEY> \
  --fs-secret <SECRET_KEY>
```

### Reset Worker

```bash
./hiclaw-install.sh worker --reset --name alice \
  --matrix-server http://matrix-local.hiclaw.io:8080 \
  --gateway http://llm-local.hiclaw.io:8080 \
  --fs http://fs-local.hiclaw.io:8080 \
  --fs-key <ACCESS_KEY> \
  --fs-secret <SECRET_KEY>
```
