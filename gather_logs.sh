#!/bin/zsh
# Pull journal, on-disk logs, crash reports, and trace_archive from the
# prod server into a local timestamped directory. Designed to run before
# deploy.sh so every deploy has a snapshot of pre-deploy state — if
# something regresses after the deploy, we have the exact "before" view
# to compare against.
#
# Output: gathered_logs/<UTC-timestamp>_<local-commit>/
#   - journal.log         systemd journal for panel-attack (last 7 days by default)
#   - logs/*.log          server-local .log files written via run_server.sh tee
#   - crash_reports/      client + server-side crash dumps (once the pipeline lands)
#   - trace_archive/      per-publicId JSONL session traces (server-side tap)
#   - META.txt            timestamp / branch / commit / source server
#
# Env overrides:
#   PANEL_SERVER         full SSH target, default "root@104.156.250.136"
#   INSTALL_DIR          remote repo dir, default "/opt/panel-attack"
#   JOURNAL_SINCE        journalctl --since arg, default "7 days ago"
#   PANEL_GATHER_DB      set to "1" to also scp PADatabase.sqlite3
#   PANEL_SKIP_TRACES    set to "1" to skip trace_archive pull (it can be
#                        large — every player session leaves one JSONL file)

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

# rsync exit codes we tolerate vs treat as fatal. From the rsync manpage:
#   0   success
#   23  partial transfer — some files couldn't be transferred. In practice
#       this is what rsync returns when the SOURCE DIR DOESN'T EXIST on
#       the remote (it logs "rsync: change_dir ... No such file or
#       directory (2)" and exits 23). We accept this — crash_reports/
#       legitimately won't exist until the crash-replay pipeline ships,
#       and logs/ may not exist on a freshly-installed remote.
#   other  network error, protocol error, auth failure, etc. → fatal.
#
# Anything fatal aborts BEFORE we do `git push` + restart, which is the
# whole point: if we can't snapshot, we don't deploy.
gather_with_rsync_check() {
  local label="$1"
  local remote_src="$2"
  local local_dst="$3"
  local extra_args="$4"  # may be empty; left unquoted in the rsync call

  set +e
  # shellcheck disable=SC2086 -- intentional word-split for extra_args
  rsync -az ${extra_args} "${remote_src}" "${local_dst}"
  local rc=$?
  set -e

  case $rc in
    0)
      echo "    ${label}: OK"
      ;;
    23)
      echo "    ${label}: code 23 — source likely absent on remote, continuing"
      ;;
    *)
      echo ""
      echo "ERROR: rsync failed (${label}) with exit code ${rc}." >&2
      echo "       Refusing to deploy without a clean snapshot." >&2
      echo "       Re-run gather, or set PANEL_SKIP_GATHER=1 to override." >&2
      exit "${rc}"
      ;;
  esac
}

# 1. systemd journal — the panel-attack service stdout. This is the
# authoritative log; run_server.sh on the prod machine ultimately feeds
# stdout, which systemd captures here.
#
# `set -e` covers the SSH itself — a connect failure / non-zero exit
# aborts. But journalctl can succeed with zero output (e.g. if --since
# is too narrow), and an empty journal is a useless snapshot, so we
# also assert the file has content.
echo "==> [1/4] journalctl"
ssh "${SERVER}" "journalctl -u panel-attack --since '${JOURNAL_SINCE}' --no-pager" \
  > "${dest}/journal.log"
if [[ ! -s "${dest}/journal.log" ]]; then
  echo "" >&2
  echo "ERROR: journal.log is empty after journalctl pull." >&2
  echo "       Either the service didn't log anything within '${JOURNAL_SINCE}'" >&2
  echo "       (widen JOURNAL_SINCE), or the SSH succeeded but the remote" >&2
  echo "       journal is empty for this unit." >&2
  echo "       Refusing to deploy without a usable snapshot." >&2
  exit 1
fi
journal_lines=$(wc -l < "${dest}/journal.log" | tr -d ' ')
echo "    journal.log: ${journal_lines} lines"

# 2. On-disk .log files in the remote logs/ dir (server.log etc).
# Redundant with the journal in most cases, but the journal can be
# rotated/dropped by systemd while these stick around. Also, run_server.sh
# uses `tee` without -a, so server.log gets truncated on next start —
# this is the one file actually at risk of disappearing on restart.
echo "==> [2/4] remote logs/"
mkdir -p "${dest}/logs"
gather_with_rsync_check "logs/" \
  "${SERVER}:${INSTALL_DIR}/logs/" "${dest}/logs/" \
  "--include=*.log --include=*/ --exclude=*"
log_count=$(find "${dest}/logs" -name '*.log' 2>/dev/null | wc -l | tr -d ' ')
echo "    pulled ${log_count} .log file(s)"

# 3. Crash reports — lands once the crash-replay pipeline ships
# (see docs/CRASH_REPLAY_PLAN.md). Pulls both <publicId>/ subdirs
# (client-uploaded reports) and server_side/ (auto-captured disconnect
# snapshots). Each report is a self-contained JSON with the replay
# payload, ready to promote into a regression-test fixture.
echo "==> [3/4] crash_reports/"
mkdir -p "${dest}/crash_reports"
gather_with_rsync_check "crash_reports/" \
  "${SERVER}:${INSTALL_DIR}/crash_reports/" "${dest}/crash_reports/" ""
report_count=$(find "${dest}/crash_reports" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
echo "    pulled ${report_count} report(s)"

# 4. Trace archive — per-publicId JSONL session traces written by the
# server-side TraceWriter tap. Each session_<ts>.jsonl is a record of
# every message the server saw from / sent to that player. Cross-
# referenced with client-side trace_archive bundles for the cross-
# perspective diff util (see docs/CRASH_REPLAY_PLAN.md Phase F'). Can be
# skipped via PANEL_SKIP_TRACES=1 since this grows unbounded over time.
echo "==> [4/4] trace_archive/"
if [[ "${PANEL_SKIP_TRACES:-0}" == "1" ]]; then
  echo "    skipped (PANEL_SKIP_TRACES=1)"
else
  mkdir -p "${dest}/trace_archive"
  gather_with_rsync_check "trace_archive/" \
    "${SERVER}:${INSTALL_DIR}/trace_archive/" "${dest}/trace_archive/" ""
  trace_count=$(find "${dest}/trace_archive" -name '*.jsonl' 2>/dev/null | wc -l | tr -d ' ')
  echo "    pulled ${trace_count} trace file(s)"
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
