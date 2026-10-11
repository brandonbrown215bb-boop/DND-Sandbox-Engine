# Current development checkpoint

Reconciled 2026-10-11. This page records the latest accepted runtime evidence
and open work. [Roadmap](../../roadmap.md) chooses priority; the Quest Board
owns the exact next action. The reviewed shared-runtime batch includes the ward and ordered Portent fixes below.

## Direction and current implementation

[ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) establishes
one shared data-driven rules runtime as the target. The broader interpreter,
class/creature language, generic continuation persistence and GM adjudication
workflow are not implemented. Named class/spell helpers remain migration code.

Ordinary spells currently opt into `execution: "shared"`. Valid operations,
rather than spell identity, enable new namespaced definitions. Existing cast
stages own resources, reactions and selection; `SharedSpell` applies ordinary
payloads once. Timed grants retain source ownership, Concentration, repeat
saves, campaign expiry and schema-2 validation.

Twelve winning definitions were converted: Fire Bolt, Burning Hands, Fireball,
Acid Splash, Cure Wounds, Healing Word, Hold Person, Inflict Wounds, Poison Spray,
Sacred Flame, Shield of Faith and Cone of Cold. Their rules limits remain.
Exploration controls support single/self party effects and single-object
attacks. Area/multi-target exploration and ongoing hazards remain separate paths.

## Latest accepted evidence — shared-runtime slices, 2026-10-11

Windows Godot 4.7 stable: bootstrap, **179-script parse gate**, production boot,
and **2,930 logic checks passed, zero failed**. The normal-control scenarios
`shared_spell_normal_controls_flow`, `ward_normal_controls_flow`,
`roll_token_normal_controls_flow`,
`short_rest_arcane_recovery_normal_controls_flow`, `crown_smoke` and
`combat_defeat` passed. The Portent and ordered-spell scenarios were rerun after
fixing consecutive exclusive-dialog handoff; that final batch had no engine
errors. All four save/reload probes passed in distinct prepare/recover processes.

Reproduce with `run_tests.ps1 -GodotPath <Godot-console-path> -Suite logic`,
then `-Suite integration -Scenario` with the six scenario names above.
Run `scripts/validate_ordered_grant_fresh_relaunch.ps1`,
`validate_roll_token_fresh_relaunch.ps1`, `validate_ward_fresh_relaunch.ps1` and
`validate_short_rest_fresh_relaunch.ps1`, each with `-GodotPath`.
See [testing](../testing.md) for the runner contract.

Local ignored evidence:

- Logic: `.artifacts/tests/33671b91de94471b866b8eba63ef048e/`.
- Gameplay: `.artifacts/tests/1bf53d3bcd9a420baa5c3c8527e2cca2/`; its Portent engine error is superseded by the clean final Portent/ordered-spell batch at `.artifacts/tests/323be74ab4614959b04e6b54126739b1/`.
- Ordered grants relaunch: `.artifacts/tests/ordered-grant-relaunch-04f61b57545a4c428a6f3fd5cf6d2b0b/`.
- Roll tokens relaunch: `.artifacts/tests/roll-token-relaunch-ddc9872d4bcd468eb974edfb6bf7d764/`.
- Wards relaunch: `.artifacts/tests/ward-relaunch-127d963aa9774ed9822daf1906d8a09d/`.
- Short Rest relaunch: `.artifacts/tests/short-rest-relaunch-50bf66638b59427d982cfd3486dbd82d/`.

These logs are evidence from this host, not a guarantee for another checkout.
No Linux execution, manual visual acceptance or full rules/campaign certification
is claimed. Broader interpreters, generic continuation persistence and unmigrated
class/monster catalogs remain unfinished.

## Verified behavior and bounded scope

**Ordered execution and zero-HP replacement**
([ADR-0019](../decisions/0019-shared-ordered-execution-and-zero-hp-replacement.md)):
`SharedStepExecutor` runs explicit spell steps and creature event rules through
one engine. Per-target gates retain attack damage when a later save succeeds;
area saves retain one shared raw damage roll and filter obstructed targets.
Empowered Spell and concentration reaction chains resume at the pending actor
and step, retain settled effects, and spend cast-wide costs once. Natural and
created Zombies and the JSON-only Dread Husk use data-driven zero-HP replacement.
Source-owned timed grants survive fresh-process reload, reject invalid content
before session replacement and expire independently. Multi-step exploration
remains single-target; active combat continuations are transient.

**Roll tokens and Portent**
([ADR-0020](../decisions/0020-roll-tokens-and-pre-roll-replacement.md)):
Diviner and the JSON-only Oracle fixture share `RollTokenRules`. Token identity,
visibility, once-per-turn use and schema-2 persistence are verified across attack,
save, ability/skill, Initiative and Death Saving Throw boundaries. Ordered casts
now offer pre-roll choices for each attack, target save and concentration save.
Declining the first attack preserves the later save choice without replaying
attack damage or slot expenditure. Stale, copied, wrong-kind and replayed request
callbacks refuse before resumption. Consecutive Portent dialogs release modal
focus before the next opens. Acquisition generates initial tokens and capacity
upgrades generate the additional tokens immediately; replacement uses the stored
natural result without another Advantage/Disadvantage d20. Those existing game
policies are documented rules limitations, not full PHB certification. Divination
Savant, Expert Divination and The Third Eye remain disabled/partial.

**Wards and damage interception**
([ADR-0021](../decisions/0021-damage-interception-and-wards.md)):
Abjurer and the JSON-only Runeguard fixture share `WardRules`. Slot-paid qualifying
casts create/recharge wards; free, ritual, item and at-will casts do not. Damage
applies Resistance/Vulnerability, ward interception, Immunity on overflow,
Temporary HP, then real HP. Immunity no longer preserves ward HP incorrectly.
Projected Ward spends one Reaction on one occurrence, including its typed damage
components, and cannot absorb a later hit or ordered step using the same decision.
Concentration uses creature damage after ward interception; fully absorbed damage
requires no save. Active zero-HP wards can recharge, and their state survives
fresh-process reload with malformed-save refusal. Abjuration Savant, Spell Breaker
and Spell Resistance remain disabled/partial.

**Short Rest and Arcane Recovery**
([ADR-0022](../decisions/0022-rest-completion-and-slot-recovery.md)):
Overworld and Dungeon entrance controls offer Short Rest (1 hour), Long Rest
(8 hours), or Cancel. Cancellation/refusal changes no time or resources; Short
Rest advances the clock once and affects living party members once. The shared
`rest_slot_recovery` effect offers a player-selected combination within
`ceil(wizard_class_level / 2)` slot levels and excludes level 6+ slots. A valid
choice consumes the once-per-Long-Rest use; declining/full slots preserve it.
The combat recovery helper is retired. Invalid, stale, wrong-actor and replayed
choices refuse without corrupting the live opportunity. Wizard and JSON-only
Leyline Savant fixture behavior, clock, slot state, spent uses, second-rest
suppression and Long Rest reset survive fresh-process reload.

## Open implementation — Animate Objects and world gaps

`src/characters/animated_object_rules.gd` and partial created-creature,
damage/perception, clock/Concentration and save hooks exist. The intended path
separates original object identity/HP from temporary Construct HP, uses a
one-minute Concentration lifetime, and carries excess damage into reversion.
These behaviors have not passed dedicated production acceptance.

`src/spells/animated_object_casting.gd` is absent. Normal selection/refusal
before cost, cast-stage integration, owner-following initiative, Bonus Action
attack/Dodge commands, and room cast/end controls are unfinished. Check optional
or null party data in save preflight and missing-record cleanup when resuming.
`SpellSupport.AVAILABLE_SLICES` includes `animate_objects`; that entry is not
proof of a working cast. Do not promote status from the allowlist alone.

Before acceptance, prove weighted object selection, orders/initiative, defenses,
expiry, zero-HP reversion/excess damage and checkpoint identity/HP through actual
controls. Use an explicit higher-level fixture: the level-5 spell is beyond
Crown's natural character level 1–5 band. Integrate the unfinished mechanics
under the roadmap's shared-runtime direction when scheduled.

Bounded Find Familiar, party corpse/recovery and Animate Dead paths have
earlier production evidence and explicit limits in their
[mechanics contracts](../mechanics/README.md). Animate Dead's latest recorded batch used
166-script parse, boot, 2,446 passing logic checks and six live regressions;
consolidated log: `.artifacts/wave4-foundations/created-accepted-validation.log`.
Finger of Death's Zombie, curated reversible forms and authored NPC/illusion
interaction remain open. Both [Wave 4 completion boundaries](../mechanics/wave4-acceptance.md)
are incomplete; they are not the active priority sequence.

## Other evidence and limits

The startup blank-window repair and normal visible start/creation/overworld
sampling are recorded in [the dated playtest](../../PLAYTEST_REPORT.md).
Phase-one Smite, Escape cancellation, object label placement and species
Darkvision repairs have a recorded 2,533-check logic pass; this precedes the
shared-spell batch above and adds no whole-class certification.

Class audits describe partial behavior and gaps, not future architecture.
[Visual acceptance](../ui/VISUAL_ACCEPTANCE.md) records the approved grimoire
presentation and its validation limits. Linux, controllers, broad manual
campaign traversal and published fresh-clone acceptance are not certified here.
