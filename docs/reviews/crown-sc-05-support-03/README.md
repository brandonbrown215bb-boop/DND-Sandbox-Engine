# SC-05 support 03: Charm Person "fighting" check follows the SRD

This PR is stacked on `codex/crown-spells-sc-05-support-02` (#95). It answers the review note that "the target is a monster" was not faithful enough to SRD 5.2.1 Charm Person: the target "makes the save with Advantage if you or your allies are fighting it".

## Generic piece
`SpellSaveResolver.is_fighting_caster_side(cast, target)` decides whether the caster's side is fighting the target. It is data-driven and has no spell-ID branches. The target counts as fighting only when all of these hold:
- the cast has a live initiative tracker, through the spatial host;
- the caster and the target are both active combatants in that tracker;
- they are on opposite sides (`is_player` differs);
- the target is not dead;
- the target's Influence attitude is not `friendly`.

Outside initiative, nobody is fighting the target. `save_advantage_if_fighting_target` now goes through this check for any target type, where before it only checked that the target was a monster.

## Proof
- **Logic suite:** 6936 passed, 0 failed.
  - Inside combat, an opposing combatant gets save Advantage through `CombatAction.resolve_spell`, with a host that carries a tracker.
  - New check: outside combat, the result is identical to a run without the flag, so there is no Advantage.
- **`crown_sc_05_support_02_flow`:**
  - Positive case: a foe on the opposing side.
  - Negative cases: no initiative running, a bystander who isn't in initiative, a creature with a friendly attitude, and the caster's own party ally.
  - Live encounter check: after the Humanoid is charmed through player controls, it joins initiative and counts as fighting the caster's side in the encounter's real tracker.
- **Recover run, charm_person_spell_flow and charm_monster_spell_flow:** all pass.

## Limits
- **Tracker joins:** combatants that are injected after initiative must join the tracker to count as fighting. The flow does this the same way a rolled encounter does.
- **Live check:** the live-encounter assertion checks the "fighting" test on the real tracker, not the Advantage roll itself. The Advantage roll is proven in the logic suite.

## Queue
charm_person stays converted, and its note now describes this check.
