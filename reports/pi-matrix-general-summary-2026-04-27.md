# Pi matrix general summary — 2026-04-27

Model/provider: `openai-codex/gpt-5.4-mini`
Iterations: 1
Harness output:

- JSON: `reports/pi-matrix-general-2026-04-27.json`
- Markdown: `reports/pi-matrix-general-2026-04-27.md`

## Raw results

| Fixture | Recommended | Core correct | Core output | Core args | Core wall | Blitz correct | Blitz output | Blitz args | Blitz wall |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| small/wrap-tail | core | yes | 94 | 78 | 3,387ms | n/a | n/a | n/a | n/a |
| medium-10k/marker-tail | core | yes | 60 | 44 | 4,815ms | yes | 66 | 45 | 3,106ms |
| medium-10k/wrap-body | blitz | yes | 9,641 | 9,625 | 85,732ms | yes | 91 | 71 | 4,866ms |
| medium-10k/compose-preserve-islands | blitz | no | 157 | 141 | 3,309ms | yes | 242 | 204 | 6,286ms |
| multi/three-body-ops | blitz | no | 161 | 145 | 3,064ms | yes | 340 | 304 | 7,277ms |
| huge-100k/marker-tail | core | yes | 63 | 47 | 6,377ms | yes | 67 | 46 | 17,020ms |

## Pairwise percentages

Positive means Blitz beats core. Negative means Blitz loses.

| Fixture | Output savings | Tool-arg savings | Speed savings | Note |
|---|---:|---:|---:|---|
| medium-10k/marker-tail | -10.0% | -2.3% | +35.5% | Core recommended; Blitz slightly more output but faster this run. |
| medium-10k/wrap-body | +99.1% | +99.3% | +94.3% | Blitz recommended; real structural ROI case. |
| medium-10k/compose-preserve-islands | -54.1% | -44.7% | -90.0% | Core incorrect, so this is correctness win, not savings claim. |
| multi/three-body-ops | -111.2% | -109.7% | -137.5% | Core incorrect, so this is correctness win, not savings claim. Tiny file is bad ROI. |
| huge-100k/marker-tail | -6.3% | +2.1% | -166.9% | Core recommended; simple exact tail edit. |

## Route-aware aggregate: mutually correct comparable rows

Rows included:

- `medium-10k/marker-tail` → core
- `medium-10k/wrap-body` → Blitz
- `huge-100k/marker-tail` → core

This compares recommended route vs opposite lane only where both lanes were correct.

| Metric | Opposite lane total | Recommended route total | Savings |
|---|---:|---:|---:|
| Provider output tokens | 9,774 | 214 | 97.8% |
| Tool arg tokens | 9,716 | 162 | 98.3% |
| Wall time | 105,858ms | 16,058ms | 84.8% |

## Route-aware aggregate vs core-attempt baseline

Includes all rows with a core attempt. Core was wrong on compose and multi-body, so this is a product-routing view rather than pure savings view.

| Metric | Core-attempt total | Route-aware total | Reduction |
|---|---:|---:|---:|
| Provider output tokens | 10,176 | 890 | 91.3% |
| Tool arg tokens | 10,080 | 748 | 92.6% |
| Wall time | 106,684ms | 33,008ms | 69.1% |

## Interpretation

Blitz is not universally cheaper.

- Tiny/simple exact text edits should route to core.
- Large structural body wraps are where Blitz gives extreme token and speed savings.
- Compose and multi-body currently show correctness advantage, not token advantage, on the tested fixtures.
- Tiny multi-edit is bad ROI because structured JSON overhead is larger than a small core edit payload.

Next benchmark should add a large multi-body case: one medium/large body wrap plus 1–2 small sibling edits. That is the realistic ROI target for `pi_blitz_multi_body`.
