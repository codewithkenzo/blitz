# D5 Phase 7 text-alias escape-fix rerun

Date: 2026-06-09

Companion pi-blitz fix used read-only: `/home/kenzo/dev/pi-blitz` pushed commit `28085fa fix(router): decode compact script escapes`; Blitz harness extension path `/home/kenzo/dev/pi-blitz/dist/index.js`. Existing artifacts preserved; new report names used.

## Commands

```bash
bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case small/wrap-tail,logging/insert-timer,long-section/replace-return,rename/function-name,markdown/append-section,css/small-edit,html/small-edit --lane router --tool-profile router --artifact-profiles router,full --iters 1 --timeout-ms 180000 --tokscale --md-out reports/pi-tmux-phase7-text-alias-router-escapes-20260609-d5.md --json-out reports/pi-tmux-phase7-text-alias-router-escapes-20260609-d5.json
```

```bash
bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case small/wrap-tail,logging/insert-timer,long-section/replace-return,rename/function-name,markdown/append-section,css/small-edit,html/small-edit --lane core --tool-profile router --artifact-profiles router,full --iters 1 --timeout-ms 180000 --tokscale --md-out reports/pi-tmux-phase7-text-alias-core-escapes-20260609-d5.md --json-out reports/pi-tmux-phase7-text-alias-core-escapes-20260609-d5.json
```

```bash
bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case markdown/append-section --lane core --tool-profile router --artifact-profiles router,full --iters 1 --timeout-ms 180000 --tokscale --md-out reports/pi-tmux-phase7-markdown-core-escapes-20260609-d5.md --json-out reports/pi-tmux-phase7-markdown-core-escapes-20260609-d5.json
```

## Artifacts

- Router report: `reports/pi-tmux-phase7-text-alias-router-escapes-20260609-d5.{md,json}`
- Router run root: `reports/pi-tmux-runs/2026-06-09T16-43-10-050Z`
- Router accounting root: `reports/pi-accounting-runs/2026-06-09T16-43-10-050Z`
- Router tmux session: `pi-bench-2026-06-09T16-43-10-050Z`
- Core all-7 report: `reports/pi-tmux-phase7-text-alias-core-escapes-20260609-d5.{md,json}`
- Core all-7 run root: `reports/pi-tmux-runs/2026-06-09T16-48-30-368Z`
- Core all-7 accounting root: `reports/pi-accounting-runs/2026-06-09T16-48-30-368Z`
- Core all-7 tmux session: `pi-bench-2026-06-09T16-48-30-368Z`
- Core markdown retry report: `reports/pi-tmux-phase7-markdown-core-escapes-20260609-d5.{md,json}`
- Core markdown retry run root: `reports/pi-tmux-runs/2026-06-09T16-50-36-081Z`
- Core markdown retry accounting root: `reports/pi-accounting-runs/2026-06-09T16-50-36-081Z`
- Core markdown retry tmux session: `pi-bench-2026-06-09T16-50-36-081Z`

## Row summary

Accepted router rows require correctness 100%, exit 0, no timeout, Tokscale match yes, intended tool `pi_blitz_route_edit`, and artifacts present. Accepted pairwise savings rows also require accepted paired core evidence.

| Fixture | Router status | Router total context | Paired core status | Core total context | Delta router-core | Savings status |
|---|---:|---:|---:|---:|---:|---|
| `small/wrap-tail` | accepted | 10,554 | accepted | 8,574 | +1,980 | no savings; router loses |
| `logging/insert-timer` | rejected; correctness 0% | 47,314 | accepted | 8,785 | +38,529 | excluded |
| `long-section/replace-return` | rejected; correctness 0% | 11,238 | rejected | 9,164 | +2,074 | excluded |
| `rename/function-name` | accepted | 10,515 | accepted | 8,598 | +1,917 | no savings; router loses |
| `markdown/append-section` | accepted | 10,556 | rejected in all-7 core and retry core | 8,849 / 13,779 | +1,707 / -3,223 | excluded; no accepted paired core row |
| `css/small-edit` | accepted | 10,466 | accepted | 8,559 | +1,907 | no savings; router loses |
| `html/small-edit` | accepted | 142,615 | accepted | 8,336 | +134,279 | no savings; router loses badly |

## Phase 7 status

Escape fix improved router correctness vs prior 4/7 to 5/7 accepted router rows (`small/wrap-tail`, `rename/function-name`, `markdown/append-section`, `css/small-edit`, `html/small-edit`). `logging/insert-timer` and `long-section/replace-return` still fail correctness. Of rows with accepted router and accepted core pairs, router loses total context in 4/4. `markdown/append-section` has accepted router evidence but no accepted core baseline after two new core attempts, so excluded from savings. Phase 7 acceptance remains **NO**. No router replacement/core-intercept claim; `pi_blitz_route_edit` remains runtime facade and unsupported fallback remains no-write decline.
