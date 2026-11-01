# Crown content scope

This is the finite content checklist for the
[Crown rules-engine roadmap](crown-roadmap.md), pinned on 2026-10-29. It records
what must be covered and the investigated starting inventory, not a new rules
authority or an acceptance ledger. Slice status belongs in
[vocabulary-slices.md](vocabulary-slices.md); actual spell delivery belongs in
the [spell register](../mechanics/spell-status.md).

The [2026-11-01 review and work split](crown-parallel-work.md) refreshes the
production inventory and identifies changed claims in this dated baseline,
including delivered Open Hand Technique and the existing multiclass entry gate.
The scope below remains unchanged.

## Source and inventory evidence

- SRD 5.2.1 is the authority. The existing
  [spell clause audit and inventory](../audits/spells.md),
  [acquisition audit](../reviews/progression-acquisition-audit.md),
  [core rules audit](../mechanics/core-rules-status.md),
  [equipment audit](../audits/items.md) and class contracts locate source clauses.
- The [revised class views](../../reference/2024/README.md) locate each class and
  subclass body. Their SRD flags are inventory hints, not correctness proof.
  Read the actual selected SRD body before preparing executable content. Unresolved
  option references remain source work under SRC-01/SRC-04, limited to this band.
- The current-tree production loader was exported on Windows Godot 4.7, without
  fixtures. Registry SHA-256: `01d6a4c6cd2327c72cd546fb68f3891715e7d6de8cacc08cc7902dfa54eb7129`.
  Zero validation failures; 25 unsupported effectless feature records rejected.
  Feats are counted separately because the registry snapshot hash omits them.
  The merchant list was obtained by calling the actual `ShopUI._is_buyable_item`
  predicate on the loaded items. Raw data/logs stay in ignored
  `.artifacts/crown-roadmap-audit/`.
- The fresh spell export can be reproduced with the existing
  [inventory scene](../../scenes/spell_inventory_export.tscn) and
  [export script](../../scripts/export_spell_inventory_node.gd), using an isolated
  profile as described by the [Windows runner](../testing.md). Join exported IDs
  with [spell-inventory.csv](../audits/spell-inventory.csv): `milestone = srd521`
  and `level <= 3`. Read current availability and `execution` from the export,
  not the older CSV. The batch column below points to the source-clause audit.

## Classes and subclasses

Each row requires the full level-1–5 base package, legal source-owned choices,
multiclass entry/grants and the named subclass's in-band clauses. Existing
mechanics are partial reuse points, not full package acceptance. Level-4 ASI/feat
and normal spell/preparation/resource progression apply to every eligible row.
Spells granted by a subclass at class level 5 are included even though the
subclass's first feature is acquired at level 3.

| Class and source | Base feature checklist through level 5 | SRD subclass and required in-band package | Investigated gap / engine reuse |
|---|---|---|---|
| [Barbarian](../../reference/2024/classes/barbarian.json) / [contract](../mechanics/barbarian-2024.md) | Rage, Unarmored Defense, Weapon Mastery, Danger Sense, Reckless Attack, Primal Knowledge, Extra Attack, Fast Movement | **Berserker:** Frenzy | Subclass absent. Existing Rage/attack/resource behavior has bounded checks; convert resistance/check-ability/roll and upkeep consumers through existing grant, S-091/S-126/S-141 and S-084/S-085 owners. Fast Movement is already generic. |
| [Bard](../../reference/2024/classes/bard.json) / [contract](../mechanics/bard-2024.md) | Spellcasting, Bardic Inspiration, Expertise, Jack of All Trades, Font of Inspiration | **Lore:** Bonus Proficiencies, Cutting Words | Subclass absent. Reuse skill acquisition, source dice, exact post-roll windows and payment (S-023/S-041/S-094/S-096); check the affected enemy roll and reaction timing rather than treating Inspiration as an equivalent. |
| [Cleric](../../reference/2024/classes/cleric.json) / [contract](../mechanics/cleric-2024.md) | Spellcasting, Divine Order choices, Channel Divinity, Divine Spark, Turn Undead, Sear Undead | **Life:** Domain Spells through class level 5, Disciple of Life, Preserve Life | Subclass absent. Source healing riders and budgeted multi-recipient healing need an exact operation/control mapping; Divine Spark does not prove Preserve Life's allocation/eligibility. Reuse S-098/S-101/S-102/S-134–S-139 and resource owners where they actually fit. |
| [Druid](../../reference/2024/classes/druid.json) / [contract](../mechanics/druid-2024.md) | Spellcasting, Druidic, Primal Order choices, Wild Shape, Wild Companion, Wild Resurgence | **Land:** selected land spell packages through class level 5, Land's Aid | Subclass absent. Druidic needs language state; form/companion integration is partial. Reuse S-052/S-134–S-139/S-154–S-158/S-163/S-164; source-map Land's Aid area, healing/damage, costs and land selection without a class-ID branch. |
| [Fighter](../../reference/2024/classes/fighter.json) / [contract](../mechanics/fighter-2024.md) | Fighting Style, Weapon Mastery, Second Wind, Action Surge, Tactical Mind, Extra Attack, Tactical Shift | **Champion:** Improved Critical, Remarkable Athlete | Present with native/shared mixed behavior. Finish S-240's threshold consumer and S-241's post-critical/Tactical Shift movement; S-094/resource refund and S-084/S-085/S-127 remain relevant conversion boundaries. |
| [Monk](../../reference/2024/classes/monk.json) / [contract](../mechanics/monk-2024.md) | Martial Arts/Unarmed Strike choices, Unarmored Defense, Focus/Flurry/Patient Defense/Step of the Wind, Unarmored Movement, Uncanny Metabolism, Deflect Attacks, Slow Fall, Extra Attack, Stunning Strike | **Open Hand:** Open Hand Technique (Addle, Push, Topple) | Subclass present but its loaded level-3 feature list is empty; Slow Fall also absent from loaded grants. Need S-181 falling, S-241 Push, action/condition/save consumers, and full Deflect target/payment continuation. Step of the Wind's passenger upgrade is level 10 and stays outside Crown. |
| [Paladin](../../reference/2024/classes/paladin.json) / [contract](../mechanics/paladin-2024.md) | Spellcasting, Lay on Hands, Weapon Mastery, Fighting Style options, Paladin's Smite, Channel Divinity/Divine Sense, Extra Attack, Faithful Steed | **Devotion:** Oath Spells through class level 5, Sacred Weapon | Subclass absent. Reuse spell permission/source benefits and S-084/S-085/S-134–S-139. Finish actual post-hit Smite/Bonus Action routing and the remaining exploration steed controls/occupancy; accepted combat arrival is not a new assignment. |
| [Ranger](../../reference/2024/classes/ranger.json) / [contract](../mechanics/ranger-2024.md) | Spellcasting, Favored Enemy, Weapon Mastery, Deft Explorer, Fighting Style options, Extra Attack | **Hunter:** Hunter's Lore, Hunter's Prey choices | Subclass absent; Hunter's Mark is currently refused. Need its source-specific damage, duration, free-use/slot, transfer and tracking consumers plus Hunter's actual disclosures/riders; reuse S-031/S-043/S-076/S-141/S-148/S-194 and acquisition owners. Languages and tool/weapon lists need source-backed data. |
| [Rogue](../../reference/2024/classes/rogue.json) / [contract](../mechanics/rogue-2024.md) | Expertise, Sneak Attack, Thieves' Cant, Weapon Mastery, Cunning Action, Steady Aim, Cunning Strike (Poison/Trip/Withdraw), Uncanny Dodge | **Thief:** Fast Hands, Second-Story Work | Subclass absent. Reuse exact hit/turn/die-cost owners; finish S-237 actions/Hide, S-239 climb/jump and S-241 Withdraw. Tools, language and restricted Martial proficiency need real grants; Fast Hands must invoke the correct usable-item action and cost. |
| [Sorcerer](../../reference/2024/classes/sorcerer.json) / [contract](../mechanics/sorcerer-2024.md) | Spellcasting, Innate Sorcery, Font of Magic, eligible Metamagic options, Sorcerous Restoration | **Draconic:** Draconic Resilience, Draconic Spells through class level 5 | Subclass absent. Reuse AC/max-HP and source spell grants; finish applicable S-123–S-127/S-140/S-141 hosts for each Metamagic option and each spell payload, preserving Sorcery Points/slot choices and casts already in flight. |
| [Warlock](../../reference/2024/classes/warlock.json) / [contract](../mechanics/warlock-2024.md) | Pact Magic, all in-band eligible invocation options and replacements, Magical Cunning | **Fiend:** Dark One's Blessing, Fiend Spells through class level 5 | Subclass present, mixed execution. Hex, Fiend free-cast transforms and other eligible invocation consumers remain incomplete. Reuse source spell/Pact/resource/Temporary-HP owners; audit familiar/pact-item consumers by actual invocation prerequisites. |
| [Wizard](../../reference/2024/classes/wizard.json) / [contract](../mechanics/wizard-2024.md) | Spellcasting/spellbook acquisition and copying, Ritual Adept, Arcane Recovery, Scholar, Memorize Spell | **Evoker:** Evocation Savant, Potent Cantrip | SRD subclass absent. Abjurer/Diviner remain existing extra packages. Reuse S-045/S-046/S-054/S-099/S-134–S-139; source-map school-based acquisition and failed-save/missed-attack cantrip outcomes instead of assuming an existing Evasion host is sufficient. |

The subclass/source rows above locate required work, including clauses whose
final S-ID assignment is not established. They do not claim every source clause
has passed a runtime audit. Resolve selected missing bodies before claiming
capability closure; no high-level feature review is a prerequisite for a known
low-level feature. Shared combat/persistence changes still require the focused
review in AGENTS.md.

## Species, backgrounds and feats

| Content set | Required records / choices | Current boundary |
|---|---|---|
| Species | Dragonborn, Dwarf, Elf, Gnome, Goliath, Halfling, Human, Orc, Tiefling; legal lineage/ancestry/legacy, size, language, skill and spellcasting choices; character-level 3/5 grants | Goliath/Orc absent; existing nine include legacy Half-Elf/Half-Orc. S-232 and source-backed data still needed. Do not delete legacy saves or their records. |
| Backgrounds | Acolyte, Criminal, Sage, Soldier; legal ability increases, Origin feat, two skills, tool and equipment/GP choices | No production content type/creation step. S-231 plus four real definitions. |
| Origin feats | Alert, Magic Initiate (all legal parameters), Savage Attacker, Skilled | No production feat definitions. S-233 prerequisite/parameter controls are already accepted; effects and actual grants remain work. |
| General feats | Ability Score Improvement, Grappler | No production definitions. Include correct ability benefits and Grappler's actual grapple/attack/movement consumers; S-236/S-239 and existing acquisition/attack owners. |
| Fighting Style feats | Archery, Defense, Great Weapon Fighting, Two-Weapon Fighting | Existing class-native/choice implementations are reuse points; actual source-owned feat grants and exact eligible attacks/equipment still need conversion/proof. |

No Epic Boon, level-19 entitlement or post-20 feat is a Crown requirement.
Background/feat/species effects are not limited to the fields currently accepted
by a chooser; complete their source clauses through the generic engine.

## Campaign and world inventory

Authority: [the loaded campaign](../../data/core/campaigns/the_lost_crown.json),
[DungeonGenerator](../../src/dungeon/dungeon_generator.gd),
[overworld/rest consumers](../../src/overworld/overworld_state.gd),
[shop predicate](../../src/ui/shop.gd) and loaded event/monster records. The
[campaign band](../crown_campaign_band.md) and
[Ruins balance fixture](../crown_ruins_balance_fixture.md) describe existing checks.

| Boundary | Pinned inventory / required continuation |
|---|---|
| Journey | 43 map tiles; Elderwick start; five miles per hex; Ruins of Ashvale (5 rooms), Caverns of Gloom (6), Tower of the Lich (7). Total levels advance at enter dungeon 1, clear dungeon 1, clear dungeon 2, enter dungeon 3. Three Crown fragments plus defeating `lich_king` complete the campaign. |
| Party | One to four player characters, companions Aldric/Mira/Rowan and four stable active slots. Existing ownership, roster, composition and safe checkpoint checks remain required. |
| Direct encounter monsters | `bandit`, `giant_spider`, `goblin`, `goblin_chief`, `lich_king`, `ooze`, `skeleton`, `wight`, `wolf`, `zombie`. Union of dungeon pools/bosses, map event tables and rest ambush pool. No full 481-monster audit is required. |
| Additional actors | Legal in-band Wild Shape forms, familiar/steed forms, Animate Dead outputs and other scoped spell-created actors. Resolve those source-defined sets with their packages; they are required consumers even if absent from direct dungeon pools. Do not count the ten direct IDs as the complete creature scope. |
| Monster behavior | Reuse actual damage/condition/save/AI owners; finish generic data for the reachable traits/attacks and legal spells. Current Lich King spells are Fire Bolt, Ray of Frost, Magic Missile, Shield, Scorching Ray, Fireball and Counterspell. Its CR 8 is not grounds to exclude the finale. Rejuvenation's longer aftermath is a campaign-ending-policy question; do not imply a phylactery/ten-day simulation already exists. |
| Locations/events | Four loaded event tables (`dungeon_events`, `forest_events`, `mountain_events`, `town_events`), generated trap/loot rooms and authored tactical room objects/terrain. Actual locks/hidden items/traps, location-sensitive checks, supplies, hazards and once-only rewards need their supported controls/state. |
| Items | Current merchant IDs below, actual starting-equipment alternatives and pack/tool contents, companion gear, loot/event outputs, tactical-object contents, spell components and low-level created copies. New source-backed background/class definitions may expose missing ordinary equipment; that is Crown work. |
| Magic-item limit | Dormant shells with zero shop value and no reachable reward/grant are outside Crown. Current reachable magical consumables still count regardless of rarity. Existing supplemental/legacy content remains a regression boundary; resolve offering policy explicitly rather than treating it as SRD scope or silently deleting it. |

The current Druid data offers ten non-flying forms at CR 1/2 or below:
`rat`, `riding_horse`, `spider`, `wolf`, `boar`, `giant_badger`, `panther`,
`giant_wolf_spider`, `giant_venomous_snake`, `giant_goat`; CR 1/2 is not available
until Druid level 4. Familiar controls currently offer Cat/Owl/Rat/Spider, with
their existing type choice and native sight/Touch delivery. These are current
curated subsets, not proof that all legal SRD forms and their traits are covered.
Source-pin the remaining legal options when completing the form package rather
than importing every loaded monster or accepting a hardcoded four-form cap.

Campaign-check gap: `test_crown_smoke` and `test_final_encounter_round_trip` in
[the harness](../../src/viewport_harness.gd) shortcut victories; the relaunch
probes stage progress. Preserve those bounded checks and add the normal
creation-to-finale progression/combat proof required by the roadmap. Their green
results alone cannot certify normal resources, level-up choices or balance.

### Current merchant IDs

The production predicate admitted **64** IDs in the pinned export. This is an
availability inventory, not proof of each item rule or of affordability at every
point in the campaign. Musket and Pistol are current non-SRD exposure to resolve
under the existing SRD milestone policy; their presence does not add supplements
to the target. Higher-grade healing potions are included because they are sold.

`antidote`, `battleaxe`, `black_pearl_powder_500gp`, `blowgun`, `breastplate`, `chain_mail`, `chain_shirt`, `club`, `dagger`, `dart`, `diamond_300gp`, `flail`, `gentle_repose_copper`, `glaive`, `greataxe`, `greatclub`, `greatsword`, `halberd`, `half_plate_armor`, `hand_crossbow`, `handaxe`, `heavy_crossbow`, `hide_armor`, `incense_10gp`, `javelin`, `lance`, `lantern_bullseye`, `leather_armor`, `light_crossbow`, `light_hammer`, `longbow`, `longsword`, `mace`, `maul`, `morningstar`, `mushroom_powder_25gp`, `musket`, `net`, `padded_armor`, `pearl_100gp`, `pike`, `pistol`, `plate_armor`, `potion_greater_healing`, `potion_healing`, `potion_superior_healing`, `potion_supreme_healing`, `quarterstaff`, `rapier`, `ring_mail`, `scale_mail`, `scimitar`, `shield`, `shortbow`, `shortsword`, `sickle`, `sling`, `spear`, `splint_armor`, `studded_leather_armor`, `trident`, `war_pick`, `warhammer`, `whip`.

## Spell inventory

All **183** SRD level-0–3 IDs below are required. The snapshot has **102 available,
81 refused; 14 shared, 169 native**. Availability was queried in the export's
non-combat context; some native spells have additional combat/room restrictions.
`shared` means the loaded record declares shared execution; `native` means it
does not. Neither label is full rule certification. Class abbreviations:
B = Bard, C = Cleric, D = Druid, P = Paladin, R = Ranger, S = Sorcerer,
W = Warlock, Z = Wizard. The memberships come from current loaded spell records;
subclass/species/feat permissions can grant additional legal access.

Audit batches refer to the [existing clause decomposition](../audits/spells.md).
Owner IDs in that audit are leads, not automatic dependencies: compare with
current registry acceptance and the selected low-level clause. For example,
Druidcraft's forecast needs represented forecast information; it does not pull
in the entire level-8 Control Weather procedure in S-275. A native spell using
generic helpers still needs its complete authored shared definition before the
engine migration gate can close.

| Spell ID | Level | Classes | Cast available | Execution | Clause audit |
|---|---:|---|---|---|---|
| `acid_splash` | 0 | S Z | yes | shared | 088-1 |
| `chill_touch` | 0 | S W Z | yes | native | 088-1 |
| `dancing_lights` | 0 | B S Z | yes | native | 088-6 |
| `druidcraft` | 0 | D | no | native | 088-7 |
| `eldritch_blast` | 0 | W | yes | native | 088-2 |
| `elementalism` | 0 | D S Z | no | native | 088-7 |
| `fire_bolt` | 0 |  | yes | shared | 088-2 |
| `guidance` | 0 | C D | yes | native | 088-4 |
| `light` | 0 |  | yes | native | 088-6 |
| `mage_hand` | 0 |  | yes | native | 088-7 |
| `mending` | 0 | B C D S Z | no | native | 088-7 |
| `message` | 0 | B D S Z | yes | native | 088-8 |
| `minor_illusion` | 0 | B S W Z | yes | native | 088-7 |
| `poison_spray` | 0 | D S W Z | yes | shared | 088-1 |
| `prestidigitation` | 0 | B S W Z | yes | native | 088-7 |
| `produce_flame` | 0 | D | yes | native | 088-6 |
| `ray_of_frost` | 0 |  | yes | native | 088-1 |
| `resistance` | 0 | C D | yes | native | 088-4 |
| `sacred_flame` | 0 | C | yes | shared | 088-2 |
| `shillelagh` | 0 | D | yes | native | 088-4 |
| `shocking_grasp` | 0 | S Z | yes | native | 088-2 |
| `sorcerous_burst` | 0 | S | yes | native | 088-2 |
| `spare_the_dying` | 0 | C D | yes | native | 088-2 |
| `starry_wisp` | 0 | B D | yes | native | 088-2 |
| `thaumaturgy` | 0 | C | no | native | 088-7 |
| `true_strike` | 0 | B S W Z | yes | native | 088-8 |
| `vicious_mockery` | 0 | B | yes | native | 088-3 |
| `alarm` | 1 | R Z | yes | native | 088-7 |
| `animal_friendship` | 1 | B D R | yes | native | 088-3 |
| `bane` | 1 | B C W | yes | shared | 088-4 |
| `bless` | 1 | C P | yes | shared | 088-4 |
| `burning_hands` | 1 |  | yes | shared | 088-2 |
| `charm_person` | 1 | B D S W Z | yes | native | 088-3 |
| `chromatic_orb` | 1 | S Z | no | native | 088-2 |
| `color_spray` | 1 | B S Z | yes | native | 088-3 |
| `command` | 1 | B C P | yes | native | 088-3 |
| `comprehend_languages` | 1 | B S W Z | no | native | 088-8 |
| `create_or_destroy_water` | 1 | C D | yes | native | 088-7 |
| `cure_wounds` | 1 | B C D P R | yes | shared | 088-2 |
| `detect_evil_and_good` | 1 | C P | yes | native | 088-6 |
| `detect_magic` | 1 | B C D P R S W Z | yes | native | 088-6 |
| `detect_poison_and_disease` | 1 | C D P R | yes | native | 088-6 |
| `disguise_self` | 1 | B S Z | no | native | 088-7 |
| `dissonant_whispers` | 1 | B | no | native | 088-3 |
| `divine_favor` | 1 | P | yes | native | 088-4 |
| `divine_smite` | 1 | P | yes | native | 088-8 |
| `ensnaring_strike` | 1 | R | no | native | 088-8 |
| `entangle` | 1 | D R | yes | native | 088-3 |
| `expeditious_retreat` | 1 | S W Z | no | native | 088-4 |
| `faerie_fire` | 1 | B D | yes | native | 088-6 |
| `false_life` | 1 | S Z | yes | native | 088-4 |
| `feather_fall` | 1 | B S Z | no | native | 088-6 |
| `find_familiar` | 1 | Z | yes | native | 088-8 |
| `fog_cloud` | 1 | D R S Z | yes | native | 088-6 |
| `goodberry` | 1 | D R | yes | native | 088-7 |
| `grease` | 1 | S Z | yes | native | 088-3 |
| `guiding_bolt` | 1 | C | yes | native | 088-2 |
| `healing_word` | 1 | B C D | yes | shared | 088-2 |
| `hellish_rebuke` | 1 | W | no | native | 088-2 |
| `heroism` | 1 | B P | yes | native | 088-4 |
| `hex` | 1 | W | no | native | 088-4 |
| `hunters_mark` | 1 | R | no | native | 088-4 |
| `ice_knife` | 1 | D S Z | yes | native | 088-2 |
| `identify` | 1 | B Z | yes | native | 088-7 |
| `illusory_script` | 1 | B W Z | no | native | 088-7 |
| `inflict_wounds` | 1 | C | yes | shared | 088-2 |
| `jump` | 1 | D R S Z | yes | native | 088-6 |
| `longstrider` | 1 | B D R Z | yes | native | 088-4 |
| `mage_armor` | 1 | S Z | yes | native | 088-4 |
| `magic_missile` | 1 |  | yes | native | 088-2 |
| `protection_from_evil_and_good` | 1 | C D P W Z | yes | native | 088-4 |
| `purify_food_and_drink` | 1 | C D P | yes | native | 088-7 |
| `ray_of_sickness` | 1 | S Z | yes | native | 088-4 |
| `sanctuary` | 1 | C | yes | native | 088-4 |
| `searing_smite` | 1 | P | no | native | 088-8 |
| `shield` | 1 |  | yes | native | 088-4 |
| `shield_of_faith` | 1 | C P | yes | shared | 088-4 |
| `silent_image` | 1 | B S Z | no | native | 088-7 |
| `sleep` | 1 |  | yes | native | 088-3 |
| `speak_with_animals` | 1 | B D R W | no | native | 088-7 |
| `tashas_hideous_laughter` | 1 | B W Z | no | native | 088-3 |
| `tensers_floating_disk` | 1 | Z | no | native | 088-7 |
| `thunderwave` | 1 |  | yes | native | 088-2 |
| `unseen_servant` | 1 | B W Z | no | native | 088-8 |
| `aid` | 2 | B C D P R | yes | native | 088-4 |
| `alter_self` | 2 | S Z | yes | native | 088-8 |
| `animal_messenger` | 2 | B D R | yes | native | 088-8 |
| `arcane_lock` | 2 | Z | no | native | 088-7 |
| `augury` | 2 | C D Z | no | native | 088-8 |
| `barkskin` | 2 | D R | yes | native | 088-4 |
| `blindness/deafness` | 2 | B C S Z | yes | native | 088-3 |
| `blur` | 2 | S Z | yes | native | 088-4 |
| `calm_emotions` | 2 | B C | no | native | 088-3 |
| `continual_flame` | 2 | C D Z | no | native | 088-6 |
| `darkness` | 2 | S W Z | yes | native | 088-6 |
| `darkvision` | 2 | D R S Z | yes | native | 088-6 |
| `detect_thoughts` | 2 | B S Z | no | native | 088-8 |
| `dragons_breath` | 2 | S Z | no | native | 088-8 |
| `enhance_ability` | 2 | B C D R S Z | yes | native | 088-4 |
| `enlarge/reduce` | 2 | B D S Z | no | native | 088-4 |
| `enthrall` | 2 | B W | no | native | 088-3 |
| `find_steed` | 2 | P | yes | native | 088-8 |
| `find_traps` | 2 | C D R | no | native | 088-6 |
| `flame_blade` | 2 | D S | no | native | 088-8 |
| `flaming_sphere` | 2 | D S Z | no | native | 088-5 |
| `gentle_repose` | 2 | C P Z | yes | native | 088-8 |
| `gust_of_wind` | 2 | D R S Z | no | native | 088-5 |
| `heat_metal` | 2 | B D | no | native | 088-7 |
| `hold_person` | 2 | B C D S W Z | yes | shared | 088-3 |
| `invisibility` | 2 | B S W Z | yes | native | 088-6 |
| `knock` | 2 | B S Z | no | native | 088-7 |
| `lesser_restoration` | 2 | B C D P R | no | native | 088-8 |
| `levitate` | 2 | S Z | yes | native | 088-6 |
| `locate_animals_or_plants` | 2 | B D R | no | native | 088-6 |
| `locate_object` | 2 | B C D P R Z | no | native | 088-6 |
| `magic_mouth` | 2 | B Z | no | native | 088-7 |
| `magic_weapon` | 2 | P R S Z | yes | native | 088-4 |
| `melfs_acid_arrow` | 2 | Z | yes | native | 088-2 |
| `mind_spike` | 2 | S W Z | no | native | 088-2 |
| `mirror_image` | 2 | B S W Z | no | native | 088-4 |
| `misty_step` | 2 |  | yes | native | 088-6 |
| `moonbeam` | 2 | D | yes | native | 088-5 |
| `nystuls_magic_aura` | 2 | Z | no | native | 088-7 |
| `pass_without_trace` | 2 | D R | no | native | 088-6 |
| `phantasmal_force` | 2 |  | no | native | 088-7 |
| `prayer_of_healing` | 2 | C P | no | native | 088-2 |
| `protection_from_poison` | 2 | C D P R | yes | native | 088-4 |
| `ray_of_enfeeblement` | 2 | W Z | yes | native | 088-4 |
| `rope_trick` | 2 | Z | no | native | 088-6 |
| `scorching_ray` | 2 |  | yes | native | 088-2 |
| `see_invisibility` | 2 | B S Z | yes | native | 088-6 |
| `shatter` | 2 | B S Z | yes | native | 088-2 |
| `shining_smite` | 2 | P | no | native | 088-8 |
| `silence` | 2 | B C R | no | native | 088-8 |
| `spider_climb` | 2 | S W Z | yes | native | 088-6 |
| `spike_growth` | 2 | D R | yes | native | 088-5 |
| `spiritual_weapon` | 2 | C | no | native | 088-8 |
| `suggestion` | 2 | B S W Z | no | native | 088-3 |
| `warding_bond` | 2 | C P | no | native | 088-4 |
| `web` | 2 | S Z | no | native | 088-3 |
| `zone_of_truth` | 2 | B C P | no | native | 088-7 |
| `animate_dead` | 3 | C Z | yes | native | 088-8 |
| `beacon_of_hope` | 3 | C | yes | native | 088-4 |
| `bestow_curse` | 3 | B C Z | no | native | 088-3 |
| `blink` | 3 | S Z | no | native | 088-6 |
| `call_lightning` | 3 | D | no | native | 088-5 |
| `clairvoyance` | 3 | B C S Z | no | native | 088-6 |
| `conjure_animals` | 3 | D R | yes | native | 088-5 |
| `counterspell` | 3 |  | yes | native | 088-8 |
| `create_food_and_water` | 3 | C P | no | native | 088-7 |
| `daylight` | 3 | C D P R S | no | native | 088-6 |
| `dispel_magic` | 3 | B C D P R S W Z | no | native | 088-8 |
| `fear` | 3 | B S W Z | no | native | 088-3 |
| `fireball` | 3 |  | yes | shared | 088-2 |
| `fly` | 3 | S W Z | yes | native | 088-6 |
| `gaseous_form` | 3 | S W Z | no | native | 088-6 |
| `glyph_of_warding` | 3 | B C Z | no | native | 088-5 |
| `haste` | 3 | S Z | no | native | 088-4 |
| `hypnotic_pattern` | 3 | B S W Z | no | native | 088-3 |
| `leomunds_tiny_hut` | 3 | B Z | no | native | 088-6 |
| `lightning_bolt` | 3 | S Z | no | native | 088-2 |
| `magic_circle` | 3 | C P W Z | no | native | 088-5 |
| `major_image` | 3 | B S W Z | no | native | 088-7 |
| `mass_healing_word` | 3 | B C | yes | shared | 088-2 |
| `meld_into_stone` | 3 | C D R | no | native | 088-6 |
| `nondetection` | 3 | B R Z | no | native | 088-6 |
| `phantom_steed` | 3 | Z | no | native | 088-8 |
| `plant_growth` | 3 | B D R | yes | native | 088-5 |
| `protection_from_energy` | 3 | C D R S Z | yes | native | 088-4 |
| `remove_curse` | 3 | C P W Z | yes | native | 088-8 |
| `revivify` | 3 | C D P R | yes | native | 088-8 |
| `sending` | 3 | B C Z | no | native | 088-8 |
| `sleet_storm` | 3 | D S Z | yes | native | 088-5 |
| `slow` | 3 | B S Z | no | native | 088-3 |
| `speak_with_dead` | 3 | B C Z | no | native | 088-7 |
| `speak_with_plants` | 3 | B D R | no | native | 088-7 |
| `spirit_guardians` | 3 | C | yes | native | 088-5 |
| `stinking_cloud` | 3 | B S Z | no | native | 088-3 |
| `tongues` | 3 | B C S W Z | no | native | 088-8 |
| `vampiric_touch` | 3 | S W Z | no | native | 088-8 |
| `water_breathing` | 3 | D R S Z | no | native | 088-6 |
| `water_walk` | 3 | C D R S | yes | native | 088-6 |
| `wind_wall` | 3 | D R | no | native | 088-5 |
