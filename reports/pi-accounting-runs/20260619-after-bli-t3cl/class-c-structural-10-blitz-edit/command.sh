#!/usr/bin/env bash
set -u
export PATH='/home/kenzo/dev/blitz/zig-out/bin'":$PATH"
export PI_BLITZ_TOOL_PROFILE=minimal
cd '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/class-c-structural-10-blitz-edit/work'
start_ms=$(date +%s%3N)
status=0
'/home/kenzo/.local/bin/pi' '--offline' '-p' '--no-context-files' '--no-prompt-templates' '--provider' 'zai' '--model' 'glm-4.5-air' '--thinking' 'off' '--session-dir' '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/class-c-structural-10-blitz-edit/sessions' '--no-extensions' '--extension' '/home/kenzo/dev/pi-blitz/dist/index.js' '--skill' '/home/kenzo/dev/pi-blitz/skills/pi-blitz' '--tools' 'blitz_edit' '@/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/class-c-structural-10-blitz-edit/prompt.md' > >(tee '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/class-c-structural-10-blitz-edit/stdout.log') 2> >(tee '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/class-c-structural-10-blitz-edit/stderr.log' >&2) || status=$?
end_ms=$(date +%s%3N)
printf '{"status":%s,"wallMs":%s,"timedOut":false}\n' "$status" "$((end_ms - start_ms))" > '/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-after-bli-t3cl/class-c-structural-10-blitz-edit/exit.json'
exit "$status"
