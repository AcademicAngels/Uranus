"""Tests for embedding config passthrough in Hermes bridge."""

import tempfile
from pathlib import Path

import yaml

from hermes_worker import bridge as bridge_module
from hermes_worker.bridge import bridge_openclaw_to_hermes


def _make_openclaw_cfg_with_embedding() -> dict:
    return {
        "channels": {
            "matrix": {
                "homeserver": "http://matrix:6167",
                "accessToken": "tok",
                "userId": "@alice:hiclaw.io",
            }
        },
        "models": {
            "providers": {
                "gw": {
                    "baseUrl": "http://aigw:8080/v1",
                    "apiKey": "key123",
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
                        "apiKey": "key123",
                    },
                },
            }
        },
    }


def _bridge_and_read(openclaw_cfg: dict) -> dict:
    with tempfile.TemporaryDirectory() as tmpdir:
        hermes_home = Path(tmpdir) / ".hermes"
        hermes_home.mkdir(parents=True, exist_ok=True)
        bridge_openclaw_to_hermes(openclaw_cfg, hermes_home)
        return yaml.safe_load((hermes_home / "config.yaml").read_text())


def test_embedding_config_written_to_hermes(monkeypatch):
    monkeypatch.setattr(bridge_module, "_is_in_container", lambda: True)
    cfg = _make_openclaw_cfg_with_embedding()
    config = _bridge_and_read(cfg)
    assert "memory" in config
    mem = config["memory"]
    assert mem["memory_enabled"] is True
    assert mem["embedding_model"] == "text-embedding-v4"
    assert mem["embedding_base_url"] == "http://aigw:8080/v1"
    assert mem["vault_path"] == "shared/vault"


def test_embedding_config_absent_when_no_memory_search(monkeypatch):
    monkeypatch.setattr(bridge_module, "_is_in_container", lambda: True)
    cfg = _make_openclaw_cfg_with_embedding()
    del cfg["agents"]["defaults"]["memorySearch"]
    config = _bridge_and_read(cfg)
    mem = config.get("memory", {})
    assert "embedding_model" not in mem
