# Behavior contracts and migration gaps

These documents retain partial production behavior, source clauses and
unimplemented outcomes. They do not prescribe native helper architecture or
the next class to implement. [Roadmap](../../roadmap.md) chooses work;
[ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) owns direction;
[checkpoint](../operations/current.md) records the latest accepted batch.
Dated counts/failures apply to their named snapshot. Reproduce affected
behavior before reopening a finding or claiming broader support.

| Class | Partial behavior and remaining scope |
|---|---|
| Barbarian | [Audit](barbarian-2024.md) |
| Bard | [Audit](bard-2024.md) |
| Cleric | [Audit](cleric-2024.md) |
| Druid | [Audit](druid-2024.md) |
| Fighter | [Audit](fighter-2024.md) |
| Monk | [Audit](monk-2024.md) |
| Paladin | [Audit](paladin-2024.md) |
| Ranger | [Audit](ranger-2024.md) |
| Rogue | [Audit](rogue-2024.md) |
| Sorcerer | [Audit](sorcerer-2024.md) |
| Warlock | [Audit](warlock-2024.md) |
| Wizard | [Audit](wizard-2024.md) |

| Shared/world behavior | Contract |
|---|---|
| Recipient Temporary HP and chosen/lingering protections (VS-84/85/86 accepted) | [Temporary HP and entry protections](temporary-hp-and-entry-protections.md) |
| Source-owned condition suppression and moving combat auras (VS-73/74/75 accepted) | [Condition suppression and auras](condition-suppression-and-auras.md) |
| Purpose-aware event skill-check context and owned tools | [Check context](purpose-aware-check-context.md) |
| Exact item/cast/progression AC and speed benefits (VS-59/60) | [Source carriers](source-benefit-carriers.md) |
| Starting/multiclass grants and permanent level gains (VS-68/69 accepted) | [Permanent progression](permanent-progression.md) |
| Filtered progression choices and safe replacement | [Progression choices](progression-choices.md) |
| Party roll contributions and fixed/rolled/dice allocations (Q accepted) | [Party rules](party-intervention-and-allocation.md) |
| Owned post-roll ability-check modifiers | [Check modifiers](owned-ability-check-modifiers.md) |
| Source-owned AC alternatives, score projections and recipient protections | [Stat protections](source-owned-stat-protections.md) |
| Shared spell effect termination on cast/action, damage cause, status, gear or range | [Source-end rules](source-end-rules.md) |
| Ordinary JSON spells supported now | [Authoring](shared-spells.md) |
| Shared repeat-save schedules, staged conditions and DC history (Batch 026 accepted) | [Authoring](shared-spells.md#conditions-lifetime-and-other-supported-fields) |
| Source-owned spell permission, payment and preparation (Batch 021 accepted) | [Casting permissions](spell-permissions-and-preparation.md) |
| Combined ordinary/Pact slot pools, fixed-level uses and ritual-only access (Batch 022 accepted) | [Slot and ritual casting](spell-slots-and-ritual-casting.md) |
| Attack/Flurry substitution and paid child continuations (Batch 028 accepted) | [Attack unit substitution](attack-unit-substitution.md) |
| Cast interruption, cancellation, stopping-costs, and recipient negation (Batch 029 accepted) | [Cast interruption and settlement](cast-interruption-and-settlement.md) |
| Physical size/mass/material facts, plane/space queries, and speeds/surface movement (Batch 030 built; awaiting review) | [Physical facts, space and movement](physical-facts-space-and-movement.md) |
| Shared source-owned numeric pools (bounded numeric, recovery, dice and fixed exchanges accepted) | [Resource pools](shared-resource-pools.md) |
| Generated per-spell availability and gaps | [Spell status](spell-status.md) |
| World dependency gaps | [Foundations](spell-foundations.md), [Wave 4 checklist](wave4-acceptance.md) |
| Familiar identity, casting and commands | [Find Familiar](find-familiar-2024.md) |
| Party death, preservation and recovery | [Recovery](party-recovery-2024.md) |
| Lasting Undead and expiring control | [Animate Dead](animate-dead-2024.md) |

Checked clauses certify only their named bounded version. Current availability
can include unfinished hooks; neither an allowlist nor schema validity proves
a normal working action. Keep raw inventories separate from acceptance evidence.

[Captured recipient grants](captured-grants.md) documents Batch P transfer,
shared values, recipient budgets and checkpoint identities. Independent review
accepts S-082/VS-63. Independent Q review accepts S-083/VS-64 for shared captured
weapon-attack bonuses, plus S-097/S-101/S-102 as VS-65/66/67 for fixed helping
modifiers and HP/Temporary HP allocations. See [party rules](party-intervention-and-allocation.md).
Broader intervention operations, roll hosts and casting consumers remain open.
