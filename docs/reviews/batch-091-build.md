# Batch 091 build: SRD class spell lists (D-09)

Base: batch-090-item-data-corrections (6e3a0af). Sources: SRD 5.2.1 (srd.txt line / PDF page of each spell's class header).
Brandon's SRD-settles-rules rule re-approves the per-class count tests (test_runner.gd `expected_class_spell_counts`) and the Guidance/Bard test.

## Class `spell_list_ids` (data/core/classes/*.json)
| Class | Change | SRD header | srd.txt | PDF p. |
|---|---|---|---|---|
| Warlock | − fire_bolt | Evocation Cantrip (Sorcerer, Wizard) | 8204 | 132 |
| Warlock | − magic_missile | Level 1 Evocation (Sorcerer, Wizard) | 9202 | 146 |
| Bard | − guidance | Divination Cantrip (Cleric, Druid) | 8679 | 138 |
| Ranger | − misty_step | Level 2 Conjuration (Sorcerer, Warlock, Wizard) | 9527 | 150 |
| Cleric | − resilient_sphere | Level 4 Abjuration (Wizard) | 10023 | 158 |
| Paladin | − resilient_sphere | Level 4 Abjuration (Wizard) | 10023 | 158 |
| Sorcerer | + mind_spike | Level 2 Divination (Sorcerer, Warlock, Wizard) | 9458 | 149 |
| Sorcerer | + phantasmal_force | Level 2 Illusion (Bard, Sorcerer, Wizard) | 9586 | 151 |
| Wizard | + phantasmal_force | Level 2 Illusion (Bard, Sorcerer, Wizard) | 9586 | 151 |

## CURATED_SPELL_ACCESS (src/autoload/data_loader.gd)
- Removed: warlock "0" fire_bolt, warlock "1" magic_missile, bard "0" guidance, ranger "2" misty_step (same citations as above).
- Also removed, beyond the D-09 audit, because the SRD header excludes them: bard "2" misty_step and druid "2" misty_step (Misty Step: Sorcerer, Warlock, Wizard, line 9527, p.150), and druid "0" ray_of_frost (Ray of Frost: "Evocation Cantrip (Sorcerer, Wizard)", line 9993, p.157). Neither class's data list had these spells.
- Added: sorcerer "2" mind_spike and phantasmal_force; wizard "2" phantasmal_force.
- Artificer is out of milestone and was not changed.

## Counts (get_spell_list_options)
wizard 219→220, sorcerer 139→141, cleric 110→109, bard 136→135, warlock 75→73, ranger 49→48, paladin 46→45, druid 125→125.

## Tests
- Guidance loop: now covers ["cleric","druid"], plus a new assertion that Guidance is not on the Bard list.
- Logic suite (Godot 4.7.2, imported twice, run sequentially): 6416 passed, 0 failed (/tmp/tlogs091). No SCRIPT/Parse/Compile errors.

## Legacy saves: BLOCKED (engine work needed)
I tested with a temporary scene, not committed. For each class I built a level-1 character, swapped one spellcasting choice for the removed spell, and round-tripped it through to_dict:
| Case | Before (6e3a0af) | After |
|---|---|---|
| Bard with guidance | saved_choices_error = "" | "Spellcasting choice contains a duplicate or unavailable spell" |
| Warlock with fire_bolt | "" | same error |
| Warlock with magic_missile | "" | same error |
| Druid with ray_of_frost (control; never on the data list) | error | error |

`Character.from_dict` still restores known_spells. However, SaveManager runs `ClassProgression.saved_choices_error` (save_manager.gd:388 and 584) and refuses the slot on any error. So **a legacy save with a now-off-list spell in its spellcasting choice will fail to load.** Nothing was deleted. A fix (for example, grandfathering previously saved choices in `_saved_spell_choice_error`, or a migration) is engine work and out of scope under the content-only rule. This PR should not merge until that is decided.

## Out of scope (unchanged)
mage_armor manifest, prayer_of_healing, bestow_curse, clairvoyance, out-of-milestone spells. test_runner.gd ~2279 still asserts the resilient_sphere spell record's `classes == ["cleric","paladin","wizard"]`. That is the spell's own metadata, not a class list. It disagrees with the SRD header (Wizard only) and is flagged for follow-up.
