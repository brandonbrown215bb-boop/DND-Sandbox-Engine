# Fighter 2024: Levels 1–20

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

Authority: [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf), Fighter and Champion pages 47–49, Fighting Styles and Epic Boons pages 87–88, weapons pages 90–91.

## Playable progression

| Level | New behavior |
|---|---|
| 1 | Fighting Style, three trained Weapon Masteries, two Second Wind uses |
| 2 | Action Surge and Tactical Mind |
| 3 | Champion: weapon criticals on 19–20, Initiative and Athletics advantage, optional half-speed movement after a critical hit |
| 4 | Ability improvement, fourth mastery, third Second Wind use |
| 5 | Two attacks per Attack action; Tactical Shift after Second Wind |
| 6 | Ability improvement |
| 7 | Champion's second Fighting Style |
| 8 | Ability improvement |
| 9 | Indomitable: one failed-save reroll with Fighter level added; Tactical Master |
| 10 | Fourth Second Wind use, fifth mastery; Champion gains Heroic Inspiration at turn start |
| 11 | Three attacks per Attack action |
| 12 | Ability improvement |
| 13 | Two Indomitable uses; Studied Attacks |
| 14 | Ability improvement |
| 15 | Champion weapon criticals on 18–20 |
| 16 | Ability improvement; sixth mastery |
| 17 | Two Action Surge uses and three Indomitable uses |
| 18 | Champion Survivor: death-save advantage, 18–20 revives at 1 HP, bloodied turn-start healing of 5 + CON modifier while above zero HP |
| 19 | Combat Prowess Epic Boon: +1 ability, maximum 30; Peerless Aim turns one missed attack into a hit until the next turn |
| 20 | Four attacks per Attack action |

## Choices and use

Champion now has a separate subclass record. It is selected automatically at
level 3 when it is the sole installed option. Additive subclasses attach to
Fighter without replacing its record; multiple options are chosen on the
Character Sheet. Other subclasses receive no Champion grants. Ability
improvements use the same saved entitlement controls as Monk and Rogue.

Open the Character Sheet outside combat to choose initial skills, styles,
mastery weapons, equipment, ability improvements and Combat Prowess. Unspent
improvements remain available after an interruption or save/load. Select the
same ability twice for +2, or different abilities for +1 each, capped at 20.
Constitution increases update HP for all existing levels.

The four SRD styles are Defense, Archery, Great Weapon Fighting and Two-Weapon
Fighting. One style can be replaced after gaining a Fighter level. A Long Rest
permits one mastery replacement. New mastery slots and Champion's second style
can be filled later. Initial defaults are Defense, longsword/greatsword/longbow,
and Athletics/Perception; change these before the first combat.

Second Wind costs a Bonus Action and heals d10 + Fighter level. A Short Rest
restores one use; a Long Rest restores all. Tactical Mind offers a d10 after a
failed event check and spends Second Wind only if the new total succeeds.
Tactical Shift offers immediate half-speed movement without Opportunity Attacks,
preserving normal movement. Cancel forfeits only this optional movement.

Action Surge activation is free, once per turn. It grants one additional
non-Magic action, restores on Short/Long Rest, and cannot bypass spell costs
through altered command metadata. Extra Attack belongs to each Attack action,
including Surge. Loading weapons still fire once per action. A dead target
leaves remaining swings available for another legal target.

Weapon Mastery supports Graze, Vex, Sap, Slow, Topple, Push, Cleave and Nick.
Tactical Master selects the trained weapon's property or Push/Sap/Slow from the
sheet, including during combat. Sap/Slow expire at their owner's next turn;
overlapping Fighters retain separate effects. Push uses two clear unoccupied
tiles away from the attacker and excludes Huge/Gargantuan targets. Cleave and
Light attacks offer nearby legal targets, with Nick preserving the Bonus Action.
Two-Weapon Fighting restores the Light extra attack's positive ability damage.
Off-hand weapons require a separate owned Light weapon and a free shield hand.

The sheet exposes automatic-use preferences for Indomitable, Heroic Inspiration
and Peerless Aim. Inspiration can reroll a missed weapon attack, or be armed
for the next owned die at or below half its maximum. The latter covers damage,
healing, saves, checks, Initiative and bonus dice; it always uses the new die,
spends once and disarms. Another character's dice never spend this resource.
Indomitable uses the new saving throw even if it still fails,
adds Fighter level and recharges only on a Long Rest. Studied Attacks gives the
next attack against a missed creature advantage through the end of the next
turn. Peerless Aim also works on spell attacks; Champion's expanded critical
range applies only to weapons.

## Scope and limitations

Champion is the implemented SRD subclass. Ability Score Improvement is the
implemented regular feat choice; Combat Prowess is the implemented Epic Boon.
Other subclasses and feat catalogs remain unavailable. Existing starting gear
remains chain mail, shield and longsword; alternative starting packages are not
a new creation flow. Crown still awards levels only through 5, although normal
Character progression and saved Fighters support level 20.

Optional dice spending uses visible preferences selected before the roll rather
than a blocking popup for each die. Opportunity Attacks use the same mastery and
Champion critical-movement paths, retain the reacting owner's identity, and
resolve before leaving reach. Push interrupts the proposed movement rather than
being overwritten by it. Cleave is limited per creature's turn. Indomitable also
rerolls failed death saves before successes/failures are recorded. It checks
the modified total, including Bless/Bane, so a Bless-converted success does not
spend a use. Natural 1/20 and Survivor's revival outcomes retain their existing
precedence; a reroll uses only its final modifier dice and Fighter-level bonus.

## Verification

`src/fighter_checks.gd` exercises all twenty real level-ups, saved choices,
resource capacity/recovery, ability caps/HP, styles, mastery effects, Tactical
Mind, Indomitable/death saves, Studied Attacks, Survivor, any-die Inspiration and
Peerless Aim. The production
`fighter_progression` viewport scenario covers one through four seats, the real
feature menu, restricted Surge actions, four settled attacks, stale targeting,
Tactical Shift's actual popup/movement, out-of-turn Push/Cleave/critical movement,
chained prompts and level-20 SaveManager round-trips.
See the [slice registry](../planning/vocabulary-slices.md) for verified shared-host boundaries.

<a id="srd-feature-inventory"></a>

## SRD 5.2.1 feature inventory — 2026-10-26

Static source/inventory pass, not a rules audit or gameplay proof. SRD headings were read from `SRD_CC_v5.2.1.pdf` (pages are PDF page numbers) and matched by name/level to `data/core/classes/fighter.json` and `data/core/subclasses/champion.json`. Repo status is the [feature matrix](../feature_matrix.md) exposure label / record `rules_status`. Registry slice is shown only where the slice registry names this feature or its generic consumer; `unassigned` means no documented owning slice. V-IDs are the [checklist](../reviews/dnd-code-vocabulary-gap-checklist.md) rows citing this feature as an example; they are open requirements, not owning slices. **Reviewed** means an SRD clause review recorded in the [slice registry](../planning/vocabulary-slices.md); every other row is unreviewed, whatever its `rules_status` says. Rows absent from repo data are not filled from memory.

SRD subclass: **Champion** — present as `champion`.

| Kind | Lvl | SRD feature / repo record | SRD | Repo ID | Repo status | V-IDs | Registry slice (documented limit) | Review |
|---|---:|---|---|---|---|---|---|---|
| class | 1 | Fighting Style | p.47 | `fighter_fighting_style` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 1 | Second Wind | p.48 | `fighter_second_wind` | mechanics-backed / 2024-supported | — | S-006/S-094/S-126/S-146/S-179 (Conversion Batch 001 blocker) | Reviewed 2026-10-21 Conversion Batch 001: Blocked (S-006/S-094/S-126/S-146/S-179) |
| class | 1 | Weapon Mastery | p.48 | `fighter_weapon_mastery` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 2 | Action Surge | p.48 | `fighter_action_surge` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 2 | Tactical Mind | p.48 | `fighter_tactical_mind` | mechanics-backed / 2024-supported | V-035 | unassigned | Unreviewed |
| class | 3 | Fighter Subclass | p.48 | (subclass choice) | repo uses `subclass_level` = 3 | — | unassigned | Unreviewed |
| class | 4 | Ability Score Improvement | p.48 | `fighter_ability_score_improvement_4`, `fighter_ability_score_improvement_6`, `fighter_ability_score_improvement_8`, `fighter_ability_score_improvement_12`, `fighter_ability_score_improvement_14`, `fighter_ability_score_improvement_16` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 5 | Extra Attack | p.48 | `fighter_extra_attack` | mechanics-backed / 2024-supported | — | S-084 (PARTIAL: exclusive Extra Attack count consumer accepted; source-backed class conversion open) | Unreviewed |
| class | 5 | Tactical Shift | p.48 | `fighter_tactical_shift` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 9 | Indomitable | p.48 | `fighter_indomitable` | mechanics-backed / 2024-supported | V-089 | unassigned | Unreviewed |
| class | 9 | Tactical Master | p.48 | `fighter_tactical_master` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 11 | Two Extra Attacks | p.48 | `fighter_two_extra_attacks` | mechanics-backed / 2024-supported | — | S-084 (PARTIAL: exclusive Extra Attack count consumer accepted; source-backed class conversion open) | Unreviewed |
| class | 13 | Studied Attacks | p.48 | `fighter_studied_attacks` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 19 | Epic Boon | p.48 | `fighter_epic_boon` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 20 | Three Extra Attacks | p.48 | `fighter_three_extra_attacks` | mechanics-backed / 2024-supported | — | S-084 (PARTIAL: exclusive Extra Attack count consumer accepted; source-backed class conversion open) | Unreviewed |
| subclass | 3 | Improved Critical | p.49 | `champion_improved_critical` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| subclass | 3 | Remarkable Athlete | p.49 | `champion_remarkable_athlete` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| subclass | 7 | Additional Fighting Style | p.49 | `champion_additional_fighting_style` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| subclass | 10 | Heroic Warrior | p.49 | `champion_heroic_warrior` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| subclass | 15 | Superior Critical | p.49 | `champion_superior_critical` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| subclass | 18 | Survivor | p.49 | `champion_survivor` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |

<a id="srd-clause-decomposition-batch-2"></a>
## SRD clause decomposition — batch 2 (2026-10-26)

**Status: partial.** Static source review for planning. It does not change runtime code, content or availability. Clauses come only from `SRD_CC_v5.2.1.pdf` (PDF page = printed page). Loaded records come from the production DataLoader export: Linux headless Godot 4.7.2, `res://scenes/feature_inventory_export.tscn`, commit `0196f328f1de` (docs-only over `ede0a3c`), registry SHA-256 `70a83cc74e530743e90f8fadc992bd0651f56b51cb84b06cd73fcaf22187845e`, 0 validation failures. The supported Windows runner was not reachable from this environment, so the export is not Windows evidence. Execution is taken from the loaded record: `native` = `resolver`, `executor` = `executor: class_feature`, `effects` = data effects. Slices and limits are quoted from the [slice registry](../planning/vocabulary-slices.md); a citation does **not** prove that this clause is covered. Coverage is proven only by that slice's acceptance evidence for this feature.

Classification: **ES** existing supported (class-doc production checks; shared-slice coverage unproven unless stated) · **PL** planned under an existing slice · **HC** missing host/control, or continuation of an accepted bounded slice · **GAP** genuinely unaccounted reusable capability (new planned row) · **SRC** source gap, deferral or ADR-0023 judgment · **ACQ** acquisition/advancement: grant logged by Subclass Stager (not classified here).

### Fighter (pp.47–48): 19 loaded records reviewed against SRD

Loaded: 10 `native` (`fighter_rules`), 1 `executor` (Second Wind), 8 `effects`.

| Feature (lvl, record, exec) | SRD clause | Class. | Slice / limit or gap |
|---|---|---|---|
| Fighting Style (1, native) | Fighting Style feat choice; replace one on Fighter level-up | ACQ | grant logged by Subclass Stager. Style bodies are SRD feats (pp.87–88) and are absent from `data/core` (SRC-01) |
| Second Wind (1, executor) | Bonus Action: regain 1d10 + Fighter level HP | ES / SRC | Conversion Batch 001: blocked by native Tactical Mind/Shift hooks (S-006/S-094/S-126/S-146/S-179) |
| | 2/3/4 uses by table; regain 1 on Short Rest, all on Long Rest | ES / PL | S-007 (VS-07 fixed Short / fill Long); table scaling S-048/V-007 |
| Weapon Mastery (1, effects) | Three kinds; change one on Long Rest; more by table | ACQ / PL | Choice: Subclass Stager. Use: S-085 (VS-122), S-127 (Planned) |
| Action Surge (2, native) | On your turn, one additional action except Magic | ES / PL | Native checks; shared S-160 (Planned extra action budgets) |
| | Once per Short/Long Rest; at 17, twice per rest but once per turn | ES | S-007 (VS-07); S-056 (VS-54 own-turn limits) |
| Tactical Mind (2, native) | On a failed ability check, spend Second Wind to add 1d10 | ES | Native checks; S-100 (VS-51 result-payment predicates) |
| | Use not expended if the check still fails | ES | S-100 (VS-51) |
| Fighter Subclass (3) | Subclass choice | ACQ | grant logged by Subclass Stager |
| ASI (4/6/8/12/14/16, effects) | Feat / ASI | ACQ | grant logged by Subclass Stager |
| Extra / Two / Three Extra Attacks (5/11/20, native) | 2/3/4 attacks per Attack action on your turn | ES | S-084 (VS-120); S-146 (VS-97) |
| Tactical Shift (5, native) | On Bonus Action Second Wind, move half Speed without provoking OAs | ES / **GAP** | Native popup/movement checks. Shared: **S-241** |
| Indomitable (9, native) | Failed save: reroll + Fighter level; must use the new roll | ES | S-105 (VS-26 mandatory-new reroll; event/choice-check host). A combat-save host is HC |
| | 1/2/3 uses per Long Rest (levels 9/13/17) | ES | S-007 (VS-07) |
| Tactical Master (9, native) | Replace the mastery property with Push, Sap or Slow for one attack | ES / PL | S-085 (VS-122 options); S-127 (Planned). Push displacement: **S-241** |
| Studied Attacks (13, native) | After a miss, Advantage on next attack vs that creature before end of your next turn | ES / PL | S-076 (Planned next selected attack grant); V-051 cites C-Fighter; S-030 (VS-39) |
| Epic Boon (19, effects) | Feat choice | ACQ | grant logged by Subclass Stager. Repo Combat Prowess: SRD Boon of Combat Prowess p.88 (Peerless Aim: miss becomes hit, once per your turn): S-092 (VS-30) + S-056 (VS-54) |

**Source note (SRC, ADR-0023):** fighter-2024.md describes Heroic Inspiration that can be "armed for the next owned die at or below half its maximum". The SRD rule (p.8, Heroic Inspiration) is: expend it "to reroll any die immediately after rolling it, and you must use the new roll"; you have at most one. The pre-armed threshold is a UI policy, not SRD text. Record it as an ADR-0023 judgment. No change is made here.

### Champion (p.49): 6 loaded records reviewed against SRD

All 6 are `native` (`fighter_rules`). Improved and Superior Critical carry `modify_crit_range` data.

| Feature (lvl) | SRD clause | Class. | Slice / limit or gap |
|---|---|---|---|
| Improved Critical (3) | Weapon and Unarmed Strike attacks crit on 19–20 | ES / **GAP** | Native checks (weapons only). Shared natural-roll outcome threshold: **S-240**. Repo note "applies only to weapons" vs SRD "weapons and Unarmed Strikes": SRC/ADR-0023 check needed |
| Remarkable Athlete (3) | Advantage on Initiative and Str (Athletics) checks | ES | S-091 (VS-29) |
| | Right after a Critical Hit, move half Speed without provoking OAs | ES / **GAP** | Native checks (including off-turn). **S-241** |
| Additional Fighting Style (7) | Another Fighting Style feat | ACQ | grant logged by Subclass Stager |
| Heroic Warrior (10) | In combat, give yourself Heroic Inspiration at turn start if you lack it | ES / HC | Native; continuation of S-062 (VS-62 turn-start floor recovery) for a single-instance token host |
| Superior Critical (15) | Crit on 18–20 | ES / **GAP** | **S-240** (same Unarmed Strike note) |
| Survivor (18) | Defy Death: Advantage on Death Saves | ES | S-091 (VS-29) |
| | Death Save 18–20 counts as a 20 | ES / **GAP** | **S-240**; S-226 (Planned Death Save roll choices) is adjacent |
| | Heroic Rally: at turn start, if Bloodied and ≥ 1 HP, regain 5 + Con mod | ES / HC | Native; continuation of the S-062 turn-start window plus S-024 (VS-27) predicates for a healing payload |

Fighter totals: 19/19 loaded class records and 6/6 Champion records decomposed. New gaps: S-241, S-240.
