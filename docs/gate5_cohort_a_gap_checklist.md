# Gate 5 Cohort A Gap Checklist

Date: 2026-08-10  
Scope: Fighter, Rogue, Wizard, and Cleric at levels 1–5.

This checklist compares the current production class records, the curated
runtime exposure, the normal creation/integration fixtures, and the Gate 5
exit criteria in `roadmap.md`. It records only confirmed gaps or evidence that
is currently too indirect to prove the criterion.

## Evidence used

- Production records: `data/core/classes/*.json` and curated access/effects in
  `src/autoload/data_loader.gd`.
- Generated exposure: `docs/feature_matrix.md`.
- Automated rules coverage: `src/test_runner.gd`, `src/viewport_harness.gd`,
  and the Windows runner. The current logic suite passes 666 assertions and
  the full isolated integration run passes every named scenario, including the
  mixed-mechanics and action-resource round-trip fixtures.
- Gate contract: `roadmap.md`, Gate 5 RULE-05 through RULE-10 and its exit
  criteria.

`mechanics-backed` means the current source exposes an executable effect or
resolver and has a named automated check. `quarantined` means the source
explicitly prevents the record from reaching player state; it is not coverage.
`unproven` means the current evidence does not establish the normal-path or
Gate 5 contract even when a lower-level resolver exists.

## Ordered class checklist

| Order | Class | Current mechanics-backed slice | Confirmed gaps or unproven criteria | Next bounded card |
|---:|---|---|---|---|
| 1 | Fighter | Second Wind, Action Surge, and Extra Attack reach levels 1–5 through the current character fixture. Normal creation now proves Human/Fighter starting chain mail, shield, and longsword selection and equipped state. | Fighting Style, Weapon Mastery, Tactical Mind, Martial Archetype/subclass, ASI, Martial Versatility, and Tactical Shift are quarantined; no accepted scope decision records which are intentionally excluded for the Crown band. | `Q-20260810-010129-1f6d` |
| 2 | Rogue | Sneak Attack, Cunning Action, and Uncanny Dodge have executable effects and deterministic reaction/resource checks. Normal creation now proves Human/Rogue starting leather armor and shield selection and equipped state. | Expertise and skill interactions are quarantined and have no accepted Crown-band scope. Cunning Strike and its costed choices are quarantined. | `Q-20260810-010129-f2f2` |
| 3 | Wizard | Arcane Recovery is mechanics-backed; normal creation now proves Human/Wizard starting equipment, curated fire_bolt and magic_missile ownership, and level-1 slots; spell command validation rejects inaccessible spells. | No visible normal-path preparation/acquisition policy is proven beyond initial curated access. Concentration, owner-facing reactions, save spells, area spells, and level-appropriate progression are not covered as one wizard path. Ritual Adept, Arcane Tradition, Scholar, Cantrip Formulas, ASI, and Memorize Spell are quarantined without a Crown-band scope decision. | `Q-20260810-010129-8c1f` |
| 4 | Cleric | Harness Divine Power has a curated spell-slot recovery effect. Normal creation now proves Human/Cleric starting equipment, curated light/bless/cure_wounds ownership, and level-1 slots. | Preparation, healing, buffs, save spells, concentration, and the Channel Divinity/Turn Undead path are not proven through a normal cleric combat path. Divine Domain, Divine Order, Protector, Thaumaturge, Channel Divinity, Divine Spark, subclass, ASI, and level-5 undead features are quarantined without a Crown-band scope decision. | `Q-20260810-010129-ecbb` |

## Cross-cutting Gate 5 gaps

The first cross-cutting gap is now closed by the named production-data fixture;
the remaining items must not be treated as covered by the per-class fixture or
by the green test count.

1. **Between-encounter action/resource persistence now has an automated
   boundary proof, but still needs normal-flow review.** The named
   `action_resource_round_trip` fixture spends a production Fighter feature and
   Wizard spell slot, saves at the overworld safe point, reloads through the DTO
   boundary, and boots the next combat with the remaining resources. Human review
   must still confirm the readable normal save/relaunch experience.
2. **CombatState separation remains incomplete.** `CombatState` still contains
   input interpretation, action resolution calls, turn progression, scene
   transition handling, and presentation/VFX coordination. The current command
   boundary is progress, not proof of RULE-04's separated responsibilities.
3. **Normal-path class proof is still incomplete.** The normal creation matrix
   now proves player count, stable seats, party ownership, starting equipment
   for all four cohort classes, and curated level-1 Wizard/Cleric spell access.
   It does not yet prove level progression, visible spell preparation, combat
   action availability, or the full expected action set through the same player
   path.

## Recommended execution order

The mixed-mechanics encounter and resource round-trip are now automated. Keep
the remaining class proof and CombatState boundary cards separate from the Gate
5 decision: a passing matrix does not satisfy the normal-path or responsibility
exit criteria. A quarantined record stays unavailable until its scope is
accepted and its mechanics are implemented and tested.
