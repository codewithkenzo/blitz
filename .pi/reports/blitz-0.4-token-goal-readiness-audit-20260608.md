# Blitz 0.4 Token/Core Goal Readiness Audit — Fix Closeout

Date: 2026-06-08
Branch audited: `main`
Scope: docs/spec/goal handoff readiness before a long-running Blitz 0.4 implementation goal.

## Verdict

PASS AFTER FIXES.

Independent reviewer returned PASS WITH FIXES. The required fixes were applied to `.pi/docs/plans/PLAN-0.4-context-token-optimization.md` and `.pi/docs/plans/START-0.4-context-token-core.md`.

The project direction is token-efficiency driven and research-backed. It does not claim universal savings. It defines a required course of action: exact context/token measurement, resident tool/skill/schema reduction, explicit cross-repo profile work in `pi-blitz`, runtime route integration, then proof or rejection with real Pi/Tokscale evidence.

## Reviewer findings closed

### 1. First-slice contract contradiction

Closed.

Docs now state the first slice is **only Phase 0 + Phase 1**:

- exact measurement harness
- raw accounting artifacts
- profile registration
- existing 12-pair matrix against core/current/profile variants

`pi_blitz_op`, compact IR, and router-selected replacement claims are explicitly Phase 2/6 work, not first-slice acceptance.

### 2. Exact schema/skill accounting

Closed.

Docs now require:

- Pi-serialized registered tool specs per profile
- exact token count for serialized specs
- exact resident skill text used by run
- exact token count for resident skill text
- tokenizer/model metadata
- Tokscale/session JSON
- residual reconciliation with provider/Tokscale input/cache totals
- raw artifact preservation

Chars/4 and rough estimates are explicitly banned for acceptance claims.

### 3. Cross-repo `pi-blitz` execution

Closed.

Docs now define companion repo execution:

- repo: `/home/kenzo/dev/pi-blitz`
- branch: `feat/blitz-0.4-token-core-profile`
- allowed scope
- forbidden scope
- preflight files
- required checks
- package/install path reporting
- final handoff requiring both repo commits/branches/checks when both are touched

### 4. Runtime router integration point

Closed.

Docs now require runtime integration before core-replacement claims. Benchmark-only routing is insufficient. Acceptable integration points are:

- Pi extension facade
- core-tool wrapper/alias
- skill-level route contract with enforced profile selection
- or explicit documented temporary benchmark-only boundary until a named follow-up phase

## Automated validation

Regression scan confirmed required terms are present:

- first slice does not require `pi_blitz_op`
- `minimal-v0` distinction exists
- exact accounting method exists
- cross-repo execution exists
- runtime router boundary exists

Risky universal-savings claim scan found no banned universal claims in:

- `AGENTS.md`
- `.pi/docs/blitz.md`
- `.pi/docs/plans/PLAN-0.4-context-token-optimization.md`
- `.pi/docs/plans/START-0.4-context-token-core.md`

## Remaining guardrails for next goal

1. Do Phase 0 measurement before broad implementation.
2. Do not use `allowed_tools` as a fake profile if full schemas remain resident.
3. Include losing rows in first report.
4. Treat simple both-correct rows as the core-replacement gate.
5. Do not claim savings without correctness + Tokscale/accounting proof.
6. Do not let routing remain benchmark-only past Phase 6.

## Related report

Independent reviewer report:

- `.pi/reports/reviewer-blitz-0.4-token-goal-docs-audit.md`
