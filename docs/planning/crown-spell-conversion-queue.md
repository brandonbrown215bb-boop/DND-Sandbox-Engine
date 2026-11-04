# Crown spell conversion: Grokbot stacking queue

Owner direction: **2026-11-04**. This is the complete remaining **169-spell**
conversion queue for Crown's pinned 183 SRD level-0-3 spells, divided into
**46 ordered PR assignments**. It includes 81 refused spells and 88 enabled
native spells. Each spell has one owning assignment in the
[machine-readable queue](crown-spell-conversion-queue.csv).
The [Crown roadmap](crown-roadmap.md) still owns the campaign finish line;
[content scope](crown-content-scope.md#spell-inventory) owns the 183 IDs;
[slice registry](vocabulary-slices.md) owns engine acceptance. This queue does
not reduce content scope or accept any engine slice/spell.

## Start here: stack continuously

**Do not wait for review, owner sign-off, approval, merge or remote CI before
starting the next PR. Keep stacking.** This explicit owner direction supersedes
the historical one-reviewed-PR-at-a-time Grokbot lane and independent-review
scheduling gates for this queue. Local verification and honest failure reporting
remain part of implementation; review is not a prerequisite to continuing.

1. Fetch the latest remote queue and runtime. Start `codex/crown-spells-sc-01`
   from `main`. Implement SC-01 and open its PR against `main`.
2. Create `codex/crown-spells-sc-02` from the SC-01 tip, open its PR against
   the SC-01 branch, and proceed immediately. Repeat with `sc-03` through
   `sc-46`; each PR's base is the preceding branch. Thus every PR has a focused
   diff while later work can use unmerged earlier work.
3. A row is a **delivery assignment**, including missing reusable operations,
   controls and world hooks before its actual data conversions. It is not a
   request for another inventory-only PR. Use the relevant source clauses,
   existing owners and the named proof obligations below.
4. If the row needs substantial prerequisite engine work, split a focused
   support PR immediately before its conversion PR on the same stack. Use
   `codex/crown-spells-sc-NN-support-01` (then `-02` if needed), base the content
   branch on that support tip, and continue after it without review/merge waits.
   Keep the stable SC ID in both titles. Bring a later row's minimal shared
   prerequisite forward when needed; record it so the later row reuses it.
5. Run relevant local production checks as work is implemented. Fix failures
   caused by the change. Reproduce unrelated failures and record their exact
   consumer; keep stacking independent work. A missing local Windows runner
   is a stated verification limit, not permission to claim a Windows pass or a
   reason to wait for review. Use the repository's supported runner when available.
6. Update each owned CSV row's status/PR reference in its PR and keep the next
   action concrete. Suggested states: `queued`, `implementing`, `converted`,
   `blocked:<exact missing consumer>`. Any genuinely blocked spell keeps its
   owning SC assignment; move directly to unblocked rows and return to it.
   No refused spell is enabled and no native route removed until its whole
   required replacement works. Do not finish a row by quietly dropping clauses.

Start with SC-01-SC-09: **32 attack/damage and condition/removal spells**.
The assignment sizes reflect shared behavior, not one PR per spell. The rest
is queued in the same stack; the first sweep is not a gate on an independent
later assignment when a concrete blocker prevents progress.

## Baseline and evidence limits

Inventory/schema triage was captured from the local working tree at
`de3891d0` (main through PR #81) on 2026-11-03; this handoff was written on
2026-11-04. Production data loaded with zero validation failures. This is a
dated inventory, not a full 169-spell source or gameplay audit. Refresh it from
remote runtime when starting; do not treat local uncommitted work as available.

The CSV preserves each current definition's **first** shared-validator failure
after adding `execution: shared` and removing loader provenance. It also carries
the existing audit's historical clause notes. Neither column determines readiness:
later schema errors can be hidden by the first one, native fields need translation,
and even passing validation can omit an entire required behavior. Hellish Rebuke's
damage can validate while full trigger coverage remains absent. Longstrider's
current speed-benefit carrier is self-only and does not prove recipient/upcast
support. Read current code and the actual source, not just these snapshots.

The remote baseline includes Druid/Monk Explorer's Packs from PR #81. Equipment
focus/Sickle follow-ups remain their own work. The local Hit Dice changes were
uncommitted during this inventory; SC-46 must use a remotely integrated version
or supply only its actual missing prerequisite in its own stack. Do not copy
machine-local addons, configuration, profiles, saves or ignored artifacts.

## Rules for every assignment

- **Source:** SRD 5.2.1. Use [reference entry points](../../reference/2024/README.md),
  the selected source body and [spell clause audit](../audits/spells.md) to locate
  clauses. Obtain missing source bodies before authoring; descriptions and
  imported metadata are not proof. Read only the selected package, not the full
  SRD again for every PR. Include source coordinates in the content/PR.
- **Runtime:** follow [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md)
  and [ADR-0023](../decisions/0023-vocabulary-first-delivery-and-bounded-world-judgment.md).
  Data declares rules; generic operations and real world hooks execute them.
  New definitions must not require a spell/class/item/monster-ID branch or
  allowlist registration. Merely flipping `execution`, accepting unknown fields,
  adding a name to `AVAILABLE_SLICES`, or emitting descriptive text is not delivery.
- **Content:** preserve spell IDs, legal source/class/slot permissions and actual
  class-feature consumers. Author complete curated manifest winners using the
  [shared-spell contract](../mechanics/shared-spells.md) and other existing
  [mechanics references](../mechanics/README.md). Do not edit generated imported
  sources as the durable replacement. Keep native consumers until covered.
- **Proof:** verify reusable operations with a neutral/renamed loaded definition,
  then actual source-backed content through real controls. Exercise relevant
  player/monster, combat/room/overworld hosts rather than assuming one host proves
  another. Include cancel/stale/decline, exact actor/source, once-only costs and
  cleanup. Persistent changes need permitted party/player-only checkpoint paths
  and fresh-process recovery. Preserve legacy saves and current save restrictions.
- **Checks:** use [Windows testing](../testing.md) and the existing harness. Run
  affected logic groups and named existing scenarios; add focused regressions
  only for real/likely failures. New scenarios go in that harness, not another
  rules implementation. Python is for structure/inventory. Reuse green evidence
  until a relevant change warrants rerunning it; do not run the entire suite
  after every data row or wait for an external review result.
- **Record:** PR title starts `SC-NN:`; body says what now works, source clauses,
  relevant checks and material remaining limits, plus the parent/next SC ID.
  Update the existing runtime contract whose behavior changed, slice boundary
  when earned, and spell register for delivered content. Do not count a fixture,
  enabled flag or partial spell as complete. Runtime owns game source/data;
  leave `tools/content_editor/` to its pipeline owner.

The S-IDs below locate reusable owners and missing consumers. They do not
require completing every unrelated clause of those umbrella slices. Counts of
accepted engine slices never serve as a spell-readiness or Crown-completion gate.

## PR stack overview

Each row depends structurally on the preceding PR, not its approval or merge.
Functional support is described in its detailed assignment. If a parent has
already merged, use the corresponding current `main` tip as base.

| PR | Assignment | Spells | Refused at baseline | Base |
|---|---|---:|---:|---|
| [SC-01](#sc-01) | Attack cantrip riders | 7 | 0 | main |
| [SC-02](#sc-02) | Multiple attacks and settled damage | 6 | 0 | SC-01 |
| [SC-03](#sc-03) | Lines, objects and displacement | 3 | 1 | SC-02 |
| [SC-04](#sc-04) | Chromatic Orb leap chain | 1 | 1 | SC-03 |
| [SC-05](#sc-05) | Flat conditions and concealment | 5 | 0 | SC-04 |
| [SC-06](#sc-06) | Sleep and Hypnotic Pattern | 2 | 1 | SC-05 |
| [SC-07](#sc-07) | Curses, distraction and calm | 4 | 3 | SC-06 |
| [SC-08](#sc-08) | Slow and Hideous Laughter | 2 | 2 | SC-07 |
| [SC-09](#sc-09) | Condition and curse removal | 2 | 1 | SC-08 |
| [SC-10](#sc-10) | AC, maximum HP and linked harm | 4 | 1 | SC-09 |
| [SC-11](#sc-11) | Weapon and hit benefits | 4 | 0 | SC-10 |
| [SC-12](#sc-12) | Healing benefits and Temporary HP | 3 | 0 | SC-11 |
| [SC-13](#sc-13) | Checks, protections and targeting | 7 | 0 | SC-12 |
| [SC-14](#sc-14) | Recipient speed, size and tracking benefits | 3 | 2 | SC-13 |
| [SC-15](#sc-15) | Teleport, jump and surface movement | 4 | 0 | SC-14 |
| [SC-16](#sc-16) | Altitude and underwater operation | 3 | 1 | SC-15 |
| [SC-17](#sc-17) | Compelled movement and restricted actions | 5 | 4 | SC-16 |
| [SC-18](#sc-18) | Forms, phasing and stone | 4 | 3 | SC-17 |
| [SC-19](#sc-19) | Rope Trick and Floating Disk | 2 | 2 | SC-18 |
| [SC-20](#sc-20) | Hunter's Mark and Hex | 2 | 2 | SC-19 |
| [SC-21](#sc-21) | Granted spell actions and repeat attacks | 4 | 4 | SC-20 |
| [SC-22](#sc-22) | Repeat effects on zones and objects | 2 | 2 | SC-21 |
| [SC-23](#sc-23) | Reaction spell delivery | 4 | 2 | SC-22 |
| [SC-24](#sc-24) | Post-hit Bonus Action spells | 4 | 3 | SC-23 |
| [SC-25](#sc-25) | Terrain and restraint zones | 4 | 0 | SC-24 |
| [SC-26](#sc-26) | Moving and creature-shaped damaging areas | 3 | 0 | SC-25 |
| [SC-27](#sc-27) | Fog, silence and hazardous atmosphere | 4 | 2 | SC-26 |
| [SC-28](#sc-28) | Interactive moving hazards | 3 | 3 | SC-27 |
| [SC-29](#sc-29) | Selective barriers and admission | 3 | 3 | SC-28 |
| [SC-30](#sc-30) | Familiar, steed and undead migration | 3 | 0 | SC-29 |
| [SC-31](#sc-31) | Servant and temporary mount | 2 | 2 | SC-30 |
| [SC-32](#sc-32) | Object and movable light | 4 | 1 | SC-31 |
| [SC-33](#sc-33) | Darkness, Daylight and source dispelling | 2 | 1 | SC-32 |
| [SC-34](#sc-34) | Observer senses and detection masking | 5 | 2 | SC-33 |
| [SC-35](#sc-35) | Detection, location and Identify | 7 | 3 | SC-34 |
| [SC-36](#sc-36) | Animals, plants and the dead | 5 | 3 | SC-35 |
| [SC-37](#sc-37) | Language and remote messages | 4 | 3 | SC-36 |
| [SC-38](#sc-38) | Divination and social consequences | 5 | 5 | SC-37 |
| [SC-39](#sc-39) | Located illusion interactions | 4 | 3 | SC-38 |
| [SC-40](#sc-40) | Appearance, decoys and false auras | 4 | 4 | SC-39 |
| [SC-41](#sc-41) | Locks, Knock and Dispel Magic | 3 | 3 | SC-40 |
| [SC-42](#sc-42) | Stored and triggered object spells | 3 | 2 | SC-41 |
| [SC-43](#sc-43) | Utility cantrips and object work | 6 | 4 | SC-42 |
| [SC-44](#sc-44) | Quantified food and water | 4 | 1 | SC-43 |
| [SC-45](#sc-45) | Death, preservation and recovery | 3 | 0 | SC-44 |
| [SC-46](#sc-46) | Prayer of Healing benefit-only recovery | 1 | 1 | SC-45 |

## Detailed assignments

<a id="sc-01"></a>

### SC-01 — Attack cantrip riders

**Owns (7):** `chill_touch`, `ray_of_frost`, `ray_of_sickness`, `shocking_grasp`, `starry_wisp`, `vicious_mockery`, `true_strike`.

**Deliver:** Deliver attack/save riders, healing prevention, speed reduction, opportunity-only prevention, observer visibility and next-roll benefits. Capture the exact caster/recipient turn boundary, including Ray of Sickness ending at the end of the caster's next turn. Preserve True Strike weapon/material/ability choices.

**Reuse/extend:** S-076/S-077, S-091/S-094, S-126/S-127, S-141, S-190/S-191; use existing attack and condition owners.

**Prove:** Hit/miss, unrelated next roll, caster versus target turns, immunity, overlapping sources, level-5 scaling; reuse true_strike_spell_flow and affected attack-choice scenarios.

<a id="sc-02"></a>

### SC-02 — Multiple attacks and settled damage

**Owns (6):** `ice_knife`, `magic_missile`, `melfs_acid_arrow`, `scorching_ray`, `eldritch_blast`, `sorcerous_burst`.

**Deliver:** Deliver distinct ray/dart allocation, fresh attack receipts, area-after-attack settlement, miss damage, delayed acid and matching-die/exploding damage where the source requires it. Preserve invocation and Metamagic consumers rather than bypassing them.

**Reuse/extend:** S-017, S-031/S-034/S-035, S-098/S-099, S-123-S-127, S-140/S-141; ordered steps and captured roll/payment owners.

**Prove:** Same/different/dead targets between attacks, cancellation, one slot/action payment, hit/miss and damage-after-miss, delayed damage cleanup, class-level versus character-level scaling.

<a id="sc-03"></a>

### SC-03 — Lines, objects and displacement

**Owns (3):** `lightning_bolt`, `shatter`, `thunderwave`.

**Deliver:** Author the real line/cube shapes and eligible object consumers. Shatter must damage every eligible object, including copies collocated with creatures, without an object CON save. Preserve Thunderwave push and 300-foot effect sound across its actual legal hosts.

**Reuse/extend:** S-032, S-091, S-098/S-099, S-184, S-218/S-237 sound, S-241; reuse OA sound and footprint placement.

**Prove:** Line direction and obstruction, mixed creature/object cells, worn/carried/magical exclusions, unknown material, push blocked by terrain, actual Action/Ready/monster/room eligibility and once-only sound.

<a id="sc-04"></a>

### SC-04 — Chromatic Orb leap chain

**Owns (1):** `chromatic_orb`.

**Deliver:** Finish S-267 matching-face detection from retained damage dice, chosen legal next target, fresh attack/damage, slot-dependent chain cap and no repeat creature; then install the complete spell.

**Reuse/extend:** S-267, S-031/S-034, S-127, S-136; captured dice and target-choice owners from preceding attack work.

**Prove:** Matching/nonmatching faces, changed dice after modifiers, no legal target, decline/stale/cancel, range, no repeated creature and exactly one original cast payment.

<a id="sc-05"></a>

### SC-05 — Flat conditions and concealment

**Owns (5):** `blindness/deafness`, `blur`, `charm_person`, `color_spray`, `faerie_fire`.

**Deliver:** Convert declared condition choices, recipient filters, hostility modifiers, light/visibility and all source-defined ending rules. Preserve actual Blinded/Deafened choices and observer-relative consequences.

**Reuse/extend:** S-029, S-075, S-091, S-126/S-127, S-141, S-190/S-191, S-235; ordinary condition and source-end owners.

**Prove:** Mixed successful/failed saves, exact chosen condition, sight/immunity, concentration, damage/hostility ending, repeat saves, upcast recipients and checkpoint recovery; reuse blindness_deafness_spell_flow.

<a id="sc-06"></a>

### SC-06 — Sleep and Hypnotic Pattern

**Owns (2):** `sleep`, `hypnotic_pattern`.

**Deliver:** Deliver complete staged incapacitation/charm, eligible observers, speed consequences and exact damage/shake endings. A Charmed or Incapacitated label alone does not deliver the whole spell.

**Reuse/extend:** S-029, S-068, S-074/S-075, S-086, S-141, S-190/S-191, S-235; staged condition and ordinary interaction owners.

**Prove:** Cannot-see and immune recipients, initial/repeat saves, different affected stages, real shake controls, damage wakeup, unrelated source retention, one Action/slot; reuse sleep_spell_flow.

<a id="sc-07"></a>

### SC-07 — Curses, distraction and calm

**Owns (4):** `bestow_curse`, `calm_emotions`, `enthrall`, `ray_of_enfeeblement`.

**Deliver:** Deliver every in-band selectable mode, purpose-aware roll/damage penalties, immunity/suppression, represented attitude changes and witness endings. Bestow Curse includes its forced-Dodge turn, with slot policy authored rather than a spell-ID branch.

**Reuse/extend:** S-028/S-036/S-040, S-068, S-074/S-075, S-091/S-094, S-109, S-141, S-148, S-190, S-219.

**Prove:** Each mode and target selection, attack/check/save distinctions, concentration, forced Action budget, witnessed/unwitnessed damage and exact source cleanup; keep level-4+ slot clauses outside Crown unless actually granted.

<a id="sc-08"></a>

### SC-08 — Slow and Hideous Laughter

**Owns (2):** `slow`, `tashas_hideous_laughter`.

**Deliver:** Deliver restricted Action/Bonus Action and attack budgets, Reaction denial, somatic-cast failure settlement, stand-up refusal and damage-triggered saves with their declared Advantage. Reuse captured consequences rather than rerolling the original event.

**Reuse/extend:** S-031, S-068, S-091, S-142, S-146, S-160, S-235/S-239; budget, roll and condition owners.

**Prove:** Action then Bonus Action and reverse order, multiple attacks, spell failure/payment, self-stand refusal, damage versus turn-end saves, upcast targets and cleanup without restoring already-spent budgets.

<a id="sc-09"></a>

### SC-09 — Condition and curse removal

**Owns (2):** `lesser_restoration`, `remove_curse`.

**Deliver:** Deliver touch/Bonus Action selection of exactly one eligible condition for Lesser Restoration and the actual curse/item interactions for Remove Curse. Preserve independent sources and explicitly guarded removal policies.

**Reuse/extend:** S-074/S-075, S-201/S-202/S-203 and condition/source owners; S-270 only if an actual in-scope guarded source requires its narrow rule.

**Prove:** Several conditions and sources, no eligible condition, wrong target, stale/cancel without cost, exact curse/attunement ending and permitted checkpoint recovery.

<a id="sc-10"></a>

### SC-10 — AC, maximum HP and linked harm

**Owns (4):** `aid`, `barkskin`, `mage_armor`, `warding_bond`.

**Deliver:** Deliver AC formulas/floors, source-owned maximum/current HP changes, true damage copy for Warding Bond, live distance/zero-HP endings and exact worn-ring requirements. Use complete source effects, not flat-AC approximations.

**Reuse/extend:** S-084/S-085, S-103, S-111/S-112, S-130/S-131, S-141, S-196 and source-end rules.

**Prove:** Armor/shield changes, stacking/expiry while injured/downed, exact copied damage after mitigation, range/recast/zero-HP endings, components and both DTO paths; reuse barkskin_spell_flow and mage_armor_spell_flow.

<a id="sc-11"></a>

### SC-11 — Weapon and hit benefits

**Owns (4):** `divine_favor`, `guiding_bolt`, `magic_weapon`, `shillelagh`.

**Deliver:** Deliver source-owned damage, attack/weapon ability and die upgrades, next eligible attack benefit and exact chosen weapon. Expiry, transfer and alternate attack routes must use the same source.

**Reuse/extend:** S-076/S-077, S-084/S-085, S-123-S-127, S-140/S-141, S-196; exact weapon and next-roll owners.

**Prove:** Eligible/ineligible weapons and hits, next benefit consumed once, off-turn and Light/Nick routes where legal, level-5 upgrades, concentration/source expiry and equipment changes; reuse divine_favor_spell_flow and magic_weapon_spell_flow.

<a id="sc-12"></a>

### SC-12 — Healing benefits and Temporary HP

**Owns (3):** `beacon_of_hope`, `heroism`, `false_life`.

**Deliver:** Deliver healing-die maximization, source benefits and repeated Temporary HP with their real lifetimes. False Life must support the Fiendish Vigor free maximized cast through generic permission parameters before replacing its native path.

**Reuse/extend:** S-064/S-068, S-074/S-075, S-103, S-123/S-126, S-134/S-135, S-140/S-141.

**Prove:** Keep-higher HP, repeated/overlapping sources, concentration cleanup, ordinary/upcast/free maximized cast without RNG or slot, Death Save/healing consumers; reuse beacon_of_hope_spell_flow, heroism_spell_flow and effect lifetime checks.

<a id="sc-13"></a>

### SC-13 — Checks, protections and targeting

**Owns (7):** `guidance`, `resistance`, `enhance_ability`, `protection_from_energy`, `protection_from_evil_and_good`, `protection_from_poison`, `sanctuary`.

**Deliver:** Deliver declared skill/type/ability selections, source-specific bonuses, protection eligibility and correct Sanctuary save/retarget/payment. Preserve exact immunity, suppression and ending clauses across legal attack/check routes.

**Reuse/extend:** S-028/S-036, S-041, S-074-S-077, S-091/S-094/S-096, S-109/S-110, S-126/S-127, S-140/S-141.

**Prove:** Wrong skill/damage/type, consumed versus persistent benefit, monster and player targeting, failed Sanctuary choices, cancellation, unrelated sources and cleanup; reuse enhance_ability_spell_flow and sanctuary_spell_flow.

<a id="sc-14"></a>

### SC-14 — Recipient speed, size and tracking benefits

**Owns (3):** `longstrider`, `enlarge/reduce`, `pass_without_trace`.

**Deliver:** Extend self-only speed carriers to exact other/multiple recipients and their lifetimes; implement real size/gear changes with safe dropped/thrown reversion; deliver selected aura Stealth bonuses and represented no-tracks state.

**Reuse/extend:** S-032, S-080, S-091, S-126/S-127, S-140/S-141, S-163/S-164, S-179, S-190/S-191, S-219.

**Prove:** Touch/upcast recipients, changing movement modes, simultaneous sizes/space, gear and damage floors, aura enter/leave, observer tracking facts, expiry and both DTO forms. Current self-only SourceBenefitRules is not sufficient for Longstrider.

<a id="sc-15"></a>

### SC-15 — Teleport, jump and surface movement

**Owns (4):** `misty_step`, `jump`, `spider_climb`, `water_walk`.

**Deliver:** Connect shared declarations to actual legal movement controls, occupied-space refusal, once-per-turn jump budgeting, walls/ceilings, liquid surfaces and the source-defined voluntary pass-through option.

**Reuse/extend:** S-121/S-122, S-179-S-181, S-239/S-241; reuse full-footprint placement and existing movement owners.

**Prove:** Seen/blocked destinations, different sizes, cancellation/no space before payment, movement costs, source ending in unsafe locations, room/combat hosts and allowed recovery; reuse jump_spell_movement and existing placement scenarios.

<a id="sc-16"></a>

### SC-16 — Altitude and underwater operation

**Owns (3):** `fly`, `levitate`, `water_breathing`.

**Deliver:** Deliver altitude/hover/fall and gentle-descent endings, willing/unwilling creature and eligible object controls, movement restrictions, ten-recipient breathing and actual submerged air consumers.

**Reuse/extend:** S-032/S-148, S-179-S-181, S-196, S-205; relevant physical-space and resource owners.

**Prove:** Weight and willingness, legal altitude controls, end aloft, incapacitation, multiple recipients, submerged duration and exact expiry; extend existing room Levitate controls rather than rebuilding them.

<a id="sc-17"></a>

### SC-17 — Compelled movement and restricted actions

**Owns (5):** `command`, `dissonant_whispers`, `fear`, `expeditious_retreat`, `haste`.

**Deliver:** Finish Reaction/safest-route movement and Opportunity Attack policies, compelled commands/drop/Dash, Bonus Action Dash and Haste's extra restricted Action plus end lethargy. Preserve separate real budgets.

**Reuse/extend:** S-086, S-146/S-148, S-160, S-179/S-183, S-190, S-237/S-239/S-241, S-269.

**Prove:** Blocked/unsafe routes, no Reaction available, OA provocation, exact dropped-copy pickup, out-of-sight repeat saves, Dash on grant/afterward, restricted one-attack Action and lethargy without budget replay.

<a id="sc-18"></a>

### SC-18 — Forms, phasing and stone

**Owns (4):** `alter_self`, `gaseous_form`, `meld_into_stone`, `blink`.

**Deliver:** Deliver every in-band form choice, real space/plane restrictions, phasing/stone access, Ethereal observer rules and legal return/destruction/zero-HP endings. Bring forward only Crown-required fall/return hooks.

**Reuse/extend:** S-032, S-121/S-122, S-163/S-164, S-178-S-181, S-190/S-191, S-196.

**Prove:** Gear, attack/casting/talking restrictions, narrow gaps and occupied cells, exact stone damage and ejection, Blink roll/return timing and blocked-return recovery without source replay.

<a id="sc-19"></a>

### SC-19 — Rope Trick and Floating Disk

**Owns (2):** `rope_trick`, `tensers_floating_disk`.

**Deliver:** Author full occupant/cargo limits, visibility and passage policy, elevation/follow-distance constraints, movement and safe ejection/drop on ending. Reuse delivered containment/vessel records instead of inventing another container system.

**Reuse/extend:** S-121/S-122, S-167, S-170-S-172, S-180/S-181/S-185/S-186, S-196.

**Prove:** Exact cargo/occupants, capacity, illegal ingress, blocked release, fall/drop, follow distance and elevation, entrance checkpoint and fresh-process recovery; reuse containment/projected-vessel flows.

<a id="sc-20"></a>

### SC-20 — Hunter's Mark and Hex

**Owns (2):** `hunters_mark`, `hex`.

**Deliver:** Deliver exact per-hit benefit, source-selected skill/ability effects, zero-HP retarget Bonus Action and source-owned free-use/slot/duration policies. Ranger and Warlock features must use these same definitions.

**Reuse/extend:** S-031/S-041/S-043, S-076/S-077, S-094, S-134/S-135, S-140/S-141, S-148, S-194.

**Prove:** Weapon/spell hit eligibility, multiple attacks, target drops before/after owner turn, stale/cancelled retarget, free versus paid cast, spell duration and tracking/check consumers, source cleanup without repeated payment.

<a id="sc-21"></a>

### SC-21 — Granted spell actions and repeat attacks

**Owns (4):** `dragons_breath`, `flame_blade`, `spiritual_weapon`, `vampiric_touch`.

**Deliver:** Deliver exact recipient child actions, damage-type choices, created attack/light origins, free-hand/re-evoke rules, movable weapon controls and half-settled-damage healing. Grant an action policy, not a general extra Action.

**Reuse/extend:** S-012/S-017, S-123-S-127, S-140/S-141, S-148/S-160, S-187/S-190.

**Prove:** Different recipient/controller, correct Action/Bonus Action, blocked placement/movement, chosen damage and cantrip/slot scaling, heal from damage actually dealt, exact concentration ending and saved controls.

<a id="sc-22"></a>

### SC-22 — Repeat effects on zones and objects

**Owns (2):** `call_lightning`, `heat_metal`.

**Deliver:** Deliver created storm-area/repeat lightning selection and authored weather/space prerequisites; exact manufactured metal contact, repeat damage, drop/save and worn-armor consequences for Heat Metal.

**Reuse/extend:** S-032, S-098/S-099, S-140/S-141, S-148, S-184, S-190/S-196/S-219.

**Prove:** Actual spell source prerequisites, indoor/outdoor declarations, once-only repeat Action/Bonus Action costs, range/contact changes, forced drop versus armor, unknown material refusal and concentration cleanup.

<a id="sc-23"></a>

### SC-23 — Reaction spell delivery

**Owns (4):** `counterspell`, `shield`, `hellish_rebuke`, `feather_fall`.

**Deliver:** Complete qualifying cast/hit/creature-damage/fall windows on all Crown player/monster/area routes. Preserve perception/range, captured roll/consequence, Counterspell settlement and real Reaction eligibility.

**Reuse/extend:** S-041/S-042, S-109/S-114, S-134/S-135, S-142, S-160, S-181; existing cancellation and reaction-trigger owners.

**Prove:** Weapon/spell/area harm, fall affecting several creatures, cannot-see/out-of-range/no-Reaction, decline/stale/cancel, once-only payment, slot handling on interruption and no replay of original damage.

<a id="sc-24"></a>

### SC-24 — Post-hit Bonus Action spells

**Owns (4):** `divine_smite`, `ensnaring_strike`, `searing_smite`, `shining_smite`.

**Deliver:** Expose legal post-hit casts and authored payment, retain the captured hit, then apply damage/conditions/ticks/light from the exact source. Preserve free-cast grants and prevent selecting incompatible weapon or hit types.

**Reuse/extend:** S-041/S-043, S-068, S-091, S-134/S-135, S-140/S-141, S-160, S-169, S-190/S-191.

**Prove:** Hit versus miss, wrong weapon/actor/turn, already spent Bonus Action, decline/cancel, size save Advantage, turn ticks/escape, source loss, one damage consequence and one cast payment.

<a id="sc-25"></a>

### SC-25 — Terrain and restraint zones

**Owns (4):** `entangle`, `grease`, `spike_growth`, `plant_growth`.

**Deliver:** Convert ongoing terrain, save/escape, path damage and permanent versus timed growth through shared area owners. Include Plant Growth's real long-cast enrichment consumer rather than only its combat Overgrowth mode.

**Reuse/extend:** S-068/S-087, S-169, S-179, S-184, S-190, S-199; source-owned area/terrain and authored world facts.

**Prove:** Entry/turn timing, path versus teleport, overlapping costs, independent restraints, actual escape Action, campaign enrichment outcome and allowed recovery; reuse all four named spell-flow scenarios.

<a id="sc-26"></a>

### SC-26 — Moving and creature-shaped damaging areas

**Owns (3):** `moonbeam`, `spirit_guardians`, `conjure_animals`.

**Deliver:** Deliver actual move/entry/start/end trigger policies, selected exemptions, area movement and source-specific damage, including any source-defined form interactions. Keep distinct spell behaviors authored.

**Reuse/extend:** S-068/S-087, S-098/S-099, S-148, S-184, S-190/S-191; spatial trigger receipts and area movement.

**Prove:** First/once-per-turn rules, movement of area versus actor, shared boundaries, selected exemptions, exact repeated costs, concentration and checkpoint cleanup; reuse existing three spell-flow scenarios.

<a id="sc-27"></a>

### SC-27 — Fog, silence and hazardous atmosphere

**Owns (4):** `fog_cloud`, `sleet_storm`, `silence`, `stinking_cloud`.

**Deliver:** Deliver obscuration/sound/component restrictions, Thunder immunity, slippery terrain and concentration/check procedures, turn-start poisoning and Action/Bonus Action denial, plus source-declared dispersal.

**Reuse/extend:** S-068/S-075/S-087, S-160, S-179, S-184, S-190/S-191, S-218/S-237 sound.

**Prove:** Observer-specific sight/hearing, Verbal and sound-triggered Ready, gas/poison eligibility, terrain saves, wind dispersal, entering/leaving overlap and no restoration of spent budgets; reuse fog_cloud and sleet_storm scenarios.

<a id="sc-28"></a>

### SC-28 — Interactive moving hazards

**Owns (3):** `flaming_sphere`, `gust_of_wind`, `web`.

**Deliver:** Deliver sphere ram/movement/light/ignition, re-aimable directional wind and its terrain/dispersal effects, and anchored Web with exact burning sections. Use authored geometry/material/anchoring facts where the world must supply them.

**Reuse/extend:** S-032/S-087, S-148, S-169, S-179, S-184, S-190/S-191, S-199.

**Prove:** Movement/ram versus end-turn damage, barriers/pits, changed wind direction, fire/gas interaction, anchor loss, burning-cell cleanup, escape and source-owned concentration without double triggers.

<a id="sc-29"></a>

### SC-29 — Selective barriers and admission

**Owns (3):** `leomunds_tiny_hut`, `magic_circle`, `wind_wall`.

**Deliver:** Deliver admitted occupant/type lists, correct directed entry/attack/spell restrictions, actual geometry/light/wind interactions, casting time and ending policies. Do not pull in high-level multi-section wall simulation.

**Reuse/extend:** S-032/S-066/S-067, S-170, S-184-S-186, S-190, S-216; represented world hooks.

**Prove:** Too-small/occupied spaces, present-at-cast versus later entrants, type/direction exemptions, attacks/spells across boundary, caster leaving, interruption and allowed persistence.

<a id="sc-30"></a>

### SC-30 — Familiar, steed and undead migration

**Owns (3):** `find_familiar`, `find_steed`, `animate_dead`.

**Deliver:** Convert source-backed forms, exact identities, creation/recall/dismissal/control renewal, turn/command policies and all remaining room/combat hosts. Reuse native pickers and delivered factory/scheduling; preserve reachable content until covered.

**Reuse/extend:** S-066/S-067, S-134-S-139, S-154-S-158/S-162, S-170, S-178, S-192/S-193.

**Prove:** Form/type choices, borrowed sight/touch delivery, legal full footprint, owner removed/downed, control expiry, injured identity, canceled placement/payment and fresh-process recovery; reuse familiar, owned-creature, steed and created-undead scenarios.

<a id="sc-31"></a>

### SC-31 — Servant and temporary mount

**Owns (2):** `phantom_steed`, `unseen_servant`.

**Deliver:** Author source-defined actor capabilities, limits and commands, mount movement, ritual/long cast, range/damage/end rules and room/overworld persistence. Extend the same factory rather than making spell-specific actors.

**Reuse/extend:** S-066/S-067, S-148, S-154-S-158, S-179, S-196; prior created-actor work.

**Prove:** Task weight/reach, no combat actions where prohibited, command budgets, rider ownership, end with cargo/rider, control/range failures and exact checkpoint identities.

<a id="sc-32"></a>

### SC-32 — Object and movable light

**Owns (4):** `dancing_lights`, `light`, `produce_flame`, `continual_flame`.

**Deliver:** Deliver selected colors/forms, object/hand anchoring, real light radii, move/spacing/recast limits, covering/quenching distinctions and component consumption. Produce Flame keeps its separate attack action and source lifecycle.

**Reuse/extend:** S-032/S-070, S-148/S-162, S-187, S-190/S-191, S-196; existing room Continual Flame/object state.

**Prove:** Object moves or is covered/destroyed, one/four light forms and separation, held-hand casting, no heat/ordinary extinguishing of Continual Flame, once-only component payment and allowed recovery.

<a id="sc-33"></a>

### SC-33 — Darkness, Daylight and source dispelling

**Owns (2):** `darkness`, `daylight`.

**Deliver:** Deliver selected sphere/object origin, actual sunlight/magical-darkness consequences, covering and level-qualified overlap source ending. Reuse exact-source dispelling for Dispel Magic later.

**Reuse/extend:** S-190/S-191, S-274/S-276, S-140/S-141, S-196; captured paid cast levels and area/object source identity.

**Prove:** Eligible versus higher-level overlapping sources, unrelated light/darkness, object cover/movement, multiple owners, source removal once and checkpoint restoration of surviving sources.

<a id="sc-34"></a>

### SC-34 — Observer senses and detection masking

**Owns (5):** `darkvision`, `invisibility`, `see_invisibility`, `mind_spike`, `nondetection`.

**Deliver:** Provide generic declared sense ranges, per-observer Invisible/known-location benefits, sight into represented Ethereal space, exact tracking and detection exclusions. Remove dependencies on spell-ID perception checks.

**Reuse/extend:** S-178, S-190/S-191, S-194/S-195, S-140/S-141; reuse known-location and source-end owners.

**Prove:** 150-foot spell Darkvision versus species senses, two observers, no sight versus known location, plane/range change, attack/cast/damage endings, Divination/sensor blocking and exact cleanup.

<a id="sc-35"></a>

### SC-35 — Detection, location and Identify

**Owns (7):** `detect_evil_and_good`, `detect_magic`, `detect_poison_and_disease`, `identify`, `find_traps`, `locate_animals_or_plants`, `locate_object`.

**Deliver:** Deliver source-backed detection predicates and actual material/geometry blockers, observer-only facts and real knowledge/inspection controls. Presence-only Find Traps must not reveal a location; Identify retains exact-copy targeting and curse limits.

**Reuse/extend:** S-032/S-066/S-067, S-194/S-195/S-196, S-219; authored Crown facts and existing Identify controls.

**Prove:** Closest matching source, missing/unknown facts, walls/materials, kind/instance selection, wrong recipient, discovery secrecy, sustained touch and ritual/payment; reuse existing detection/Identify scenarios.

<a id="sc-36"></a>

### SC-36 — Animals, plants and the dead

**Owns (5):** `animal_friendship`, `animal_messenger`, `speak_with_animals`, `speak_with_dead`, `speak_with_plants`.

**Deliver:** Deliver actual typed recipients, language/communication, source-defined task/destination rules and bounded Crown-authored answers/influence outcomes. Include corpse question/ten-day limits and plant terrain changes.

**Reuse/extend:** S-014/S-032, S-179, S-194/S-195, S-216-S-219; reuse represented speech/Influence/knowledge.

**Prove:** Wrong creature type/dead body, hostile/unwilling refusal where required, per-recipient memory/lockout, exact question count, destination/terrain facts, interruption, wrong location and no reward replay.

<a id="sc-37"></a>

### SC-37 — Language and remote messages

**Owns (4):** `message`, `sending`, `comprehend_languages`, `tongues`.

**Deliver:** Deliver literal written/spoken comprehension distinctions, willing replies, target familiarity, language-independent speech where declared, range/plane/material blockers and actual message delivery.

**Reuse/extend:** S-032/S-178, S-190, S-218/S-219, S-237 communication; reuse OA-08 shared-language/audibility without treating overlap as automatic translation.

**Prove:** Known/unknown language, written versus spoken and encoded text, deafness/Silence, remote target and reply, same/different plane, source limits and no fabricated message receipt.

<a id="sc-38"></a>

### SC-38 — Divination and social consequences

**Owns (5):** `augury`, `clairvoyance`, `detect_thoughts`, `suggestion`, `zone_of_truth`.

**Deliver:** Deliver authored Augury outcomes and repeated-use uncertainty, controllable see/hear sensors, exact thought disclosure and consent/probing consequences, represented Suggestion actions and Zone of Truth truth-aware dialogue.

**Reuse/extend:** S-014/S-038, S-187/S-190/S-191/S-193, S-209/S-214, S-218/S-219; actual Crown actors, facts and outcomes.

**Prove:** One captured uncertainty roll, actual sensor placement/control, secret saves/disclosures, thought-probe endings, actionable suggestions with refusal/end policies, truthful/evasive authored responses and observer-specific recovery.

<a id="sc-39"></a>

### SC-39 — Located illusion interactions

**Owns (4):** `minor_illusion`, `silent_image`, `major_image`, `phantasmal_force`.

**Deliver:** Deliver located visual/audio/sensory representations, move controls, per-observer physical/Study discovery and declared interaction outcomes; Phantasmal Force retains exact private recipient and real damage eligibility.

**Reuse/extend:** S-148/S-187-S-191, S-218/S-219; ADR-0023 bounded illusion policy and existing Study/knowledge.

**Prove:** Unaware versus informed observer, physical contact and actual Study, failed investigation secrecy, movement/range/concentration, no invented matter or damage, exact private phantasm damage and source cleanup.

<a id="sc-40"></a>

### SC-40 — Appearance, decoys and false auras

**Owns (4):** `disguise_self`, `mirror_image`, `illusory_script`, `nystuls_magic_aura`.

**Deliver:** Deliver appearance constraints and tactile/Study discovery, actual Mirror Image attack diversion/destruction, authorized-reader script and target/detection aura overrides with recast/permanence rules.

**Reuse/extend:** S-014/S-070, S-091/S-098/S-099, S-187-S-191, S-195/S-218/S-219.

**Prove:** Valid size/limbs/gear appearance, attacker senses and exact decoy loss, authorized/uncomprehending readers, real versus false creature/magic predicates, repeated-cast counts and checkpoint state.

<a id="sc-41"></a>

### SC-41 — Locks, Knock and Dispel Magic

**Owns (3):** `arcane_lock`, `knock`, `dispel_magic`.

**Deliver:** Connect existing room magical locks to shared object selection, authorized users/passwords, one chosen mundane obstruction and ten-minute suppression. Finish target-origin Knock sound and level/check-qualified exact-source dispelling across all relevant owners.

**Reuse/extend:** S-032/S-070, S-126/S-127, S-190/S-196/S-203, S-218/S-237 sound, S-274/S-276; reuse earlier source-dispelling work.

**Prove:** Several locks/sources on one object, passwords and designated users, suppression expiry, target-origin sound with no duplicate Ready, captured paid levels, failure/decline and condition/benefit/area/object cleanup plus fresh reload.

<a id="sc-42"></a>

### SC-42 — Stored and triggered object spells

**Owns (3):** `alarm`, `magic_mouth`, `glyph_of_warding`.

**Deliver:** Deliver authored trigger and exemption facts, real audible/mental alerts or messages, stored eligible spell capture, once-only/exact-repeat release, movement restrictions and long casting/component settlement.

**Reuse/extend:** S-066/S-067/S-070, S-134-S-136, S-150/S-151, S-184, S-196/S-218/S-219.

**Prove:** Eligible/ineligible entry, invisible/unknown actor handling, exact stored level/targets, material payment, moved object, repeated observation and fresh-process recovery without trigger or spell replay.

<a id="sc-43"></a>

### SC-43 — Utility cantrips and object work

**Owns (6):** `mage_hand`, `prestidigitation`, `druidcraft`, `elementalism`, `mending`, `thaumaturgy`.

**Deliver:** Deliver every in-band mode through generic object/environment/knowledge operations with real quantities, active-effect caps, range, action and physical constraints. Druidcraft forecast uses authored information; Mending repairs an existing exact copy.

**Reuse/extend:** S-032/S-148/S-162, S-187/S-190/S-196/S-199/S-200/S-212/S-218/S-219; ordinary Utilize/Study/Influence hosts.

**Prove:** Each mode, hand weight/no-attack limits, three-effect cap, real fire/fluid/mark/object state, repair size/pieces/no magic restoration, wrong material/space, cancellation and saved exact-copy results.

<a id="sc-44"></a>

### SC-44 — Quantified food and water

**Owns (4):** `create_or_destroy_water`, `purify_food_and_drink`, `create_food_and_water`, `goodberry`.

**Deliver:** Deliver actual volume/portions and source-defined edible/drinkable/poisoned states, exact outputs and consumption, nourishment/expiry and real Crown supply consequences. Goodberry must not be just a heal button.

**Reuse/extend:** S-032/S-065/S-070, S-196/S-197/S-199/S-200, S-219; exact-copy inventory and campaign-time consumers.

**Prove:** Created/destroyed quantities, containers and space, poisoned/unknown contents, food expiry, repeated consumption, source limits, creation payment and checkpoint recovery without duplicate supplies.

<a id="sc-45"></a>

### SC-45 — Death, preservation and recovery

**Owns (3):** `gentle_repose`, `revivify`, `spare_the_dying`.

**Deliver:** Migrate real downed/dead/stable distinctions, corpse ownership/time/preservation, revival eligibility, exact component spending and actual legal combat/room controls.

**Reuse/extend:** S-014/S-066/S-067/S-070, S-072/S-073, S-175/S-176, S-235; preserve existing party-recovery behavior.

**Prove:** Alive/downed/dead, time inside/outside preservation, repeat/stale/cancel, missing diamond or free hand, corpse safe-save and fresh-process recovery; reuse party_recovery_flow and downed-area/death checks.

<a id="sc-46"></a>

### SC-46 — Prayer of Healing benefit-only recovery

**Owns (1):** `prayer_of_healing`.

**Deliver:** Deliver the ten-minute multi-participant cast, continued range/interruption, declared Short Rest benefits without a false completed-rest event, healing and per-recipient Long Rest lockout. Reuse integrated Hit Dice work when remotely available.

**Reuse/extend:** S-014, S-054/S-066/S-067, S-070/S-071, S-142; no dependency on this machine's uncommitted HitDiceRules files.

**Prove:** Five eligible recipients through the entire cast, interruption and changed location, already affected recipient, actual benefit choices, no rest-completion replay, one payment/time advancement and both fresh-process save paths.

## Existing shared baseline retained outside the migration queue

These 14 scoped definitions already declare shared execution: `acid_splash`, `bane`, `bless`, `burning_hands`, `cure_wounds`, `fire_bolt`, `fireball`, `healing_word`, `hold_person`, `inflict_wounds`, `mass_healing_word`, `poison_spray`, `sacred_flame`, `shield_of_faith`.

Retain their recorded limitations and source-clause follow-ups in the existing
spell/slice registers. They are not new native-to-shared conversions, and this
queue does not certify them fully complete. Shared-operation changes must protect
the relevant existing consumers (including these spells). New gaps required by
any of the 183 remain Crown work; add a focused follow-up assignment when found.

## Queue accounting

169 unique assignments + 14 existing shared definitions = 183 scoped spells.
The CSV assigns all 81 refused and 88 enabled-native records exactly once across
46 PRs. It covers the spell conversion lane; character acquisition, complete
class/subclass packages, ordinary movement/equipment and normal campaign proof
remain in the Crown roadmap and are not silently finished by this stack.
