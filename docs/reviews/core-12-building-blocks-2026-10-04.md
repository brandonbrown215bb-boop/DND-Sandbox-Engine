# Core-12 class building-block review

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

Reviewed: 2026-10-04, current uncommitted working tree. Scope: the twelve core
class records, their shared production consumers, and the class rules helpers.
The concurrent visual overhaul is outside this review. This review makes no
claim of complete SRD coverage or a full campaign playthrough.

Correction status: all five findings below have been corrected in the current
working tree. The findings and original line references retain the pre-fix
evidence; verification of the corrections is recorded below.

## Assessment

The building-block method was substantially followed. At review time, it was
not fully working across the twelve classes. Common progression, saved choices,
subclasses, self-activation, resources, spell preparation, auras, skill checks,
and weapon damage riders have shared implementations. Five concrete bypasses
below prevented acceptance of that shared behavior; those bypasses are now fixed.

The guide and ADR-0006 deliberately permit trusted custom combat paths. Keeping
Wild Shape, Rage maintenance, reaction timing, attack tradeoffs, Divine
Intervention, and Find Steed in narrow helpers is consistent with that contract.
Missing subclasses, curated spell lists, and explicitly disabled features are
staged scope limits, not evidence of an architectural failure. The twelve
progression records do not mean twelve fully implemented classes.

## Original Fix now findings — corrected

### 1. Shared spellcasting ignores its declared ability — P1

**What happens:** `Character.get_spell_save_dc()` reads `primary_ability`, not
the owned `spellcasting` effect's `ability`. The ordinary spell attack and
Scorching Ray paths do the same. Ranger declares Wisdom spellcasting but uses
Dexterity; Paladin declares Charisma but uses Strength. The probe set the
casting score to 10 and the primary score to 18: both level-2 classes returned
DC 14 instead of 10.

**Why care:** The player's spellcasting investment does not determine spell
accuracy or save difficulty. A mod combining a martial primary ability with
another casting ability inherits the same error. Paladin's Abjure Foes also
uses this incorrect DC.

**Smallest fix:** Resolve the casting ability once from the owned spellcasting
effect, retaining a deliberate fallback for older records, and use that same
method for DCs and every spell attack path. Do not change the classes' martial
primary abilities to mask the problem.

Source: `src/characters/character.gd:830`,
`src/combat/combat_action.gd:855` and `:965`.

### 2. Shared Weapon Mastery still stops at a Fighter gate — P1

**What happens:** Selection and the attack resolver accept masteries for other
classes, but `_finish_fighter_attack()` returns for non-Fighters before Push
and Cleave. `_offer_light_attack()` similarly returns before offering a
non-Fighter's Light/Nick attack. The probe selected Pike mastery normally:
Barbarian resolved `push` but produced zero spatial requests; Fighter produced
one. A Rogue with Shortsword, offhand Dagger, and Dagger's `nick` mastery
produced no Light attack prompt.

**Why care:** Barbarian, Paladin, Ranger, Rogue, and mod characters can spend
training choices on effects that do not execute. Two-Weapon Fighting choices
also cannot provide their expected benefit through the current Light flow.

**Smallest fix:** Run ordinary mastery and Light effects for every eligible
character. Gate only the actual Fighter/Champion features, such as Remarkable
Athlete. Preserve the shared action and once-per-turn limits.

Source: `src/combat/combat_state.gd:2790` and `:2849`.

### 3. Damage cleanup removes unrelated conditions — P1

**What happens:** `ClericRules.clear_turning_after_damage()` unconditionally
removes Frightened and Incapacitated. Normal weapon and spell damage call it
even when the target was never turned. The probe passed a target with neither
Turn Undead nor Abjure Foes markers; both unrelated conditions disappeared.
The Character branch has the same unconditional cleanup.

**Why care:** Damaging a creature can unexpectedly undo unrelated crowd
control. A class-specific cleanup helper is changing common combat behavior
without checking which rule owns the conditions.

**Smallest fix:** Require the matching effect marker before ending Turn
Undead, and remove only conditions supplied by that effect. Keep Abjure Foes'
separate damage-ending rule. Preserve other sources if effects overlap.

Source: `src/characters/cleric_rules.gd:119`; callers include
`src/combat/combat_state.gd:1818`, `:2278` and `:2295`.

### 4. Damage settlement is duplicated and disagrees on mitigation — P1

**What happens:** Ordinary weapon attacks directly subtract monster HP without
checking damage immunity, while Cleric's private damage helper checks it.
Hunter's Mark also subtracts its Force rider directly; other rider/special
paths have their own versions. The probe dealt eight Force damage to an immune
monster through the weapon resolver, while the Cleric helper dealt zero for
the same amount/type. Cleric's helper also dealt all eight damage to a target
declaring Radiant resistance; live monster construction currently omits
`damage_resistances` altogether.

**Why care:** The same damage type behaves differently depending on which
class feature or attack delivers it. New class mechanics carry forward this
existing shared-boundary gap instead of consistently reusing mitigation.

**Smallest fix:** Add one bounded typed-damage settlement utility using the
existing Character/monster representations. Route weapon, spell and rider
damage through it, including immunity, resistance, HP/death state and relevant
cleanup. Copy mitigation fields when constructing live monsters. This does
not require a new service, entity hierarchy, or CombatState rewrite.

Source: `src/combat/combat_action.gd:512`,
`src/characters/cleric_rules.gd:98`, and
`src/combat/combat_state.gd:441`.

### 5. Ranger bypasses the shared Fighting Style choice — P2

**What happens:** `get_attack_style_bonus()` grants +2 to ranged attacks when
the character merely owns `ranger_fighting_style`, regardless of its saved
choice. The probe selected Defense, confirmed that the character did not have
Archery, and still received +2 with a Longbow.

**Why care:** Rangers receive an extra style benefit they never selected. The
picker and saved choice are working, but their common combat consumer is
bypassed by an older feature-ID shortcut.

**Smallest fix:** Require the shared selected-style query for Archery, as other
classes already do. Check pending selection, Defense, and Archery cases.

Source: `src/characters/character.gd:841`.

## Reuse across the twelve classes

All classes use shared permanent-improvement progression; the table highlights
their other common operations and the rules that reasonably retain specialized
production paths. This is a source assessment, not a complete gameplay
certification of every feature in each row.

| Class | Main shared building blocks used | Specialized behavior retained |
|---|---|---|
| Barbarian | Rage self-activation, capacities/recovery, conditional check/save effects, movement, fixed capstone scores, mastery choices | Rage upkeep and initiative choice; Relentless Rage; Brutal Strike tradeoffs |
| Bard | Spell choices/slots, Expertise, check bonuses, recovery/exchange, always-prepared and extra-target effects | Inspiration's failed-test timing, reused through one helper; Countercharm reaction orchestration |
| Cleric | Spell choices/slots, shared Channel Divinity pool, Divine Order choices, weapon/spell riders | Divine Spark target variant; Turn/Sear Undead; Intervention selection/cooldown |
| Druid | Spell choices/slots, resource recovery, Primal Order choices, Elemental Fury riders, initiative recovery | Wild Shape forms/state/attacks; Wild Companion; Wild Resurgence restrictions |
| Fighter | Common Second Wind activation, saved subclass/improvements/boons, Extra Attack and critical progression | Restricted Surge; Tactical Mind/Shift/Master; Studied Attacks; Champion timing |
| Monk | Common Wholeness activation, subclass/improvements, movement, fixed capstone scores, attack resolution | Focus variants; Deflect/Stunning Strike; Uncanny Metabolism; end-turn restoration |
| Paladin | Spell choices/slots/free casts, style choices, mastery choices, auras, unrestricted melee damage rider | Smite hit trigger; Find Steed; Lay on Hands/Restoring Touch selections; Divine Sense/Abjure Foes |
| Ranger | Spell choices/slots/free casts, Expertise/styles/masteries, movement, Tireless self-effect, concentration protection and spell die override | Hunter's Mark identity and concentration-bound damage |
| Rogue | Expertise/masteries, minimum-roll checks, save proficiency, shared reactions/Evasion | Sneak Attack eligibility and scaling; Cunning Action combat budget |
| Sorcerer | Spell choices/slots, common Innate Sorcery activation, bounded Short Rest recovery | Sorcery Point compatibility methods and supported Metamagic spell-damage path |
| Warlock | Spell choices/capacities, data-driven Pact slots, common recovery fraction and capstone scaling | Pact Magic recovery semantics; invocation/arcanum behavior remains unavailable |
| Wizard | Spell choices/slots, restricted Expertise, existing slot-recovery operation | Arcane Recovery's allocation/level cap; spellbook-specific behavior remains unavailable |

## Are helpers limited to one-off rules?

Not strictly. `FighterRules` also houses shared Fighting Style and Weapon
Mastery consumers; `BarbarianRules.roll_monster_save()` is called by multiple
classes. These are genuinely reused functions, so their class-labelled file
locations alone are not a reason to rewrite them. **Ignore** naming/placement
alone; correct the behavior bypasses above.

**Fix when touched:** Monk Perfect Focus repeats the resource-floor behavior
of `initiative_resource_recovery`. It can share that operation after the
common resource lookup recognizes Focus; currently
`get_feature_max_uses("focus_points")` does not resolve that special pool.
Uncanny Metabolism should keep its exceptional choice/timing path. Common
Focus and Sorcery Point storage also retain class-ID-specific compatibility
methods; generalize them when a real additional consumer needs those pools.
Avoid creating a general rules framework merely to relocate working functions.

## Original review verification and limits

One Godot 4.7 headless diagnostic used the production loader, Character,
ClassProgression, combat resolvers and combat follow-up methods. It reproduced
all five findings. Only spatial requests and optional prompt presentation were
replaced for observation. The loader reported zero content validation failures;
that does not detect these runtime behavior gaps.

Probe and logs: ignored `.artifacts/core12-review/`, including `probe.gd`,
`probe.tscn`, `output.log` and `godot.log`. The run printed
`CORE12_REVIEW_COMPLETE` and had no script errors. APPDATA and LOCALAPPDATA
pointed to a disposable repository-local profile. No real saves were loaded or
changed. No production code was edited; no full logic/integration suite,
rendered UI playthrough or SaveManager relaunch probe was run for this review.

CodeGraph and Agent Ground tooling were unavailable. The configured personal
team contracts were absent, so this was a solo review.

## Correction verification

The five corrections extend existing shared consumers rather than adding a new
class framework. `Character.get_spellcasting_ability()` supplies every spell
attack and save DC, and Archery uses the selected-style query. CombatState now
executes ordinary mastery/Light follow-ups without a class-identity gate.
`CombatAction.resolve_damage()` settles typed damage from weapons, spells,
riders and special helpers. Monster construction retains resistance metadata.
The existing condition boundary tracks separate Turn Undead/Abjure sources and
durations, preserving other fear/incapacitation when those effects end.

The original production diagnostic now reports the expected spell DCs, style
bonuses, non-Fighter follow-up requests, condition preservation and mitigation.
Godot 4.7 passed **1,282 logic checks** and **all 35 integration scenarios**
across a broad run and focused reruns. Regression checks cover nine damage
paths against immunity/resistance, casting ability in ordinary/ray attacks,
pending/Defense/Archery choices, overlapping conditions with independent
expiry, cleansing, Sear Undead, resistance bypass and temporary HP. A real
combat scenario verifies non-Fighter Push/Cleave/Nick, actual prompts,
once-per-turn/action limits, extra-attack history and spawned resistance.

The first suite exposed stale tests for free Hunter's Mark casts, starting
equipment, default cantrips and automatic Fighting Styles; these were updated
to the current production contract. The mastery fixture now registers its
actual actor before spawning combat. A forced Abjure duration edit was replaced
by normal production ticks. Successful focused logs are under ignored
`.artifacts/core12-fixes/logic-final/`, `integration-final/` and `mastery-final/`;
the initial broad run remains under `tests/`.

No new save schema or migration was introduced. The isolated profiles also
exercised the existing save/load scenarios without touching real saves. A
rendered playthrough and separate fresh-process relaunch probe were not run.
The staged coverage limits and **Fix when touched** recommendation above remain.
