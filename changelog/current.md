# Changelog (Unreleased)

Record image-affecting changes to `manager/`, `worker/`, `openclaw-base/` here before the next release.

---

- fix(hermes): let web UI build stage use configurable Node image and mirror build args
- fix(hermes): default web UI Node base image to a China Docker Hub mirror
- fix(build): use local or Higress-registry controller/base images for Worker builds
- fix(manager): restrict Manager runtime to OpenClaw or CoPaw and keep Hermes as Worker-only
