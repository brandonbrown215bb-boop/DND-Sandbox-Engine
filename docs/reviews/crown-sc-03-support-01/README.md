# SC-03 support 01 — generic source-owned conditions; converts 4 blocked SC-01 cantrips

Stacked on `codex/crown-spells-sc-03` (no rebase). Built the missing generic pieces for four SC-01 cantrips, then converted them.

## Generic engine support (no spell-ID branches)
- `SharedSpell.CONDITIONS` adds `speed_reduced`, `healing_prevented`, `opportunity_attack_blocked`, `next_attack_disadvantage`, `invisibility_suppressed`.
- `SharedSpell.AMOUNT_CONDITIONS`: `speed_reduced` requires an integer `amount` from 1 to 12 hexes. An amount on any other condition is rejected.
- Expiry boundaries add `target_turn_start` and `target_turn_end`, saved as `recipient_start`/`recipient_end`. `SpellEffects.tick_boundary` advances these on the recipient's own turn boundaries, for players and for monsters (the monster spellcaster's `character_id` is the monster id).
- `SpellEffects.set_condition_amount`, `condition_amount` (the largest value per spell, summed across spells) and `consume_condition`.
- Consumers:
  - `Character.get_speed` and `FighterRules.monster_speed` subtract the reduction.
  - `Character.heal` and `CombatAction.is_healing_suppressed` read `healing_prevented`.
  - `blocks_opportunity_attack` reads `opportunity_attack_blocked`.
  - `attacker_has_condition_disadvantage` reads `next_attack_disadvantage`. `make_attack_roll` consumes it once, and so does `_sync_consumed_monster_attack_conditions` for monsters.
  - `is_invisible` reads `invisibility_suppressed`.
- **Save data:** `SpellEffectPersistence` accepts recipient phases only when a `recipient_id` is present. It also accepts optional `condition_amounts`, which must be in range and on a granted condition. Older saves without these fields stay valid.

## Spells (SRD 5.2.1), `data/core/spells/crown_sc_01_support_01.json` plus manifest overrides
- `ray_of_frost`: ranged spell attack, 1d8 Cold, Speed −10 ft until the start of your next turn.
- `chill_touch`: melee spell attack, 1d10 Necrotic, the target can't regain HP until the end of your next turn.
- `shocking_grasp`: melee spell attack, 1d8 Lightning, no Opportunity Attacks until the start of the target's next turn.
- `vicious_mockery`: WIS save, 1d6 Psychic, Disadvantage on the target's next attack before the end of its next turn.
- All four have cantrip upgrades at levels 5, 11 and 17.

## Proof (`crown_sc_01_support_01_flow`, PASS, 41 checks)
- Contract rejects: a missing, zero or out-of-range amount; an amount on a condition that has no magnitude; an unknown boundary.
- **Renamed neutral copies:**
  - Three copies (`neutral_slow`, `neutral_jolt`, `neutral_jeer`) have no class membership.
  - They go through the production loader, a range check (`HexUtils`) and `CombatAction.resolve_spell`.
  - They cover the amount, the recipient-start expiry and a one-use failed-save disadvantage, with no ID registration.
- **Real controls:**
  - Setup: a level-1 Sorcerer and Bard learn the spells through ordinary class selection. Every cast goes through the spell picker and a hex click and spends the action, with no slot.
  - Ray of Frost:
    - A miss does nothing.
    - A hit deals at most 8 damage and sets Speed to 4.
    - The reduction survives the caster's turn end and the target's own turn, then ends at the caster's next start.
  - Chill Touch: healing stays blocked through the end of the casting turn and returns after the caster's next turn ends.
  - Shocking Grasp: the caster's boundaries don't clear the restriction, but the target's own turn start does.
  - Vicious Mockery:
    - A failed save deals at most 6 damage and imposes Disadvantage. A successful save gives nothing.
    - The next monster attack has Disadvantage and uses it up.
    - If unused, the Disadvantage survives the caster's turn end and the target's turn start, then expires at the end of the target's next turn.
- **Save round trips:**
  - New format: an ally carrying a speed amount and a target-owned block saves, passes preflight, reloads and recovers in a fresh process (`-recover.log`). In the fresh process, the target's turn start ends the block and the caster's start ends the slow.
  - Old `.sav`:
    - A `crown_sc_01` checkpoint was written by the SC-03 tip code (`old-save-sc03-tip-crown_sc_01_checkpoint.log`).
    - This branch loaded it, ticked it, expired it and re-saved it (`old-save-recover-on-support-01.log`).
- **Limit:** class spell lists are keyed by ID, so a renamed ID can't enter the picker. The renamed proof therefore goes through the loader, the range check and `resolve_spell`, not the HUD.

## Legacy test updates
- `test_runner.gd` assertions for these four spells used native-ID APIs (`apply_spell_hit_effects`, `clear_shocking_grasp`, `tick_healing_suppression_for_source`, `EventResolver.apply_effects` reduce_speed).
- They now assert the same rules through `resolve_spell` and `SpellEffects.tick_boundary`.
- `crown_sc_01_flow`'s "unsupported boundary" check now uses `target_turn_middle`, because `target_turn_start` is now valid.

## Checks
- Logic suite: PASS, 0 failed (`logic.log`).
- Scenarios PASS with no SCRIPT/Parse/Compile errors: crown_sc_01_support_01_flow (+recover), crown_sc_01_flow, crown_sc_02_flow, crown_sc_03_flow, shared_spell_flow, conversion_batch_002_flow.
- `conversion_batch_001_flow`: 2 failures from the known Bless-on-downed error at `spell_cast_results.gd:363`. It fails identically on the SC-03 tip (`sc03-tip-conversion_batch_001_flow.log`), so it predates this branch.
  - **Consumer:** `SpellCastResults._resolve_player_target` appends to `caster.concentrating_on["targets"]` for concentration spells. On the upcast-Bless-on-an-already-downed-creature path, `concentrating_on` has no `targets` key.
  - None of the spells in this PR concentrate or reach that line, so it was left alone.

## Still blocked (CSV)
- vicious_mockery: `blocked:` target by hearing alone (the S-190 perception consumer). Every other clause is converted.
- starry_wisp: `blocked:` Dim Light emitter (S-190). The `invisibility_suppressed` condition now exists.
