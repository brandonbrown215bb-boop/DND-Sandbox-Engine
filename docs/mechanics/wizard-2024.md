# Wizard 2024 progression

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

**Rules authority:** [D&D Beyond Basic Rules, Wizard](https://www.dndbeyond.com/sources/dnd/br-2024/character-classes#Wizard).
**SRD basis:** 5.2.1. The Wizard class record now covers levels 1–20, including
the class feature progression, prepared spell and cantrip capacities, and full
spell slot table.

## Shared mechanics

- Spellcasting uses the common saved cantrip/prepared-spell choices and slot
  table. Wizard level 1 grants six saved level-1+ spellbook entries; each later
  Wizard level grants two learning choices. Prepared level-1+ spells must come
  from that saved book. Long Rest allows any legal prepared-list changes;
  Memorize Spell allows exactly one level-1+ replacement after a Short Rest.
- Spell copying is available from another active party Wizard's owned spellbook.
  It charges 50 GP per spell level and displays the two-hours-per-level
  transcription requirement. A campaign clock now exists, but this copy
  operation still does not advance/enforce those hours. Earlier schema-2 saves
  without a separate book reconstruct it from recorded prepared leveled spells;
  legacy save namespaces are not migrated.
- Ritual Adept exposes ritual spells recorded in the book when outside combat
  and resolves them without a slot through the spell behavior already modeled
  by the game. This generic Character Sheet ritual adapter still resolves
  against the caster and only reports added ritual time; it is not the full
  local-room casting coordinator. Later room paths support bounded utility
  effects and [Find Familiar ritual casting](find-familiar-2024.md), with
  their own targeting, components and elapsed-time checks.
- Spell Mastery saves one action spellbook choice at each of levels 1 and 2.
  Those spells are always prepared and can be cast at will at their lowest
  level; combat offers separate at-will and slot-based entries so a Wizard can
  still upcast them using a chosen eligible slot.
  A Long Rest grants one matching-level replacement of either mastery spell;
  the replacement opportunity is saved and consumed only by a valid change.
- Signature Spells saves two distinct level-3 spellbook choices and always
  prepares them. Each spell has an independent free cast at level 3, restored
  on a Short or Long Rest. The Signature choice permits any level-3 spell,
  including reaction spells; Counterspell uses the free Signature cast before
  an ordinary level-3 slot when both are available.
- Scholar uses the shared Expertise choice, restricted to its six eligible
  skills through the `allowed_skills` option on the common chooser.
- Ability Score Improvements and Epic Boon use shared progression choices.
- Arcane Recovery uses its existing targeted spell-slot recovery operation. It
  uses the Wizard's level-based slot table, excludes level 6+ slots, recovers no
  more than half the Wizard level in slot levels, and is limited to one use per
  Long Rest. The current combat flow automatically selects eligible slots.

## Partial or unavailable

- The original audit counted 33 spell records, 26 leveled; use current
  runtime inventory for catalog counts.
  Training permits recording the available spells in batches and preparing
  from the recorded book while further learning choices remain pending. Missing
  catalog entries do not consume those earned choices or block preparation.
  The added supported choices are Burning Hands, Thunderwave, Shatter, Cone of
  Cold, Power Word Kill, Ice Knife, Melf's Acid Arrow, and Disintegrate. Cone
  of Cold's area save and damage use the normal production resolver; Ice Knife's
  piercing attack and post-hit or post-miss cold burst, Acid Arrow's delayed
  damage, and Disintegrate's death effect are checked in combat. This still
  does not certify the full level-20 spellbook/list. Later content additions
  invalidate the audit's old missing-level counts; verify available choices
  through production training and runtime inventory.
- The generic sheet ritual entry and dedicated room ritual controls have
  different current capabilities. Full ritual catalog, target/component rules
  and time interruption are not certified by this audit.
- Subclass features are listed at levels 3, 6, 10, and 14. No Wizard subclass
  records currently ship.
- Starting equipment remains a minimal supported subset.

The shared spell and feature contracts are described in
[`modding_guide.md`](../modding_guide.md). Unsupported feature records are
preserved as reference data and omitted from player feature state.
