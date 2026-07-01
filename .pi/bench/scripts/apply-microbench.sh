#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TS="${BLITZ_BENCH_TS:-$(date -u +%Y%m%d-%H%M%S)}"
OUT_DIR="${BLITZ_BENCH_OUT_DIR:-${TMPDIR:-/tmp}/blitz-lane-f-apply-microbench-${TS}}"
REPORT="${BLITZ_BENCH_REPORT:-${REPO_ROOT}/reports/lane-f-apply-microbench-${TS}.md}"
ITERATIONS="${BLITZ_BENCH_ITERATIONS:-20}"
BLITZ_BIN="${BLITZ_BIN:-${REPO_ROOT}/zig-out/bin/blitz}"
TMP_ROOT="${TMPDIR:-/tmp}/blitz-apply-microbench-${TS}"

mkdir -p "${OUT_DIR}" "${TMP_ROOT}"
cd "${REPO_ROOT}"

if [[ ! -x "${BLITZ_BIN}" ]]; then
	if ! command -v zig >/dev/null 2>&1; then
		echo "blitz binary missing and zig not found" >&2
		exit 127
	fi
	zig build >/dev/null
fi

now_ns() { date +%s%N; }
ms_delta() { awk -v start="$1" -v end="$2" 'BEGIN { printf "%.3f", (end - start) / 1000000 }'; }
median_ms() {
	awk 'NF { print $1 }' | sort -n | awk '{ a[NR]=$1 } END { if (NR == 0) print "n/a"; else if (NR % 2) printf "%.3f", a[(NR + 1) / 2]; else printf "%.3f", (a[NR / 2] + a[NR / 2 + 1]) / 2 }'
}

p95_ms() {
	awk 'NF { print $1 }' | sort -n | awk '{ a[NR]=$1 } END { if (NR == 0) print "n/a"; else { rank = int(NR * 0.95); if (rank < NR * 0.95) rank++; if (rank < 1) rank = 1; printf "%.3f", a[rank] } }'
}

fixture="${TMP_ROOT}/sample.ts"
cat >"${fixture}" <<'EOF'
export function scale(value: number): number {
  const base = value * 2;
  return base;
}

export function greet(name: string): string {
  const clean = name.trim();
  return `hello ${clean}`;
}
EOF

request_replace="$(
	cat <<EOF
{"version":1,"file":"${fixture}","operation":"patch","edit":{"ops":[["replace_return","scale","base + 1"]]},"options":{"dryRun":true}}
EOF
)"
request_wrap="$(
	cat <<EOF
{"version":1,"file":"${fixture}","operation":"patch","edit":{"ops":[["try_catch","greet","  console.error(error);\n  throw error;"]]},"options":{"dryRun":true}}
EOF
)"

run_case() {
	local label="$1"
	local request="$2"
	local samples="${OUT_DIR}/${label}.samples-ms.txt"
	local stdout_file="${OUT_DIR}/${label}.last.json"
	local stderr_file="${OUT_DIR}/${label}.last.err"
	: >"${samples}"
	for _ in $(seq 1 "${ITERATIONS}"); do
		local start end status
		start="$(now_ns)"
		if printf '%s' "${request}" | "${BLITZ_BIN}" apply --edit - --json --dry-run >"${stdout_file}" 2>"${stderr_file}"; then
			status=0
		else
			status=$?
		fi
		end="$(now_ns)"
		if [[ "${status}" != "0" ]]; then
			echo "case ${label} failed with status ${status}; see ${stderr_file}" >&2
			return "${status}"
		fi
		ms_delta "${start}" "${end}" >>"${samples}"
		printf '\n' >>"${samples}"
	done
	printf '%s %s\n' "$(median_ms <"${samples}")" "$(p95_ms <"${samples}")"
}

replace_stats="$(run_case replace_return "${request_replace}")"
read -r replace_median replace_p95 <<<"${replace_stats}"
wrap_stats="$(run_case try_catch "${request_wrap}")"
read -r wrap_median wrap_p95 <<<"${wrap_stats}"

apply_fixture="${TMP_ROOT}/sample-apply.ts"
cp "${fixture}" "${apply_fixture}"
apply_request="$(
	cat <<EOF
{"version":1,"file":"${apply_fixture}","operation":"patch","edit":{"ops":[["replace_return","scale","base + 1"]]}}
EOF
)"
apply_status=0
printf '%s' "${apply_request}" | "${BLITZ_BIN}" apply --edit - --json >"${OUT_DIR}/apply-smoke.json" 2>"${OUT_DIR}/apply-smoke.err" || apply_status=$?

cat >"${REPORT}" <<EOF
# Lane F apply microbench evidence

Date (UTC): ${TS}  
Binary: ${BLITZ_BIN}  
Iterations per dry-run case: ${ITERATIONS}  
Temp fixture dir: ${TMP_ROOT}  
Artifacts dir: ${OUT_DIR}

| Case | Command | Median wall ms | p95 wall ms | Status |
|---|---|---:|---:|---:|
| replace_return dry-run | \`blitz apply --edit - --json --dry-run\` | ${replace_median} | ${replace_p95} | 0 |
| try_catch dry-run | \`blitz apply --edit - --json --dry-run\` | ${wrap_median} | ${wrap_p95} | 0 |
| replace_return apply smoke | \`blitz apply --edit - --json\` | n/a | n/a | ${apply_status} |

Notes:
- All mutations happen under \`${TMP_ROOT}\`.
- Dry-run requests include JSON \`options.dryRun=true\` plus CLI \`--dry-run\`.
- p95 uses nearest-rank over numeric ascending sample files: rank = ceil(0.95 * N).
- Last JSON/stdout and stderr artifacts are stored in \`${OUT_DIR}\`.
EOF

echo "${REPORT}"
