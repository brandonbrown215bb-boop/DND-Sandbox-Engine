# Batch 059 acceptance (runtime-reviewer)

Verdict: ACCEPT after R1 (7aa585a). Head reviewed: d8b720f (stacked on #30 ebad83a).

## Runs (worktree /tmp/rev_wt059, imported twice)
- Logic suite: 5573/0 at d8b720f (matches the builder). 5576/0 after R1 (+3: the R1 regression plus 2 stress tests).
- Scenarios 031-059, one at a time: 29/29 SCENARIO PASSED.
- N1: 0 SCRIPT ERROR across logic and scenario logs.

## Checks
- Finish line ("...the spell still works and creates as many as it can"): met. `_capped` clamps to min(slot, remains). A fixed count above the cap becomes the cap.
- Zero-target ruling: correct. SRD Animate Dead requires a chosen pile of bones or corpse, so with zero remains the spell has no legal target. The refusal happens in `choose_factory`, before placement and payment. Per-kind shortfalls are refused in `_choose_mix` and `mix_cap_error`, also before payment.
- Consume hook (SpellCastResults): runs only when `successful and not interrupted`. Refused or cancelled casts consume nothing. It re-scans `eligible`, so used bodies cannot be consumed twice (stress-tested).
- Eligibility: used party corpses (`transformed_undead`), corpses protected from undeath, monster bodies with `material_used`, living creatures, and wrong type, size or remains are all excluded. The range edge is inclusive and +1 is excluded (stress-tested).
- ADR-0018: no spell or creature ID branches. The tags, range, types, sizes and kinds all come from data.
- Legacy: an absent key means no cap (058 unchanged). Monster entries default to `is_alive` true. The saved corpse restriction already exists, so no save-format change.
- `material_used` lives on per-encounter monster dicts, so it resets with the encounter.
- Incapacitated caster: unchanged existing cast gating. Nothing new here.

## Defects
- R1 (7aa585a): `consume` filled kinds in mix order. An undeclared (any-tag) kind listed first could take the only bones a declared Skeleton needed. The creature was still created, `used` came back short, and a valid corpse was left unconsumed. Fixed by sorting so tagged kinds claim first. Regression test added.

## Known limit (not fixed)
- Consume uses the factory count before `attach_created_actors`. If placement ever places fewer creatures than the count, bodies would be over-consumed. Today 053 placement is all-or-nothing, so this is latent only.

## Decisions for Brandon
- Should the player pick which corpse is used, instead of the nearest one being used automatically?
- Is it OK that party corpses used this way are permanently `transformed_undead` (this blocks later revival rules)?
