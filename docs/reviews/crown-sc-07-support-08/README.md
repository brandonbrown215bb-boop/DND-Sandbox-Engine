# SC-07 support 08: Bestow Curse (converted)

Stacked on SC-07 support 07 (#104). This converts `bestow_curse` (SRD 5.2.1) to shared data in `data/core/spells/crown_sc_07.json`. A manifest entry replaces `imported_spells.json#17`.

## New generic, data-driven pieces (no spell-ID branches)
- **`duration_by_slot`** (shared contract): it holds ascending tiers `{min_slot, duration_seconds (-1 or 1..172800), concentration}`, each above the spell level.
  - `SharedSpell.duration_tier_for_slot` looks up the tier.
  - The player path (`SpellCastResources`) applies the tier to the per-cast spell copy after the slot is paid.
  - Direct `CombatAction.resolve_spell` callers get the tier applied to the new source record (`apply_slot_duration_to_record`).
- **`until_dispelled` source flag**:
  - The record has `remaining_seconds = -1`, and its granted conditions use duration -1.
  - Persistence accepts the flag only as Boolean true with -1.
  - A condition-source duration of -1 is accepted only when its spell source carries the flag.
  - A tampered record (flag set but remaining 30) is rejected by preflight; the test covers this.
- **`condition_options`** now allows two to nine options (it was two to eight).
- **Nine `cursed_*` markers** in `CombatAction.MARKER_RULES`:
  - `cursed_str` … `cursed_cha`: Disadvantage on that ability's saving throws (`save_has_disadvantage`) and ability checks (both character and monster check paths in `EventResolver`).
  - `cursed_attack_source`: Disadvantage on attack rolls only against the marker's source. It covers weapon attacks (`attack_target_id` in the decisions), spell attacks, projectile attacks, and the player weapon path.
  - `cursed_dodge` (`MARKER_TURN_SAVES`): a WIS save at the start of the creature's turn (`CombatAction.resolve_turn_start_marker_save`).
    - In combat (`_apply_turn_start_marker_save`), a failure makes a player Dodge and spends their action. A monster Dodges, its turn is flagged, and its AI action becomes a Dodge.
  - `cursed_necrotic` (`MARKER_RIDERS`): when the marker's source deals the creature damage, a 1d8 Necrotic rider resolves once as a child damage call (no recursion). It is reported in `marker_rider_receipts`.

## Proof (`src/spells/crown_sc_07_support_08_flow.gd`)
- **Contract:** the spell loads with nine options and the tier table is correct. Bad tiers are rejected: a tier at the spell level, a non-Boolean concentration, and a duration of -5.
- **Renamed neutral definition** (`crown_sc_07_support_08:neutral_hex`) through the production loader and `CombatAction.resolve_spell`:
  - Each option kind behaves as described above.
  - Slot 3 gives 60 s, slot 5 gives 8 h without Concentration, and slot 9 gives until dispelled.
  - Removing the source ends the marker.
- **Player controls:** a level-9 Cleric casts through the real picker.
  - At level 3: the Level popup, then the target click, then the nine-option menu, picking the Dodge curse. The cast is concentrated. At the monster's turn start the failed save forces the Dodge.
  - At level 5: an 8-hour curse with no Concentration that leaves the level-3 concentration intact. The player's damage triggers the 1d8 Necrotic rider. Ending Concentration ends only the level-3 curse.
- **Checkpoint and fresh process** (`CROWN_SC_07_SUPPORT_08_RECOVER=1`): an until-dispelled curse on the caster and a 10-minute Concentration curse on a party member both reload with their effects. The test also round-trips the old `crown_sc_07_support_06` .sav (load, re-save, reload).
- **Logs:** `scenario.log`, `recover.log`, `support06-scenario.log`, `logic.log` (6936 passed, 0 failed).

## Limits and approximations (disclosed)
- **Option 4:** the rider fires on any damage the caster deals to the target, not only damage from an attack roll or a spell.
- **Forced Dodge:** the creature still moves and may use a Bonus Action, which matches SRD wording. Scripted `combat_command` monster paths are not altered, only the AI action choice.
- **Ability-check Disadvantage:** reaches the same check paths that the existing enfeebled marker reaches.
- **Remove Curse / Dispel Magic:** the curse ends by removing the source record. No new interaction was added for these spells.
