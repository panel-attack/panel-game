# PR Checks Reference

This document explains how the Panel Attack GitHub PR checks work and how to refresh the bundled Love2D binary. See `.github/workflows/pr-checks.yml` for the authoritative configuration.

## Checks at a Glance

- **Lua Language Server Diagnostics (`lua-diagnostics`)**: runs the lua-language-server action and fails on any diagnostic at information level or higher.
- **Test Suite (`love2d-tests`)**: launches `testLauncher.lua` in headless mode using the cached Love AppImage and exports logs for review.

The workflow runs on pull requests and on pushes to `beta`. Each job first checks which files changed: diagnostics run only if a changed file matches `DIAGNOSTICS_PATHS`, and tests are skipped when every changed file matches `TESTS_SKIP_PATHS`. A skipped job passes.

Each job publishes a concise failure summary to the GitHub Actions job summary while still failing the workflow so that GitHub blocks the PR when problems are detected.

## Diagnostics Job Notes

- The action writes raw results to `check.json`; the following step formats that output down to file, line, message, and diagnostic code for easier consumption.
- The "Type Check and Lint" step is marked with `continue-on-error`, so the "Publish diagnostics annotations" step still runs. It formats the results, adds inline error annotations to the PR and exits with status 1 to propagate the failure back to GitHub.
- All emitted diagnostics appear in a collapsible section, so reviewers can expand to inspect the full context without leaving the PR.

## Love2D Test Job Notes

- Tests execute with the Love2D AppImage downloaded from the project’s GitHub release. The artifact is cached using the key that incorporates `.github/love-version.txt`.
- Failures capture filtered output: failing test names and the tail of ERROR-level logs are surfaced in the job summary, while the untouched log files are uploaded as artifacts for deep dives.
- The job mirrors the diagnostics pattern: the run step may continue to allow formatting and logging, and the "Format Test Failures" step exits non-zero so GitHub marks the PR check as failed.

## Updating the Love2D Distribution

1. Publish the new Linux Love2D build to a GitHub release that the workflow can access (keep naming consistent so the download URL change is minimal).
   - Package the AppImage with `tar -czf love-<version>-linux-x86_64.tar.gz <the AppImage>` so it sits at the top level of the archive; the workflow unpacks it and renames `*.AppImage` to `love.AppImage`.
   - Create (or reuse) a release and upload the archive. The GitHub UI works, or you can run `gh release upload love2d-<version> love-<version>-linux-x86_64.tar.gz --clobber`.
   - Note the release tag and asset filename—the workflow download step uses both, so keep them aligned when you update the YAML.
2. Update `.github/love-version.txt` with a new cache token (date, hash). This invalidates the Actions cache and forces the new binary to download.
3. Adjust the download URL in `.github/workflows/pr-checks.yml` if the release tag or asset name changed. For a new LÖVE version, also change the `love2d-12.0-` prefix of the cache key.
4. Open a PR containing these updates; the first workflow run will repopulate the cache and subsequent runs will reuse it.