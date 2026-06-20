#!/bin/bash
# One-shot setup for friends running Claude Usage OSD locally.
#
# 1. Wires up the Claude Code statusLine hook that feeds this app real usage
#    data (~/.claude/usage-osd-cache.json, ~/.claude/usage-osd-events.jsonl).
#    Without this hook the app's gauges show "—" forever — there is no public
#    API for subscription usage; the statusLine stdin payload is the only
#    place Claude Code exposes it, and only while a session is active.
# 2. Builds the app and installs it to ~/Applications as a login item.
set -euo pipefail
cd "$(dirname "$0")"

CLAUDE_DIR="$HOME/.claude"
STATUSLINE_SCRIPT="$CLAUDE_DIR/statusline-command.sh"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
MARKER="# >>> usage-osd-cache (Claude Usage OSD) >>>"
MARKER_END="# <<< usage-osd-cache (Claude Usage OSD) <<<"

mkdir -p "$CLAUDE_DIR"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (brew install jq) — install it and re-run this script." >&2
  exit 1
fi

cache_block() {
  cat <<'BLOCK'
# >>> usage-osd-cache (Claude Usage OSD) >>>
input="${USAGE_OSD_INPUT:-$(cat)}"
session_id=$(echo "$input" | jq -r '.session_id // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
now_epoch=$(date +%s)
cache_file="$HOME/.claude/usage-osd-cache.json"
events_file="$HOME/.claude/usage-osd-events.jsonl"

jq -n \
  --argjson ts "$now_epoch" \
  --arg five_pct "$five_pct" --arg five_reset "$five_reset" \
  --arg week_pct "$week_pct" --arg week_reset "$week_reset" \
  --arg session "$session_id" --arg cost "$cost_usd" \
  '{
    updated_at: $ts,
    five_hour: { used_percentage: ($five_pct | tonumber?), resets_at: ($five_reset | tonumber?) },
    seven_day: { used_percentage: ($week_pct | tonumber?), resets_at: ($week_reset | tonumber?) },
    session_id: $session,
    cost_usd: ($cost | tonumber? // 0)
  }' > "${cache_file}.tmp" 2>/dev/null && mv "${cache_file}.tmp" "$cache_file"

if [ -n "$session_id" ]; then
  printf '{"ts":%s,"session_id":"%s","cost_usd":%s}\n' "$now_epoch" "$session_id" "${cost_usd:-0}" >> "$events_file"
  cutoff=$((now_epoch - 8 * 86400))
  jq -c --argjson cutoff "$cutoff" 'select(.ts >= $cutoff)' "$events_file" 2>/dev/null \
    | tail -n 2000 > "${events_file}.tmp" && mv "${events_file}.tmp" "$events_file"
fi
# <<< usage-osd-cache (Claude Usage OSD) <<<
BLOCK
}

if [ ! -f "$STATUSLINE_SCRIPT" ]; then
  echo "No existing statusline script — creating $STATUSLINE_SCRIPT"
  {
    echo "#!/bin/bash"
    echo 'input=$(cat)'
    echo 'USAGE_OSD_INPUT="$input"'
    cache_block
    echo 'echo "Claude Code"'
  } > "$STATUSLINE_SCRIPT"
  chmod +x "$STATUSLINE_SCRIPT"

  if [ -f "$SETTINGS_FILE" ]; then
    tmp=$(mktemp)
    jq --arg cmd "bash \"$STATUSLINE_SCRIPT\"" \
      '.statusLine = {type: "command", command: $cmd}' \
      "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
  else
    jq -n --arg cmd "bash \"$STATUSLINE_SCRIPT\"" \
      '{statusLine: {type: "command", command: $cmd}}' > "$SETTINGS_FILE"
  fi
  echo "Registered statusLine hook in $SETTINGS_FILE"
elif grep -qF "$MARKER" "$STATUSLINE_SCRIPT"; then
  echo "Usage OSD cache block already present in $STATUSLINE_SCRIPT — skipping."
else
  echo
  echo "You already have a statusline script at $STATUSLINE_SCRIPT."
  echo "To avoid breaking it, this script will NOT edit it automatically."
  echo "Paste the block below into it (anywhere after \$input is read), then re-run this script:"
  echo
  cache_block
  echo
  read -p "Press Enter once you've added it (or Ctrl-C to do it later) " _
fi

echo
echo "Building and installing the app..."
./build_app.sh
