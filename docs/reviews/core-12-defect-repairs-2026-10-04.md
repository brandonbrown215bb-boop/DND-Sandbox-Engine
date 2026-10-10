# Core-12 audit defect repairs — 2026-10-04

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

This implements the demonstrated defects from the
[completion audit](core-12-completion-plan-2026-10-04.md). It does not complete
the remaining core-12 feature or spell catalog work. The earlier completion
chart remains a record of its audit snapshot.

| Defect | Repaired behavior | Main source |
|---|---|---|
| Evasion ignored the Rogue's feature ID and incapacitation | The owned `evasion` effect applies only to Dexterity saves that normally deal half damage on success. Success deals zero; failure deals half. Incapacitated, Paralyzed, Petrified, Stunned, and Unconscious disable it for both Rogue and Monk. | `src/combat/combat_action.gd` |
| Sneak Attack renewal and eligibility were incorrect; extra/reaction attacks bypassed it | Every creature's turn renews the marker. A Finesse or Ranged weapon is required. An adjacent living ally must also be conscious; Advantage/Disadvantage cancellation uses the resolver's final attack context. Ordinary, extra, Light, Cleave, and Opportunity attacks share the same rider and Cunning Strike choices. Opportunity attacks publish their actual attack record. Withdraw uses immediate optional movement, including off-turn. | `src/characters/rogue_rules.gd`, `src/combat/combat_state.gd` |
| Wizard copying compared a spell ID to class-list IDs; mastery could never change | Copying checks actual Wizard-list membership and retains the source-book, destination-book, level, duplicate, and gold checks. A Long Rest grants exactly one valid matching-level mastery replacement, saved with the existing schema. Initial choices remain free; rejected and unchanged selections do not spend the replacement. | `src/characters/class_progression.gd`, `src/characters/character.gd`, `src/ui/class_training.gd` |
| Empowered rerolled a whole formula and kept the higher total | The owner sees the actual damage dice and selects up to their Charisma modifier, minimum one. Only selected dice change; the new rolls stand even when lower. Constants and other dice survive. Invalid/empty selections spend no Sorcery Point. HP settlement waits for the choice and then uses the existing damage boundary. Critical spell dice, all Magic Missile darts, and all successful Scorching Ray damage remain selectable. An area cast reuses one damage roll and one cost for all targets. | `src/autoload/dice.gd`, `src/combat/combat_action.gd`, `src/combat/combat_hud.gd`, `src/combat/combat_state.gd` |
| Class grants and training dead ends were misleading | New Barbarians receive no Heavy Armor training or Fighter armor/shield package, and gain only the level-3 Primal Knowledge skill. New Wizards receive no armor training or starting armor. Nature Magician works for both Druid Primal Orders. Spellbook learning accepts available batches; preparation and mastery are usable while missing book entries remain pending. Other casters can save the available distinct spells and retain unfilled entitlements. The UI avoids impossible empty rows and explains catalog shortages. | Barbarian/Wizard/Druid class JSON, `druid_rules.gd`, `class_progression.gd`, `class_training.gd` |

## Save compatibility

The save schema and 2024 namespace are unchanged. Saved possessions and armor
proficiencies remain intact. Existing saves with the obsolete Barbarian
level-10 Primal Knowledge choice retain that choice and its skill; new
characters cannot earn it. The validator permits that bounded legacy record
only for a Barbarian of sufficient level with a valid distinct class skill.
Missing spell choices remain pending across JSON reconstruction. The new
Wizard mastery replacement flag defaults to false in older saves and is
validated as a Boolean entitlement available only at level 18 or higher.

## Verification

Verified with the existing Windows Godot 4.7 stable executable and disposable
per-case `user://` directories, without touching the owner's campaign saves.

- Project bootstrap, parse gate (85 scripts), and production boot pass.
- DataLoader reports zero content validation failures.
- Full Godot logic suite: **1,449 passed, zero failed**. Checks reproduce the
  repaired save/damage/choice behavior, including a lower replacement die,
  rejection without resource loss, and repeated settlement without repeated
  HP damage or cost.
- Six focused real-scene scenarios pass: `core12_audit_repairs`,
  `rogue_devious_strikes`, `wizard_capstone_cast_modes`,
  `core12_shared_rules`, `sorcerer_twinned_spell`, and
  `mixed_mechanics_encounter`. After the final target-decision handoff change,
  the audit-repair, Twinned, and mixed encounter scenarios were rerun and pass.
- The new audit-repair scenario exercises the actual Light and Opportunity
  reaction prompts, training buttons, and Empowered dice picker. It is included
  in the standard integration runner.

Retained local logs: `.artifacts/core12-repairs/final-gates/`,
`.artifacts/core12-repairs/verified-scenarios/`, and
`.artifacts/core12-repairs/final-scenarios/`. Intermediate failing logs are
retained separately for diagnosis and are not acceptance evidence.

Work and final checking were performed solo: the configured team routing and
role-contract files were unavailable. The engine checks provide production
evidence; this is not a separate independent-agent review.

## Remaining work

No spell descriptions or placeholder records were added to inflate coverage.
The Wizard catalog still contains 22 leveled spells versus 44 earned book
entries at level 20. Sorcerer and other caster lists also remain incomplete.
Training is now usable within those limits and preserves what is owed; full
catalog behavior remains the next staged content work, including the existing
Wizard levels 4, 6, 7, and 8 quest.

The broader audit plan still owns incomplete base features, choices,
exploration effects, shared rules, and separately tracked subclasses. These
repairs do not establish 100% implementation for any class. Starting equipment
remains a minimal modeled subset, rather than complete SRD package choices.
