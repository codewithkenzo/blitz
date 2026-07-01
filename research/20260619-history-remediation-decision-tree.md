# Research: Safe history remediation for removing contributor command-code or problematic code from pushed Git history/releases

## Question
How to choose between revert and history purge, what are GitHub-safe workflows, and what strict preconditions must be met before taking action on pushed history, release tags, and published artifacts?

## Answer / Recommendation
- Default path is **revert** (forward-safe) for non-secret bad code already published: create follow-up commits that undo behavior, keep audit trail, avoid branch rewriting risks.
- **Purge** (rewrite + force-push) only when secret/credential/policy requirements demand historical material be unreachable from server copy and cache surfaces, and when all stakeholders can execute coordinated cleanup.
- If GitHub release tag is immutable, or npm package is already published, prefer **non-destructive remediation** (new release/republish + deprecation/withdrawal) over historical purge of tags/releases.

Decision in short:
- **Need immediate secret hardening** → rotate credentials first, then evaluate purge path only if secret is actually in persistent history.
- **Need code behavior rollback only** → use `git revert` chain.
- **Published immutable artifacts exist** → cannot safely erase; publish fixed replacement artifact and remove discoverability.

## Findings
### A) Revert-first policy for most incidents (safe default)
- `git revert` is for recording new commits that reverse prior commits; it does **not** remove existing commits from history, preserving collaboration safety and allowing timeline integrity.
  - Source: Git docs (`git-revert`) “revert the changes ... and record some new commits”.【https://git-scm.com/docs/git-revert.html】
- GitHub’s sensitive-removal doc frames revocation first: rotate/revoke tokens; if revocation solves risk, rewrite may be unnecessary.
  - Source: “If the sensitive data is a secret… rotate/ revoke first.”【https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository】

### B) Purge path is destructive and requires coordinated infrastructure
- GitHub explicitly warns rewrites have high coordination risk: collaborator work loss, recontamination via `git pull && git push`, broken PR diff context, lost hashes/signatures, and impossible cleanup if old clones keep old refs/caches.
  - Source: GitHub “Side effects of rewriting history” + recontamination notes.【https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository】
- `git-filter-repo` is purpose-built for history rewrite and includes explicit first-commit and changed-refs reports used for coordination and cleanup.
  - Source: GitHub docs + `git-filter-repo --sensitive-data-removal` + filter-repo output artifacts (`first-changed-commits`, `changed-refs`).【https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository】【https://github.com/newren/git-filter-repo/blob/main/Documentation/git-filter-repo.txt】
- GitHub recommends for sensitive-data cleanups: rewrite locally, force push all refs, force push affected teammates’ environments; then support-guided GitHub-side purge of cached refs/views.
  - Source: “Fully removing the data from GitHub” + support workflow with PR/GC cleanup and cache removal.【https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository】
- `git push --mirror` updates all refs and removes missing refs on remote; it is effectively force-update + prune for all refs and dangerous without explicit preconditions.
  - Source: `git push --mirror` description (push all refs, update/fc, remove deleted refs).【https://git-scm.com/docs/git-push.html】
- `--force-with-lease` is safer than raw `--force` because it checks expected remote state; raw `--force` can clobber others’ work.
  - Source: git push docs `--force-with-lease` vs `--force` semantics.【https://git-scm.com/docs/git-push.html】

### C) Branch protections and release/package surfaces can block/reshape choices
- GitHub protected branches block force pushes by default and allow explicit force-push bypass config.
  - Source: “about protected branches… By default, each branch protection rule disables force pushes...” and “Allow force pushes” setting.【https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches】
- GitHub API branch protection has explicit `allow_force_pushes`, `allow_deletions`, etc.; must be set to permit destructive rewrite/update.
  - Source: REST branch protection payload fields in docs endpoint.【https://docs.github.com/en/rest/branches/branch-protection】
- GitHub releases: if immutable releases are enabled, tags become locked and release assets cannot be modified/deleted while release exists; deleting release still needs special sequencing and some effects are constrained.
  - Source: Immutable releases docs.【https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases】
- GitHub release notes can contain contributor mentions; immutable releases may only allow limited edits post-publish.
  - Source: release management notes + immutable editing note.【https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#editing-a-release】【https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases】
- npm registry is immutable-by-design for exact version objects; `npm unpublish` removes entries, same name/version can never be reused; even full package unpublish has cooldown and governance constraints.
  - Source: npm unpublish policy + CLI docs.【https://docs.npmjs.com/policies/unpublish】【https://docs.npmjs.com/cli/v11/commands/npm-unpublish】
- For non-secrets in npm packages, deprecate instead of purge when you just need to stop consumer use.
  - Source: `npm deprecate` warns it only marks package with warning; `npm unpublish` docs recommend deprecate when intent is upgrade/warn rather than full removal.【https://docs.npmjs.com/cli/v11/commands/npm-deprecate】【https://docs.npmjs.com/cli/v11/commands/npm-unpublish】

### D) GitHub source-of-truth implications
- Even after server force push, old SHAs can remain reachable from forks/PR refs/caches unless those surfaces are explicitly cleaned; GitHub notes this and points to support for PR cache removal.
  - Source: “If commit exists in forks/PRs/CAS, you cannot remove from all users by local rewrite alone.”【https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository】
- `git push --delete`/empty ref deletion works for refs, but only within what refs are still discoverable and permitted by permissions/hook config.
  - Source: git push docs deletion semantics (`--delete`, empty src deletes ref).【https://git-scm.com/docs/git-push.html】

## Source Notes (kept / dropped)
### Kept
- Official primary docs: GitHub sensitive-data removal, protected branches, immutable releases, release mgmt.
- Official Git docs: `git-revert`, `git-push`, `git-filter-repo` manual/source.
- Official npm docs: policies + `npm-unpublish`, `npm-deprecate`.

### Dropped
- StackOverflow/tutorial snippets used only for corroboration, not as primary policy basis.
- Community/marketing discussions on “how to delete tags” not used as authority for decisioning.

## Version / Date Notes
- Repo/stack context: current date 2026-06-19. Docs fetched from current GitHub/npm/docs endpoints and `git` docs snapshot in tool output.
- Behavior may vary by enterprise plan (branch rules/rulesets), webhook hooks, and repo permissions.

## Open Questions
- Is any public fork containing the bad commit still active or used in CI/distribution pipelines? (required if purge path attempted).
- Are any immutable releases/artifacts currently anchored to the suspect SHAs? (blocks classic purge).
- Is problematic content a credential (needs immediate invalidate) vs compliance-only historical concern.
- Legal/compliance review on attribution removal (DCO/NOTICE/COPYRIGHT) for rewritten vs reverted history before action.

## Builder-Ready Implications
1. Add decision gate: if no secret/data-leak requirement -> `git revert`; block purge.
2. If purge required, gate on:
   - secret revoked, collaborators frozen, all required permissions (force push + branch protection bypass + maintainer approvals) confirmed,
   - full surface inventory (branches, tags, PRs, forks, release refs, npm packages),
   - backup and dry-run verification.
3. Preflight checklist (hard requirements before action):
   - fresh clone for filter run, identify first changed commit set,
   - stop all development; no local-only uncommitted work on source,
   - disable/relax protected-branch force restrictions temporarily with explicit approval,
   - coordinate external artifact plan (immutable release/npm).
4. Post-action: force push refs intentionally with `--force-with-lease` when feasible, verify `git cat-file -t <first_changed>` fatal on all collaborators’ clean environments, run GitHub cleanup/support path for PR cache and orphaned refs, then rotate audit logs/secrets and monitor.
