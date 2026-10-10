# Spell foundations and Wave 2 delivery review

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

Reviewed 2026-10-07 against the current working tree, using Windows Godot
4.7.stable.official.5b4e0cb0f. This is a bounded delivery review, not a complete
spell-clause audit. The initial review made no implementation changes; the
owner subsequently authorized the corrections recorded below.

## Correction acceptance — 2026-10-07

All five findings below are resolved. Wave 2's supported first versions can
proceed with their existing explicit deferrals; complete SRD rules certification
remains open.

- Chain Lightning selection, previews and final validation measure every
  secondary bolt from the first target. The live cast resolves creatures,
  authored objects, carried copies and dropped copies, with an outside-radius
  refusal that spends nothing.
- Spells without a sight prerequisite accept known unseen targets, retain wall
  checks and apply unseen attack modifiers. Magic Missile and Healing Word
  now declare their existing sight prerequisites explicitly. A Blinded caster
  can cast Mage Armor on themselves.
- Replacing a curse-bound equipped copy refuses before changing either copy's
  location. Replacement succeeds after its binding is removed.
- Only actual emitters supply light; Dim Light cannot reduce ambient Bright
  Light. Distant illuminated targets remain visible across natural darkness.
  True Seeing and Blindsight retain physical wall obstruction.
- The affected True Strike live check exposed a related component preflight
  defect: its equipped weapon now supplies its Material component, and that
  hand can also perform its Somatic component, without a separate pouch.
  Proficiency remains a cast requirement.

Final Windows Godot verification: bootstrap, 152-script parse gate and
production boot passed; **1,277 logic checks passed, zero failed** across
`spells,effects,world,combat,conditions,persistence`. Nine affected live
scenarios passed, with no engine/script errors in their accepted runs:

- `.artifacts/wave2-review-fixes/final/`: `combat_light_visibility_flow`
  (20 assertions), `true_strike_spell_flow` (4), and final logic/gate logs.
- `.artifacts/wave2-review-fixes/confirmed/`:
  `chain_lightning_mixed_targets_flow` (6).
- `.artifacts/wave2-review-fixes/live/`:
  `chain_lightning_target_identity_flow`, `spell_cast_stage_flow`,
  `darkness_spell_flow`, `meteor_swarm_object_area_flow`,
  `wand_magic_missiles_flow`, and `local_room_object_flow` (including reload).

The Chain Lightning fixture now guarantees its player turn starts before
asynchronous monster turns, and all secondary targets obey the corrected
radius. The backpack-cap fixture uses the actual inventory limit. Tests used
disposable save roots. The production spell export, register and feature
matrix were regenerated; no spell's full rules status was promoted.
The full suite and interactive visual review were not run.

## Initial review verdict — superseded by correction acceptance

Wave 2 has substantial working, verified foundations, but its supported first
versions should not be signed off yet. Five confirmed issues affect behavior
inside the claimed scope. W2-F2, W2-F3 and W2-F5 need narrow corrections and
their affected acceptance cases before the delivery statement is reliable.
The intentional broader deferrals do not need to be implemented to close these
bounded versions.

| Card | Assessment |
|---|---|
| W2-F1 Equipment/components | The bounded component, exact-copy and pack paths have production checks. The review found no additional confirmed defect in this card. Its explicit component-audit and supply limits still apply. |
| W2-F2 Magic items | Both Wand live scenarios pass. The implemented cursed-item removal restriction can be bypassed by replacing the equipped weapon. |
| W2-F3 Perception | The existing light scenario passes, but additional production probes expose wrong sight requirements, invented light, rejected illuminated targets, and a wall bypass. |
| W2-F4 Conditions | The bounded source slice is represented in the production checks; the live Sunburst scenario passes. This does not certify broad condition consequences or saved source attribution. |
| W2-F5 Target resolution | Meteor Swarm's live scenario passes. Chain Lightning's range rule is wrong, and its current mixed-target live scenario failed four assertions. |

## Original findings — resolved above

### 1. Fix now — Chain Lightning links to any previous target instead of the first target

**Location:** `src/spells/spell_cast_targeting.gd:212` and `:242`.

Both selection and final validation accept another target within six hexes of
any earlier target. A production probe accepts targets at x=30, 36, 42 and 48
with the caster at x=0. The last two are more than 30 feet from the first target.
SRD 5.2.1 requires each secondary target to be within 30 feet of the first
target, including additional upcast bolts (page 114).

This materially expands the spell's reach. The existing mixed-target scenario
also uses this stretched arrangement, so a passing version of that fixture
would verify the wrong rule.

**Smallest fix:** Anchor both checks to the first selected target. Arrange the
creature, room-object, carried-copy and dropped-copy acceptance targets within
that first target's radius; add one refusal outside that radius. Correct the
“ordered chain” description and examples in the plan/checkpoint/register.

Rules reference: [SRD 5.2.1, Chain Lightning](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=114).

### 2. Fix now — All creature-targeted spells acquire a sight prerequisite

**Location:** `src/spells/spell_cast_targeting.gd:274` and `:277`.

The initial check is conditional on `requires_target_sight`, but the subsequent
creature branches call `CombatPerception.can_see_target` unconditionally. Final
cast validation calls this helper for selected targets. Production probes
reject Fire Bolt against a known Invisible creature and reject a Blinded
caster selecting themselves for Mage Armor. Fire Bolt's loaded record has
`requires_target_sight=false`.

Players lose otherwise supported attacks and buffs. This contradicts the
plan's distinction between unseen attacks and explicitly sight-required spells.

**Smallest fix:** Apply visual eligibility only when the spell requires it;
retain physical obstruction/range checks separately. Preserve unseen-target
attack penalties in the shared spell attack resolver, including natural
darkness, rather than simply removing the refusal and losing those penalties.
Check one unseen spell attack, one self/touch buff while Blinded, and one
sight-required refusal through the actual cast flow.

### 3. Fix now — Equipping another weapon bypasses the cursed sword's removal guard

**Location:** `src/characters/inventory.gd:651`, especially `:656`.

`unequip` refuses a cursed attuned copy, but `equip_instance` moves the previous
copy into the backpack without checking its curse. The room's Equip button
calls this method directly (`src/dungeon/local_room_view.gd:71`). A production
probe attunes and equips Sword of Vengeance: explicit unequip refuses, then
equipping the selected Longsword succeeds and removes the sword from the slot.

The ordinary player interface therefore bypasses a restriction this bounded
version explicitly claims to enforce. This finding concerns that implemented
restriction, not the intentionally deferred DMG retaliation behavior.

**Smallest fix:** Refuse replacement of a curse-bound equipped copy before
mutating either item location. Verify refusal preserves both exact copies and
that replacement works after Remove Curse releases the binding.

### 4. Fix now — Natural-light visibility invents light and blocks distant lit targets

**Location:** `src/combat/combat_perception.gd:26` and `:60`.

Every grid entity is examined as a light source, with missing radii defaulting
to zero. At its own cell, distance zero passes the bright-radius comparison.
Two adjacent unlit entities in an otherwise dark grid therefore become visible
to a Human without Darkvision. Separately, `_ambient_path_is_visible` rejects
any unlit intermediate hex: a clearly illuminated target 60 feet away is
rejected when natural darkness lies between the observer and its light.

These errors produce contradictory targeting and attack penalties even within
the supported encounter-wide darkness model.

**Smallest fix:** Count only actual emitting sources, preserve ambient light,
and evaluate natural illumination at the target while keeping physical and
magical obstruction separate. Add the adjacent-unlit and distant-lit cases to
the perception acceptance scenario. Per-hex editing, dropped lights and NPC
simulation are unnecessary for these fixes.

### 5. Fix now — Seeing through magical Darkness bypasses walls

**Location:** `src/combat/combat_perception.gd:39`.

When either endpoint has `darkness_obscured`, the helper immediately returns
the Truesight/Blindsight result. The shared wall check below it is skipped.
A production probe puts a sight-blocking wall between the caster and a target
inside magical Darkness; granting True Seeing changes the result to visible
despite the wall.

Sight-required targeting and Counterspell observers can see through the
authored walls/closed doors that this card claims to honor.

**Smallest fix:** Always settle the shared wall/door obstruction before allowing
a special sense to overcome magical obscuration. Verify True Seeing sees a
darkened target through an open path and refuses the same target behind a wall
or closed door.

## Document review

The separation between availability, evidence and complete rules support is
useful, and the explicit Wave 2 deferrals are concrete. Retain those limits;
this review does not recommend implementing them all before further work.

The introductory paragraph at `docs/mechanics/spell-foundations.md:10` still
says Waves 2–5 remain open, while the Wave 2 checkpoint at line 47 says all five
supported first versions are delivered and verified. After correcting the
findings, replace the introductory status with one current summary, and keep
the bounded delivery statement distinct from full rules completion. The
Chain Lightning description needs correction independently of that wording.

## Verification and limits

Fresh checks used disposable APPDATA/LOCALAPPDATA roots, preserving the owner's
real saves. Evidence is in `.artifacts/wave2-completion-review/`.

- Bootstrap, parser (152 scripts), and production boot passed; DataLoader
  reported zero content validation failures.
- Logic groups `spells,effects,world,combat,conditions,persistence`: **1,270
  passed, 1 failed**. The failure is `add_item fails when backpack full` in
  `src/test_runner.gd:3181`: the fixture fills 20 entries, while
  `Inventory.MAX_BACKPACK_SIZE` is 40. This is an outdated test assertion;
  change it to exercise the actual constant when touching that test. Existing
  capacity/transaction checks cover the 40-copy boundary.
- Live scenarios: **5 of 6 passed**. Passing: `wand_magic_missiles_flow`,
  `wand_last_charge_destruction_flow`, `meteor_swarm_object_area_flow`,
  `sunburst_spell_flow`, and `combat_light_visibility_flow`.
- `chain_lightning_mixed_targets_flow`: its slot-choice assertion passed, but
  creature/object damage, carried-copy damage, dropped-copy damage, and final
  slot/action spending assertions failed. The run emitted no script/engine
  errors. The immediate cause of this scenario failure was not established;
  do not treat it as proof of a specific additional gameplay bug or as green
  current acceptance. Correct its known illegal layout and investigate the
  remaining failure if it persists.
- The additional `probe.tscn` uses real initialized production classes. Its
  recorded outputs reproduce all five findings, including contrasting curse
  refusal/replacement and lighting cases. It is an ignored diagnostic artifact,
  not a new permanent test suite.
- Existing dedicated historical evidence was read alongside current source.
  A full catalog clause audit, full class suite, and interactive visual review
  were outside this bounded review. No complete-suite-green claim is made.
- CodeGraph was attempted but its command was unavailable; no Agent Ground
  tool was exposed. The configured team routing and role contracts were
  missing, so the review ran solo using current source and production checks.

The original next action was to correct the first-target rule, sight guard,
equipment/perception defects and acceptance fixtures. That work is complete;
the current delivery statement and exclusions are in
[spell-foundations.md](../mechanics/spell-foundations.md).
