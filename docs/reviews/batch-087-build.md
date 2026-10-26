# Batch 087 build: S-127 damage-type choices on remaining attack routes

Builder: runtime-builder. Base: batch-086-find-steed-arrival (6aa8924). Card Q-20261026-064523-4895.

Finish line (verbatim): "Add the existing choice behavior to Opportunity, Light/off-hand, Cleave and created-creature attacks. Preserve each route's budgets and selection timing. Don't rebuild ordinary Attack/Extra Attack choices; those already work."

## What changed
- `CombatState._route_damage_choice(actor, weapon, label, carry, still_error)`: one data-driven host (ADR-0018; reads only `AttackProfileRules`, no per-ID branches). Production callers: `_offer_light_attack`, Cleave in `_finish_fighter_attack`, the player branch of `_check_opportunity_attacks_for_path`, and `CreatedCreatureCombat.take_turn`.
- The ordinary Attack/Extra Attack path (`_extra_swing_damage_choice`) is unchanged.

## Rules (SRD 5.2.1)
- **Carry:** an Attack-action pick (`choice_duration: attack_action`) carries only into attacks that are part of that Attack action. Of these routes, that is only Nick ("as part of the Attack action"). The Bonus Action Light attack, Cleave (a separate once-per-turn extra attack), the Opportunity Attack (a Reaction) and a created creature's attack (its own action) each ask their own menu.
- **Activation window:** asked before the route's budget is spent (Reaction / Bonus Action and Light use / Cleave use / creature action). After the async answer the host rechecks the rule and the route's validity: budget unused, actor able, target alive and within reach (the #50 nit). A dismissal or stale answer makes no attack, spends nothing, and is logged. No silent fallback.
- **Hit window:** the budget is spent when the attack is made. The menu follows the hit via `_settle_attack_profile_hit_choice`; a dismissal keeps the weapon's own type, with a log line (the existing rule).
- **OA:** the Reaction is cleared only after the choice is accepted, immediately before the attack resolves. A dismissal keeps the Reaction and the mover continues.
- No durable state was added, so no fresh-process reload is needed. Legacy saves are untouched.

## Proof
- Logic suite: 6399 passed, 0 failed.
- `batch_087_choice_routes_flow` (28 ok). This is the real HUD path: Attack button, hex click, real ConfirmationDialog and PopupMenu, with test_mode off. The data comes from `data/fixtures/batch_087/attack_profiles.json`.
  - Light Bonus Action: pick, dismiss and stale-reach cases.
  - Nick carry: no second menu and no Bonus Action spent.
  - Cleave: no carry, asks its own menu; a dismissal keeps the use.
  - OA: pick and dismiss, plus a hit-window case.
  - Created zombie: the rule comes from its monster `special_abilities`; pick and dismiss cases.
- Regressions passed unchanged: `batch_077_per_swing_choice_flow` (14 ok), `batch_067_weapon_damage_choice_flow` (10 ok), `batch_067_weapon_damage_choice_reload` (1 ok).
- Imported twice; no SCRIPT, Parse or Compile errors in any log.

## PARTIAL
- S-156 commanded created actors (`CreatedCommandRules._attack`, synchronous), Conjure-style summon attacks and monster attacks still settle with the inherited type.
- Item-granted profiles and reach/mastery choices are not built.
- Observation (pre-existing): `CreatedCreatureCombat.take_turn` spends `"attack_action"`, which `CombatTurnBudget.spend` treats as a no-op. The creature's turn ends on return either way. Not changed here.
