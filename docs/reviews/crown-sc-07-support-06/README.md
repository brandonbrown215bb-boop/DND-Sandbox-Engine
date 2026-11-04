# SC-07 support 06 — Calm Emotions (converted)

Stacked on `codex/crown-spells-sc-07-support-05` (#102). Closes the three #102 gaps and marks `calm_emotions` converted.

## What changed (all generic, no spell-ID branches)
- **Per-creature option after the area resolves.** New `grant_condition` key `choice_per_target` (boolean, validated). `SpellCastTargeting` asks, for each affected creature in the area, which `condition_options` entry applies (real PopupMenu), storing picks in `spell._chosen_conditions[target_id]`. The per-cast prompt in `SpellCastChoices` is skipped for such effects. `crown_sc_07.json` #3 sets it.
- **Indifference toward chosen creatures.** When any pick carries `attitude_indifferent`, the caster is asked per party member (ConfirmationDialog) whom it covers → `spell._attitude_scope_ids`, copied onto the SpellEffects source record as `attitude_scope_ids`. `InfluenceRules.effective_attitude(monster, toward_id)` returns Indifferent only toward listed ids (unscoped/old records stay global); `roll()` passes the acting character.
- **Ends when an ally it can see takes damage.** New consequence `ends_on_seen_ally_damage` (on `calmed_indifferent`) and class `DamageWitnessRules`: the live `CombatState` binds/unbinds itself; on every `resolve_damage`, same-side creatures carrying the consequence that `CombatPerception.can_see_target` the damaged creature lose the marker. `CombatAction.end_markers_with()` factored out of the ends_on_damage path.
- **Raw conditions-dict readers routed through suppression:** `spell_cast_targeting` monster condition gate, `combat_perception` dict branch, `shared_step_executor` zero-HP source eligibility and `_target_has_source_condition`, `CombatAction.charmer_ids` (early return when Charmed is suppressed), combat HUD condition list (shows "(suppressed)").
- `crown_sc_07_support_05_flow` updated to answer the new per-creature prompts (the Bard stands in its own Sphere).

## Raw-reader audit (left unchanged, judged not to matter)
- Duration tick/expiry loops (Character ~2288, CombatState ~5579–5605): a suppressed condition's own duration keeps running, as written.
- Lay on Hands / Restoring Touch removal eligibility (combat_action ~1175, paladin_rules 277): removing a suppressed condition is allowed.
- aura_rules 95: only incapacitating conditions, which calmed never suppresses.
- Countercharm: checks spell grants, not raw conditions.
- Character sheet / overworld / dungeon / VTT displays: out of lane; they show stored conditions.

## Proof
`src/spells/crown_sc_07_support_06_flow.gd`, scenario `crown_sc_07_support_06_flow`:
- Contract: data validates; non-boolean `choice_per_target` rejected.
- Renamed neutral definition through the production loader and `CombatAction.resolve_spell`: scope ids land on the record; Indifferent only toward the chosen caster; an unchosen character's Influence roll keeps Hostile Disadvantage, the caster's does not.
- Player: level-3 Bard, picker → level → area click → three per-creature option menus (Bard, scared, angry) → scope dialog; scared gets option 1 (Frightened suppressed), angry option 2 scoped to the Bard; a Blinded ally does not witness damage; once unblinded, damage to its ally ends option 2.
- Checkpoint + `CROWN_SC_07_SUPPORT_06_RECOVER=1` fresh process: option 2 with `attitude_scope_ids` survives save, preflight and reload.
- Old-.sav round trip: the support-05 checkpoint (no `attitude_scope_ids`) loads, re-saves and reloads in the fresh process.
- Logs: `scenario.log`, `recover.log`, `support05-scenario.log`, `support04-scenario.log` PASSED; `logic.log` 6936 passed, 0 failed.

## Limits
- "Allies" = same side of the combat roster (party vs monsters); witnessing only happens inside a live combat scene.
- Scope choices are offered per party member; non-party creatures cannot be chosen.
- One logic run showed a one-off `Chill Touch applies no healing restriction on a miss` failure (random roll; untouched code); two reruns were 6936/0.
