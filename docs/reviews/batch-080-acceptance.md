# Batch 080 acceptance — S-060/S-203 per-item last-charge outcomes (PR #53)

Reviewer: runtime-reviewer. Head reviewed: 64ef7cb. Judged against Brandon's ruling **as quoted by the builder** in the PR (original not seen).

**Verdict: ACCEPT (PARTIAL as declared). No code fixes.**

## Evidence
- Import x2 headless; logic suite 6295 passed / 0 failed; no SCRIPT/Parse errors.
- Scenarios (one at a time, all PASSED, 0 errors): batch_080_last_charge_text_flow, batch_080_last_charge_text_reload, batch_072_last_charge_flow, batch_072_last_charge_reload, wand_last_charge_destruction_flow, batch_078_declared_capacity_flow, batch_067_weapon_damage_choice_flow. Full scenario set not run.
- SRD 5.2.1 (from memory; no PDF, p.246 unconfirmed): Staff of Power +2 atk/dmg, +2 AC, 20 charges, 2d8+4 dawn (range 6–20), d20=1 on last charge keeps the +2 atk/dmg and loses everything else — matches. Staff of Striking +3, 10 charges, 1d6+4 (5–10), d20=1 → nonmagical — matches. Nothing invented.
- ADR-0018: staff ids appear only in src/batch_080_checks.gd (tests). No per-ID branches in code.
- Attunement partial: an attuned copy that went nonmagical grants nothing — `LastChargeRules.lost()` returns true for every property on a nonmagical copy, so `active()` gates weapon_bonus/source_benefits/features off; check 082 confirms 0 on a real attack while still attuned. Partial acceptable.
- Batch 072 holds: drained/nonmagical copy refuses attunement; a second copy of the same id still attunes (no cross-copy leak); nonmagical copy regains no charges at dawn.
- Refusals: degrade without keep_properties, conversion keys, unknown outcome, unknown keys, keep_properties on nonmagical, malformed/mundane weapon_bonus — all refused. Zero charges without a declared aftermath keeps the bonus.
- Legacy: legacy_charge_state "full" restores 20; items without it still refuse; tampered magical flag refused.

## Proposed counts
Logic 6270 → 6295.

## Open for Brandon
- End existing attunement when a copy goes nonmagical (currently harmless: grants nothing, but occupies an attunement slot).
- Dawn regain is uniform min..max, not dice-shaped (2d8+4 / 1d6+4).
- Staff of Power's d20=20 regain, +2 saves/spell attacks, spells and Retributive Strike: cards?
