# Batch 085 acceptance review (PR #58): S-126/S-140 cast-local transformations

Reviewer: Runtime Reviewer. Head reviewed: 05cbe95, stacked on #57 (54074d6). Card Q-20261026-050635-4cf2.
The finish line was judged as quoted by the builder in `docs/reviews/batch-085-build.md`. It is a builder-quoted ruling; I did not see Brandon's original message.

## Verdict: ACCEPT (PARTIAL as declared), with two reviewer fixes

## Reviewer fixes
1. **Load validation silently accepted unknown keys.** A scope typo such as `"school": [...]` instead of `"schools"` was ignored, which widened the profile to *every* spell. An unknown operation such as `"multiply"` was dropped without an error. `validate_rule` now refuses unknown scope keys (`SCOPE_KEYS`) and unknown rule fields (`RULE_KEYS`; generic feature metadata and `_`-prefixed keys are allowed). I added three malformed cases to `batch_085_checks.gd`: `scope_typo`, `unknown_op` and `replace_unknown`. All existing data (14 attack_profile features) still loads.
2. **Ignored conflicts were only in memory.** `_cast_profile.ignored` was recorded, but the player never saw it. `SpellCastSelection.choose` now logs each ignored change.

## Findings
1. **apply_cast:** the first replace of a field wins, and later ones are recorded as ignored (now also logged). Scope is judged on inherited fields: `_spell_qualifies` reads `_cast_profile.inherited`, and the school is only rewritten after the loop. The abjuration-scoped save-DC source does not qualify off another source's school change, which is checked. Applying again to a copy that already carries `_cast_profile` changes nothing. `replace` is limited to range, school and timing, `add` sums range, and `remove` unions V and S. Malformed types are refused at load (10 builder cases plus my 3).
2. **Production caller:** `apply_cast` runs once in `choose` after the payment-availability check and before targeting. Payment happens later on the transformed copy. In the HUD scenario, the refused bonus-action cast left the slot and the Action unspent, and the out-of-range Ray of Frost was refused with nothing spent. Both are asserted by counts, and the scenario passes. Quickened Spell sees the transformed `casting_time`, so it is not offered for an already-Bonus-Action cast, and Sorcery Points can't be double-charged.
3. **Wand copy:** `duplicate(true)` is a deep copy. The catalog equality checks pass after wand and slot casts. I grepped every `var x := DataLoader.get_*(...)` in non-test `src`, looking for writes in the following 60 lines. The only two hits are in `viewport_harness.gd`, and both are already deep copies. I found no other live catalog mutation.
4. **Bounds are enforced in code, not just documented:**
   - Only `choose` calls `apply_cast`, so monster casts and reaction casts never see a transform.
   - Reaction-only spells are refused before `apply_cast`.
   - `casting_time` is changed only when the catalog value is action or bonus action.
   - Removing M is refused at load.
   - Item activations are skipped.
   - No half-application path exists.
- **ADR-0018:** the diff has no spell or wand id branches. The wand line uses the pre-existing `magic_missile` lookup in `combat_command.gd`, not a new one.
- **Save:** effect records store `spell_id`, not the spell dict. The check confirms `to_dict()` has no `_cast_profile`. Because the save format is unchanged, old saves are unaffected. I did not load a real old save.

## Evidence
- Imported twice, with no SCRIPT, Parse or Compile errors.
- Logic: head 6380/0, and 6383/0 with the reviewer fixes.
- Scenarios after the fixes, run one at a time, all pass:
  - batch_085_cast_transform_flow
  - wand_magic_missiles_flow
  - wand_last_charge_destruction_flow
  - spell_cast_stage_flow
  - batch_077_per_swing_choice_flow
  - batch_067_weapon_damage_choice_flow
  - sorcerer_subtle_spell (failed once on the Invisible-caster Counterspell line, then passed on rerun and passed at 05cbe95, so it is flaky and unrelated)
- **Base comparison:**
  - wizard_capstone_cast_modes: the [FAIL] line is identical at base and head (1 line).
  - sorcerer_twinned_spell: this is **not identical**, which corrects the builder's claim. Base fails 5 lines, twice. Head fails 4, the same lines minus "selecting a second humanoid resolves the twinned cast". So it is not a regression.

## Open decisions for Brandon
- Should a transform that doesn't apply (range on a Touch or Self spell, or timing on a reaction spell) also be recorded and logged as ignored? Right now it is skipped silently.
- Should S-141 (duration and concentration) be the next card?

## Proposed count updates
- Logic count: 6383.
- S-126 and S-140: PARTIAL (batch 085 bound).
