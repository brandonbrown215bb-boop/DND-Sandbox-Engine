# Batch 091 Acceptance: SRD class spell lists, D-09 (PR #69)

Reviewer: Runtime Reviewer. Head reviewed: bc6729a, stacked on #68. Verdict: **ACCEPTED for the data. MERGE GATED on Brandon confirming the legacy-save break directly (below).**

## SRD 5.2.1 header checks (srd.txt)
| Change | Header | Line | Result |
|---|---|---|---|
| Warlock loses fire_bolt | Evocation Cantrip (Sorcerer, Wizard) | 8203 | PASS |
| Warlock loses magic_missile | Level 1 Evocation (Sorcerer, Wizard) | 9201 | PASS |
| Bard loses guidance | Divination Cantrip (Cleric, Druid) | 8678 | PASS |
| Ranger, Bard and Druid lose misty_step | Level 2 Conjuration (Sorcerer, Warlock, Wizard) | 9526 | PASS |
| Cleric and Paladin lose resilient_sphere | Level 4 Abjuration (Wizard) | 10022 | PASS |
| Druid loses ray_of_frost | Evocation Cantrip (Sorcerer, Wizard) | 9993 | PASS |
| Sorcerer gains mind_spike | Level 2 Divination (Sorcerer, Warlock, Wizard) | 9457 | PASS |
| Sorcerer and Wizard gain phantasmal_force | Level 2 Illusion (Bard, Sorcerer, Wizard) | 9586 | PASS |

## Counts and CURATED_SPELL_ACCESS
- The CURATED_SPELL_ACCESS diff (data_loader.gd) matches the class JSON changes. Artificer is untouched.
- `expected_class_spell_counts` (test_runner.gd:~675) still uses exact `==` checks. The new numbers are the old numbers plus or minus exactly the listed adds and removals, so the counts were changed, not loosened. The Guidance loop has a real negative assertion for Bard.

## Defect found and fixed (reviewer commit)
`SpellPermissionRules._on_lists` (src/spells/spell_permission_rules.gd:167-168) also grants a spell when the spell record's own `classes` contains a requested list. The records were not updated:
- `resilient_sphere.classes` was still `["cleric","paladin","wizard"]`.
- `guidance.classes` was still `["bard","cleric","druid"]`.
- `mind_spike.classes` was missing sorcerer.

So list-based permissions (feats and items that use spell_permissions) would still treat Resilient Sphere as a Cleric or Paladin spell and Guidance as a Bard spell. **That means the PR's removals were incomplete.**

I fixed the records to `["wizard"]`, `["cleric","druid"]` and `["sorcerer","warlock","wizard"]`. I also updated the test_runner.gd:2282 assertion to `["wizard"]`, which answers the ~2279 question: it does affect permission and it should change. phantasmal_force has `classes: []`, which grants nothing, so I left it alone.

## Legacy-save break (BRANDON MUST CONFIRM BEFORE MERGE)
The builder says Brandon accepted this on Oct 26. The reviewer has **no direct confirmation** of that.

How I reproduced it:
- On 6e3a0af I built a level-1 Bard and chose guidance with `choose_spell_selection`, then called to_dict. saved_choices_error was "".
- On this branch, the same dict gives `"Spellcasting choice contains a duplicate or unavailable spell"`. `Character.from_dict` still restores known_spells.

What a player sees:
- `SaveManager.load_game` calls `_validate_save_data`, which reaches save_manager.gd:388 for party data and 584. Validation runs **before any game state is touched**. The function then `push_warning`s "Save '<slot>' rejected: …" and returns false.
- No data is corrupted and the save file is left unchanged.
- It fails **loudly only in the log**. main_menu.gd:101 and :279 ignore the return value, so to the player, the Load button just does nothing.
- There is **no migration path**: no code removes the spell or grandfathers it on load.

Affected saves: Bard with guidance; Warlock with fire_bolt or magic_missile; Ranger with misty_step; Cleric or Paladin with resilient_sphere. Bard or Druid with misty_step, and Druid with ray_of_frost, are already refused because those were never on the data list.

## Checks
- **ADR-0018:** no per-ID branches were added. PASS.
- **Import twice:** 0 SCRIPT ERROR.
- **Logic suite:** 6416/0, both as the builder claimed and with the reviewer fix.
- **Scenarios:** character_creation, save_load and shared_spell_flow all pass with 0 SCRIPT ERROR.

## Proposed
Once Brandon confirms: registry D-09 FIXED, logic baseline 6416 on this stack (6418 after restacking onto the #67/#68 reviewer commits).
