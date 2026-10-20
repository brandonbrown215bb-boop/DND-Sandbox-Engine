# Batch 039 review: parameterized created actor (S-154) and maximum-HP zero death (S-131)

Independent review by Runtime Reviewer on 2026-10-20 of PR #7 (`batch-039-s154-s131`). The head is `7915c10` on 038 at `fe53898` (verified ancestor). Reviewer commits are `6da5dfc` (stress cases) and `eec3e3d` (R1).

**Recommendation: ACCEPT after R1.** This is reviewer evidence; counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| R1 | Defect | `CreatedActorRules._live` caches built actors by `actor_id` only. An in-session `SaveManager.load_game` builds a new owner with the same id and the same source ids, so `actors()` returned the **pre-load cached actor**: damage taken after the save survived the load, and a warden killed after the save stayed dead. Reproduced in logic (RX1 saved=15, got 8; RX2) and through the real save/load in the scenario once its `_live.clear()` test shortcut is removed (expected 17, got 13). | Fixed in `eec3e3d`. Each actor records its owner's instance id, and `actors()` rebuilds from the owner's record when the owner object differs. The scenario now damages the live warden after the save and loads with no cache clear. |
| F1 | Known limit (builder weak spot 1) | Removing a source record and re-adding the same record without `sync` loses the live HP. Production cannot reach this. Records leave only through end of source (concentration end), and a recast mints a new source id with fresh actors (RX5). Party dismiss/recruit keeps the owner object, so the cache stays correct (RX4). Save/load was the real path, and R1 fixes it. | Documented |
| F2 | Known limit (builder weak spot 2) | SRD 5.2.1 says a creature whose HP maximum drops to 0 dies. Zero-limit death is implemented only on `Character` `max_hp_sources`. Monster dicts carry no maximum-HP sources at all, which is the existing S-130 boundary, so a withering attack on a monster cannot occur in this engine yet. Created actors are `Character`s and die correctly (RX6). | Carry to the monster max-HP source slice; not a blocker for S-131's finish line |
| F3 | Checked (builder weak spot 3) | The logic helper sets `concentrating_on` by hand. The scenario casts through the actual HUD, and concentration is set by the combat pipeline. After a real reload, `SpellEffects.end_concentration` removes the warden. RX5 adds a logic check: the real end path removes both the record and the actors, and a recast is fresh (slot 3: count 2, max HP 30). | OK |
| F4 | Checked (builder weak spot 4) | S-131 depends on S-130 (PR #2, R1 re-derivation) and S-119 (PR #1, creature_type R1 plus the child-damage fix), and both are reviewed. RX7 adds an increase plus a zero-limit, removed in either order: 15, then 10 or 25, then 20, with no drift. RX7b applies a floor-clamped drain, then a zero-limit, which gives 0 and death. Removing the drain re-derives to 16 and does not revive. | OK |
| N1 | Checked | 0 `SCRIPT ERROR` in every run. The totals reconcile: 5013 + 37 (builder) = 5050, then + 11 (review) = 5061. The 035–038 review suites pass. | OK |

## Stress cases (`Batch039Checks.review_stress`, 11 assertions)

- **RX1/RX2:** reloading into a new owner object rebuilds from the saved record. Damage or death after the save does not leak (failed before R1).
- **RX3:** the rebuilt actor stays linked to the owner id.
- **RX4:** the same owner object keeps its live actor and HP.
- **RX5:** a real concentration end removes the record and the actors. A recast at a higher slot creates fresh actors.
- **RX6:** a zero-limit reduction on a created actor kills it rather than downing it.
- **RX7/RX7b:** zero-limit combined with S-130 re-derivation (removal order, floor clamp).

## Runs on `eec3e3d`

| Run | Result |
|---|---|
| import | 0 |
| logic | 5061 passed, 0 failed, 0 SCRIPT ERROR |
| 021 / 029 / 031 / 032 / 033 / 034 / 035 / 036 / 037 / 038 / 039 | 21 / 37 / 25 / 33 / 70 / 10 / 9 / 7 / 11 / 7 / 10 ok, 0 failed |
| shared_spell_flow | 67 ok, 0 failed |
| downed_area_damage_flow / party_recovery_flow | 1 / 2 failures, identical to main |

## Proposed registry change (on owner acceptance)

- S-154 becomes `Verified (VS-123; source-linked template actor with owner identity)`, P6 (+1).
- S-131 becomes `Verified (VS-124; zero-maximum death with source remains)`, P4 (+1).
- Counts: **124/226 accepted; 102 remain**.
