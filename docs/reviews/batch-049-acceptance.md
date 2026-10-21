# Batch 049 acceptance review (PR #18, card Q-20261020-154337-209c)

**Verdict: ACCEPT after R1 and R2 (3ced4d1).** Reviewer: runtime-reviewer. Base: stacked on #17 (e3869bb); merge #16, #17 first.

## Evidence
- `--headless --import` clean. Builder head 281df25 reproduced: logic **5405 passed, 0 failed**.
- After review: logic **5411 passed, 0 failed** (+6 = six new `check.call` lines in `Batch049Checks._review`). 0 SCRIPT ERROR in boot_gate, parse_gate and logic logs (N1).
- Scenarios 031-049 all `SCENARIO PASSED`, 0 FAIL, 0 SCRIPT ERROR; ok counts match the build doc (049: 9; shared_spell_flow 67). downed_area_damage_flow (6 ok) and party_recovery_flow (19 ok) now pass on this stack.
- 9c63252 is on origin/main; `FeatureModeRules.declared_features` rebuilds class+subclass by saved level and is shared by both SaveManager routes. Confirmed.
- ADR-0018: no per-ID branches. One resolver (`OwnedFeatureSources`) with data-driven owners.

## Defects
- **R1: a copy merged into a form, or with its magic suppressed, still activated and granted its mode.** The probe showed a merged circlet activating `ward`, spending a use and granting +1 AC. This violates S-164 (merged copies grant nothing, as 041 R2 fixed for spell permissions and negation) and S-203. Fix: `FeatureModeRules.rule()` returns `{}` for a feature whose `source_instance_id` copy is merged or whose new `features` magic property is suppressed or destroyed (`MagicPropertyRules.PROPERTIES` += `features`). The state is kept and returns when the form or suppression ends. Activation is refused before cost.
- **R2: giving a spent copy away refilled it.** Pools were keyed on the wearer, so the new owner's first acquisition granted the full pool (1 use became 3). Item uses belong to the item. Fix: when `sync` drops a copy's feature, it stamps the pool on `record.state.feature_uses`; on acquisition the stamped value wins (clamped) and is cleared. `OwnedFeatureSources.record_error` is wired into `InventoryCopies.record_state_error`: it accepts only the copy's own namespaced activation pools and whole counts from 0 to 100.

## Stress results
- Same mode id from two sources: the first owner wins and it is listed once (sync `present`). Item ids are namespaced, so they can't collide.
- Forged owner ids, unequipped or unattuned copies in saves: refused (builder checks). A forged `feature_uses` of 99 is clamped to the maximum on load. A forged stamped pool naming another copy is refused (R2 check).
- 038 R1 recheck: `choose_alternative` clamps held uses for every source (generic pool). Covered for item, and feat/species use the same path.
- Give/sell: only backpack copies transfer, and unequip ends the mode first. After R2 the pool travels with the copy. A save/load round trip keeps it.

## Known limits (accepted, not defects)
- No HUD control for modes or alternatives (any source). Feats come only from the species. There's no production path to change species.
- Rest only refills pools that are currently owned. An unowned copy's pool waits until it is worn again.
- Unequipping clears the copy's chosen alternative, so re-equipping goes back to the default option (held uses are never raised).
- No SRD spell content lists `features` in its suppression properties yet. Antimagic-type content must name it.

## Decisions for Brandon
1. Should an unequipped copy keep its chosen alternative (store it on the record like the pool), or reset to the default as it does now?
2. Should existing suppression content (044's suppress_item_magic sources) add `features` to its property list?

## Proposed updates on accept
- Registry: card 209c → done (owned species/feat/item modes and upgrades).
- Checklist: (a) refusal before cost, including merged/suppressed; (b) the new nested state `feature_uses` validated via record_state_error; (c) production callers; (d) real persistence. All pass.
- Checkpoint/roadmap: logic total 5411; scenario list + `batch_049_owned_feature_sources_flow`.
