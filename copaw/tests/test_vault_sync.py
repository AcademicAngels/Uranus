"""Smoke test: vault path flows from controller config to agent config."""

import json
import tempfile
from pathlib import Path

from copaw_worker import bridge as bridge_module
from copaw_worker.bridge import bridge_controller_to_copaw


def test_vault_path_end_to_end(monkeypatch):
    """Controller -> openclaw.json -> CoPaw bridge -> agent.json vault_path."""
    monkeypatch.setattr(bridge_module, "_is_in_container", lambda: True)

    openclaw_cfg = {
        "channels": {
            "matrix": {
                "homeserver": "http://matrix:6167",
                "accessToken": "tok",
                "userId": "@test:hiclaw.io",
            }
        },
        "models": {
            "providers": {
                "gw": {
                    "baseUrl": "http://aigw:8080/v1",
                    "apiKey": "key",
                    "models": [{"id": "qwen3.5-plus", "input": ["text"]}],
                }
            }
        },
        "agents": {
            "defaults": {
                "model": {"primary": "gw/qwen3.5-plus"},
                "memorySearch": {
                    "provider": "openai",
                    "model": "text-embedding-v4",
                    "vaultPath": "shared/vault",
                    "remote": {
                        "baseUrl": "http://aigw:8080/v1",
                        "apiKey": "key",
                    },
                },
            }
        },
    }

    with tempfile.TemporaryDirectory() as tmpdir:
        working_dir = Path(tmpdir) / "agent"
        bridge_controller_to_copaw(openclaw_cfg, working_dir)
        agent_json = json.loads(
            (working_dir / "workspaces" / "default" / "agent.json").read_text()
        )

    emb = agent_json["running"]["embedding_config"]
    assert emb["model_name"] == "text-embedding-v4"
    assert emb["vault_path"] == "shared/vault"
    assert emb["backend"] == "openai"
