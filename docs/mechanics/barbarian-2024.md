# Barbarian behavior audit

> Partial behavior/migration snapshot. Dated evidence and catalog counts
> below apply to their original audit, not automatic acceptance of the
> current tree. [Roadmap](../../roadmap.md) selects work;
> [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md) governs
> new rule execution. Existing named helpers are transitional.

Status: **partial**. This is the base-class level 1–20 audit, not a claim that
Barbarian or its subclasses are fully SRD-complete. Rules authority:
[SRD 5.2.1, Barbarian](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
printed pages 27–30. The checkpoint owns current test results.

## One feature status list

| Level | Feature | Evidence and remaining boundary |
|---|---|---|
| 1 | Traits/equipment | Class traits and skill list are curated. Actual creation verifies Greataxe, four Handaxes, an Explorer’s Pack and 15 GP, or 75 GP. Pack supplies remain a carried bundle rather than individually simulated tools. |
| 1 | Rage | Entry/extension costs, pool recovery, damage bonus, resistance, spell/Concentration refusal, upkeep expiry, ten-minute cap, immediate incapacitation cleanup, reload and campaign expiry have production checks. Initial enemy saves extend upkeep through the shared save helper; automatic repeat saves do not. SRD 5.2.1 supplies no voluntary-ending action. |
| 1 | Unarmored Defense | Existing shared armor calculation and checks; shield allowance is curated. No new live armor-selection acceptance in this pass. |
| 1, 4, 10 | Weapon Mastery | Shared acquisition/capacity, save validation and live non-Fighter follow-ups already checked. Uses the shared weapon rules. |
| 2 | Danger Sense | Dexterity save Advantage; this pass fixes exclusion for conditions that include Incapacitated. |
| 2 | Reckless Attack | Actual accepted and declined first-attack choices, later Strength attacks, an off-turn Opportunity Attack and next-turn cleanup are checked. Resolver checks cover thrown Strength attacks and attacks against Reckless targets. |
| 3 | Primal Knowledge | One extra skill choice uses shared progression. The real event check offers an optional Strength substitution while raging; declining updates the shown ability and actual roll payload. |
| 4, 8, 12, 16 | Ability Score Improvement | Shared saved improvements; the complete alternative feat catalog is outside current support. |
| 5 | Extra Attack | Two settled attacks for one Attack action are verified. Brutal Strike can be declined on the first swing and selected on the second. |
| 5 | Fast Movement | This pass fixes the reversed armor test. Focused checks verify the bonus without Heavy armor and its removal with Heavy armor. |
| 7 | Feral Instinct | Initiative Advantage is wired into combat setup. Not separately driven in this pass. |
| 7 | Instinctive Pounce | Existing checks verify half-Speed and armor restriction; entering Rage grants extra movement. Extending Rage no longer grants another Pounce. No new path/Opportunity Attack sampler. |
| 9, 13, 17 | Brutal Strike | Existing damage/effect checks plus nonstacking Hamstring replacement, expiry, and Bless plus Staggering save order. Forceful’s Huge-target push and straight movement are exercised on the live grid. The UI offers each eligible swing until committed, including shared follow-ups; the resolver enforces own-turn use, no Disadvantage, and consumption even on a miss. The live scenario selects Hamstring on swing two and excludes off-turn use. |
| 11 | Relentless Rage | Actual damage path, restored HP, rising DC, inspiration and rest reset have existing checks. Outright lethal damage skips the attempt. A saved sheet checkbox chooses before taking damage whether to attempt it across all damage sources; declining leaves the DC unchanged. This is a preselected policy, not a popup on each hit. Older saves default to the previous enabled behavior; malformed policies fail preflight. |
| 15 | Persistent Rage | Fixed duration, conscious-incapacitation survival, unconscious cleanup and saved clock are checked. Once-per-Long-Rest initiative recovery has existing logic checks and an inspected optional combat prompt. |
| 18 | Indomitable Might | Existing production checks cover Strength check/save floors. |
| 19 | Epic Boon | Two supported shared choices and persistence. The complete eligible feat/boon set is not implemented. |
| 20 | Primal Champion | Shared permanent increase is checked through JSON reload without replaying the grant. |
| 3, 6, 10, 14 | Berserker subclass | No Berserker registry record exists. This is outside the present base-class pass and must not be implied by Barbarian selection. |

## Accepted fixes and checks

`BarbarianRules` keeps a ten-minute budget and a shorter upkeep clock in saved
`feature_uses`. Attacks, initial enemy saves and the explicit Extend Rage action refresh only upkeep;
ordinary Bonus Actions do not automatically extend it. `Character` advances six
seconds per turn, and the existing campaign clock advances the same saved state.
Persistent Rage uses the whole remaining budget without upkeep. Older records
without a clock get a bounded clock on first use; past elapsed time cannot be
reconstructed. A Long Rest ends Rage.

SaveManager now rebinds a player's character reference to the loaded party
character with the same stable ID. The prior separate reconstructions could
show different state after campaign expiry or later character changes.

Development uses `-Suite logic -LogicGroup barbarian` for the small regression
set. `barbarian_action_flow` protects menu/grid/save interaction;
`barbarian_choice_flow` drives per-swing prompts, an off-turn reaction, sheet and
event choices, disk reload, save preflight and both creation alternatives.
Full logic runs once at shared-behavior batch acceptance. The initial focused
baseline reproduced eleven failures; the current small group has 43 checks.
Counts do not certify every feature row.

## Remaining scope

Complete alternative feat/boon catalogs, Berserker and individual supply
simulation remain outside this pass. Rows without separate live acceptance
retain that verification limit. This audit does not schedule the next class.

The configured review contracts were unavailable; the original implementation
was checked solo on Windows Godot 4.7, headless. No full integration-suite or
manual/rendered acceptance is claimed by that batch.

<a id="srd-feature-inventory"></a>

## SRD 5.2.1 feature inventory — 2026-10-26

Static source/inventory pass, not a rules audit or gameplay proof. SRD headings were read from `SRD_CC_v5.2.1.pdf` (pages are PDF page numbers) and matched by name/level to `data/core/classes/barbarian.json`. Repo status is the [feature matrix](../feature_matrix.md) exposure label / record `rules_status`. Registry slice is shown only where the slice registry names this feature or its generic consumer; `unassigned` means no documented owning slice. V-IDs are the [checklist](../reviews/dnd-code-vocabulary-gap-checklist.md) rows citing this feature as an example; they are open requirements, not owning slices. **Reviewed** means an SRD clause review recorded in the [slice registry](../planning/vocabulary-slices.md); every other row is unreviewed, whatever its `rules_status` says. Rows absent from repo data are not filled from memory.

SRD subclass: **Path of the Berserker** — absent from repo data.

| Kind | Lvl | SRD feature / repo record | SRD | Repo ID | Repo status | V-IDs | Registry slice (documented limit) | Review |
|---|---:|---|---|---|---|---|---|---|
| class | 1 | Rage | p.28 | `barbarian_rage` | mechanics-backed / unset | V-020, V-039, V-049, V-055, V-088 | unassigned | Unreviewed |
| class | 1 | Unarmored Defense | p.29 | `barbarian_unarmored_defense` | mechanics-backed / unset | — | S-085 (PARTIAL: first unarmored base-AC consumer only; class conversion open) | Unreviewed |
| class | 1 | Weapon Mastery | p.29 | `barbarian_weapon_mastery` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 2 | Danger Sense | p.29 | `barbarian_danger_sense` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 2 | Reckless Attack | p.29 | `barbarian_reckless_attack` | mechanics-backed / unset | V-001 | unassigned | Unreviewed |
| class | 3 | Barbarian Subclass | p.29 | `barbarian_barbarian_subclass` | quarantined / unset | — | unassigned | Unreviewed |
| class | 3 | Primal Knowledge | p.29 | `barbarian_primal_knowledge` | mechanics-backed / unset | — | unassigned | Unreviewed |
| class | 4 | Ability Score Improvement | p.29 | `barbarian_ability_score_improvement`, `barbarian_ability_improvement_8`, `barbarian_ability_improvement_12`, `barbarian_ability_improvement_16` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 5 | Extra Attack | p.29 | `barbarian_extra_attack` | mechanics-backed / unset | — | S-084 (PARTIAL: exclusive Extra Attack count consumer accepted; source-backed class conversion open) | Unreviewed |
| class | 5 | Fast Movement | p.29 | `barbarian_fast_movement` | mechanics-backed / 2024-supported | — | unassigned | Reviewed 2026-10-21 Conversion Batch 001: already generic |
| class | 7 | Feral Instinct | p.29 | `barbarian_feral_instinct` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 7 | Instinctive Pounce | p.29 | `barbarian_instinctive_pounce` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 9 | Brutal Strike | p.29 | `barbarian_brutal_strike` | mechanics-backed / 2024-supported | V-001, V-012 | unassigned | Unreviewed |
| class | 11 | Relentless Rage | p.30 | `barbarian_relentless_rage` | mechanics-backed / 2024-supported | V-020, V-088 | unassigned | Unreviewed |
| class | 13 | Improved Brutal Strike | p.30 | `barbarian_improved_brutal_strike_13` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 15 | Persistent Rage | p.30 | `barbarian_persistent_rage` | mechanics-backed / 2024-supported | V-049, V-055 | unassigned | Unreviewed |
| class | 17 | Improved Brutal Strike | p.30 | `barbarian_improved_brutal_strike_17` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| class | 18 | Indomitable Might | p.30 | `barbarian_indomitable_might` | mechanics-backed / 2024-supported | V-008 | unassigned | Unreviewed |
| class | 19 | Epic Boon | p.30 | `barbarian_epic_boon` | mechanics-backed / 2024-supported | — | S-049/S-050/S-084/S-085/S-103/S-104 (fixture-only Origin/ASI feat acquisition; feat content, prerequisites, ability benefits, Fighting Style grants, level-19 feat path open) | Unreviewed |
| class | 20 | Primal Champion | p.30 | `barbarian_primal_champion` | mechanics-backed / 2024-supported | — | unassigned | Unreviewed |
| repo-only class | 3 | Primal Path | Placeholder for subclass level; SRD subclass body not in repo | `barbarian_primal_path` | quarantined / unset | — | unassigned | Unreviewed |
| subclass | 3 | Frenzy | p.30 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 6 | Mindless Rage | p.30 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 10 | Retaliation | p.30 | — | absent | — | unassigned | Unreviewed (absent) |
| subclass | 14 | Intimidating Presence | p.30 | — | absent | — | unassigned | Unreviewed (absent) |

<a id="srd-clause-decomposition-batch-2"></a>
## SRD clause decomposition — batch 2 (2026-10-26)

**Status: partial.** Static source review for planning. It does not change runtime code, content or availability. Clauses come only from `SRD_CC_v5.2.1.pdf` (PDF page = printed page). Loaded records come from the production DataLoader export: Linux headless Godot 4.7.2, `res://scenes/feature_inventory_export.tscn`, commit `0196f328f1de` (docs-only over `ede0a3c`), registry SHA-256 `70a83cc74e530743e90f8fadc992bd0651f56b51cb84b06cd73fcaf22187845e`, 0 validation failures. The supported Windows runner was not reachable from this environment, so the export is not Windows evidence. Execution is taken from the loaded record: `native` = `resolver`, `executor` = `executor: class_feature`, `effects` = data effects. Slices and limits are quoted from the [slice registry](../planning/vocabulary-slices.md); a citation does **not** prove that this clause is covered. Coverage is proven only by that slice's acceptance evidence for this feature.

Classification: **ES** existing supported (class-doc production checks; shared-slice coverage unproven unless stated) · **PL** planned under an existing slice · **HC** missing host/control, or continuation of an accepted bounded slice · **GAP** genuinely unaccounted reusable capability (new planned row) · **SRC** source gap, deferral or ADR-0023 judgment · **ACQ** acquisition/advancement: grant logged by Subclass Stager (not classified here).

### Barbarian (pp.28–30): 22 loaded records reviewed against SRD

Loaded: 1 `executor`, 15 `effects`, 6 `native` (`barbarian_rules`). Refused by DataLoader as effectless: `barbarian_primal_path`, `barbarian_barbarian_subclass` (subclass-choice levels: ACQ). Berserker (p.30) has no loaded record, so its clauses are unreviewed (no repo host to classify).

| Feature (lvl, record, exec) | SRD clause | Class. | Slice / limit or gap |
|---|---|---|---|
| Rage (1, `barbarian_rage`, executor) | Bonus Action entry; not while wearing Heavy armor | ES | Class-doc production checks; shared action-cost host via executor |
| | Uses per table; regain 1 on Short Rest, all on Long Rest | ES / PL | S-007 (VS-07: fixed Short Rest / fill Long Rest). Short Rest "one" amount: the S-007 limit is "fixed", so a one-use regain is covered only if VS-07 fixtures include amount 1 (unproven) |
| | Resistance to Bludgeoning/Piercing/Slashing | ES | Native checks; shared timed self-grant S-012 is AC-only (VS-12), so a shared resistance grant is HC |
| | Rage damage bonus on Strength attacks, scaled by table | ES / HC | Native checks; table scaling: S-048/V-007 (VS-69 level deltas) |
| | Advantage on Strength checks/saves | ES | S-091 (VS-29 declared Advantage policy) |
| | No spellcasting or Concentration while raging | ES | Native checks (spell/Concentration refusal) |
| | Lasts until end of next turn; extended by an attack roll, a forced save or a Bonus Action; 10-minute cap | ES / PL | Native upkeep clock; shared duration S-141 (Planned) |
| | Ends on donning Heavy armor or becoming Incapacitated | ES | Native checks; shared S-072 (VS-71 action/status/equipment termination) |
| Unarmored Defense (1, effects) | AC = 10 + Dex + Con while no armor; Shield allowed | ES | Shared armor calculation; S-085 cites Unarmored Defense (VS-122 bounded) |
| Weapon Mastery (1, effects) | Mastery properties of chosen weapons; change on Long Rest | ACQ / PL | Choice and persistence: Subclass Stager. Use: S-085 (VS-122), S-127 (Planned) |
| Danger Sense (2, effects) | Advantage on Dex saves unless Incapacitated | ES | S-091 (VS-29) |
| Reckless Attack (2, effects) | First-attack choice: Advantage on own Str attacks; attacks against you have Advantage until next turn | ES | S-091 (VS-29); own-turn window S-056 (VS-54) |
| Primal Knowledge (3, effects) | Extra skill proficiency | ACQ | grant logged by Subclass Stager |
| | Raging: use Str for listed skill checks | ES | Native event check; shared ability replacement S-126 (VS-116 is weapon/spell-DC only), so a check-ability swap is HC |
| ASI (4/8/12/16, effects) | Feat / ASI | ACQ | grant logged by Subclass Stager |
| Extra Attack (5, effects) | Two attacks per Attack action | ES | S-084 (VS-120 owned parameter upgrades); S-146 (VS-97) |
| Fast Movement (5, effects) | +10 ft Speed without Heavy armor | ES | Conversion Batch 001: already generic; S-179 (VS-102) |
| Feral Instinct (7, effects) | Advantage on Initiative | ES | S-091 (VS-29); no live acceptance in class doc |
| Instinctive Pounce (7, native) | Move up to half Speed as part of the Rage Bonus Action | ES / **GAP** | Native checks. Shared granted movement outside the normal budget: **FEAT-B2-MOVE** |
| Brutal Strike (9, native) | With Reckless Attack, forgo Advantage on one Str attack without Disadvantage | ES / HC | Native checks; shared forgo-Advantage option is HC on S-091 + S-085 |
| | On hit: +1d10 damage of the weapon's type, plus one effect | ES / HC | S-084 option upgrade; typed extra damage S-013 is next-hit/fixed (VS-13), so per-hit choice is HC |
| | Forceful Blow: push 15 ft straight away, then move half Speed straight toward the target without provoking OAs | ES / **GAP** | Native live-grid checks. Shared forced and granted movement: **FEAT-B2-MOVE** |
| | Hamstring Blow: Speed −15 ft until your next turn; most recent only | ES / HC | Native checks; S-179 speed (VS-102); non-stacking replacement S-057 (VS-55) |
| Relentless Rage (11, native) | At 0 HP while raging, not outright death: DC 10 Con save; success sets HP to 2 × level | ES | S-117 (VS-111), S-118 (VS-112) |
| | DC +5 per use; resets on Short/Long Rest | ES | S-118 / S-090 (VS-96) |
| Improved Brutal Strike (13, native) | Staggering Blow: Disadvantage on next save; no OAs until your next turn | ES / PL | Native; next-save matcher S-076 (Planned); OA forbid HC |
| | Sundering Blow: another creature's next attack gets +5 before your next turn; once per roll | ES / PL | S-076 (Planned); S-057 (VS-55) once per roll |
| Persistent Rage (15, native) | On Initiative regain all Rage uses; once per Long Rest | ES | S-062 (VS-62 turn-start/Initiative recovery) |
| | Rage lasts 10 min without extension, ends only on Unconscious or Heavy armor | ES | Native checks; S-072 (VS-71) |
| Improved Brutal Strike (17, native) | 2d10 and two different effects | ES | S-084 (VS-120) |
| Indomitable Might (18, effects) | Str check/save total below Str score: use the score | ES | S-038 (VS-45) |
| Epic Boon (19, effects) | Feat choice | ACQ | grant logged by Subclass Stager; boon bodies are SRC-01 feats |
| Primal Champion (20, effects) | Str and Con +4, max 25 | ES | S-048 (VS-69) |

Barbarian totals: 22/22 loaded records decomposed (100% of loaded; 0 of the Berserker records, which are absent). New gap: FEAT-B2-MOVE. Native-only behaviors still needing shared hosts (HC): resistance self-grant, check-ability swap, forgo-Advantage option, per-hit typed damage choice, OA prohibition.
