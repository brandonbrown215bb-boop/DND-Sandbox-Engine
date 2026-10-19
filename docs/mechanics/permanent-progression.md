# Permanent acquisition and progression

Independent [Batch 018 review](../../.artifacts/planning/vocabulary-reports/batch-018-review.md)
accepts S-047/S-048 as VS-68/69 on an opt-in Character class host. This does not
convert the class catalog or implement multiclass spellcasting.

Classes declare `permanent_progression` with exactly four fields:

```json
{
  "starting": [
    {"type": "proficiency_grant", "skill_proficiencies": ["Stealth"], "expertise": ["Stealth"]},
    {"type": "equipment_grant", "item_id": "dagger", "quantity": 1}
  ],
  "multiclass": [
    {"type": "proficiency_grant", "armor_proficiencies": ["light"]}
  ],
  "level_hit_points": 5,
  "levels": [
    {"id": "second_class_level", "basis": "class", "at": 2,
     "grants": [{"type": "ability_delta", "ability": "CON", "amount": 2, "maximum": 20}]},
    {"id": "third_character_level", "basis": "character", "at": 3,
     "grants": [{"type": "max_hp_delta", "amount": 2}]}
  ]
}
```

The first class gets `starting`; each later class gets only its own `multiclass`
set on entry. Equipment goes into the backpack as ordinary exact copies, once.
Full backpacks refuse the whole level before changing HP, scores, entitlements,
proficiencies or inventory. Creation validates its complete initial grant set
before mutation. The creation review displays the actual authored starting gear.
If the complete initial grant cannot fit, equipment/review displays the reason
and Confirm stays disabled; refusal never registers an uninitialized character.

`proficiency_grant` accepts `skill_proficiencies`, `tool_proficiencies`,
`weapon_proficiencies`, `armor_proficiencies`, `saving_throw_proficiencies` and
`expertise` arrays. Expertise also supplies skill proficiency and uses twice the
current proficiency bonus. Overlapping permanent grants survive replacement of
an independent feature-choice grant. Tools/items must resolve to loaded content;
skills and saving throws must be known. No arbitrary script payload is supported.

`ability_delta` adds a positive integer to the underlying permanent score,
clamped to the declared maximum. CON modifier changes adjust maximum/current HP
for the character's actual total level through ClassProgression's existing
owner. A dead actor gains no current HP. `max_hp_delta` adds a positive fixed
integer, with current HP gained only by living actors. These are permanent gains;
this is not the reversible maximum-HP effect host in S-130.

Each `levels` entry has a distinct `id`, `basis` (`class` or `character`), integer
`at` (1–20) and `grants` array. An entry executes once at its threshold, or on
class entry if its character-level threshold was already earned. Character-level
entries on every acquired class observe the same actual level; class entries
only observe that class's allocation. Multiple entries express repeated gains.
The first-level base HP remains the class hit-die maximum plus permanent CON;
later levels add the chosen class's `level_hit_points` plus permanent CON,
minimum one. Proficiency bonus uses total character level. No progression RNG is
needed. Later level gains retain the existing living-character full heal.

The milestone's normal `Character.level_up()` path creates an unspent level.
Outside combat, Class Progression offers loaded eligible classes and a Gain class
level button. Confirming spends one entitlement; closing the sheet spends none.
The button captures the ordered state, so old/double-clicked buttons cannot spend
a later entitlement. Combat refuses confirmation.

This bounded host replaces native starting proficiency/equipment/slot fields.
Primary features may use the existing passive proficiency-choice contract for
weapon, armor and skill arrays only. Other choice fields refuse at validation;
the broader direct permanent-grant fields above do not extend that choice host.
Secondary classes currently require an empty `features_by_level`. Other native
features, resources, subclass/casting progression and level HP rolls are outside
this host and are refused rather than acquired partially. Existing classes
without this contract retain their current native progression. No shipped
class/spell/monster definition is changed.

Character stores ordered class history, pending levels and exact class/entry
receipts under `permanent_progression`, beside `class_levels` and already-applied
scores/HP/proficiencies/inventory. Receipts identify the class, boundary, actual
class/character levels and authored grants. Checkpoint preflight reconstructs
required receipts from ordered history and loaded definitions on both player and
party DTO paths before replacing the session. Missing, forged, changed or
inconsistent history/receipts refuse. Already-granted equipment need not still
exist: selling or consuming it does not recreate it on load.

Restore reads saved totals and identities; it never executes receipts. Pending
levels survive allowed checkpoints; open pickers do not. Existing save namespace,
legacy handling and allowed-checkpoint boundaries remain unchanged. See
[ADR-0030](../decisions/0030-permanent-acquisition-receipts.md).
