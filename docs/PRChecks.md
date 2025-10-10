# PR Check Strategy

- **Need:** Keep pull requests from regressing gameplay tests, Lua syntax, or diagnostics.
- **Approach:** Use GitHub Actions to run language-quality gates up front, then execute the Love2D driven test suite on any change that touches Lua or Love configuration.

## Common Checks for Lua Projects

- `lua-language-server --check` (LuaLS) to mirror editor diagnostics in CI; configured via `.luarc.json`.

## Common Checks for Love2D Projects

- Run `love` in headless mode to execute unit/integration harnesses (`love ./testLauncher.lua`).
- Cache the Love2D runtime between workflow runs to avoid repeated downloads.
- Smoke-test content with scene load scripts when deterministic tests exist.
- Validate assets (fonts, audio) if pipeline supports it; skipped here for now.

## Proposed GitHub Actions Workflow

- **Job 1 – Lua Diagnostics Gate**
  - Trigger: all PRs touching Lua or workflow files.
  - Steps:
    - Install LuaLS CLI (from release binary or `npm i -g @luals/server`).
    - Run `lua-language-server --check .` with project `.luarc.json`.
  - Failure policy: block merge; artifacts limited to logs for now.

- **Job 2 – Love2D Test Suite**
  - Trigger: same filters as above (plus ability to call manually).
  - Steps:
    - Acquire Love 12.0 CI build (see "Bundling Love2D" below).
    - Cache `~/.cache/love` and downloaded archive.
    - Launch tests: `love ./testLauncher.lua`.
    - Optional extension: add verification run (`love ./verificationLauncher.lua`) once stable in CI.
  - Failure policy: block merge; upload test logs if failure occurs.

- **Job 3 – Fast Smoke (Optional)**
  - Lightweight job to run targeted scriptable scenarios via `panel_attack_navigator.py` if runtime budget allows.

## Bundling Love2D for CI

- **Preferred:** Download nightly build during CI (scripted curl/wget) and cache it; keeps repo small, ensures updates stay centralized.
- **Alternative:** Publish required build as a release asset (or private bucket) and fetch from there; version with SHA pinning.
- **Last resort:** Commit binary via Git LFS; only if external hosting is impossible and size remains manageable.
- Implementation detail: use `tar`/`unzip`, place binary on PATH (`export LOVE_PATH="$HOME/love/bin"`), and run `LOVE_PATH/love ./testLauncher.lua`.

## Preventing New Diagnostics

- LuaLS `--check` exits non-zero when diagnostics are produced; run against the repo root configured by `.luarc.json`.
- Gate merges on LuaLS results; document baseline suppressions in `.luarc.json` if needed to stay green.

## Next Steps

- Decide on Love2D distribution source (nightly URL vs. hosted artifact).
- Author `.github/workflows/pr-checks.yml` implementing jobs above.
- Add caching key for Love builds (`love-12.0-${{ hashFiles('scripts/love-download.sh') }}`).
- Verify LuaLS installation strategy on Ubuntu runners (binary release vs. `npm`).
