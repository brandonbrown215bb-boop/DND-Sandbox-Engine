# Wave 4 acceptance boundaries

> Priority update (2026-10-09): the [roadmap](../../roadmap.md) and
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) govern delivery.
> This document retains capability gaps and bounded acceptance checklists.
> Its old wave/class order is no longer an implementation instruction.

This checklist applies the two Wave 4 gates in
[spell-foundations.md](spell-foundations.md) to Crown's level 1–5 path.
Checked entries have production evidence recorded in the current operations
checkpoint. An available spell or a data record alone does not complete a gate.

## Gate A: playable foundations

### W4-F1: owned creatures

- [x] Stable owner/creature identity, retained HP and legal room placement.
- [x] Independent familiar initiative and owner seat; steed owner initiative.
- [x] Dismiss/recall/release, owner-incapacitation default and death cleanup.
- [x] Wild Companion ends at the owner's Long Rest; steed ends on owner death.
- [x] Encounter exit and safe checkpoint preserve creature damage and presence.
- [x] Four curated forms' movement, senses and supported skill Help.
- [x] Familiar borrowed senses and Reaction-based Touch delivery, player controls
  and refusal without lost resources.
- [x] Ordinary Find Familiar casting/materials and form replacement for those
  four forms; [clause checklist and limits](find-familiar-2024.md).
- [ ] Existence, command/control lifetime and expiry remain distinct for created
  undead and animated objects.
  Animate Dead has a [bounded production integration](animate-dead-2024.md);
  Animate Objects has interrupted, unvalidated implementation work; normal
  casting and player controls are unfinished. Finger of Death's Zombie remains
  open. See the [interruption checkpoint](../operations/current.md); the last
  accepted tests predate the Animate Objects edits.

### W4-F2: bodies and forms

- [x] Durable party corpse identity, death time, remains, willingness and recovery
  restrictions; distinguish unconscious party members from dead ones.
- [x] Eligible party recovery and ineligible refusals without resource loss;
  bounded Revivify/Gentle Repose [clauses and limits](party-recovery-2024.md).
- [ ] Curated reversible Beast forms retain character identity, equipment,
  movement, size, senses and the correct HP behavior for each feature/spell.
- [ ] Normal player path, failure path and safe checkpoint round trip for each.
  Body/recovery paths are verified; curated reversible forms remain open.

### W4-F3: authored NPC and illusion interaction

- [ ] Stable NPC identity, languages, knowledge, attitude and recognition.
- [ ] Authored requests/deception have authored outcomes; missing outcomes
  produce an explicit refusal.
- [ ] Illusion content is observable, discovery is per observer, and supported
  Investigation/physical interaction resolves the authored illusion.
- [ ] Appearance changes affect recognition without inventing belief.
- [ ] Normal player path, failure path and safe checkpoint round trip for each.

## Gate B: separate named integrations

Each integration needs its own SRD 5.2.1 clause checklist, production path and
explicit limits. W4-F1 names Find Familiar, companion gaps, Animate Dead,
Animate Objects and Finger of Death's Zombie. W4-F2 names Revivify, Gentle
Repose, Speak with Dead, Regenerate, Alter Self and Polymorph. W4-F3 names
Comprehend Languages, Tongues, Message, Charm Person/Monster, Disguise Self,
Minor Illusion and Silent Image. None is certified by this checklist alone.

Animal Shapes, Reincarnate and higher forms retain the additional dependencies
and first-version exclusions in the foundation roadmap. Speak with Dead's
knowledge delivery depends on Wave 5. These exclusions do not remove the
underlying corpse/form/interaction foundations from Gate A.
