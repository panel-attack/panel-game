# GitHub PR Checks Implementation for Panel Attack

## Overview

This document outlines the GitHub Actions PR checks for Panel Attack:
1. **Lua Language Server diagnostics** - Block PRs that introduce new warnings
2. **Love2D test suite** - Run all tests in headless mode with log output

## Implementation

See `.github/workflows/pr-checks.yml` for the complete workflow implementation.

### Job 1: Lua Language Server Diagnostics

- Uses [mrcjkb/lua-typecheck-action](https://github.com/mrcjkb/lua-typecheck-action)
- Uses your `.luarc.json` configuration
- Check level: Information (fails on Info, Warning, or Error diagnostics)
- Formats error output in job summary for easy reading

### Job 2: Love2D Test Suite

- Runs `testLauncher.lua` using Xvfb for headless OpenGL support
- Uses AppImage format for Love2D (self-contained)
- Downloads Love2D from GitHub release and caches it
- Captures and uploads logs on failure

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
