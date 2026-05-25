#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TS="${BLITZ_BENCH_TS:-$(date -u +%Y%m%d-%H%M%S)}"
OUT_DIR="${BLITZ_BENCH_OUT_DIR:-${TMPDIR:-/tmp}/blitz-lane-f-release-build-matrix-${TS}}"
REPORT="${BLITZ_BENCH_REPORT:-${REPO_ROOT}/reports/lane-f-release-build-matrix-${TS}.md}"
ITERATIONS="${BLITZ_BENCH_ITERATIONS:-5}"

mkdir -p "${OUT_DIR}" "$(dirname "${REPORT}")"
cd "${REPO_ROOT}"

if ! command -v zig >/dev/null 2>&1; then
	echo "zig not found" >&2
	exit 127
fi

zig_version="$(zig version)"
host_uname="$(uname -sm)"

now_ns() { date +%s%N; }
ms_delta() { awk -v start="$1" -v end="$2" 'BEGIN { printf "%.3f", (end - start) / 1000000 }'; }
file_size() { stat -c '%s' "$1"; }

run_timed() {
	local label="$1"
	shift
	local log="${OUT_DIR}/${label}.log"
	local start end status
	start="$(now_ns)"
	if "$@" >"${log}" 2>&1; then
		status=0
	else
		status=$?
	fi
	end="$(now_ns)"
	printf '%s\t%s\t%s\t%s\n' "${label}" "${status}" "$(ms_delta "${start}" "${end}")" "${log}"
	return "${status}"
}

median_ms() {
	awk 'NF { print $1 }' | sort -n | awk '{ a[NR]=$1 } END { if (NR == 0) print "n/a"; else if (NR % 2) printf "%.3f", a[(NR + 1) / 2]; else printf "%.3f", (a[NR / 2] + a[NR / 2 + 1]) / 2 }'
}

time_binary() {
	local bin="$1"
	local subcmd="$2"
	local tmp="${OUT_DIR}/time-${subcmd//[^A-Za-z0-9_.-]/_}.txt"
	: >"${tmp}"
	for _ in $(seq 1 "${ITERATIONS}"); do
		local start end
		start="$(now_ns)"
		"${bin}" "${subcmd}" >/dev/null 2>&1 || true
		end="$(now_ns)"
		ms_delta "${start}" "${end}" >>"${tmp}"
		printf '\n' >>"${tmp}"
	done
	median_ms <"${tmp}"
}

cat >"${REPORT}" <<EOF
# Lane F release build matrix evidence

Date (UTC): ${TS}  
Host: ${host_uname}  
Zig: ${zig_version}  
Iterations per timing: ${ITERATIONS}  
Artifacts dir: ${OUT_DIR}

## Build matrix

| Label | Command | Status | Build ms | Binary bytes | Cold --version median ms | Doctor median ms | Notes |
|---|---|---:|---:|---:|---:|---:|---|
EOF

build_one() {
	local label="$1"
	local can_run="$2"
	shift 2
	local cmd=("$@")
	local row status build_ms log bin_copy size cold_ms doctor_ms notes
	row="$(run_timed "build-${label}" "${cmd[@]}" || true)"
	status="$(printf '%s' "${row}" | cut -f2)"
	build_ms="$(printf '%s' "${row}" | cut -f3)"
	log="$(printf '%s' "${row}" | cut -f4)"
	bin_copy="${OUT_DIR}/blitz-${label}"
	size="n/a"
	cold_ms="n/a"
	doctor_ms="n/a"
	notes="log: ${log}"
	if [[ "${status}" == "0" && -f zig-out/bin/blitz ]]; then
		cp zig-out/bin/blitz "${bin_copy}"
		chmod +x "${bin_copy}"
		size="$(file_size "${bin_copy}")"
		if [[ "${can_run}" == "yes" ]]; then
			cold_ms="$(time_binary "${bin_copy}" "--version")"
			doctor_ms="$(time_binary "${bin_copy}" "doctor")"
		else
			notes="${notes}; not run on host"
		fi
	fi
	printf '| `%s` | `%s` | %s | %s | %s | %s | %s | %s |\n' \
		"${label}" "${cmd[*]}" "${status}" "${build_ms}" "${size}" "${cold_ms}" "${doctor_ms}" "${notes}" >>"${REPORT}"
}

build_one "native-releasefast" "yes" zig build -Doptimize=ReleaseFast
build_one "native-releasesmall" "yes" zig build -Doptimize=ReleaseSmall

musl_can_run="no"
if [[ "$(uname -s)" == "Linux" && "$(uname -m)" == "x86_64" ]]; then
	musl_can_run="yes"
fi
build_one "x86_64-linux-musl-releasefast" "${musl_can_run}" zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast

cimport_status="none found"
if grep -R --include='*.zig' -n '@cImport(' src build.zig >"${OUT_DIR}/cimport-search.txt" 2>&1; then
	cimport_status="found; see ${OUT_DIR}/cimport-search.txt"
fi

cat >>"${REPORT}" <<EOF

## C interop check

- Command: \`grep -R --include='*.zig' -n '@cImport(' src build.zig\`
- Result: ${cimport_status}

## Deferred evaluations

- Zig master/0.17-dev: not run by this script; optional until local toolchain exists and proves runtime or size win.
- \`smp_allocator\`: not enabled here. Repo AGENTS keeps Zig 0.16 stable and debug allocator/debug-safe policy; allocator switch needs isolated benchmark evidence before code change.
EOF

echo "${REPORT}"
