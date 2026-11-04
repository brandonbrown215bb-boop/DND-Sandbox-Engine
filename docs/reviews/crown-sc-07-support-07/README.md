# SC-07 support 07 — deterministic Chill Touch miss check

Stacked on `codex/crown-spells-sc-07-support-06` (#103). Test-only; no runtime or data change; no CSV row changes.

## Cause
`Chill Touch applies no healing restriction on a miss` (from #86) reused one AC-1000 target across up to 40 `resolve_spell` attempts. A natural 20 still hits, and `resolve_spell` applies the healing restriction on that hit, so a crit before the first miss left the target restricted (~5% per run).

## Fix
`src/test_runner.gd`: each attempt uses a fresh target; only the target that was actually missed is checked, and the assert now also requires that a miss occurred. Remaining failure chance is 40 consecutive natural 20s (≈1e-52).

## Proof
`logic.log`: 6936 passed, 0 failed.
