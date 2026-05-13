#!/bin/zsh
# Pull journal, on-disk logs, and crash reports from the prod server into
# a local timestamped directory. Designed to run before deploy.sh so every
# deploy has a snapshot of pre-deploy state — if something regresses after
# the deploy, we have the exact "before" view to compare against.
#
# Output: gathered_logs/<UTC-timestamp>_<local-commit>/
#   - journal.log         systemd journal for panel-attack (last 7 days by default)
#   - logs/*.log          server-local .log files written via run_server.sh tee
#   - crash_reports/      client + server-side crash dumps (once the pipeline lands)
#   - META.txt            timestamp / branch / commit / source server
#
# Env overrides:
#   PANEL_SERVER       full SSH target, default "root@104.156.250.136"
#   INSTALL_DIR        remote repo dir, default "/opt/panel-attack"
#   JOURNAL_SINCE      journalctl --since arg, default "7 days ago"
#   PANEL_GATHER_DB    set to "1" to also scp PADatabase.sqlite3

set -euo pipefail

SERVER="${PANEL_SERVER:-root@104.156.250.136}"
INSTALL_DIR="${INSTALL_DIR:-/opt/panel-attack}"
JOURNAL_SINCE="${JOURNAL_SINCE:-7 days ago}"

cd "$(dirname "$0")"

ts=$(date -u +%Y%m%dT%H%M%SZ)
commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
dest="gathered_logs/${ts}_${commit}"
mkdir -p "${dest}"

echo "==> Gathering server state to ${dest}"
echo "    server:  ${SERVER}"
echo "    remote:  ${INSTALL_DIR}"
echo "    journal: since ${JOURNAL_SINCE}"

# 1. systemd journal — the panel-attack service stdout. This is the
# authoritative log; run_server.sh on the prod machine ultimately feeds
# stdout, which systemd captures here.
echo "==> [1/3] journalctl"
ssh "${SERVER}" "journalctl -u panel-attack --since '${JOURNAL_SINCE}' --no-pager" \
  > "${dest}/journal.log"
journal_lines=$(wc -l < "${dest}/journal.log" | tr -d ' ')
echo "    journal.log: ${journal_lines} lines"

# 2. On-disk .log files in the remote logs/ dir (server.log etc).
# Redundant with the journal in most cases, but: (a) the journal can be
# rotated/dropped by systemd while these stick around, (b) clients of
# run_local.sh write here without journal involvement.
echo "==> [2/3] remote logs/"
mkdir -p "${dest}/logs"
if rsync -az --include='*.log' --include='*/' --exclude='*' \
    "${SERVER}:${INSTALL_DIR}/logs/" "${dest}/logs/" 2>/dev/null; then
  log_count=$(find "${dest}/logs" -name '*.log' | wc -l | tr -d ' ')
  echo "    pulled ${log_count} .log file(s)"
else
  echo "    (no logs/ on remote — skipping)"
fi

# 3. Crash reports — lands once the crash-replay pipeline ships
# (see docs/CRASH_REPLAY_PLAN.md). Pulls both <publicId>/ subdirs
# (client-uploaded reports) and server_side/ (auto-captured disconnect
# snapshots). Each report is a self-contained JSON with the replay
# payload, ready to promote into a regression-test fixture.
echo "==> [3/3] crash_reports/"
mkdir -p "${dest}/crash_reports"
if rsync -az \
    "${SERVER}:${INSTALL_DIR}/crash_reports/" "${dest}/crash_reports/" 2>/dev/null; then
  report_count=$(find "${dest}/crash_reports" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
  echo "    pulled ${report_count} report(s)"
else
  echo "    (no crash_reports/ on remote — pipeline not yet shipped, OK)"
fi

# Optional: pull the live SQLite DB. Heavy (potentially many MB) so it's
# opt-in. Useful when debugging leaderboard / player-row issues.
if [[ "${PANEL_GATHER_DB:-0}" == "1" ]]; then
  echo "==> [bonus] PADatabase.sqlite3"
  if scp "${SERVER}:${INSTALL_DIR}/PADatabase.sqlite3" \
         "${dest}/PADatabase.sqlite3" 2>/dev/null; then
    db_size=$(wc -c < "${dest}/PADatabase.sqlite3" | tr -d ' ')
    echo "    DB: ${db_size} bytes"
  else
    echo "    (no DB on remote)"
  fi
fi

# Metadata file so a stale gather is identifiable later.
cat > "${dest}/META.txt" <<EOF
Gathered at:    ${ts} UTC
Local branch:   $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
Local commit:   $(git rev-parse HEAD 2>/dev/null || echo "unknown")
Remote:         ${SERVER}:${INSTALL_DIR}
Journal since:  ${JOURNAL_SINCE}
EOF

echo "==> Done. ${dest}"
