# SC-05 support 01: Color Spray (shared cone save + caster-turn Blinded expiry)

Stacked on `codex/crown-spells-sc-04-support-01` (#93). This is the first SC-05 PR. It converts **Color Spray** only. The other SC-05 rows (Blindness/Deafness, Blur, Charm Person and Faerie Fire) remain `queued` for follow-up SC-05 PRs.

## What changed
- `data/core/spells/crown_sc_05_support_01.json` authors Color Spray as shared data, following SRD 5.2.1:
  - Level 1 Illusion for Bard, Sorcerer and Wizard.
  - Range Self, 15-ft Cone (3 hexes), V/S/M (a pinch of colorful sand), Instantaneous.
  - On a failed Con save the creature is Blinded until the end of your next turn. This uses the existing generic `grant_condition.expiry {caster_turn_end, 2}` and needs no new engine code.
- The manifest override replaces `imported_spells.json#33`, whose `grant_condition.duration` field was unsupported.
- `src/test_runner.gd`: the legacy Color Spray logic test called the imported failed-save path, which granted the condition and removed it after one tick. It now asserts the shared behaviour: `resolve_spell` grants Blinded, and the target's attack rolls have Disadvantage.

## Proof
- A renamed `neutral_glare` copy goes through the production loader and `CombatAction.resolve_spell`. It grants Blinded with a caster end-of-turn expiry of 12 s. The old `duration` field is still rejected.
- A real cast: a Sorcerer learns Color Spray through ordinary selection and casts it with the picker and a cone click. The flow checks that:
  - each cast spends exactly one slot;
  - a failed save Blinds the target, whose attacks then have Disadvantage;
  - a Blinded-immune creature in the cone gets nothing;
  - a creature 30 ft away is outside the cone;
  - Blinded survives the target's turn and the end of the casting turn, then ends at the end of the caster's next turn.
- Logic suite: 6935 passed, 0 failed. `mixed_mechanics_encounter` and `crown_sc_04_support_01_flow` pass.

## Limits
- The cone uses the existing 3-hex cone template.
- The material component is satisfied by a focus or pouch, since it has no cost.
- The save shape is unchanged.

## Recorded, not fixed
`conversion_batch_001_flow` already fails on the true base 6a47efa, with a Bless-on-downed "Invalid access to 'targets'" error in `_resolve_player_target`. That failure predates this stack and is left as is.
