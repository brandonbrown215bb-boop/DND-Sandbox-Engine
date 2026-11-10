# Armor donning and doffing (S-252)

The local-room equipment controls report campaign time for armor changes:

| Armor | Don | Doff |
|---|---:|---:|
| Light | 1 minute | 1 minute |
| Medium | 5 minutes | 1 minute |
| Heavy | 10 minutes | 5 minutes |

Replacing armor includes doffing the old armor and donning the new armor.
Combat equipment controls refuse to don Medium or Heavy armor. The Shield
control in combat spends the character's Action; outside combat its one-action
don/doff is represented as six seconds. Armor class updates only after the
equipment change succeeds.

## Worn armor work in progress

CXM-07 is not complete. The current implementation reads an armor item's
`strength_requirement` and `stealth_disadvantage`, checks its armor category
against the wearer's training, and checks Shield training separately. It applies
the resulting movement and roll penalties and refuses new casts while wearing
untrained armor. Chain Mail, Splint and Plate carry their source Strength
requirements. The room and combat mode controls also offer a base AC choice
when multiple formulas are legal. Choices retain the exact source; the automatic
option takes the highest legal base. A source that is no longer eligible falls
back to the automatic result. A temporarily ineligible owned source keeps its
preference; a source that has gone is cleared when saving.
Protection additions and Barkskin's later floor still apply independently.
CXM-07 remains open until the actual controls and both fresh-process checkpoint
routes have passed the full assignment checks.
