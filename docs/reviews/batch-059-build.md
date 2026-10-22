# Batch 059 build: S-155 corpse-limited summon count

Card Q-20261021-140434-ff8e. Stacked on #30 (batch-058-summon-lists @ ebad83a, accepted by Runtime Reviewer, not merged), because #25-#30 are still open and this edits the 058 factory code.

## Finish line (Brandon, verbatim)
"Animate Dead's creature count scales with the spell slot used. If there aren't enough corpses or bones nearby to match that slot, the spell still works and creates as many as it can."

## Design
- **Slot scaling (verified, unchanged).** The existing `mix.count` formula (base 1, per_level 2) gives 1 at 3rd, 3 at 4th, 5 at 5th, 13 at 9th. Logic asserts it.
- **`material_targets` (new, optional) on `create_actor`.** Example: `{"tags": ["bones", "corpse"], "range": 2, "creature_types": ["humanoid"], "sizes": ["small", "medium"], "kinds": {"b059_skeleton": "bones", "b059_zombie": "corpse"}}`.
  - `tags`: corpse and/or bones. Remains `intact`/`partial` count as corpse, and `bones` as bones. Dust and destroyed remains never count.
  - `range`: hexes from the caster (2 = 10 ft).
  - `creature_types`/`sizes`: optional filters. `kinds`: optional, maps a declared template to the tag it needs, so bones become a Skeleton and a corpse a Zombie.
  - The loader (`MaterialTargetRules.error`) refuses unknown keys, unknown tags, a bad range, unknown types or sizes, and kinds naming undeclared templates or tags. No per-ID branches: everything comes from JSON (ADR-0018).
- **Eligible targets.** Dead party Characters (corpse_state, not `transformed_undead`, not under Gentle Repose) and dead combat monsters (`is_alive` false, not `material_used`) within range.
- **Cap.** `choose_factory` (before placement and payment) computes `MaterialTargetRules.cap`. The mix total is capped at min(slot count, available), and each kind is capped by its own tag's count. A fixed count above the cap becomes the cap. The cast still succeeds with fewer creatures.
- **Zero targets: refuse before paying.** SRD 5.2.1 Animate Dead: "Choose a pile of bones or a corpse of a Medium or Small Humanoid within range." With no eligible remains there is no legal target, so the cast is refused with "There are no eligible remains within range; nothing was spent." The scenario asserts the slot is unspent. The "creates as many as it can" ruling covers 1..N-1 remains, not zero.
- **Consumption.** SRD 5.2.1 Animate Dead (Using a Higher-Level Spell Slot): "Each of the creatures must come from a different corpse or pile of bones." After a successful cast, `MaterialTargetRules.consume` (called from `SpellCastResults`) uses one nearest matching body per creature.
  - A party corpse gets the existing saved `transformed_undead` restriction (already validated by `CorpseRules.saved_error`).
  - A monster body gets `material_used` on its combat entity.
  - Used bodies stop counting, and the scenario asserts a recast is refused.

## Checklist
- (a) Refuse before paying. Zero remains, and remains already used, are refused in a real HUD cast with the 4th-level slot unspent. A kind with no remains can't be chosen. Cancel and stale answers keep the 054/058 paths.
- (b) No new saved record or field. Party corpses reuse the saved `transformed_undead` restriction, and logic asserts `CorpseRules.saved_error` still passes. These are not inventory copies, so `record_state_error` does not apply. The monster flag is transient combat state.
- (c) Production callers:
  - `SharedSpell.content_error` → `MaterialTargetRules.error`
  - `choose_factory`/`_choose_mix` → `cap`, `mix_cap_error`, `_capped`
  - `SpellCastResults` → `consume` → `eligible`/`_tag`/`spec`
- (d) Real `SaveManager.save_game`/`load_game` after the capped cast rebuilds "Skeleton 1/14". No cache clearing.
- (e) Merged/suppressed item gate: not relevant. There are no item-granted effects.
- Legacy: effects without `material_targets` are uncapped (asserted). All 054/058 scenarios pass unchanged. No save format change.

## Counts
- Baseline: #30 (reviewer acceptance at 9794b7c; ebad83a adds only the acceptance doc): 5562/0.
- Branch (imported twice): logic 5573 passed, 0 failed (+11, all 059).
- Scenarios 031-059, one at a time: 29/29 SCENARIO PASSED.
- 0 SCRIPT/Parse/Compile errors in all logs.

## Limits
- Monster bodies are marked used only on the combat entity. Consumption does not outlast the encounter, because dead monsters are not world remains after combat. Party corpses are marked permanently.
- Authored room `remains` objects (the Crown Animate Dead path in `CreatedCreatureRules.animate`) are not read by the shared combat path. That path remains single-body.
- Only `corpse` and `bones` tags exist. Other material kinds would need new tags.
- No core Animate Dead spell is added (fixture `fixture:b059_animate_remains` only). The fixture omits Animate Dead's 1-minute casting time.
- Mixed-size summons are not supported: mixed templates must still share one size and command policy (058). Documented only, no card.
- Find Familiar's creature-type choice (Celestial/Fey/Fiend) has no building block. Documented only, no card.
