# Batch 065 build: data reaction triggers

Card Q-20261021-172804-829a. Queue item 6. Stacked on #36 (batch-064-mode-duration @ aca5a70, accepted by Runtime Reviewer, not merged), because #25-#36 are still open and this edits the 057-064 mode cost code.

## Finish line (verbatim)
Brandon: "If something costs a reaction like 'Hellish Rebuke', then it should be able to happen on a defined trigger from the data."

Grok Bot's note: the costed on-hit mode switch should use this.

Added constraint (Brandon via Grok Bot): the data supplies the trigger, and the engine sets NO default trigger for any reaction. A reaction without a declared trigger is never offered automatically. Include the costed on-hit mode switch.

## SRD 5.2.1 wording (checked against the published SRD 5.2.1 text)
- Hellish Rebuke: "Reaction, which you take in response to taking damage from a creature that you can see within 60 feet of yourself" -> `{"event": "on_damaged_by_creature", "range_feet": 60, "requires_sight": true}`.
- Shield: "Reaction, which you take when you are hit by an attack roll" -> the `on_hit_by_attack` shape. Shield is **not** converted; it keeps its own pre-roll path and declares no trigger.

## Existing reaction code studied
- `CombatState._collect_reaction_decisions` (Uncanny Dodge, Shield, Deflect Attacks) asks before the monster attack resolves; `_collect_spell_cast_reactions` (Counterspell/stopping spells) filters by `reaction_available`, incapacitation, `CombatPerception.can_see_target` and `Targeting.is_in_range`; opportunity attacks in `_check_opportunity_attacks_for_path`. All prompt through `CombatHUD.request_reaction` and pay spells with `request_spell_payment` + `SpellPermissionRules.spend_reaction`.
- 057 limit 3: `hit` switch windows with a declared cost opened on the attacker's turn and were always refused `wrong_turn`.

## Design
- **Vocabulary** (`src/combat/reaction_triggers.gd`, `ReactionTriggers`): `reaction_trigger = {event, range_feet?, requires_sight?}`; events `on_attacked`, `on_hit_by_attack`, `on_damaged_by_creature`, `on_hit_with_attack`; `range_feet` 5-1000 in steps of 5; `requires_sight` bool; unknown keys refused.
- **Where it is declared.** Spells: only `casting_time: reaction` spells (`DataLoader._validate_semantics`; allowed as a shared-spell field; a shared reaction spell may now rely on a `reaction_trigger` instead of a cancellation rule). Modes: `mode_choice` rules with `costs.switch: "reaction"` must declare one (refused with "no default trigger" otherwise), a trigger without a reaction cost is refused, only `switch` may cost a reaction, and the trigger must be `on_hit_with_attack` with `switch_events` containing `hit` (the S-104 window it fires through).
- **No default.** `offers` only reads `spell.reaction_trigger` / `rule.reaction_trigger`; nothing else is offered. A check strips the fixture's trigger and asserts no offer. No per-ID branches (ADR-0018).
- **Filters.** Owner match, event kind, open event, alive/not Incapacitated, Reaction available, `range_feet` against the event distance (hexes x 5), `requires_sight` against `CombatPerception.can_see_target` (same calls the Counterspell path uses).
- **Cost vocabulary.** `reaction` added to the mode `COST_TYPES` (switch only) and `CombatTurnBudget.cost_label`. `ModeControls.cost_error` refuses a reaction-cost act unless it comes through `ModeControls.ReactionPayer` (passed only by `ReactionTriggers.confirm`), so a HUD/room press is refused `reaction_trigger_only`; the payer refuses `reaction_used`/`incapacitated` and pays by clearing `reaction_available`. Reaction acts take 0 s for 064's `activation_seconds`.
- **Prompt path.** `CombatState._fire_reaction_trigger(reactor, kind, source, reactor_pos, source_pos)` builds the event, then for each offer asks `hud.request_reaction`; a spell then asks `hud.request_spell_payment`, a mode asks for the target mode. `ReactionTriggers.confirm` re-checks everything (token, open event, filters) before paying. The first success closes the event; later answers are `stale`.
- **Wiring.** Monster attack on a player: `on_attacked` before `_collect_reaction_decisions`; `on_hit_by_attack` after a hit settles; `on_damaged_by_creature` when damage > 0. Player weapon attack: `on_hit_with_attack` after a hit (the costed on-hit mode switch).
- **Spells pay on confirmation only.** `confirm` calls `SpellPermissionRules.spend_reaction` (slot + Reaction) only after an accepted prompt and a chosen payment; the paid record carries `_reaction_trigger_paid` so `CombatAction.validate_spell_target`'s "resolves only through its reaction boundary" guard lets it resolve once, with `deduct_slot = false`.
- **Hellish Rebuke.** Real data exists, so `hellish_rebuke` in `imported_spells.json` gains the SRD trigger (one field, no catalog rewrite). It is still not a supported slice in `SpellSupport`, so it has no cast permission and is not offered yet. The executable path is proven with the neutral fixture `fixture:b065_rebuke` (shared execution, DEX save, 2d10 Fire, half on save).

## Checklist
- (a) Refuse before paying: cancelled prompt, cancelled payment, Reaction already used, Incapacitated, out of range, unseen, stale (other or closed event, re-opened mode window) spend no slot, no Reaction and no mode change (logic); a declined prompt spends nothing in real combat (scenario).
- (b) No new saved record or field; `FeatureModeRules.saved_error` clean; saves contain no `reaction_trigger`. Legacy saves unchanged.
- (c) Callers: `ReactionTriggers.offers/confirm` by `CombatState._fire_reaction_trigger`; `_fire_reaction_trigger` by the monster-attack and player-attack paths; `mode_trigger_error` by `FeatureModeRules.validate_rule`; `spell_trigger_error` by `DataLoader._validate_semantics`; `ReactionPayer` by `confirm`.
- (d) Real `SaveManager.save_game`/`load_game` in `batch_065_reaction_triggers_flow`: switched mode, Reaction cost and declared trigger survive. No cache clearing.
- (e) No item-granted effect added; the fixture is a feat; the 049/057 merged/suppressed gate still runs through `ModeControls.apply`.
- Legacy: 057 Rush validates; existing free/action/bonus/magic costs unchanged; Shield, Counterspell, Uncanny Dodge, Deflect Attacks and opportunity attacks untouched.

## Counts
- Baseline aca5a70 (imported): logic 5633 passed, 0 failed, 61 check scripts.
- Branch (imported): logic 5649 passed, 0 failed (+16, all 065), 62 check scripts, 0 failed.
- Scenarios 031-065, one at a time: 35/35 passed (new: `batch_065_reaction_triggers_flow`, 5 assertions). 0 SCRIPT/Parse errors.

## Limits
- Hellish Rebuke data declares its trigger but the spell is not a supported cast slice yet, so real warlocks are not offered it; only the fixture runs end to end.
- `on_hit_by_attack` and `on_damaged_by_creature` fire after the attack settles, so a trigger reaction there cannot change that hit (Shield keeps its own pre-roll path). `on_attacked` fires before the roll.
- Only monster-on-player weapon attacks and the player's main weapon attack fire triggers. Spell attacks, Extra Attack swings, opportunity attacks, area damage and monster-to-monster damage do not fire them yet.
- Monsters and created creatures are never reactors on this path; one reaction per event (first confirmed offer closes it).
- Commands (060) do not take a `reaction` cost: no command trigger exists. Modes take `reaction` on `switch` only, through `on_hit_with_attack`.
- The combat HUD/room can still list a reaction-cost switch while its window is open; pressing it is refused `reaction_trigger_only` (spends nothing).
- Prompt text is not localized.

## Carried limits
- 064: time passing for outside-combat modes is PARTIAL (no clock advanced).
- 059 review: bodies are consumed before placement.
- 058: mixed-size summons and Find Familiar type choice documented only.
- 060: Reaction as a command cost — still open (see Limits).
- 062: only the local room panel offers modes outside combat.
