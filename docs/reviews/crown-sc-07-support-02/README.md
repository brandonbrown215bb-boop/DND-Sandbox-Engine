# SC-07 support 02: Strength ability checks in combat read the shared enfeebled consequence

Stacked on `codex/crown-spells-sc-07-support-01` (#98). This answers the #98 review: SRD Ray of Enfeeblement gives Disadvantage on **Strength-based D20 Tests**, so every Strength check in combat must read the generic consequence.

## Findings
- The engine has no grapple or shove contest. In the 2024 rules, Unarmed Strike Grapple and Shove use the target's **saving throw**, not a check, and Strength saves already read `str_d20_disadvantage` (#98).
- The Strength ability checks that do exist in combat are:
  - Restraint-zone escapes, for Characters (`_try_escape_restrained_zone`) and monsters (`_try_monster_escape_restrained_zone`).
  - Tether escape and rescue (`TetherRules.escape` / `rescue`).
  - Local-room interactions and event checks.
- All of these call `EventResolver.resolve_skill_check` (Characters) or `EventResolver.resolve_monster_ability_check` (monsters). Both resolvers read `CombatAction.conditions_with_consequence(..., "str_d20_disadvantage")`, which uses CONDITION_RULES plus MARKER_RULES. No spell IDs are involved.

## Changes
- New `crown_sc_07_support_02_flow` (registered in the harness):
  - **Routing guard:** scans every production `.gd` under `src/`. It fails if anything other than `event_resolver.gd` calls `resolve_d20_test(... "ability_check" ...)`, so any new Strength check has to go through the consequence-reading resolvers.
  - **Renamed neutral ray** (`crown_sc_07_support_02:neutral_wilt`) through `CombatAction.resolve_spell`:
    - A control check rolls normally first.
    - An enfeebled Character rolls Strength (Athletics) and raw Strength checks at Disadvantage, and Dexterity checks normally.
    - The receipt names `enfeebled` as the source.
    - An enfeebled monster also rolls Strength at Disadvantage and Dexterity normally.
    - Legacy `ray_of_enfeeblement` markers give the same result.
  - **Live combat:**
    - A Warlock casts Ray through the picker and a hex click.
    - The restrained monster's production zone escape rolls a `disadvantage` die event; the control before the cast does not.
    - An enfeebled party member uses its action on its own turn to escape a restraint. The production escape rolls at Disadvantage.
  - **Checkpoint and fresh-process recovery:** Strength check Disadvantage survives; Dexterity stays normal.
- `test_runner.gd`: the Chill Touch / Divine Spark monster check is now deterministic. The goblin gets 200 max HP, so the hit can no longer kill it; it flaked once in this run.
- CSV note updated. `ray_of_enfeeblement` stays **converted**, because the gap is closed with proof.

## Results
- crown_sc_07_support_02_flow: 0 failed. Recovery: 0 failed.
- Old-save round trip: the #98 commit (4b0ab22) wrote the SC-07 s1 checkpoint, and this branch recovered it with 0 failed. This PR changes no saved data.
- 0 failed: crown_sc_07_support_01_flow, entangle_spell_flow, mixed_mechanics_encounter, crown_sc_06_flow, crown_smoke, charm_person_spell_flow.
- Logic suite: 6936 passed, 0 failed.
- condition_recovery_flow: 1 failure ("S247 spell and generic save owners cancel Restrained against Advantage once"). It fails the same way on the SC-06 base (e899572), so it was already failing before this work.

## Limits
- When a tether can be escaped with either ability, TetherRules picks the one with the higher modifier. It does not avoid an ability that has Disadvantage. A player who prefers Dexterity while enfeebled cannot choose it yet; this is unchanged from before.
