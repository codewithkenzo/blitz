#!/usr/bin/env bash
set -u
RUN_DIR='/home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T02-59-35-877Z/medium-10k_wrap-body__blitz__0'
STDOUT_LOG="$RUN_DIR/stdout.log"
STDERR_LOG="$RUN_DIR/stderr.log"
EXIT_FILE="$RUN_DIR/exit.json"
export PATH='/home/kenzo/dev/blitz/zig-out/bin'":$PATH"
export PI_BLITZ_TOOL_PROFILE='minimal'
cd '/home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T02-59-35-877Z/medium-10k_wrap-body__blitz__0/work'
start_ms=$(date +%s%3N)
status=0
{
	'/home/kenzo/.local/bin/pi' '--offline' '-p' '--no-context-files' '--no-prompt-templates' '--provider' 'zai' '--model' 'glm-4.5-air' '--thinking' 'off' '--session-dir' '/home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T02-59-35-877Z/medium-10k_wrap-body__blitz__0/sessions' '--no-extensions' '--extension' '/home/kenzo/dev/pi-blitz/dist/index.js' '--skill' '/home/kenzo/dev/pi-blitz/skills/pi-blitz' '--tools' 'pi_blitz_op' '@/home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T02-59-35-877Z/medium-10k_wrap-body__blitz__0/prompt.md'
} > >(tee "$STDOUT_LOG") 2> >(tee "$STDERR_LOG" >&2) || status=$?
end_ms=$(date +%s%3N)
wall_ms=$((end_ms - start_ms))
printf '{"status":%s,"wallMs":%s,"timedOut":false}
' "$status" "$wall_ms" > "$EXIT_FILE.tmp"
mv "$EXIT_FILE.tmp" "$EXIT_FILE"
exit "$status"
