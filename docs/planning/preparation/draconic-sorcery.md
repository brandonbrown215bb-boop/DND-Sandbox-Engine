# Draconic Sorcery preparation — Sorcerer levels 3–5 (G6)

Preparation only (assignment G6 in [crown-parallel-work.md](../crown-parallel-work.md)).
Base: `origin/main` `bd54fa5`, 2026-11-01. This source map is **not acceptance**,
adds no runtime content, and the [candidate record](draconic-sorcery.candidate.json)
sits outside `data/core`/`data/mods`, so DataLoader never reads it. It contains no
enabled placeholder, no class-ID branch and nothing from level 6 up.

## Pinned SRD 5.2.1 clauses

Source: `SRD_CC_v5.2.1.pdf`, page numbers are the printed/PDF pages.

| Clause | Page | Exact text |
|---|---|---|
| Draconic Resilience (HP) | p.69 | "Level 3: Draconic Resilience. The magic in your body manifests physical traits of your draconic gift. Your Hit Point maximum increases by 3, and it increases by 1 whenever you gain another Sorcerer level." |
| Draconic Resilience (AC) | p.69 | "Parts of you are also covered by dragon-like scales. While you aren't wearing armor, your base Armor Class equals 10 plus your Dexterity and Charisma modifiers." |
| Draconic Spells | p.70 | "Level 3: Draconic Spells. When you reach a Sorcerer level specified in the Draconic Spells table, you thereafter always have the listed spells prepared." |
| Draconic Spells table (in band) | p.70 | Sorcerer level 3: Alter Self, Chromatic Orb, Command, Dragon's Breath. Level 5: Fear, Fly. (Rows 7 and 9 are out of band and omitted.) |

Supporting rules used for the mapping:

| Rule | Page | Exact text |
|---|---|---|
| Only One Base AC | p.7 | "A character with multiple features that give different ways to calculate AC must choose which one to use; only one base calculation can be in effect for a creature." |
| Rules Glossary, Armor Class | p.177 | "If a rule gives you another base AC calculation, you choose which calculation to use; you can't use more than one." |
| Armor Training | p.92 | "Anyone can don armor or hold a Shield…" / "You gain the Armor Class benefit of a Shield only if you have training with it." |

Draconic Resilience conditions only on armor (compare Monk Unarmored Defense p.50, "aren't wearing
armor or wielding a Shield"), so holding a Shield does not end the Draconic base;
the Shield's +2 then applies only with Shield training, which Sorcerer lacks.

## Owner mapping

| Clause | Current owner | Fit | Candidate declaration |
|---|---|---|---|
| Base AC 10 + DEX + CHA while not wearing armor | `Character._equipment_base_ac` via `unarmored_defense` effect (`ability`, `allows_shield`); S-085 `RuleUpgradeRules.base_ac_formula` alternatives | Formula fits (`ability: "CHA"`); armor test is `inventory.get_armor().is_empty()`; Mage Armor already takes `maxi` with any better unarmored base | `{"type":"unarmored_defense","ability":"CHA","allows_shield":true}` |
| HP max +3 at grant, +1 per later Sorcerer level | **None.** `PermanentProgressionRules` `max_hp_delta` is fixed, opt-in `permanent_progression` only and rejects subclasses; `MaxHpSourceRules` (S-130) is a reversible fixed-amount effect host | Missing consumer (V-026, "C-Draconic: per-Sorcerer-level HP") | Recorded as `unmapped_clauses`; no fake effect |
| Always prepared, split by level | `always_prepared_spells` → `Character._append_always_prepared_spells` (creation and `level_up`), `SpellPermissionRules`; same split as `fiend_patron` (`fiend_spells_3`/`fiend_spells_5`) | Fits; Command is off the Sorcerer list and is granted by source exactly as Fiend grants it | `draconic_sorcery_draconic_spells_3`, `draconic_sorcery_draconic_spells_5` |

All six spell IDs resolve in production (`alter_self` L2, `chromatic_orb` L1,
`command` L1, `dragons_breath` L2, `fear` L3, `fly` L3). Per the
[content scope spell table](../crown-content-scope.md), only Alter Self, Command
and Fly are currently cast-available; Chromatic Orb, Dragon's Breath and Fear are
refused. Preparation does not change that.

## AC-host limits and gaps found

1. **Shield training is not checked.** `_equipment_base_ac` adds a Shield's
   `ac_bonus` whenever one is equipped. Probe: Draconic fixture, DEX 14 / CHA 16,
   Shield held, no Shield training → AC 17; SRD p.92 gives 15. This affects every
   untrained Shield user, not only Draconic; it needs a generic training check.
2. **No base-AC choice.** `get_feature_effect("unarmored_defense")` returns the
   first matching effect. With two sources (e.g. a future Monk/Barbarian
   multiclass) the host neither offers the p.7 choice nor picks the better base.
   Not reachable today (production multiclassing is blocked), but it must be
   solved before a second unarmored source can coexist.
3. **Stale cached AC after level-up.** `Character.level_up` unlocks features but
   does not call `_recalculate_ac`; `get_ac` reads cached `base_ac`. Probe: AC
   stayed 12 after the level-3 grant until `_recalculate_ac` ran (then 15).
   Barbarian/Monk never hit this because they gain the effect at level 1.
4. **Per-class-level max-HP grant missing** (see mapping). Needs a once-only,
   saved, class-level-scaled feature grant that also applies retroactively when
   the subclass is acquired at a level above 3 and never replays on restore.
5. **Subclass selection.** `_unlock_features_for_level` auto-assigns a subclass
   only when exactly one exists for the class; loading Draconic as the sole
   Sorcerer subclass would auto-select it. Explicit choice remains the existing
   acquisition path's concern.

## Validation (Linux headless Godot 4.7.2, not the Windows runner)

Ad-hoc probe in ignored `.artifacts/crown-draconic-2026-11-01/` (`probe.gd`,
`ac_probe.gd`, `probe.log`): production DataLoader loads 14 classes / 5 subclasses
/ 362 spells with 0 validation failures and no `draconic_sorcery`; candidate has
the required subclass fields, level keys 3 and 5 only, `draconic_sorcery_`
feature IDs, only already-supported effect types, no `resolver`/`enabled`, and
every spell resolves at a castable slot level. The AC fixture results are listed
above. `run_tests.ps1` (Windows) was not run; local verification remains.

## Next implementation PR

Supply the generic owners for gaps 1, 3 and 4 (and 2 before multiclassing), then
copy the candidate into `data/core/subclasses/` with the HP effect replacing
`unmapped_clauses`, and prove creation, level 3→5, retroactive HP, Shield/armor
AC, save/reload without replay, and spell permissions.
