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
| Purpose-aware event skill-check context and owned tools | [Check context](purpose-aware-check-context.md) |
| Owned post-roll ability-check modifiers | [Check modifiers](owned-ability-check-modifiers.md) |
| Ordinary JSON spells supported now | [Authoring](shared-spells.md) |
| Shared source-owned numeric pools (numeric, recovery and dice slices validated; fixed exchange awaiting separate acceptance) | [Resource pools](shared-resource-pools.md) |
| Generated per-spell availability and gaps | [Spell status](spell-status.md) |
| World dependency gaps | [Foundations](spell-foundations.md), [Wave 4 checklist](wave4-acceptance.md) |
| Familiar identity, casting and commands | [Find Familiar](find-familiar-2024.md) |
| Party death, preservation and recovery | [Recovery](party-recovery-2024.md) |
| Lasting Undead and expiring control | [Animate Dead](animate-dead-2024.md) |

Checked clauses certify only their named bounded version. Current availability
can include unfinished hooks; neither an allowlist nor schema validity proves
a normal working action. Keep raw inventories separate from acceptance evidence.
