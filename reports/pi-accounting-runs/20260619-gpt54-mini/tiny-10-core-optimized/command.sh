#!/usr/bin/env bash
set -u
export PATH='/home/kenzo/dev/blitz/zig-out/bin'":$PATH"
export PI_BLITZ_TOOL_PROFILE=
cd '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-gpt54-mini/tiny-10-core-optimized/work'
start_ms=$(date +%s%3N)
status=0
'/home/kenzo/.local/bin/pi' '--offline' '-p' '--no-context-files' '--no-prompt-templates' '--provider' 'openai-codex' '--model' 'gpt-5.4-mini' '--thinking' 'off' '--session-dir' '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-gpt54-mini/tiny-10-core-optimized/sessions' '--no-skills' '--no-extensions' '--tools' 'edit' '@/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-gpt54-mini/tiny-10-core-optimized/prompt.md' > >(tee '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-gpt54-mini/tiny-10-core-optimized/stdout.log') 2> >(tee '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-gpt54-mini/tiny-10-core-optimized/stderr.log' >&2) || status=$?
end_ms=$(date +%s%3N)
printf '{"status":%s,"wallMs":%s,"timedOut":false}\n' "$status" "$((end_ms - start_ms))" > '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-gpt54-mini/tiny-10-core-optimized/exit.json'
exit "$status"
