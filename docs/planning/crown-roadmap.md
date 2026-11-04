# Crown rules-engine roadmap: levels 1–5

Finish the shared rules engine needed to play The Lost Crown from creation to
the level-5 finale. This is the selected campaign-sized queue. The
[main roadmap](../../roadmap.md#outside-crown) retains the wider engine backlog;
the [slice registry](vocabulary-slices.md) still owns S-IDs, prerequisites,
acceptance and verified limits. This document selects the relevant part of a
slice; it does not create a second acceptance count.

**Spell execution queue (2026-11-04):** the
[Grokbot conversion stack](crown-spell-conversion-queue.md) assigns all 169
native spells at dispatch (81 refused, 88 enabled) to 46 stackable PRs, with
missing generic support and actual-content checks included. Start with the
32-spell damage/condition sweep and keep stacking without review/merge waits,
as explicitly directed by the owner. The queue is an assignment plan, not a
readiness certification or a replacement for the finish line below.

## Scope and finish line

The [2026-11-04 usage cutoff](crown-spell-conversion-queue.md#resume-here--grokbot-usage-cutoff-2026-11-04)
records progress through reviewed PR #104 and unfinished Bestow Curse #105–106.
SC-08 onward remains unstarted; earlier partial consumers remain named in the CSV.

- The existing Crown campaign: level 1 start, level 5 cap, one to four local
  players, four stable party slots, existing companions, map, three dungeons,
  milestones, encounters, shops, objectives and supported save checkpoints.
- All twelve SRD 5.2.1 classes through **total character level 5**, including
  their SRD subclass packages, legal multiclass combinations, class choices,
  level-4 ASI/feat choices and grants that arrive at character levels 3 and 5.
  Only the clauses available by that level belong here. A level-3 subclass
  record does not pull in its level-6/10/14/17 features.
- The nine SRD species, four backgrounds, four Origin feats, two General feats
  and four Fighting Style feats. The seven Epic Boons stay in the main roadmap.
  Include SRD invocation and Metamagic options whose prerequisites can be met
  in this band, rather than treating the current chooser's shorter list as scope.
- The **183 SRD spells at levels 0–3** pinned in the
  [content scope](crown-content-scope.md#spell-inventory). Enforce actual source,
  class, species, feat and slot permissions; a Paladin or Ranger does not gain
  level-3 spell slots just because those spells are in the engine scope.
- Ordinary equipment and tools required by those character packages, plus
  equipment, consumables, spell components, creatures and objects obtainable
  through Crown's shops, events, loot, forms, summons and spell-created outputs.
  A dormant item elsewhere in the registry is not automatically Crown content.
- Combat, room and overworld consumers of those rules, including checks,
  conditions, movement, rests, time, recovery, sensory/targeting rules and
  checkpoint persistence. Low spell level does not excuse missing world behavior.

There are two required finishes. **Engine completion** means the in-scope
clauses can be authored and executed through reusable data-driven operations
and actual world hooks, with neutral/renamed consumers proving independence
from spell, class, feature, item and monster IDs. **Playable Crown completion**
also needs the actual source-backed definitions, available controls and campaign
checks. Fixtures alone do not supply the content. Existing native behavior stays
while its replacement is incomplete; keeping that behavior is useful during the
work, but native-only execution does not close the engine migration requirement.

The scope is a content boundary, not a frozen number of engine slices. A newly
found requirement of an included rule remains Crown work. A requirement used
only above this band or by unselected content goes to the main roadmap. Record
the named consumer and missing behavior before expanding the queue. Shared
prerequisites need the relevant operation, not every unrelated clause of their
broader slice or phase. Do not substitute a reduced class/spell selection for
this finish line without an explicit scope change.

## Investigated baseline — 2026-10-29

A fresh headless **Windows Godot 4.7** production-DataLoader export of the current
working tree, without fixtures, reported 14 loaded classes (12 offered), five
subclasses, nine species, zero feats, 290 items, 362 spells and 481 monsters.
There were zero validation failures and 25 rejected effectless feature records.
This is inventory evidence, not a gameplay pass. Raw export, source extraction
and logs are ignored under `.artifacts/crown-roadmap-audit/`.

- All 183 scoped spell IDs are loaded. **102 are cast-available and 81 refused;
  14 use shared execution and 169 use native execution.** These are independent
  measures: availability and the execution field prove neither correctness nor
  complete shared behavior. The spell table pins each ID and its clause-audit
  batch so the backlog is not inferred from an enabled count.
- Only Champion, Fiend Patron and Warrior of the Open Hand are present from the
  twelve target SRD subclasses. The Open Hand level-3 feature list is empty in
  the loaded registry. The other nine packages are missing. Abjurer and Diviner
  remain existing extra content, not replacements for the missing SRD Evoker.
- Backgrounds have no production content type or creation step. Goliath and Orc
  are missing; Half-Elf and Half-Orc are the two legacy entries in the nine
  currently loaded species. Production feats are empty, despite accepted generic
  acquisition/prerequisite controls.
- Current class data still has the audited Wizard/Rogue skill-list errors,
  Rogue's unrestricted Martial proficiency, absent Druid/Monk tool grants and
  Cleric's singular `shield` token. Subclass-level fallbacks are not the same as
  explicit source-backed class data. No class currently opts into
  `permanent_progression`; multiclass acquisition remains a fixture-proven
  capability without production class data and the S-234 eligibility check.
- Crown's existing campaign loop, milestones and recovery already have bounded
  checks. They are reuse points, not work to rebuild. Historical mixed-mechanics
  scenario failures still need focused reproduction; a dated failure count is
  not a current defect diagnosis.
- Familiar form/type selection and borrowed-sight/touch-delivery already have
  native room/combat controls and a bounded contract. Older follow-up prose does
  not justify rebuilding those pickers. Check the remaining source-defined forms,
  missing hosts and shared-data integration against the actual controls.
- The existing `crown_smoke` intentionally shortcuts the first boss completion
  and gives the finale party 10,000 HP/1,000 base AC against a 1-HP boss.
  `final_encounter_round_trip` forces its victory state, and Crown relaunch
  probes stage progressed saves. These are valid transition/recovery checks,
  not evidence of a normal level-1–5 journey. The final ordinary-play check below
  remains required; there is no established full-campaign gameplay pass to reuse.
  See the actual scenarios in [the harness](../../src/viewport_harness.gd) and
  [relaunch preparation](../../src/crown_fresh_relaunch_probe.gd).

## Current integration — 2026-11-03

Merged main through PR #80 now supplies the G1–G4 acquisition work and its
follow-ups, including real Skilled, class skill/tool choices and Druid/Monk tool
items; G5/G6 remain non-loaded preparation. The baseline above is historical.
Production multiclassing, complete equipment packages, backgrounds/species and
full class/subclass content remain unfinished. OA-01–OA-13 and Thunderwave's
bounded player Action/Ready sound are delivered; S-237/S-238 remain open.
See the [current lane split](crown-parallel-work.md#integrated-work--2026-11-03)
and the registry for their exact limits. Do not reassign completed packages.

## Delivery order

The [2026-11-01 review and local/Grokbot split](crown-parallel-work.md)
refreshes the inventory above and provides bounded parallel assignments. The
dated baseline's empty Open Hand feature and absent multiclass entry checks
have since changed; production multiclassing and full class packages remain
unfinished. Reuse those delivered pieces rather than implementing them again.

Finish the selected bounded assignment before expanding it. **S-237/S-238 are
requirement umbrellas, not one execution assignment.** Use their
[work packages](vocabulary-slices.md#ordinary-action-work-packages) and
[separate-chat prompts](ordinary-action-chat-prompts.md), using the verified OA-01–OA-13 boundaries to select the next missing consumer. Independent movement, Hit Dice, character and
content work can proceed when their actual prerequisites are ready; the whole
ordinary-action umbrella is not a gate. A completed package does not accept its
parent slice or waive the registry's retained requirements. Prioritize subsequent
ready assignments by the amount of scoped Crown content they unblock.
Build the prerequisites required by that slice without turning unrelated parts
of a prerequisite's broader scope into a second assignment.

Each step follows the existing sequence: settle the selected rule clauses,
implement/check missing generic operations, prepare executable definitions,
then replace covered native paths. Independent rows can proceed when their
actual prerequisites are ready. Do not wait for every spell or world system to
finish before completing an independent background or equipment improvement.

### 1. Finish ordinary combat and recovery

| Existing slices | Missing Crown behavior and next check |
|---|---|
| S-235, S-246–S-248 | Crown portion complete: shared conditions, late-created/group initiative, retained monster concentration, AI/check hosts and reachable level-3 Open Hand Topple/Push saves are verified through production flows and checkpoint recovery. S-235/S-246/S-248 are accepted; S-247 retains only level-17 Quivering Palm outside Crown. See the registry for exact boundaries. |
| S-237; relevant S-160 action/Reaction budgets | Reuse the delivered [ordinary actions/Ready/Utilize](vocabulary-slices.md#ordinary-action-continuation), [room Search/Help](vocabulary-slices.md#room-search-continuation), [object Study](../mechanics/ordinary-actions.md#study-and-authored-knowledge) and [gesture Influence](../mechanics/ordinary-actions.md#influence-through-represented-gestures). Select one [bounded work package](vocabulary-slices.md#ordinary-action-work-packages) for additional sound hosts, individual Search tasks, communication, verbal Help, recollection Study or spoken encounter Influence. The same registry section retains world NPCs, further knowledge/Search/noise and actual tool/item effects separately. An extra restricted action must not become a general Action or Reaction. Search and social actions consume steps 5/6's represented facts and real outcomes. Completing the parent umbrella is not a prerequisite for independent rows. |
| S-236, S-239, S-241 | Grapple/Shove, exact escape/drag/end conditions, fallback climb/swim, crawl, voluntary stand, jumping and declared granted/forced movement. Check Champion's critical-hit movement, Fighter Tactical Shift, Rogue Withdraw with legal paths, correct budgets and declared Opportunity Attack policy. Open Hand Push now reuses the existing forced-movement owner for up to 15 feet without Opportunity Attacks; that narrow consumer does not accept all S-241 movement. Ordinary movement/terrain S-179 and exact tethers S-168/S-169 already exist. |
| S-238 | OA-01 reviews/repairs the delivered standing flat-grid obstruction host and its targeting, AC, DEX-save, exemption and Hide consumers. Reuse existing evidence; further posture/aperture/elevation geometry remains explicit work in the registry, not an automatic expansion of this assignment. S-190/S-191 already supply bounded senses/concealment. |
| S-071, reusing S-070 | Add actual Hit Dice pools, selection, healing and Long Rest recovery, including mixed class die sizes and allowed reload. Separate Prayer of Healing's rest-like benefits from a false elapsed/completed rest event; its ten-minute casting, interruption and daily recipient limit also need their actual hosts (S-066/S-067/S-014 continuation). Rest lifecycle/actor duration is already accepted. |
| S-096, S-224, S-226 and accepted roll owners | Finish only the needed off-turn attack, noncombat check, Death Save and Concentration choice routes. Compare with the existing S-093/S-094 and captured-roll/payment machinery. A declined, stale or ineligible choice must not spend resources, roll again or duplicate the consequence. |

Start with the condition quartet and its affected production checks. Then action
and movement consumers can use the same final condition semantics. See the
[current recovery boundary](vocabulary-slices.md#srd-condition-and-roll-host-spine),
[core rules contract](../mechanics/core-rules-status.md) and
[core-rules host audit](../audits/core-rules-2.md).

### 2. Complete character acquisition and level-ups

| Existing slices | Missing Crown behavior and next check |
|---|---|
| S-231 | Background content type, selection and exact once-only grants: ability increases, Origin feat, skills, tool and equipment/gold. Add Acolyte, Criminal, Sage and Soldier; prevent old species ability bonuses from stacking on new background increases. Back/Random/seat reset and checkpoint validation must retain the chosen source and grants. |
| S-232; S-045/S-048/S-139 reuse | Complete nine-species data and lineage/ancestry/legacy, size, language, skill and spellcasting-ability choices. Apply level-3/5 grants once at the correct character level. Preserve legacy saves; do not delete or silently rewrite their species. Druidic, Thieves' Cant and Ranger language grants need real language state. |
| S-234; S-047/S-048/S-137/S-138 reuse | Verify the existing entry prerequisite code and class overrides; S-234 remains unaccepted. Production multiclassing also needs source-backed proficiency subsets and extensions to the bounded progression host, which currently refuses subclasses, most feature kinds and secondary classes with features. Class declarations alone cannot enable it. Check legal/illegal entry, total versus class level, HP, mixed slot/Pact progression, source preparation and reload without grants replaying. Crown's milestones still award total levels through 5; XP advancement is separate. |
| S-233/S-242 already accepted; S-049/S-050/S-084/S-085/S-103/S-104 reuse | Supply the ten in-band SRD feats and their effects, including Origin parameters, ASI/Grappler ability benefits and Fighting Style acquisition. Finish missing effect consumers rather than redoing prerequisite or generation controls. Validate level-4 choices, replacement cadence and exact ownership through real creation/training and fresh-process recovery. |
| Content corrections using existing owners | Correct the class skills, weapon restrictions, tool grants, armor tokens, starting packages and explicit subclass levels identified above. Check actual creation/sheet output against source; possessing a Thieves' Tools item is not the Rogue tool-proficiency grant. |

Use the [acquisition audit](../reviews/progression-acquisition-audit.md) for source
clauses and the registry for current status; that audit predates accepted S-233
and S-242. The [class-by-class scope](crown-content-scope.md#classes-and-subclasses)
owns the finite feature/package checklist for step 3.

### 3. Finish the twelve level-1–5 class and subclass packages

For each row in the content scope, map the source clauses to actual operations,
permissions, controls and lifetimes. Do not count an empty, quarantined or
native-only feature as shared-engine completion. There are no dedicated accepted
slice assignments for many of the missing subclass clauses yet: inspect their
named source body, reuse existing operations first, and add a registry requirement
only when a distinct generic capability is missing.

Priority consumers include Ranger Hunter's Mark and Hunter's Prey; Warlock Hex,
Fiend spells and eligible invocations; Monk Slow Fall, Deflect Attacks and Open
Hand Technique; the missing subclass spell grants and resource/Reaction effects;
Champion's critical threshold; and level-5 prepared-spell/Extra Attack upgrades.

Known reusable/unfinished boundaries are S-076/S-077 next-result grants,
S-084/S-085 parameter/AC upgrades, S-094 check modifiers, S-109/S-114 incoming
damage reduction/countereffects, S-123–S-127 cast/attack edits, S-134–S-142 spell
permission/payment/preparation/parameters, S-154–S-158 owned creatures,
S-163/S-164 forms/equipment, S-181 falling and S-240/S-241 threshold/movement.
The existing [Second Wind conversion blocker](vocabulary-slices.md#conversion-batch-001)
also needs Tactical Mind refund and Tactical Shift wired to the same resource.
These are continuations of existing owners, not a new class executor per class.

In particular, a generic pre-damage reduction and a generic post-damage
countereffect do not by themselves prove Deflect Attacks' optional Focus
payment, target/range/cover selection, damage type and save. Check the whole
declared sequence. Slow Fall must reach actual falling damage. A present
Open Hand subclass record must supply its level-3 technique.

Check each completed package at levels 1, 3, 4 and 5 through ordinary menus and
legal off-turn windows, with its actual choices and resources. Test allowed
reload when durable grants/state change. Keep class-level 6+ follow-ups in the
main roadmap even when their helpers share the same source file.

### 4. Complete the scoped spell engine and actual spell definitions

The 183-ID table is the work boundary, not just the 81 currently refused spells.
Audit cast-available native spells too. Use the complete
[spell clause audit](../audits/spells.md) to locate requirements, then compare
with current owners; its old `Planned` labels do not override newer acceptance.

| Existing slices/owners | Concrete in-band consumers and missing boundary |
|---|---|
| S-041/S-042/S-134/S-135 continuation; S-160 | Hellish Rebuke, Counterspell, Feather Fall and hit-triggered smites need the actual qualifying damage/cast/fall/hit windows across player and monster routes, with legal reaction/bonus-action payment. Existing bounded reaction delivery is not every attack/spell/area route. |
| S-032/S-091/S-098/S-099 continuation | Shatter must damage every eligible object, including objects collocated with creatures, without a CON save for objects; Burning Hands/Fireball need their unworn flammable-object consumers. Preserve unknown material/equipment facts rather than inventing eligibility. |
| S-076/S-077/S-080/S-086/S-087; S-126/S-127/S-140/S-141 continuation | Hunter's Mark, Hex, Guiding Bolt, Haste, Enlarge/Reduce, Dragon's Breath, False Life/Fiendish Vigor, and timed multi-recipient benefits need their actual retarget, hit/save, attack-unit, parameter and lifetime hosts. Flat condition duration support does not establish benefit, actor, zone and item lifetimes. |
| S-267 | Chromatic Orb's captured matching-face leap: next legal target, fresh attack/damage, slot-based chain cap and no repeat creature. Damage-type selection alone is insufficient. |
| S-183/S-241/S-269 | Dissonant Whispers' recipient Reaction movement and Command/Fear compelled behavior need actual safe routes, budgets and correct Opportunity Attack rules. A Frightened condition flag does not execute Fear's movement. |
| S-180/S-181/S-185/S-186; S-121/S-122/S-170/S-172 continuation | Gaseous Form, Meld into Stone, Blink, Fly, Levitate, Wind Wall, Tiny Hut, Rope Trick and Floating Disk need their actual occupancy, fall/return, selective barrier, occupant and movement rules. Do not require planar travel everywhere or damageable high-level wall segments just to close a narrower low-level consumer. |
| S-154–S-158/S-162/S-163/S-164 continuation; S-178/S-192/S-193 | Find Familiar, Find Steed, Animate Dead, Unseen Servant, Phantom Steed, Spiritual Weapon and Wild Shape need their remaining choice, command, form, remote-origin, recall and exploration hosts. Reuse accepted placement/commands/turns and party recovery instead of restarting those systems. |
| S-187/S-188/S-189; S-190/S-191 continuation | Minor/Silent/Major Image, Disguise Self, Mirror Image and Phantasmal Force need located representations, per-observer discovery and actual selected interaction/effect outcomes. No universal AI or free-text GM is required; unsupported world outcomes must remain explicit. |
| S-194/S-195/S-218/S-219 | Detection/location, languages, Message/Sending, thought/attitude and Speak with Animals/Plants/Dead require represented targets, knowledge and communication. Add actual Crown-authored answers/interactions; do not enable a spell that only records that a conversation occurred. Augury needs the authored outcome and once-rolled repeated-use uncertainty (S-209/S-214 reuse as applicable). |
| S-197/S-199/S-200/S-205/S-212/S-213 | Create/Purify Food or Water, Goodberry, Plant Growth, Water Breathing/Alter Self and Mending need real quantities, environmental/breathing consumers, campaign outcomes and exact damaged-object repair/piece constraints. Do not substitute new objects for repairing an existing copy. |
| S-150/S-151; S-184/S-203 continuation | Glyph of Warding stores an exact eligible spell and releases it once at its real trigger; Arcane Lock/Knock, magical triggers and persistent room states must have working world controls and allowed checkpoint recovery. Existing room locks/areas are reuse points. |
| S-274/S-276; S-116/S-190 reuse | Darkness/Daylight overlap ending and Dispel Magic need captured cast levels, thresholds, higher-level checks and exact-source removal across condition/benefit/area/object owners. Accepted senses and generic negation alone do not establish spell-level dispelling. |

Rows are consumer groups, not extra S-IDs or universal prerequisite gates. Source
clauses that use an already accepted operation need executable data and a focused
consumer check. A distinct missing operation needs a slice/extension with a
concrete finish line. Some spells also need the action, information, equipment
and exploration work in other steps; those dependencies are shared, not repeated.

### 5. Finish equipment, exploration and Crown world consumers

| Existing slices/owners | Required Crown boundary and proof |
|---|---|
| S-249/S-251/S-266; S-196 continuation | Ammunition items, exact spending/recovery, free-hand/loading behavior, armor proficiency/Strength/Stealth restrictions and actual carried weight/size limits. Include equipped/carried/container contents without double-counting. Range/Heavy (S-250) and don/doff (S-252) are already accepted. |
| S-197/S-256/S-258; S-028/S-168/S-169/S-184 reuse | Fuel/portions, tool use, acid/holy-water/alchemist's-fire attack substitutions, Net, caltrops and ball bearings where the scoped equipment packages grant them. The current purchasable Net does ordinary weapon damage; it needs its real attack-replacement/restraint behavior. New pack contents must resolve to actual items and usable quantities. |
| S-227/S-228; S-065/S-179/S-200/S-219 reuse | Real travel time/pace, terrain, marching-order and survival checks on Crown's five-mile hexes; keep milestone level-ups. Check slow members/mounts, timed benefits, supplies, event delivery, interruption and allowed reload without duplicate distance/time or consequences. Campaign-authored navigation/foraging outcomes fill facts the SRD leaves to the campaign. |
| S-229/S-230; S-188/S-190/S-212 reuse | Actual local Search, hidden-object/trap discovery, key/tool/disarm/break routes and once-only state/costs. Crown has generated `trapped_chest` events and authored room doors/objects; a disconnected event roll is not a general spatial trap procedure. |
| S-216/S-217/S-218/S-219 relevant consumers | Reuse current objective/reward ledgers and event continuations; prove authored information, language, influence and any spell-conditioned objective can resolve against actual Crown actors/objects. Wrong location/recipient and an unfinished child event must not award knowledge or rewards. |

The current merchant predicate admits 64 items (pinned in the content scope),
including non-SRD firearms and a lantern record that needs its actual light/fuel
path checked. Do not silently turn all 290 loaded items into mandatory content.
Preserve existing extras during development; resolve their availability or
campaign-specific rule policy before final acceptance. Dormant magic shells,
rarity alone and the existence of an item schema do not select the full magic
item backlog. If an in-scope consumer actually obtains an item power, pull its
specific S-253–S-265 requirement into this queue with that receipt.

### 6. Verify enemies, real content and the complete campaign

The [content scope](crown-content-scope.md#campaign-and-world-inventory) pins ten
direct Crown encounter monster IDs. Include the actual actors reachable through
forms, familiars, summons and created undead as those packages are completed.
Audit their loaded attacks/traits through shared operations too: Wight maximum-HP
loss, Spider poison/restraint, Zombie Fortitude, Ooze corrosion and Lich King
paralysis, spellcasting, turning resistance and Legendary Resistance. S-109–S-120,
S-130/S-131 and S-235/S-246–S-248 provide reuse points; a trait name/description
in JSON is not an executable grant. The custom CR-8 Lich King remains in Crown
because the campaign uses it, despite the party's level-5 cap. Preserve the
custom encounter; this is not a request to replace it with the SRD Lich.

Reproduce the remaining scenario investigations before assigning fixes. In
particular, separate the high-level Bard standing prompt and Ranger Nature's
Veil failures from low-level aura, Identify, movement/cost, typed hit-grant,
damage-settlement and Wizard casting failures. Scope follows the reproduced
consumer, not the scenario's filename. The repaired Heroism/Enhance Ability
source-count expectations and creation matrix are not new repair assignments.

Acceptance uses the supported [Windows runner](../testing.md), with the existing
tests appropriate to each changed behavior, not a fresh parallel harness:

1. Relevant logic groups and actual input-path checks for each engine capability;
   neutral/renamed definitions prove reusable execution. Review shared combat or
   persistence changes independently as required by AGENTS.md.
2. Actual source-backed class/subclass/feat/spell/equipment definitions exercise
   the same path, including cancellation, stale targets, once-only payment,
   condition/source cleanup and the correct actor's budgets.
3. Run existing `normal_creation_matrix`, relevant class action/creation flows,
   `core12_audit_repairs`, `mixed_mechanics_encounter`, `spell_effect_lifetime`
   and new focused regressions only where a missing/likely failure needs one.
   Triage mixed scenarios by clause/level; a high-level unrelated failure remains
   visible in the main backlog without pretending the scenario is all green.
4. Exercise `crown_smoke`, `crown_composition_solo_two`,
   `crown_composition_three_four`, `crown_balance_fixture` and
   `dungeon_reentry_round_trip`/`final_encounter_round_trip`, plus the existing Crown single-/two-player
   separate-process relaunch scripts. Verify level 1→5 milestones, choices at
   3/4/5, three fragments, final victory, defeat, safe save/reload, ownership and
   once-only rewards. Add the missing normal journey coverage in the existing
   harness: start from actual creation, earn the four milestones and three
   fragments, settle training/choices, rest and resume an allowed checkpoint,
   and defeat the actual finale through legal commands with normal stats,
   resources and rewards. No invulnerable party, 1-HP replacement boss, manual
   victory settlement or pre-staged completed milestones count as that proof.
   Existing isolated failure/transition fixtures keep their bounded purpose.
5. Observe a normal campaign run in the game for controls, encounter readability
   and pacing. Headless assertions do not certify visual/input usability or
   balance. Stop any play session started for this check.

Completion requires evidence for the full scope above, including the still
unmapped class/subclass/option clauses. There is no current claim that the
engine or campaign is complete, and no trustworthy remaining-slice percentage.
Finish behavior and its real consumers; update acceptance only in the slice
registry and per-content contracts/registers.

## Where to start next

The **Crown portion of S-235/S-246–S-248 is complete**; level-17 Quivering
Palm remains outside Crown. Next take ordinary actions/movement and Hit Dice.
Independent background/species data preparation can use the existing acquisition
contracts when actually staffed. Then complete each ready character/spell package
through the sequence above. No universal engine, full SRD audit rerun, new save
framework, complete magic-item catalog or high-level class pass is a gate.
