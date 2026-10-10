# Current development checkpoint

Reconciled 2026-10-09. This page records the latest accepted runtime evidence
and open work. [Roadmap](../../roadmap.md) chooses priority; the Quest Board
owns the exact next action. Documentation reconciliation changed no gameplay.

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

The current validator rejects combined attack/save delivery. Ordered mixed
checks required by [ADR-0017](../decisions/0017-shared-json-spell-execution.md)
are still unimplemented. See [executable authoring syntax](../mechanics/shared-spells.md).

## Latest accepted evidence — shared spells, 2026-10-09

Recorded Windows Godot 4.7 stable result: recovery bootstrap, **171-script
parse gate**, production boot and **2,553 logic checks passed, zero failed**.
Seven live scenarios passed: `shared_spell_flow`, `spell_effect_lifetime`,
`spell_cast_stage_flow`, `wave_three_foundations_flow`, `local_room_object_flow`,
`crown_smoke` and `combat_defeat`.

Logs: `.artifacts/tests/4c8eb8557b5843ca951268e2f6462f00/` and
`.artifacts/shared-spell-accepted-final.log`. These are local ignored evidence,
not a reproducibility guarantee for another checkout. Commands are in
[testing](../testing.md); inspect/reproduce the affected behavior after changes.

This batch covers new-ID loading/learning/preparation, combat/exploration
controls, hit/save outcomes, downed-target healing, exactly-once costs,
cancellation, source-preserving cleanup, repeat saves, disk reload and expiry.
Missing mod content rejects load before session replacement. Invalid fields,
operations and unsupported scaling combinations reject instead of spending
resources for no effect. Sanctuary's attacker save and existing
Countercharm/Repelling Blast hooks were corrected/preserved.

Disk reload was same-process. This batch does not claim fresh-process recovery,
manual visual acceptance, Linux execution or full rules/campaign completion.
Earlier named relaunch probes cover their own older scenarios only.
The current project snapshot includes unfinished work; a prior pass is not
blanket acceptance of every current file.

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
