# GitHub PR Checks Implementation for Panel Attack

## Overview

This document outlines the GitHub Actions PR checks for Panel Attack:
1. **Lua Language Server diagnostics** - Block PRs that introduce new warnings
2. **Love2D test suite** - Run all tests in headless mode with log output

## Implementation

Create `.github/workflows/pr-checks.yml`:

```yaml
name: PR Checks

on:
  pull_request:
    paths:
      - '**.lua'
      - '.luarc.json'
      - '.github/workflows/pr-checks.yml'
  push:
    branches: [beta]

jobs:
  lua-diagnostics:
    name: Lua Language Server Diagnostics
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Type Check and Lint
        uses: mrcjkb/lua-typecheck-action@v0
        with:
          config_file: .luarc.json
          level: Warning

  love2d-tests:
    name: Love2D Test Suite
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Love2D dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libsdl2-2.0-0 libopenal1 libfreetype6 \
            libtheora0 libvorbis0a libmodplug1

      - name: Cache Love2D binary
        id: cache-love
        uses: actions/cache@v4
        with:
          path: ~/love2d
          key: love2d-12.0-${{ hashFiles('.github/love-version.txt') }}

      - name: Download Love2D 12.0
        if: steps.cache-love.outputs.cache-hit != 'true'
        run: |
          mkdir -p ~/love2d
          curl -L "https://github.com/YOUR-ORG/panel-attack/releases/download/love2d-12.0/love-12.0-linux-x86_64.tar.gz" \
            -o /tmp/love.tar.gz
          tar -xzf /tmp/love.tar.gz -C ~/love2d --strip-components=1

      - name: Run tests
        run: ~/love2d/bin/love ./testLauncher.lua
        env:
          SDL_VIDEODRIVER: dummy
          SDL_AUDIODRIVER: dummy
        timeout-minutes: 10

      - name: Upload test logs on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-logs
          path: "*.log"
```

### What Each Job Does

**Job 1: Lua Language Server Diagnostics**
- Uses your existing `.luarc.json` configuration
- Checks for type mismatches, undefined fields, nil safety issues
- Blocks PRs that introduce new warnings
- Matches your local development environment exactly

**Job 2: Love2D Test Suite**
- Runs `testLauncher.lua` in headless mode (no UI rendering)
- Uses `SDL_VIDEODRIVER=dummy` and `SDL_AUDIODRIVER=dummy` for log-only output
- Downloads Love2D from a GitHub release in your repo
- Caches the binary for faster subsequent runs
- Uploads logs on failure for debugging

### Optional: Stricter Diagnostic Checking

Consider changing `.luarc.json` diagnostics from "Opened" to "Any" for comprehensive CI checking:

```json
{
  "diagnostics.neededFileStatus": {
    "assign-type-mismatch": "Any",
    "cast-local-type": "Any",
    "need-check-nil": "Any",
    "param-type-mismatch": "Any",
    "undefined-field": "Any",
    "undefined-doc-name": "Any"
  }
}
```

## Love2D Binary Distribution

### Upload Your Current Love2D Binary

1. **Package your current Love2D 12.0 binary:**
   ```bash
   # On your Mac where you have Love2D 12.0 working
   # Get the Linux version (download CI build or compile)
   # Then package it:
   tar -czf love-12.0-linux-x86_64.tar.gz love-directory/
   ```

2. **Create a GitHub release to host it:**
   ```bash
   gh release create love2d-12.0 \
     love-12.0-linux-x86_64.tar.gz \
     --title "Love2D 12.0 Development Build" \
     --notes "Love2D 12.0 CI build for GitHub Actions"
   ```

3. **Create version tracking file:**
   ```bash
   # Create .github/love-version.txt with a hash or date
   echo "12.0-2025-10-10" > .github/love-version.txt
   git add .github/love-version.txt
   git commit -m "Add Love2D version tracking for CI cache"
   ```

4. **Update the workflow URL:**
   Replace `YOUR-ORG` in the workflow with your actual GitHub org/username.

### Updating Love2D Version

When you want to update the Love2D binary:
1. Upload new binary to a new GitHub release
2. Update `.github/love-version.txt`
3. Update the download URL in the workflow if needed

## CI Performance

**Expected Runtime:**
- Lua Language Server: ~30-60 seconds
- Love2D Tests: ~2-5 minutes
- **Total: ~3-6 minutes per PR**

**Caching:**
- Love2D binary is cached after first download
- Cache invalidates when `.github/love-version.txt` changes

## Next Steps

1. ✅ Create `.github/workflows/pr-checks.yml` with the complete workflow above
2. ✅ Package your Love2D 12.0 Linux binary as a tar.gz
3. ✅ Upload it to a GitHub release: `love2d-12.0`
4. ✅ Create `.github/love-version.txt` to track version for caching
5. ✅ Update workflow URL with your org/username
6. ✅ Test on a development branch
7. ✅ Enable as required check for PRs

## References

- [mrcjkb/lua-typecheck-action](https://github.com/marketplace/actions/lua-typecheck-action) - Lua Language Server CI
- [Lua Language Server Diagnostics](https://luals.github.io/wiki/diagnostics/)
- [SDL Environment Variables](https://wiki.libsdl.org/SDL2/CategoryHints) - For headless mode
