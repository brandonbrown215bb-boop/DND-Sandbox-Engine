# Batch 047 acceptance review (PR #16, card Q-20261020-173959-7e2c)

Reviewer: Runtime Reviewer. Head reviewed: 86d7f31 on main 10f9bd3 (not stacked). Worktree /tmp/rev_wt047.

## Verdict: ACCEPT. No defects found, no review commits to runtime code.

## Evidence (Godot 4.7.2, runs strictly one at a time)
- Import clean. Logic suite: **5367 passed, 0 failed**, 0 SCRIPT ERROR. Baseline 5362 + 5 new `check.call` lines in batch_047_checks.gd = 5367. Reconciled (N1).
- Scenarios 031-047 all print SCENARIO PASSED, 0 SCRIPT ERROR. [ok] counts: 031 25, 032 33, 033 70, 034 10, 035 9, 036 7, 037 11, 038 7, 039 10, 040 12, 041 10, 042 10, 043 11, 044 12, 045 16, 046 16, 047 10. Matches the build doc.

## Checks
- **ADR-0018:** no per-ID branches. Options come from the shared `actor_projection` effect's declared `forms`/`equipment` via `projection_options`; labels are a policy-keyed table, not spell IDs.
- **Refusal before cost:** `choose_projection_options` runs in `validate_and_choose` before `validate_actor` and before `commit_spell_resource`/Action spend. Cancel, closed popup, out-of-list answer, superseded serial and failed `commit_guard` all return false before cost. Scenario asserts slot + Action unspent and no projection for each. Picks are written to the cast's own spell copy only; DataLoader content asserted unmutated.
- **Headless/defence in depth:** with no HUD a multi-option cast refuses; `ActorProjectionRules.cast_error` still refuses missing or undeclared picks (logic check 5), so the HUD chooser is not the only gate.
- **040/041 edits:** the old assertions guarded "HUD refuses multi-option cast with no choice". That behaviour is exactly what the card removes. Both scenarios keep the same post-condition (unprojected, slot unspent, AC/copies unchanged) via chooser-cancel, and the underlying `cast_error` refusal is covered in logic check 5. The lost line was the shared 036 helper's "cast finishes" check; 047 scenario step 1 asserts `_cast_in_progress` is cleared after cancel. No refusal coverage lost; nothing restored.
- **041 R4 legacy equip() block during a form:** still asserted and passing in 041.
- **Legacy saves:** no new record or save field. Real save/load of a chosen Boar/merged projection round-trips.

## Notes (not blocking)
- The chooser opens before `validate_actor`, so a cast that `validate_actor` will refuse for another reason (unsupported content, lost permission) asks for a form first, then refuses. Nothing is spent; it is UX only. Incapacitated/no-slot casters are stopped earlier by the HUD.
- The stale-popup scenario forces `_cast_in_progress = false` to open a second chooser; in normal play that guard prevents a second cast, so the serial check is defence in depth.

## Proposed bookkeeping on merge
Card 7e2c to done; registry/checkpoint/roadmap: logic total 5367, scenario list +batch_047_form_equipment_chooser_flow.
