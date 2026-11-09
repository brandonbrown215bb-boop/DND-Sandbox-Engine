"""Authored planning assignments. Regenerate JSON/Markdown with this file.

This is a crosswalk, not runtime code or an alternate rules implementation.
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CAPS = []


def c(key, title, owner, reuse, remaining, after, consumers, acceptance, evidence,
      kinds="engine_extension;content_wiring;gameplay_proof"):
    paths = []
    for name in evidence.split(";"):
        path = ROOT / name
        if not path.exists():
            hits = list((ROOT / "src").rglob(name)) + list((ROOT / "docs/mechanics").rglob(name))
            assert len(hits) == 1, (name, hits)
            path = hits[0]
        paths.append(path.relative_to(ROOT).as_posix())
    order = len(CAPS)
    CAPS.append(dict(id=key, order=order, assignment="REUSE" if not order else f"CXM-{order:02}",
                     title=title, slice_owner=owner, reuse=reuse, remaining=remaining,
                     prerequisites=after.split(), concrete_consumers=consumers,
                     acceptance=acceptance, evidence=paths, work_kinds=kinds.split(";"),
                     state="planning_only"))


c("BASE", "Reuse shared execution and accepted proofs", "S-021/S-022/S-033/S-034/S-043",
  "SharedSpell automatic/attack/save; SharedStepExecutor ordered gates; heal/temporary_hp/grant_condition/remove_condition/weapon_attack/projectiles/delayed_damage/push/exploding_dice/leap_on_matching_dice; CombatAction typed settlement. Accepted SC-01–07 and condition/OA subsets stay accepted.",
  "Candidate translation and missing consumer proof. Bestow Curse support-10 packet/paid-slot repair exists locally despite older held prose; direct/delayed/aftermath/class-feature/monster/repeated-step limits remain. A valid fragment never certifies the whole candidate.", "",
  "All spells/features/items/actors; Acid Splash, Cure Wounds, Hold Person, True Strike, Ice Knife, Chromatic Orb, Shatter are concrete reusable paths.",
  "Reuse unchanged focused proofs. New/renamed loaded data must traverse ordinary controls, refuse before unintended RNG/payment and settle once. No blanket repeat of accepted parent slices.",
  "shared_spell.gd;shared_step_executor.gd;docs/mechanics/shared-spells.md;docs/planning/crown-spell-conversion-queue.csv", "content_wiring;gameplay_proof")
c("AMMO", "Exact ammunition spending and recovery", "S-249; S-049/S-196/S-064 reuse",
  "Exact inventory copies/quantities, attack budgets and campaign clock; accepted S-250 range/Heavy. Native Loading already caps ordinary Attack swings.",
  "No established exact debit/recovery host. Bind ammunition kind and weapon to each committed shot, hand/loading eligibility, spent encounter batch and once-only recovery. Purchase lots differ from pieces; general liquids/fuel are not prerequisites.", "",
  "Arrows/Quiver, Bolts/Case, Sling Bullets, Firearm Bullets, Blowgun Needles; bows/crossbows/Sling/Pistol/Musket/Blowgun; Fighter B/Ranger/Rogue packages and merchant links.",
  "Windows production input with renamed bow/ammo: 0 refuses before RNG/action; two shots from 3 leave 1, including misses. Cancel/stale spends0, committed continuation spends1. Check actual loading/free hand and off-turn routes. One minute recovers floor(half eligible spent) once per encounter; destroyed ammunition is excluded when corrosion is wired. Both allowed DTO/relaunch routes retain counts; malformed counters refuse before replacing session.",
  "inventory_copies.gd;combat_action.gd;combat_state.gd;docs/mechanics/exact-contents-and-parts.md")
c("ARMOR", "Worn penalties and legal base AC", "S-251; S-085/S-252 reuse",
  "Real don/doff and Shield Action; ProtectionRules/RuleUpgradeRules base alternatives and equipment queries.",
  "Strength Speed penalty, Stealth Disadvantage, untrained STR/DEX D20 penalties/cast refusal on actual hosts; Shield training and choice among legal AC bases. Keep native armor behavior until its consumers are covered.", "",
  "All13 armor/Shield candidates; Defense, Barbarian/Monk defense, Draconic Resilience, Mage Armor/Barkskin.",
  "Real Equip/Unequip, checks/attacks/casts at/below STR threshold, trained/untrained and Shield-only. Removal clears only its penalties, never refunds movement. Compare competing base AC and checkpoint recovery; reuse accepted timing proof.",
  "docs/mechanics/equipment-timing.md;docs/mechanics/attack-and-ac-upgrades.md;protection_rules.gd")
c("PACK", "Exact starting alternatives and pack grants", "S-047/S-049/S-050; S-231 consumer",
  "G2 skill/tool choices, Monk tool copy, Explorer pack expansion, combined Druid Quarterstaff/focus, permanent-grant fit preflight/receipts.",
  "Wire16 full A/B/C/GP packages, six packs and linked choices once. No pack shell/contents double counting, invented Backpack fit, forced Amulet, Bard proficiency match or replay. Retained source conflicts remain explicit.", "",
  "packages.json; all12 classes/four backgrounds, Bard/Monk/Soldier choices, Holy Symbol forms; Cleric A is7GP.",
  "Normal creation each alternative plus Back/Random/seat reset: exact quantities/GP, Monk/Soldier match tool, Bard independent. Full grant refuses atomically when it cannot fit; expand once. Sell/consume then reload both DTOs: no recreation. Unknown weights remain unknown.",
  "docs/mechanics/permanent-progression.md;docs/mechanics/progression-choices.md;inventory.gd")
c("CARRY", "Capacity, mass and handling", "S-266; S-196/S-210 reuse",
  "Accepted non-nested compartments, attachments/transfers and vessel capacities; PhysicalFactsRules and exact copies.",
  "Equipped/carried/contained totals once; STR/size/form carry, push/drag/lift and Block/Tackle multiplier. Nested and equipped/combat content selectors exceed accepted controls. Unknown mass/volume is a source fact, never zero.", "",
  "Backpack/Quiver/Case/Pouch/Waterskin/Barrel/Bucket, Block/Tackle; Floating Disk/Levitate, Goliath Powerful Build, Mule Beast of Burden.",
  "At/over limits with mixed equipment and contents: no double count, source size/multipliers correct, removing load refreshes Speed without distance refund. Full/blocked transfer preserves copies; unknown/nested unsupported cases refuse explicitly. Both DTOs recover exact contents.",
  "docs/mechanics/exact-contents-and-parts.md;docs/mechanics/physical-facts-space-and-movement.md;inventory_copies.gd")
c("QUANTITY", "Measured portions and cumulative fuel", "S-197; S-196/S-064 reuse",
  "Exact copies, non-nested contents, clock/light owners; linked destruction cause already covers components/fuel.",
  "Gallons/pounds/sheets/days/flasks/uses distinct from lots; partial transfers/overflow/stock, active fuel time across extinction/rekindling. Do not invent stock, weight or servings-to-pounds conversion.", "CARRY",
  "Oil six-hour fuel, Torch/Candle/Lanterns, Waterskin/Cistern/Food Basket/Rations, ten-use Healer Kit, created batches.",
  "Partial/full/overcapacity transfers lose/duplicate nothing. Burn/extinguish/wait/rekindle/reload spends only active fuel time. Exhaust finite stock once; empty vessel identity survives. Equal copies independent; malformed units/counters refuse save preflight.",
  "inventory_copies.gd;light_source_rules.gd;docs/mechanics/linked-removal-causes.md")
c("COMPONENT", "Exact materials, hands and focus roles", "S-134/S-135/S-136/S-142; S-049 reuse",
  "Source/payment chooser, Ready prepaid materials, Chromatic Orb diamond; class-permitted held focus and same-hand M/S; exact copies.",
  "All183 material routes: worth/form/consumed quantity and persistent worn/held roles. Worth is not price; touched Rope/weapon target remains required. Current Somatic-only held-focus house rule is policy, not SRD.", "",
  "spell-materials.json; Warding Bond rings, Gentle Repose coins, Clairvoyance eye/horn, Revivify diamonds, Protection Holy Water; dual-role staff/Holy Symbols.",
  "Normal/ritual/Ready casts: focus/pouch only substitutes unpriced unconsumed material. Wrong worth/form/hand/wear/copy refuses unpaid; paid held release never repays. Two rings checked throughout. Renamed dual-role staff works for True Strike/Shillelagh/Topple without ID branch.",
  "docs/mechanics/spell-permissions-and-preparation.md;docs/mechanics/spell-slots-and-ritual-casting.md;docs/mechanics/progression-choices.md")
c("ROLL", "Captured choices on remaining roll hosts", "S-096/S-224/S-226; S-093/S-094/S-225 reuse",
  "Owned bonuses/refunds/captured grants/rerolls, save condition modes and OA Help/purpose context; accepted weapon/shared-spell hosts.",
  "Actual off-turn/room/event checks, rolled Death Saves/Concentration choices and source-scoped D20 modifiers; automatic/natural outcomes retain precedence. Native feature behavior is not generic support.", "",
  "Bardic Inspiration/Cutting Words, Tactical Mind, Halfling Luck/Heroic Inspiration, Gnomish Cunning/Eldritch Mind, Sphinx Burst, Guidance/Beacon.",
  "Qualifying and unrelated rolls on each selected host: hold/decline/stale/double callback retains original d20/DC/counters. Refund continued Tactical Mind failure to same Second Wind source. Death natural outcomes and earlier concentration damage never replay; reuse unchanged host tests.",
  "docs/mechanics/owned-ability-check-modifiers.md;docs/mechanics/party-intervention-and-allocation.md;docs/mechanics/core-rules-status.md")
c("DICE", "Natural thresholds and whole damage rolls", "S-240; S-123/S-124/S-125/S-126 reuse",
  "Captured natural/critical faces, remove/maximize/reroll/multiplier operations; native Champion/GWF/Savage Attacker comparison.",
  "Weapon/Unarmed natural19 critical; GWF eligible1/2 become3; Savage Attacker chooses one whole weapon roll, not selected dice. Potent Cantrip half damage on miss/save excludes extra effects. Exact dice/turn locks.", "",
  "Champion, GWF, Savage Attacker, Evoker Potent Cantrip, Fiendish Vigor, Empowered/Seeking Spell.",
  "Natural18/19/20 versus modified19; two-handed/Versatile/one-hand, weapon/spell dice; two whole weapon rolls leave other riders untouched. Cantrip miss/save half never applies hit-only rider. Duplicate continuation neither rerolls nor repays.",
  "docs/mechanics/shared-spells.md;docs/mechanics/attack-profiles.md;combat_action.gd")
c("INIT", "Immediate willing initiative exchange", "S-091 initiative owner extension; S-233 acquisition reuse",
  "Settled initiative/order, encounter identity, conditions and feat ownership; late/group rolls already delivered.",
  "Alert exact value swap immediately after owner rolls, willing same-combat ally, neither Incapacitated. Generic exchange not established; record narrow registry requirement at implementation, not a fabricated accepted S-ID.", "",
  "Alert /authored_operations/1; Criminal and legal Human/feat acquisitions.",
  "Real initiative window accept swaps exact values/order once. Decline/nonconsent/incapacity/wrong combat/stale/late/double choice does nothing. Late/group actors cannot reopen old window. Pending choice remains transient.",
  "docs/mechanics/progression-choices.md;combat_state.gd")
c("REPEAT", "Damage-triggered repeat saves", "S-087/S-092; S-072 schedules reuse",
  "Shared repeat saves/stages, exact condition lifetimes, target-turn scheduling and damage occurrence receipts.",
  "Tasha damage WIS save with Advantage alongside scheduled turn-end save; source prevents self-ending Prone. One qualifying damage occurrence, independent packet settlement.", "",
  "Tashas Hideous Laughter full rules/operations; renamed neutral repeat-save consumer.",
  "Real flat/ordered/off-turn typed damage: one source-defined qualifying occurrence produces one Advantage save; independent turn-end save remains. Success removes only this source; sibling Prone remains. Held/stale/duplicate chooser never rerolls or repays.",
  "shared_spell.gd;spell_encounter_lifecycle.gd;docs/mechanics/shared-spells.md")
c("BUDGET", "Restricted actions and Somatic cast failure", "S-160/S-142; S-021/S-237 reuse",
  "CombatTurnBudget restricted actions, Action Surge Magic exclusion, ordinary action outcomes and captured failure payment.",
  "Slow Action-or-Bonus/one attack/no Reactions/d4=1 Somatic failure; Haste extra restricted action/one attack/end lethargy; Stinking Cloud turn-local no Action/Bonus. Never convert restricted permission to general action.", "",
  "Slow/Haste/Stinking Cloud; Fighter Action Surge and Monk/Rogue action versions.",
  "Real HUD with exhausted ordinary budgets: Haste cannot Magic/Extra Attack, Slow cannot spend both kinds or exceed one attack including substitutions. Capture one failure d4, retain prescribed costs through continuation. Exact lethargy ending and source-only permission removal.",
  "combat_turn_budget.gd;docs/mechanics/ordinary-actions.md;docs/mechanics/cast-interruption-and-settlement.md")
c("REACTION", "Qualifying off-turn spell windows", "S-041/S-042/S-134/S-135; S-115/S-143 reuse",
  "ReactionTriggers attack/damage contexts, Counterspell stopping settlement, native Shield and exact Reaction/source payments.",
  "Missing qualifying hit/cast/damage/fall producers across player/monster routes with exact sight/range/components; Hellish Rebuke permission. A bounded trigger does not establish every caller.", "",
  "Hellish Rebuke/Shield/Counterspell/Feather Fall; Lich spell entries; Goliath incoming choices.",
  "Actual off-turn HUD/AI weapons/spells/areas: sight/range/no-Reaction/componentless checks. Decline/cancel/stale pays0; accept pays exact source once, resumes original occurrence/budgets. Counterspell refunds only eligible original slot. FALL supplies actual falling trigger later.",
  "reaction_triggers.gd;spell_cast_reactions.gd;docs/mechanics/cast-interruption-and-settlement.md")
c("POSTHIT", "Paid post-hit casts", "S-041/S-135/S-146; S-076/S-123 reuse",
  "Captured hit/Attack units, permissions/payment, typed damage and critical provenance.",
  "Immediate own qualifying hit Bonus casts and Pact-only Eldritch Smite. Initial damage joins same hit; recurring save/damage/lifetime remains independent. No second attack payment or unconditional smite.", "REACTION",
  "Divine/Searing/Shining Smite, Ensnaring Strike, Paladin free Smite, Eldritch Smite; Cunning Strike pre-dice choice shares hit identity.",
  "Normal multiattack hit/miss/critical: right weapon/turn/budget/source only, slot/free alternatives independent, cancel retains use. Same hit resumes once with correct critical initial dice and independent ticks/escape. Pact-only refuses ordinary slots.",
  "docs/mechanics/attack-unit-substitution.md;docs/mechanics/shared-spells.md;combat_action.gd")
c("DAMAGE_COPY", "Copy actual damage without splitting", "S-114 continuation; S-111/S-112 receipt reuse",
  "Final typed amount, DamageResponseRules causal/depth limits and independent recipient defenses/concentration/defeat.",
  "Warding Bond copy actual damage to caster; split/redirect cannot express copy. Rings/range/caster0/recast endings and feedback limit remain mandatory.", "REACTION",
  "Warding Bond damage_copy extension and two worn rings.",
  "Real mixed typed damage with resistance/immunity/TempHP; source-defined actual amount copied once, caster settles own defenses/concentration/0HP. Original is not reduced again. Range/caster0/removal stops copies; stale/two-source callbacks cannot loop.",
  "damage_response_rules.gd;docs/mechanics/shared-spells.md;combat_action.gd")
c("DAMAGE_HEAL", "Heal from actual damage dealt", "S-114 continuation; S-034/S-125 reuse",
  "Receipts distinguish raw/prevented/resolved/TempHP/HP loss; bounded counter-heal/rounding owner.",
  "Vampiric Touch half actual Necrotic damage dealt after defenses, exact initial/repeated attack, not raw roll fraction.", "",
  "Vampiric Touch and neutral settled-damage-to-caster-healing declaration.",
  "Initial/repeat actual attacks, miss/immunity/resistance/TempHP/odd total; hold damage choice/0HP replacement then resume one heal with source rounding. No attack/cast replay; ended source offers no repeat action.",
  "damage_response_rules.gd;combat_action.gd;docs/mechanics/shared-spells.md")
c("DEFLECT", "Reduction then optional paid redirection", "S-109/S-114 continuation",
  "Formula damage reduction, settled counters, cover/target queries and exact Focus/save modes.",
  "Monk Reaction total reduction d10+DEX+level; only at0 optional Focus1 and visible5ft melee or60ft ranged/no Total Cover target; DEX save uses WIS DC, two Martial Arts dice+DEX triggering type.", "REACTION",
  "Deflect Attacks; Goliath Stones Endurance; Investment familiar Resistance shares incoming window with its own payload.",
  "Real melee/ranged B/P/S/mixed attack,0/nonzero/no-Reaction/Focus and range/sight/cover edges. Reduction remains if redirect declined; target cancellation spends no Focus. Accepted save/damage happens once without original attack replay.",
  "damage_response_rules.gd;docs/mechanics/shared-spells.md;docs/mechanics/ordinary-actions.md")
c("RIDER", "Scoped hits, next results and retargeting", "S-076/S-077/S-080/S-086 continuation",
  "Owned next-result grants, once-turn limits/modes, typed riders and repaired Bestow Curse support-10 packet/paid-slot duration.",
  "Weapon-only versus caster attack predicates, next-attack consumption, below-max/ally/reckless conditions and exact mark transfer after0. Finish remaining curse direct/delayed/aftermath/class-feature/monster/repeated-step producers without reopening repaired packets.", "",
  "Hex/Hunters Mark/Divine Favor/Guiding Bolt, Frenzy/Sneak Attack/Colossus Slayer/Horde Breaker/Agonizing Blast, Fiend blessing/Stunning Strike success.",
  "Real eligible/unrelated/off-turn/critical attacks and spells; first-hit/next-attack/miss consumption follows source. Retarget legal later-turn Bonus only after marked target0. Multi-step/projectile hits neither drop nor multiply riders; source ending leaves siblings.",
  "docs/mechanics/captured-grants.md;docs/mechanics/source-end-rules.md;combat_action.gd")
c("BENEFIT", "Recipient benefits and captured formulas", "S-080/S-084/S-085/S-130/S-141 continuation",
  "Fixed AC/walking-speed source carriers, base AC/score protections, fixed max/current-HP sources, TempHP replacement and suppression.",
  "Nonself/multiple recipients and per-recipient parameters; paid-slot/casting-ability formulas. Aid fixed max_hp_source exists, upcast +5 current/max needs extension. Barkskin floor17, Mage Armor option, Heroism retained TempHP, Guidance skill and Resistance type/turn budget remain exact.", "",
  "Aid/Barkskin/Mage Armor/Longstrider/Darkvision/Heroism/Guidance/Resistance/Beacon/Shield of Faith; Draconic/source species stats.",
  "Normal target chooser with competing sources; slot3 Aid +10 current/max, expiry only own delta. Correct base/floor/equipment choices, independent recipient parameters, spent movement/TempHP replacement. Both checkpoints retain captured values and reject forged ones; no self-only approximation.",
  "docs/mechanics/source-benefit-carriers.md;docs/mechanics/source-owned-stat-protections.md;docs/mechanics/monster-max-hp-sources.md")
c("LIFETIME", "Captured durations and source endings", "S-070/S-080/S-086/S-087/S-141 continuation",
  "Accepted flat-condition HUD duration/concentration, actor-specific rest-start expiry, source-end events and located aftermath VS-145.",
  "Other benefit/area/actor/item owners and room/AI/item/Reaction casts need captured settings and exact recipient endings. Long/recast/until-dispelled records require source-level validation; condition proof is not other-owner proof.", "",
  "Extended Spell, Animal Friendship, Animate Dead control, Invisibility recipients, Enlarge gear/ammo reversion, Magic Weapon/Nystuls permanence, world timers.",
  "Actual noncondition owner altered duration/concentration, unchanged catalog and sibling values. Cast/action/range/item/rest/recipient-turn endings, unloaded rooms and clock jumps settle once. Both allowed saves retain deadline/paid level and reject stripped required state; no new checkpoint.",
  "docs/mechanics/source-end-rules.md;docs/mechanics/source-benefit-carriers.md;docs/mechanics/created-actors-and-placement.md")
c("ITEM_MAGIC", "Exact weapon enhancements, bonds and curses", "S-161/S-162/S-126/S-127/S-202/S-203 continuation",
  "Bond/Release/Project/Dismiss controls, copy identity, linked loss causes, damage-type choices and magical-property suppression/degradation.",
  "Shillelagh/Magic Weapon/Sacred Weapon/pact copy, choices/hand/carry/recast ending. Remove Curse ends eligible creature/object curses; cursed-item curse remains while attunement breaks. No dormant magic catalog import.", "COMPONENT",
  "Shillelagh/Magic Weapon/Sacred Weapon/Pact Blade/Remove Curse; created pact weapon/Book of Shadows.",
  "Two identical copies independently selected, dual-role staff valid. Correct type choices on actual ordinary/Opportunity/command hosts; ending leaves catalog/sibling untouched. Drop/loss/bond uses exact cause; cursed item becomes removable with retained curse. Checkpoint preserves state.",
  "docs/mechanics/attack-profiles.md;docs/mechanics/created-actors-and-placement.md;docs/mechanics/linked-removal-causes.md")
c("WEAPON", "Source weapon properties and masteries", "S-127; S-250/S-084/S-085 reuse",
  "Range/Heavy, bounded damage-type routes, nonstacking Extra Attack and native Light/Nick/Cleave/Loading hosts.",
  "Source-driven mastery eligibility/replacement, reach/property/hand/ability predicates on selected routes. Loading is not absent everywhere. Candidate S-255 hints do not select dormant magic templates.", "AMMO",
  "38 weapon candidates; class Mastery, Monk weapons/DEX/dice, Archery/GWF/TWF, pact weapon/True Strike.",
  "Normal mastery acquisition/replacement and ordinary/Extra/Light/Nick/Cleave/Opportunity/selected creature attacks. Thrown versus Ranged, reach, hands/proficiency/exact copy; renamed item works. Upgrade switch creates/refunds no swings. Reuse unchanged range/Heavy checks.",
  "docs/mechanics/attack-profiles.md;docs/mechanics/attack-and-ac-upgrades.md;fighter_rules.gd")
c("GRAPPLE", "Unarmed Grapple/Shove and exact relations", "S-236; S-168/S-169/S-235 reuse",
  "Accepted tether anchors/Escape/Rescue/Cut/source cleanup and shared Grappled consequences.",
  "Actual Unarmed choices/free hand/size/reach/DC; dragging/end on incapacity/out-of-reach. Grappler Damage+Grapple once-turn and size exception. Rope/Net use same relations, distinct checks.", "",
  "Monk Dexterous Attacks, Grappler/Rope/Net; Frog/Snake/Crocodile grapples and Spider Web.",
  "Ordinary Unarmed chooser validates size/reach/hands and permitted STR/DEX DC. Two captors keep independent relations; incapacity/out-of-reach releases only matching grip. Drag costs/size exceptions, legal escape/help/cut and both checkpoint identities.",
  "docs/mechanics/tethers.md;docs/mechanics/core-rules-status.md;docs/mechanics/ordinary-actions.md")
c("MOVE", "Fallback movement and actual jumps", "S-239; S-179 reuse",
  "Combat mode/surface/terrain queries and initial zero-spend refusal; form-specific printed speeds.",
  "Double-cost fallback climb/swim, crawl/voluntary stand/STR or declared DEX jumps; Jump spends10ft once-turn for up to30ft, not teleport. Moving footprints/room hosts only concrete consumers.", "",
  "Jump/Otherworldly Leap, Step of Wind/Second Story, Cat/Frog leaps, Halfling Nimbleness, Spider Climb/form sizes.",
  "Actual route at/under budget, running/standing jumps, DEX substitution, Prone/Speed0, hands/surface and larger creature passage. Refusal spends0; once-turn Jump/budget survives interruption; no overlap or invented OA immunity.",
  "docs/mechanics/physical-facts-space-and-movement.md;docs/mechanics/ordinary-actions.md")
c("GRANTED_MOVE", "Post-hit, Reaction and compelled movement", "S-241/S-183/S-269; S-179/S-148 reuse",
  "Open Hand15ft Push and shared/Thunderwave push delivered; ordinary child movement and actor budgets.",
  "Whispers target Reaction safe route; Command five orders/Fear Dash/drop; Champion/Fighter/Rogue half-Speed no-OA; Repelling Blast and charge history. Every source owns budget and OA policy.", "MOVE",
  "Whispers/Command/Fear/Gust, Turn Undead; Champion critical/Tactical Shift/Withdraw; Boar/Elk charge, Deer/Owl/Bubble Dash.",
  "Actual input/AI safe/blocked/no-exit routes; Reaction belongs to target. Whispers can provoke under movement rules; Push neither provokes nor spends voluntary movement. Half-Speed moves and forced hazard crossings settle once, stale post-hit choices cannot replay.",
  "docs/mechanics/physical-facts-space-and-movement.md;docs/mechanics/attack-unit-substitution.md;combat_turn_budget.gd")
c("FALL", "Descent, falling damage and lost flight", "S-181; S-121/S-122/S-179 reuse",
  "Altitude/clearance/legal placement, damage reductions and Reaction scheduling; speed fields alone are not fall execution.",
  "Actual fall/descent/landing: Feather Fall60ft/round, Levitate gentle end, flight loss, Slow Fall actual damage reduction. No universal3D map gate.", "MOVE REACTION",
  "Feather Fall/Fly/Levitate/Gaseous/Spider Climb; Monk Slow Fall/Dragonborn Flight/Chain Fly40.",
  "Start real falling, accept/decline Reaction, land before/after expiry and compare actual damage. End flight at altitude/incapacity: legal landing/descent or fall, no telefrag. Slow Fall reduces5*Monk level at legal window; save only allowed resulting state.",
  "docs/mechanics/physical-facts-space-and-movement.md;placement_rules.gd;docs/mechanics/core-rules-status.md")
c("PHASE", "Bounded teleport, gas/stone access and return", "S-177/S-178/S-180/S-181; S-121/S-122 reuse",
  "Plane/location facts, legal arrivals, represented random overworld travel and room/save-exit placement.",
  "Misty Step seen destination; Blink d6/plane/return; gas gaps/liquids/restrictions; stone volume/deformation expulsion. Fairy return policy unresolved; general planar travel outside.", "MOVE FALL",
  "Misty Step/Cloud ancestry/Blink/Gaseous/Meld; Halfling through-space/Ooze Amorphous/Octopus Compression.",
  "Seen/blocked/wrong-plane destinations, cancellation costs0. Passage may not end illegally. Blink4–6/already-Ethereal ending/60ft perception and next-turn nearest legal return retain gear. Stone destruction/deformation damage/Prone/shunt once.",
  "docs/mechanics/physical-facts-space-and-movement.md;docs/mechanics/created-actors-and-placement.md")
c("BARRIER", "Selective crossings and occupant admission", "S-185/S-186; S-184/S-122 reuse",
  "Spatial receipts/geometry/occupancy, containment targeting and legal release.",
  "Hut initial encapsulation/permitted creatures+objects/level3 spell barrier; Wind selective gases/flight/projectiles; Circle type/reversal/teleport save. No generic impassability or high-level segmented walls gate.", "PHASE",
  "Tiny Hut/Wind Wall/Magic Circle; Rope Trick combat/spell boundary via CONTAIN.",
  "Actual placement over permitted/excluded occupants, crossings/projectiles/boulders/spell levels and reversed Circle. Rejection spends no partial distance/payload. Hut caster leaves/recasts: only own source ends; occupants legal.",
  "docs/mechanics/physical-facts-space-and-movement.md;docs/mechanics/containment.md")
c("OBJECT", "Exact object damage, targeting and ignition", "S-032/S-091/S-098/S-099/S-119 continuation",
  "Room/exact-part objects and CombatUtilize; Shatter no-save unattended nonmagic area-object damage and Thunderwave object push/destruction.",
  "Remaining single/area/projectile object selectors including collocated copies; actual eligible ignition. Unknown material/magic/equipment stays unknown. Heat Metal contact/drop/removal and Enlarge targets use exact objects.", "",
  "Eldritch Blast/Sorcerous Burst/Starry Wisp, Fire Bolt/Burning Hands/Fireball/Faerie Fire; nine world objects, Heat Metal/Light/Levitate.",
  "Real chooser differentiates creature/two objects at same cell and worn versus unattended. Unknown fact cannot invent outcome. Miss/save/cover/HP/destruction affects selected copy/geometry; no worn/carried burning. Reuse accepted Shatter/Thunderwave subset.",
  "docs/mechanics/shared-spells.md;docs/mechanics/ordinary-actions.md;local_room_shared_spells.gd")
c("REPAIR", "Retained-object repair and corrosion", "S-212/S-213; S-060/S-203/S-210 reuse",
  "Exact copies/parts/object damage/destruction/magic loss and work clocks; native corrosion observation.",
  "Mending one break<=1ft/all pieces, physical function without magic/new copy. Exact ammo/weapon/armor corrosion thresholds; SRD armor penalty explicitly Mending-removable. Crown Ooze stays custom.", "OBJECT",
  "Mending/Rock Gnome, Rope sections, weapons/armor, Gray Ooze Corrosive Form/Pseudopod versus custom Ooze.",
  "Corrode one of two identical copies via real contact/hit; cumulative attack/AC penalty/destruction, magical exemptions/ammo destruction. Repair exact eligible all-piece copy preserving ID/attachments/charges; reject missing pieces/>1ft/magic restoration. No generic HP refill.",
  "docs/mechanics/exact-contents-and-parts.md;docs/mechanics/last-charge-property-loss.md;docs/mechanics/work-sites.md")
c("TOOL", "Real tool tasks and consulted context", "S-237/S-238; S-036/S-094 reuse",
  "Purpose checks/owned exact tool, tool-ID Help, room Utilize/Study and proficiency-source ownership.",
  "Each tool ability/DC and actual task; relevant skill plus tool Advantage, consulted accurate topic Book+5, Crowbar/Costume predicates. Owning tool/proficiency is not completing task; unwritten recipe outputs stay dependencies.", "OBJECT",
  "All33 tool/instrument/gaming records, Books/Crowbar/Costume, Poisoners Kit, Thieves Tools, Rope/Kit and Fast Hands.",
  "Ordinary tool/operation choice with correct/wrong variant/copy/proficiency/skill; failed paid attempt/time/matching Help once, cancel/stale0. Book must be consulted/accurate for real topic. Task changes actual lock/repair/knowledge state.",
  "docs/mechanics/purpose-aware-check-context.md;docs/mechanics/ordinary-actions.md")
c("ITEM_ATTACK", "Thrown items, Net, kits and potions", "S-256/S-146/S-237; S-049/S-064 reuse",
  "Bounded consumable Attack substitution, exact backpack copies, heal/stabilize and tethers.",
  "Acid/Holy Water/Fire/Oil one-attack replacement/DEX DC/consumption; Net save/size/restraint/rescue instead of current damage. Kit one-of-ten stabilize; potion drink/administer Bonus Action. Custom Antidote remains distinct.", "QUANTITY GRAPPLE",
  "Holy Water/Net/Oil/Healer Kit/four potions/Antidote.",
  "Two Attack units: substitute one, retain other and exact type/size eligibility; cancel/stale loses no copy/unit. Net rescue/cut exact source. Kit only living Unconscious0 spends1. Drink/administer actual legal target/range and healing once; save quantities.",
  "docs/mechanics/attack-unit-substitution.md;docs/mechanics/tethers.md;docs/mechanics/ordinary-actions.md")
c("MIX", "Potion miscibility table and retained effects", "S-214/S-215; S-049/S-064 reuse",
  "Exact potion copies, source effects, captured table rolls and consumption/clock owners.",
  "The retained p.204 mixing procedure/table is separate from drinking/healing. Translate every table result, repeated/combined effects and any lasting outcome against actual potion sources. Unsupported selected result must be explicit before unintended mutation, not silently ordinary healing.", "ITEM_ATTACK",
  "All four Healing Potion candidates /authored_operations mixing clause and /rules source context p.204.",
  "Actual two-potion mixing/use control with exact copies, seeded table boundaries and source effects. Each table branch preserves its stated consumption, effect/time/result; original roll is not rerolled on child continuation. Equal copies independent. Permanent/long results survive allowed checkpoint or remain blocked with exact missing contract; schema-only table presence is not acceptance.",
  "docs/mechanics/shared-spells.md;event_resolver.gd;inventory_copies.gd")
c("HAZARD", "Recoverable hazards and burning", "S-258; S-184/S-122 reuse",
  "Accepted entry/crossing/turn/area movement receipts, room areas and placement.",
  "Caltrops/Bearings level ground/first-entry/movement exceptions/ten-minute recover; Oil dousing/ground fire distinct from fuel; Web cubes/Ashvale custom1d4 heat. No generic area substitutes for source conditions.", "QUANTITY ITEM_ATTACK",
  "Caltrops/Bearings/Oil/Alchemists Fire/Web/lava fissure/timber.",
  "Actual placement rejects bad ground unpaid; distinguish appearance/entry/area move/start/end and once-turn. Slow crossing exemption, recovery quantities/time, dousing+Fire ordering; no duplicate damage across sources. Checkpoint preserves remaining area/stock.",
  "docs/mechanics/physical-facts-space-and-movement.md;spatial_trigger_rules.gd;local_room_areas.gd")
c("LIGHT", "Located light and hearing-only targeting", "S-190/S-191 continuation; S-274 via DISPEL",
  "Observer senses/light/concealment, OA hearing/noise, portable lights and real AI/roll targeting.",
  "Outline light/observer-specific advantage, object covering, flame/light movement controls, fuel/hood/cones. Mockery seen OR heard target. Map reveal is not sight.", "OBJECT QUANTITY",
  "All11 light-group spells, Lantern/Torch/Candle/Oil/Sacred Weapon/Fire Beetle/Devils Sight; Vicious Mockery.",
  "Two real observers/sources; cover/uncover/extinguish/rekindle/hood proper budgets/radii. Advantage requires actual outline sight. Blinded/hearing-only versus Deafened/unseen Mockery uses known-location facts without global reveal. Reuse perception fixture subset.",
  "docs/mechanics/perception.md;docs/mechanics/ordinary-actions.md;light_source_rules.gd")
c("ZONE", "Exact area, terrain and aura consumers", "S-184/S-179/S-098/S-099; S-075 continuation",
  "Accepted spatial policies, live AuraRules, exemptions, timed areas/light/obscuration.",
  "Wire exact appearance/entry/area-entry/start/end/per-distance policies and exclusions/speed/save/damage; vegetation/wind facts/endings and nonharm aura scope. Generic trigger existence is not every spell payload.", "BENEFIT LIGHT",
  "Moonbeam/Conjure Animals/Spirit Guardians/Web/Entangle/Grease/Spike Growth/Sleet/Cloud/Sphere/Call Lightning/Gust; Pass without Trace/Plant Growth.",
  "Actual actor versus area movement and initial/wrong-turn events; once-turn differs from Spike each5ft. Guardians all nonexcluded creatures half Speed; Conjure no half on save. Gust flames/gas and storm/plant eligibility need facts. Cleanup/unloaded clock/checkpoint exact source no replay.",
  "docs/mechanics/physical-facts-space-and-movement.md;docs/mechanics/condition-suppression-and-auras.md;combat_spell_zones.gd")
c("REMOTE", "Borrowed senses and cast origins", "S-192/S-193/S-145; S-190 reuse",
  "Native familiar form/type menus, Bonus sight/Reaction Touch controls; exact actors, senses and source permissions.",
  "Shared integration for familiar/Gaze/Clairvoyance origin, sense selection/upkeep/range/plane/own-sense restrictions and Touch delivery. Reuse native pickers, do not grant omniscience.", "LIGHT REACTION",
  "Familiar/Wild Companion/Chain, Clairvoyance eye/horn, Gaze of Two Minds.",
  "Real sensor/cast controls at distinct locations: own/borrowed senses/special senses and100ft familiar/60ft Gaze/plane limits; correct Bonus/Reaction/upkeep. Delivery uses familiar Reaction/caster source once. Sight never implies through-barrier casting; ending restores only relevant senses.",
  "docs/mechanics/find-familiar-2024.md;docs/mechanics/perception.md;docs/mechanics/created-actors-and-placement.md")
c("DETECT", "Fact-limited detection and masking", "S-194/S-195; S-190/S-219 reuse",
  "Observer/plane/range facts, exact item/source state and bounded Study knowledge.",
  "Only authorized location/direction/kind/school/properties; material/lead thickness, detection versus sight, thoughts/probing/intrusion, Nondetection/Mask/False Aura with true identity unchanged. Unknown is explicit.", "REMOTE",
  "Detect/Find Traps/Identify/Locate/Mind Spike/See Invisibility/Nondetection/Nystuls; Divine Sense/Hunter Lore/Sprite Heart Sight.",
  "Actual casts on nearest/hidden/masked/wrong-type/other-plane targets and barrier thresholds. Find Traps presence/nature not location; Identify Touch throughout/full time and only supplied properties. Per-observer facts; masking never changes real type. No invented answer from unknown.",
  "docs/mechanics/perception.md;docs/mechanics/ordinary-actions.md;docs/mechanics/spell-foundations.md")
c("LANGUAGE", "Language grants and bounded messages", "S-218; S-232/S-219 reuse",
  "OA local speech/verbal Help/hearing/Influence; saved languages and observer receipts.",
  "Common+two Standard/class secrets; written/signed/whisper/remote controls and limits, telepathy and Sending reply/block history; literal Comprehend/Tongues scope. Language does not grant knowledge/obedience.", "",
  "languages.json, Druidic/Cant/Ranger, Comprehend/Message/Sending/Tongues/Magic Mouth/Script; Animal/Plant/Dead speech.",
  "Normal creation/level grants and actual message UI: wrong language/range/hearing/material barrier refuses eligible route, private content stays private. Druidic auto-read vs INT15 notice/undeciphered. Sending25-word/captured5%/8h blocking survives allowed reload without reroll/replay.",
  "docs/mechanics/ordinary-actions.md;docs/mechanics/progression-choices.md;character.gd")
c("KNOWLEDGE", "Authored answers, attitudes and divination history", "S-219/S-209/S-214; S-188/S-237 reuse",
  "Study/Field Notes and Influence retry/fulfillment, language/hearing; ADR-0023 bounded campaign outcomes.",
  "Actual answers/literacy/attitudes for corpse/Beast/plant/rumor/forecast/thought. Augury course<=30min/cumulative25% no-answer until Long Rest. No fake conversation log or universal GM.", "LANGUAGE DETECT",
  "Augury/Druidcraft/Speak spells/Suggestion/Charm aftermath/Thoughts/Truth; Guard/Ghost/Hermit/Quest Board.",
  "Real target/question/place: unknown stays unknown. Corpse5 questions/10min/no reuse10days, plant past-day facts, Suggestion25-word safe achievable task with real completion/damage ending. Capture repeated Augury roll once. Wrong recipient or unfinished child cannot award answer/objective.",
  "docs/mechanics/ordinary-actions.md;docs/decisions/0023-vocabulary-first-delivery-and-bounded-world-judgment.md")
c("ILLUSION", "Located images and per-observer disbelief", "S-187/S-188; S-189 only selected outcome",
  "Perception/Study, exact source ending and located records; ADR-0023 constrained realizations.",
  "Nonoccupying sound/image/duplicates, source sensory/size/tactile limits and observer discovery. Mirror Image post-hit d6 per duplicate; Sanctuary failed-save alternate target continuation. No fabricated HP/collision/GM.", "KNOWLEDGE OBJECT",
  "Minor/Silent/Major/Disguise/Mirror/Phantasmal/Script/Nystuls/Sanctuary and image actor records.",
  "Actual locate/move/Study/attack: two observers separately disbelieve; physical and Study tests differ. Mirror thresholds2/3/4, special-sense exclusions, one duplicate destroyed per diverted hit. Sanctuary retarget retains original cost/attack and area exemption. Phantom damage exact target/cause/turn only.",
  "docs/mechanics/perception.md;docs/mechanics/source-end-rules.md;docs/mechanics/spell-foundations.md")
c("WARD", "Exact locks and authorized persistent triggers", "S-230/S-184/S-203 continuation",
  "Ordinary key/tool/break interactions, Alarm/object states and spatial receipt/expiry owners.",
  "Arcane Lock closed target/password/authorization; Knock one lock/10min suppression/target noise; Alarm eight-hour permitted list/mental1mile/audible60ft10s; Mouth sensed30ft/message/repeat/end. Geometry/log is not full outcome.", "OBJECT LANGUAGE",
  "Arcane Lock/Knock/Alarm/Magic Mouth; Door/Chest/key and three dungeon locks.",
  "Real object/spell controls with two locks/wrong key/password/excluded actor. Knock exact source suppresses10min, emits300ft noise once. Alarm waking/recipient/sound limits and duration. Revisit/reload cannot retrigger same occurrence or respawn object.",
  "docs/mechanics/ordinary-actions.md;docs/mechanics/physical-facts-space-and-movement.md;local_room_rules.gd")
c("DISPEL", "Spell-level ending and light overlap", "S-276/S-274; S-116/S-190 reuse",
  "Exact source removal/incoming negation, paid slot snapshots, light/obscuration owners.",
  "Capture actual ongoing cast levels across condition/benefit/area/object. End each <=paid threshold; independent higher check DC10+level. Darkness/Daylight actual overlap threshold ending; nonspell/item properties survive.", "LIFETIME LIGHT",
  "Dispel/Darkness/Daylight/Continual Flame/Script/Nystuls/Arcane Lock/Glyph/Hut.",
  "Mixed source levels plus nonspell siblings on creature/object/effect: independent captured higher checks and correct paid slot. Opposite light overlap versus separation. Remove exact consequences everywhere; malformed/missing required level fails checkpoint validation before live mutation.",
  "shared_spell.gd;docs/mechanics/source-end-rules.md;docs/mechanics/perception.md")
c("STORAGE", "Store and release one exact cast", "S-150/S-151; S-135/S-142/S-184 reuse",
  "Original cast snapshot/permissions/payment and ordered continuation; room object triggers/receipts.",
  "Glyph eligible spell storage/second costs/snapshot without normal effect, trigger targets/concentration/once release,10ft relocation/dispel ending. Universal item storage is not a gate.", "WARD DISPEL",
  "Glyph full Runes/Spell Glyph rules and200GP material.",
  "One-hour real cast validates child/levels/targets, pays each cost once and stores without casting effects. Real trigger uses original numbers/new eligible targets, no second slot; duplicate/reopen cannot release twice. Move>10ft/dispel/reload retains correct active/consumed entry.",
  "docs/mechanics/cast-interruption-and-settlement.md;docs/mechanics/created-actors-and-placement.md;docs/mechanics/physical-facts-space-and-movement.md")
c("WORK", "Long casts and fixed-location work", "S-066/S-067/S-136/S-142 continuation",
  "Accepted work cell/helpers/incapacity/accrual/interruption and clock; bounded ritual normal time+10min.",
  "Real long/ritual targeted/spatial/ordered controls, continuous Touch/participant range and exact interruption payment. Add only named room-object/combat/overworld site hosts.", "",
  "15 long-cast spells, Identify/Mending Touch, Prayer range, Familiar hour/Plant Growth8h, copying/creation work.",
  "Normal timed cast move/lose Touch/incapacitate/interrupt then complete exact elapsed time. No premature effect; refund/commit from captured source policy. Prayer recipient leaving range handled precisely. Open workflow cannot save; completed work recovers without replay.",
  "docs/mechanics/work-sites.md;docs/mechanics/spell-slots-and-ritual-casting.md;docs/mechanics/cast-interruption-and-settlement.md")
c("REST", "Rest exceptions and benefit-only Short Rest", "S-071/S-014/S-070 continuation",
  "Rest-start expiry/actor-specific rest including Trance4h duration, mixed Hit Dice and real Short/Long lifecycle accepted.",
  "Prayer benefits/healing without false elapsed/completed-rest event, ten-minute participants/per-recipient Long Rest lockout. Wire source species/no-sleep exceptions to accepted duration host; inn reset-versus-rest policy. Do not rebuild Hit Dice or actor-specific rest duration.", "WORK",
  "Prayer/Elf Trance, class rest recoveries and Camp/Inn. All retained source exceptions remain in ledger.",
  "Real Prayer gives legal benefits/Hit Dice opportunity/2d8 once, no extra hour/completed-rest event/unrelated reset. Retry before recipient Long Rest refuses. Genuine4h/8h/interrupted rest and both DTOs retain precise lock/recovery; accepted Hit Dice proof reused.",
  "docs/mechanics/shared-resource-pools.md;rest_rules.gd;docs/planning/vocabulary-slices.md")
c("POOL", "Exchange destinations, refunds and recovery extras", "S-052/S-053/S-054/S-055/S-059/S-062 continuation",
  "Numeric pools, slot-to-numeric/dice/inventory exchange and result recovery accepted; separate Channel/ordinary/Pact identities.",
  "Pool-to-created-slot, no-action/empty/per-turn/rest exceptions, secondary recovery effects and shared Second Wind/Mind/Shift pool. Numeric recovery alone does not supply Metabolism healing.", "",
  "Bard Font/Sorcerer Font+Restoration/Druid Resurgence/Fighter Second Wind/Monk Metabolism/Warlock Cunning/Wizard Recovery.",
  "Real controls cancel/stale/insufficient/overcap and mixed pools: validate both sides first. Generated slots/caps/level6 exclusion, exact rest/turn/floor/locks; failure refund same source. Checkpoint retains remaining source quantities without replay.",
  "docs/mechanics/shared-resource-pools.md;resource_pool_rules.gd;docs/mechanics/spell-slots-and-ritual-casting.md")
c("SUPPLY", "Actual intake, stock and exposure", "S-197/S-200/S-201; S-199 reuse",
  "Survival nourishment deadlines, camp/rest, measured quantities/clock and Exhaustion semantics.",
  "Physical intake versus magic nourishment, size pounds/gallons, spoilage/contamination/deprivation/recovery restrictions. Form/actor exceptions exact cause; servings/spring prose lack units.", "QUANTITY REST",
  "Rations/Waterskin/Cistern/Food Basket/Goodberry/Create/Purify/Plant Growth/camp/cold clothing.",
  "At actual daily deadlines consume source quantities; half/no-water/food exhaustion and recovery restrictions. Goodberry not water; created food45lb spoils24h, water30gal no invented expiry; Purify modifies existing stock. Clock jump/reload neither resets deprivation nor double-consumes.",
  "survival_rules.gd;rest_rules.gd;docs/mechanics/physical-facts-space-and-movement.md")
c("BREATH", "Environment breathing and suffocation", "S-205; S-200/S-201 reuse; S-204 only selected air consumer",
  "Actual type/size/environment/source protections and clock; no universal enclosed-air prerequisite for adaptation.",
  "Water Breathing retains normal respiration; Alter Self/Gift and Amphibious/water-only/Hold Breath execute actual drowning/suffocation. Hut atmosphere/gas limits separate.", "SUPPLY",
  "Water Breathing/Alter Self/Gift; Crab/Frog/Seahorse/Crocodile/Octopus forms and selected Hut/Rope environment.",
  "Real water/air entry and breath expiration; amphibious vs water-only. Source ending underwater reaches real progression, not icon. Unknown environment explicit; allowed restore keeps clock. Do not require full S-204 when no air-volume consumer exists.",
  "survival_rules.gd;docs/mechanics/physical-facts-space-and-movement.md")
c("CREATION", "Bounded outputs and granted action controllers", "S-049/S-064/S-160/S-161/S-162/S-199 continuation",
  "Exact copies/modes/children, located source-end objects and written force/image representations.",
  "Physical batches versus spectral force/image/area, quantity/lifetime/end; granted Magic/Bonus controllers for breath/flame/weapon/hand/servant. Gnome fixed-effect device activation by toucher. No permanent tradeable transient output.", "LIFETIME QUANTITY",
  "Eight physical creations; utility cantrips, Rock Gnome/Tome/Blade/Tinker, spectral hand/weapon/disk and Dragons Breath.",
  "Real creation/action controls: selected source output/max limits/quantity/location, no invented worth/HP/loot. Gnome toucher Bonus fires fixed effect;8h/dismantle correct copy. Granted action uses original DC/ability/range and ends with source, no recast payment. Tool output waits selected CRAFT work.",
  "docs/mechanics/attack-unit-substitution.md;docs/mechanics/source-end-rules.md;docs/mechanics/created-actors-and-placement.md")
c("CRAFT", "Selected recipes and real world changes", "S-198/S-199; S-066/S-067 reuse",
  "Qualified site/helper/time and exact materials; finite creation boundary map.",
  "Only selected Tiny scrap/Tinker/repair and acquired tool outputs with source time/GP/materials. Craft lists do not grant or select every product; missing output is explicit content dependency.", "TOOL WORK CREATION",
  "Tinker Tiny assemblies, distinct Gnome magical devices, named source repair/tool tasks; unselected lists retained.",
  "One named written result: tools/materials/qualification/cost once and correct work. Interrupt per source; no early result. Completion modifies original object or creates exact output once. Missing definition reports precise dependency before expenditure.",
  "docs/mechanics/work-sites.md;docs/mechanics/purpose-aware-check-context.md")
c("ACTOR", "Source templates and shared monster actions", "S-154/S-155/S-126/S-134 continuation",
  "Parameterized factory/footprints/placement/count choices, combat-room position capture, exact actors and CombatState monster projection/cast paths.",
  "Full printed stats/attacks/save-only/Multiattack/recharge/daily traits through shared executor, fixed bonuses/units. No second monster interpreter or ID registration. Trait names/metadata are not executable.", "WEAPON REACTION",
  "68 SRD blocks incl four held swarms, ten encounters, Steed;39/46 Wild Shape,24+7 familiar legal sets.",
  "Renamed loaded statblock plus real selected blocks through ordinary spawn/form controls; printed bonus/DC/damage, Multiattack members, recharge once actual turn, daily/rest policy. Monster spells exact source/components/slot; legal footprints. Never merge/rebalance custom Crown with SRD or offer held swarm.",
  "docs/mechanics/created-actors-and-placement.md;docs/architecture/data-driven-2024-monster-execution-plan.md;combat_state.gd")
c("COMMAND", "Orders, attack substitution and mount policies", "S-156/S-157/S-158; narrow in-band S-147 Chain consumer",
  "Exact command/cost/owner-group-independent initiative/default policies and native familiar/steed recovery accepted.",
  "Autonomous tasks/moves/standing orders, Chain forgo-attack+familiar Reaction one attack versus Investment command Attack action; ridden/control/incapacitated owner/Life Bond/telepathy/room travel. Bring only Chain S-147 into Crown.", "ACTOR REMOTE",
  "Chain/Investment/Familiar/Wild Companion/Steed/Faithful/Animate Dead/Servant/Phantom.",
  "Actual command controls exact owner/source; Chain one owner attack+familiar Reaction, no Multiattack. Investment Bonus Attack and Resistance Reaction distinct. Downed/dead owner/late arrival/rebuild never replays turns.60ft commands/24h control distinct from actor existence; no party slots/respawn on restore.",
  "docs/mechanics/created-actors-and-placement.md;docs/mechanics/find-familiar-2024.md;docs/mechanics/animate-dead-2024.md")
c("FORM", "Source retained forms and equipment", "S-163/S-164/S-141 continuation",
  "Reversible retained-stat projections, equipment chooser and persistent-room exact ground transfers accepted; reversion does not refill/reacquire.",
  "Full legal known forms/replace, Wild Shape stats/proficiencies/mental/HP/TempHP/breath/casting/equipment/endings; Alter/enlarge/gas/stone and Imp/Quasit only printed Speed changes. No curated menu reduction.", "ACTOR ARMOR GRAPPLE",
  "Wild Shape/Wild Companion, Goliath Large Form, Alter/Enlarge/Gaseous/Meld/Moonbeam; complete form blocks/Imp/Quasit.",
  "Normal Druid2/4 legal CR/type/no-Fly,4/6 known/one Long Rest replacement; swarm held. Before cost recheck size/equipment policy. Revert same actor original HP/resources, exact remaining gear, no refill. Moonbeam blocks shape change only while in area; both checkpoint forms preserve chosen source.",
  "docs/mechanics/created-actors-and-placement.md;docs/mechanics/physical-facts-space-and-movement.md;docs/mechanics/temporary-hp-and-entry-protections.md")
c("CONTAIN", "Source swallowing, space and cargo consumers", "S-170/S-171/S-172/S-167 reuse",
  "VS-148–151 occupancy/capacity/internal harm/escape/moving release/vessel cargo are accepted.",
  "Giant Frog exact swallow/internal damage/death5ft escape/Prone; Rope Trick eight Medium-or-smaller/rope/window/barrier/release; Disk follow500lb/height/gap/lag. Existing vessel ground host is not full source or travel proof.", "FORM PHASE BARRIER",
  "Giant Frog Swallow, Rope Trick, Floating Disk; steed passenger/temporary tack references.",
  "Real admission/capacity/inside-outside targeting. Frog own-grapple replaces conditions/disables Bite, next-turn Acid/disgorge and corpse exit5ft Prone. Disk follows limits with exact cargo. Full/blocked ending safe deferred release; allowed restore exact occupants, no duplicated gear. Reuse unchanged containment proofs.",
  "docs/mechanics/containment.md;docs/mechanics/projected-vessels.md")
c("REMAINS", "Death, preservation, revival and delayed creation", "S-175/S-176; S-119/S-120/S-130/S-131 reuse",
  "Corpse dead/downed identity/cause/gear, explicit/max0 death, lasting Undead existence/control and aftermath records.",
  "Repose exact deadline pause; Revivify same actor<=1min/excluded death/1HP/missing parts, unknown facts refuse. Wight actual-damage maxHP/cure and24h Zombie/cancel/control12. Lich revival held for policy.", "ACTOR REPAIR",
  "Repose/Revivify/Spare/Dead speech/Animate Dead; Wight Life Drain/Zombie Fortitude/Guard/traveler facts.",
  "Real death vs living0, just-before/after revive deadline with Repose/diamonds once, same gear/actor. Wight settled damage/max0/cancelled delayed creation/cap; Zombie exclusions/DC5+damage before defeat. Allowed reload cannot restart timers or recreate remains.",
  "docs/mechanics/party-recovery-2024.md;docs/mechanics/animate-dead-2024.md;docs/mechanics/monster-max-hp-sources.md")
c("CAST", "Casting sources, repertoires and costed edits", "S-134–S-142; S-126/S-127 continuation",
  "Accepted permissions/payments/preparation/ordinary-Pact-fixed uses; free player HUD range/V-S/school/timing edits and flat-condition lifetime edits.",
  "Actual source definitions/replacement cadence, Metamagic cost/eligibility/one-option exceptions on needed noncondition/room/AI/Reaction hosts. Subtle Material exception/Twinned target progression/Extended concentration Advantage/Quickened turn limit remain whole.", "COMPONENT POOL ROLL LIFETIME",
  "Twelve casting packages, subclass spell tables, Magic Initiate/species3/5,22 invocations/10 Metamagics/Lich slots.",
  "Two sources same spell different ability/free use: normal chooser retains exact permission/payment. Own-class eligible preparation distinct from higher combined slots; no Paladin/Ranger level3 access at5. Costed edits cancel/revalidate before spend, compatible choices once/catalog unchanged. Only actual extra hosts need new proof.",
  "docs/mechanics/spell-permissions-and-preparation.md;docs/mechanics/spell-slots-and-ritual-casting.md;docs/mechanics/attack-profiles.md")
c("BOOK", "Exact books, copying and rest preparation", "S-046/S-048/S-137/S-161/S-162 continuation",
  "Source book/preparation permission, exact copies, work time and source/grant receipts.",
  "Wizard initial6/+2/class-level/copy/loss/time/GP, Ritual Adept reading/Memorize rest; Savant free additions distinct. Tome on-person3 cantrips+2 rituals/rest conjure/replace/end, not ritual-only slot permission.", "CAST WORK",
  "Wizard/Savant/Ritual/Memorize/Arcane Recovery, Spellbook item, Pact Tome/Book of Shadows; ordinary Book separate.",
  "Normal book/preparation UI legal lists/levels; copy/pay once with actual book/time, interrupt no duplicated additions. Lose/replace book honors prepared/ritual source limits. Tome on-person ending/recreation exact source, no acquisition replay; chosen spells/costs recover.",
  "docs/mechanics/spell-permissions-and-preparation.md;docs/mechanics/spell-slots-and-ritual-casting.md;docs/mechanics/work-sites.md")
c("CHOICE", "Complete parameters, replacements and feats", "S-045/S-046/S-049/S-050; S-233/S-242 reuse",
  "Generation/feat prerequisites/repeat-parameter controls, G2 all-class choices and real repeatable Skilled/source grants accepted.",
  "Source ten feats/feature/invocation/Metamagic choices, dependency-safe replacement/cadence, ASI/Grappler ability ownership; Origin fixed list versus Lessons different-feat limit. Do not redo chooser/Skilled.", "CAST DICE GRAPPLE",
  "All79 character candidates; ten feats/22 invocations/10 Metamagics, styles/Order/Land/Human.",
  "Actual creation/training legal/illegal/class-total prerequisites/repeated parameters/dependency removal. Level4 ASI/CON HP once, Magic Initiate level replace, Fighter style and Land rest cadence. Back/reset/stale confirm and both DTOs keep independent sources.",
  "docs/mechanics/progression-choices.md;docs/mechanics/permanent-progression.md")
c("ACQUIRE", "Permanent feature and resource acquisition", "S-047/S-048 continuation",
  "Permanent proficiency/equipment/ability/maxHP grants, ordered class/character receipts and fit preflight; primary G2 native path.",
  "Host rejects subclasses/most feature kinds/resources/secondary feature lists. Extend only selected acquired source kinds. JSON opt-in alone cannot enable it; native class paths remain until covered.", "PACK CHOICE",
  "All12 class/subclass1–5 features, species3/5 and multiclass class1 feature sources.",
  "Neutral loaded primary then secondary with one selected passive/active/resource/casting source and class/total thresholds. Invalid choice/full inventory refuses whole grant. Both DTOs validate receipts; sell/consume/reload no replay. Unsupported source kinds stay explicit until their assignments pass.",
  "permanent_progression_rules.gd;docs/mechanics/permanent-progression.md;class_progression.gd")
c("BACKGROUND", "Background creation and origins", "S-231; S-233/S-242/S-047 reuse",
  "Four adapted candidates, ability/feat parameters, tool-source ownership and complete package map.",
  "Production background type/loader/creation step, listed +2/+1 or+1/+1/+1, fixed feat/skills/tool/A-or50GP once. Prevent legacy species ASI stacking, no legacy rewrite.", "PACK CHOICE ACQUIRE",
  "Acolyte/Criminal/Sage/Soldier; fixed Cleric/Wizard Initiate and chosen Gaming Set.",
  "Normal four-seat creation each ability split/alternative/Back/Random/reset/stale confirm. Soldier set matches; fixed Initiate list with legal ability/spells. No revisited/reloaded double grants; both DTO source validation and legacy species boundary.",
  "docs/mechanics/progression-choices.md;docs/mechanics/permanent-progression.md")
c("SPECIES", "Nine species and total-level grants", "S-232; S-045/S-139/S-047 reuse",
  "Saved species/size/languages, source spell uses/stat/condition/sense contracts; retained old species.",
  "Full lineage/ancestry/legacy/size/skill/ability choices and character3/5 grants regardless of class. Route traits through narrow owners, no legacy fixed ASI/weapons or species-ID branches.", "BACKGROUND ACQUIRE FORM FALL LANGUAGE",
  "Dragonborn/Dwarf/Elf/Gnome/Goliath/Halfling/Human/Orc/Tiefling all trait operations/spell links.",
  "Actual creation and mixed classes total3/5 legal options/uses/rest and no early/lost/repeated grant. Dwarf HP each total level, Orc Dash+TempHP/zero replacement, Gnome device/Large space use specific proofs. Both DTOs preserve legacy separately, no migration.",
  "docs/mechanics/progression-choices.md;docs/mechanics/permanent-progression.md;docs/mechanics/core-rules-status.md")
c("MULTI", "Secondary classes through total5", "S-234; S-047/S-048/S-137/S-138 reuse",
  "Existing all/any entry gate every current/new class permanent13, offer/confirm recheck/history; combined/Pact formulas.",
  "Real secondary feature/subclass/resource/casting acquisition; restricted proficiencies/no starting gear/saves, HP roll choice policy unresolved. Class thresholds/nonstacking Extra Attack/baseAC. Gate code exists, production reachability unaccepted.", "ACQUIRE CAST BOOK SPECIES",
  "multiclass.json all12 grants/half-caster round-up, class/subclass thresholds and milestone entitlements.",
  "Normal legal/illegal/all-any12/13/stale permanent score, existing class after drop. Several total5 sequences cover class1/3/4, mixed slots/Pact/preparation/HP/Hit Dice and no extra gear/saves/replay. Reuse G3 gate checks; new source kinds need only their narrow proof. Both checkpoint forms retain entitlements.",
  "docs/mechanics/permanent-progression.md;docs/mechanics/spell-slots-and-ritual-casting.md")
c("TRAVEL", "Five-mile travel stages and terrain procedures", "S-227/S-228; S-065/S-179/S-200 reuse",
  "Campaign hexes/legal arrival/events/clock/supplies and persistent position/milestones.",
  "Actual pace/time/terrain/road/slow-member/special speed/mount hour, marching order and once-stage distance/forage/navigation/search. Terrain aliases/yields/lost destination/vehicle applicability unresolved; no general planar/waterborne gate.", "SUPPLY COMMAND FORM KNOWLEDGE",
  "43 tiles/travel tables, Phantom Steed/Disk/Animal Messenger and actual class travel consumers.",
  "Five-mile stage selected legal pace/exact elapsed time, terrain caps/roads/slow member/special speed/mount cumulative hour. Interruption/event/allowed reload never doubles time/distance/supply. Seed actual campaign yield/lost facts; unknown outcomes stay held.",
  "overworld_state.gd;hex_tile.gd;docs/mechanics/physical-facts-space-and-movement.md")
c("TRAP", "Positioned discovery, trigger and disarm", "S-229/S-230; OA Search/S-168/S-212 reuse",
  "Observer room Search, key/tool/break/Help/persistence; custom INT13 trapped_chest branches.",
  "Generated spatial trap with separate discovery/trigger/disarm/consequence/reset decisions. Keep original combined event until deliberate mapping. No SRD Needle/Darts substitution or inferred key consumption.", "WARD TOOL REPAIR",
  "Generated Trap Room/trapped_chest/Door/Chest/dungeon locks, Find Traps/Fast Hands.",
  "Actual generated room Search wrong/right space/observer, paid tool failure/Help once. Trigger/disarm/reset persist through revisit/checkpoint, no wrong/unfinished child reward. Preserve every original branch; geometry/split/reset decisions gate only affected replacement.",
  "docs/mechanics/ordinary-actions.md;local_room_rules.gd;dungeon_generator.gd")
c("EVENT", "Table routing and nested continuations", "S-214/S-215/S-217; existing event hosts reuse",
  "Weighted EventSystem, canonical EventResolver checks/child-combat handoff; native town direct shop/generated direct trapped_chest remain real routes.",
  "All4 tables/29 events delivery, shop dispatch/reveal_map fog consumer/Fairy child/return, rest/healer/custom duration semantics. Wire declared dungeon boss names/Chief bonus_hp20 and table routing currently ignored by generation; these are content wiring, not missing source values. New table roll differs from same occurrence resume; no global once-per-event-ID.", "KNOWLEDGE REST",
  "Every table/event/branch, Fairy Ring/Court/Quest Board/Merchant/Inn/Healer/generated events.",
  "Actual overworld/dungeon route and dialog branches; parent roll/GP/effects once through child open/close/reentry, unfinished child no reward. Actual fog/stock changes; boss declared name/bonus HP consumed once without replacing template. Preserve weights/leave/surprise/multiplicity. Unknown return/rest/duration remains held explicitly.",
  "event_system.gd;event_dialog.gd;event_resolver.gd;overworld_state.gd")
c("CLEAR_REWARD", "Dungeon and generated-room delivery", "S-216; S-049/S-048 reuse",
  "cleared_dungeons/mark_dungeon_cleared, generated loot/room state, native payout and milestones. claim_reward is not their actual payment route.",
  "Prove actual delivery/full-inventory before clear/claim, dungeon-clear distinct from generated room. Shared replacement consumes existing receipt, never pays beside native route.", "PACK EVENT",
  "Three clear rewards/generated_loot_room/three fragments/four milestones/crown_goals active-character predicate.",
  "Real boss clear/loot pickup normal/full inventory/recipient; failure cannot lose reward or misleadingly claim. Reentry/both checkpoint relaunches never duplicate GP/items/levels. Three fragments plus actual Lich defeat; active/inactive policy remains explicit. Existing shortcut fixtures keep bounded purpose.",
  "game_manager.gd;local_room_view.gd;overworld_state.gd;dungeon_generator.gd")
c("EVENT_REWARD", "Event and bounty victory settlement", "S-217; S-216 continuation",
  "Immediate event item/gold/check branches and encounter identities; existing transient continuation concepts/exact inventory.",
  "Quest choice.reward has no established EventDialog consumer/bounty payment. Bind exact child victory/recipient without prepayment/resume duplicate/dungeon-monster collision. Immediate event branches separate.", "EVENT CLEAR_REWARD",
  "Quest Board100GP/three-monster child; Fairy/event immediate reward branches.",
  "Actual bounty accept: defeat/flee/cancel0, only matching victory100GP once. Stale unrelated combat cannot claim; reopen/double callback/post-settlement allowed reload never repays. Immediate reward remains branch-owned, not later victory. No event/combat save checkpoint.",
  "event_dialog.gd;event_resolver.gd;game_manager.gd;combat_state.gd")
c("MONSTER_REWARD", "Monster loot policy and payment route", "S-216/S-217; campaign decision first",
  "Loot metadata copied into entities; complete acquisition links. No generic post-combat table settlement established. Dungeon/event payouts separate.",
  "Decide whether/how metadata pays, recipient/full-inventory/chance/repeated entries/form-summon-respawn exclusions, then exact occurrence settlement. Metadata is not automatically owed drop.", "CLEAR_REWARD EVENT_REWARD",
  "Ten encounters/42 direct occurrences, Lich repeated gold100/fragment, Wight/Ooze and item links.",
  "Pin policy and overlap before implementation. After decision real victory captured rolls once, exact GP/copies/recipient, intentional repeated entries preserved. Same victory reload never repays; forms/summons/defeat/flee only explicitly authorized. Metadata inspection never passes payment proof.",
  "combat_state.gd;game_manager.gd", "campaign_policy;engine_extension;content_wiring;gameplay_proof")
c("COMPANION", "Companion origins and stable recruitment", "S-231/S-232/S-234 consumers; S-047/S-049 reuse",
  "Aldric/Mira/Rowan fixed Characters/roster/stable four slots/current gear/ownership recovery.",
  "Explicit 2024 origins/lineage/subclass/later options without double ASI/package on recruit. Fixed scores/identity retained; active/inactive goal and failed recruit handling remain visible.", "BACKGROUND SPECIES MULTI CLEAR_REWARD",
  "Aldric/Mira/Rowan and current class/item reachability links.",
  "Recruit/dismiss/swap/level3/4/5 after decisions: same identity/seat/scores/gear/resources. No extra package/ASI on reload/join, player/party ownership agrees. Full party cannot lose recruit/reward; fragment goal follows explicit roster policy.",
  "party_manager.gd;docs/mechanics/permanent-progression.md", "campaign_policy;content_wiring;gameplay_proof")
c("CATALOG", "Complete consumer-cohort promotion", "S-222/S-223; proof belongs to implementing slice",
  "Written full rules/drafts, DataLoader and conversion register; accepted fixtures reusable.",
  "Only ready cohort actual definitions/controls without ID handlers. Partial stays nonloaded/refused/native until covered. No whole-engine/parent gate. This convergence list is not a prerequisite for earlier narrow promotion.", "COMPANION",
  "All unique indexed candidates plus multiclass; every pointed rule/operation/blocker in requirements.json; held/excluded cases remain explicit.",
  "Windows production loader/ordinary controls with neutral renamed then actual source consumer, cancel/stale/payment/cleanup/recovery. Check every pointed clause/blocker, not just schema. Update relevant slice boundary/content readiness; no enable with required clause missing.",
  "docs/content_pipeline.md;docs/testing.md;docs/decisions/0018-shared-data-driven-rules-runtime.md", "content_wiring;gameplay_proof")
c("JOURNEY", "Normal creation-to-finale proof", "Campaign acceptance; S-216/S-217 consumers",
  "Existing Crown smoke/composition/balance/reentry/finale/relaunch checks and campaign loop. Staged shortcuts are bounded transition proofs.",
  "Normal1–4-player journey earns four milestones/three fragments/legal training/rest/recovery/finale victory/defeat. Live controls/readability/pacing separate from headless correctness.", "CATALOG",
  "Full Crown, real companions/three dungeons/rewards/allowed checkpoints, existing native/shared composition.",
  "Supported Windows runner existing scenarios plus normal journey in existing harness: create, earn1→5/fragments, choices3/4/5, rest/save/fresh relaunch, actual finale legal commands/normal stats/resources. No invulnerability/1HP replacement boss/forced victory/precompleted milestone substitute. Observe normal play, stop session; unrelated higher-level failures stay separate.",
  "docs/testing.md;viewport_harness.gd;crown_fresh_relaunch_probe.gd", "gameplay_proof")


# 2026-11-09 source validation. Where a native per-ID path already exists, the
# assignment replaces it with shared data; it must not build a second path.
VALIDATION = {
    "PACK": "Background packages need BACKGROUND, which has no host yet. Deliver grants through the CLEAR_REWARD deliver-or-refuse helper.",
    "ARMOR": "Mage Armor base AC is native (src/characters/character.gd:1603). armor_proficiencies has no gameplay consumer, so untrained penalties and Shield training are genuinely new.",
    "QUANTITY": "Native fuel consumes a whole fuel copy per lighting (src/characters/inventory.gd:938). Replace it; don't add a second fuel model.",
    "COMPONENT": "Focus compatibility is a hardcoded item-ID check (src/characters/inventory.gd:171); replace it with item data.",
    "DICE": "Savage Attacker and Potent Cantrip exist nowhere in src/ or data/ (data/core/feats holds only skilled.json). Champion crit is already data-driven (modify_crit_range, src/characters/character.gd:1380). GWF is native (src/characters/fighter_rules.gd:306). Potent Cantrip's half damage reuses damage_scale_by_outcome (src/combat/shared_step_executor.gd:1131), not a new halving path.",
    "INIT": "Alert is not loaded; it is Criminal's origin feat, so it moves forward with BACKGROUND.",
    "REPEAT": "Extend the existing damage event (src/combat/combat_action.gd:1255 into SpellEffects.publish_event, src/spells/spell_effects.gd:303) with a save gate. Don't add a new damage hook.",
    "BUDGET": "Reuse is overstated: CombatTurnBudget tracks only Action Surge and magic_action (src/combat/combat_turn_budget.gd). Restricted-action permission is new.",
    "POSTHIT": "Divine Smite (src/combat/combat_action.gd:2289) and Pact-only Eldritch Smite (src/characters/warlock_rules.gd:302) exist natively. Replace them; don't add a parallel post-hit cast.",
    "DAMAGE_COPY": "Add copy as another DamageLinkRules policy (src/combat/damage_link_rules.gd) next to split/redirect.",
    "DAMAGE_HEAL": "DamageResponseRules counter_heal (src/combat/damage_response_rules.gd:12) already heals from settled damage. Extend it for Vampiric Touch.",
    "DEFLECT": "Deflect Attacks reduction (src/combat/combat_action.gd:2128) and the Focus-paid redirect (:1380) are native. What remains is the sight, Total Cover and 60 ft checks, plus moving it to shared data.",
    "RIDER": "Native riders: Hunter's Mark (src/combat/combat_action.gd:1534), also hardcoded as target.marked_by_actor in src/combat/shared_step_executor.gd:552; Guiding Bolt, Divine Favor, Sneak Attack. Replace them. Only retargeting is new.",
    "BENEFIT": "Aid, Barkskin, Heroism, Beacon of Hope, Magic Weapon and Enhance Ability already target others natively (src/spells/spell_effect_benefits.gd). The work is grant_source_benefits for other recipients. AC already has five carriers: converge on source_benefits and add no sixth.",
    "LIFETIME": "Record the paid cast level on every lifetime owner here; DISPEL depends on it.",
    "ITEM_MAGIC": "Shillelagh (keyed by weapon definition ID, src/characters/character.gd:388), Magic Weapon, pact weapon and Remove Curse item breaking (src/characters/curse_rules.gd:46) are native. Key them to exact copies.",
    "WEAPON": "Mastery is a hardcoded weapon-ID map (src/characters/fighter_rules.gd:8), so renamed weapons get none. Moving mastery into item data is the core work.",
    "GRAPPLE": "Reuse is overstated: Grappled only sets Speed 0 (src/combat/combat_action.gd:83). Attack Disadvantage against non-grapplers and Unarmed Grapple/Shove are new.",
    "MOVE": "Fallback climb/swim cost already exists in PhysicalFactsRules.attempt_movement_step (src/combat/physical_facts_rules.gd:734), but only checks call it. Wire it into production movement. Jump is native (src/combat/combat_state.gd:2793).",
    "GRANTED_MOVE": "Command's orders (src/combat/combat_state.gd:1258) and Repelling Blast (src/spells/spell_effect_application.gd) are native. Dissonant Whispers and Fear are new.",
    "FALL": "Falling damage is native in combat (src/combat/combat_state.gd:7006) and in rooms (src/dungeon/local_room_rules.gd:397). Feather Fall and Slow Fall hook these; no new fall path.",
    "PHASE": "Misty Step is already data-driven (a teleport effect with requires_sight, src/combat/travel_placement_rules.gd).",
    "OBJECT": "Area object damage and ignition already exist (src/combat/combat_object_rules.gd:200).",
    "TOOL": "Thieves' Tools lockpicking and Crowbar prying are native (src/dungeon/local_room_rules.gd:856). A Crowbar is required there, but in the SRD it grants Advantage.",
    "HAZARD": "Ashvale heat is already data-driven terrain (src/dungeon/local_room_rules.gd:406).",
    "LIGHT": "Outlined Advantage exists natively (src/combat/combat_action.gd:625).",
    "ZONE": "Spirit Guardians, Moonbeam, Spike Growth and other zones are native per-spell code (src/spells/combat_spell_zones.gd). This is replacement, not new wiring.",
    "WARD": "Knock suppression (src/combat/combat_object_rules.gd:335) and Arcane Lock password/designated users (:373) are native. Missing: the password UI, Knock's noise, Magic Mouth.",
    "POOL": "Created slots (src/characters/sorcerer_rules.gd:217), Wild Resurgence (src/characters/druid_rules.gd:180), Tactical Mind (src/characters/fighter_rules.gd:241) and the shared exchange (src/characters/resource_pool_rules.gd:312) exist. Arcane Recovery is the new piece.",
    "SUPPLY": "Per-size food/water needs and deprivation exhaustion exist (src/characters/survival_rules.gd:6). Stock, spoilage and contamination are new.",
    "REMAINS": "The Gentle Repose clock pause (src/characters/corpse_rules.gd:56) and Revivify window/refusals (:73) are native. Wight max-HP drain and the delayed Zombie are new.",
    "BOOK": "Wizard copying cost/time is native (src/characters/class_progression.gd:771), but it only reports hours and never spends campaign time.",
    "ACTOR": "Build Multiattack on the existing extra-attack units, not a monster-only path.",
    "BACKGROUND": "No background host exists (src/ui/character_creation/character_creation.gd:628: no background step yet). The four SRD backgrounds are written only as candidates in preparation/crown-characters/backgrounds. Their origin feats (Alert, Magic Initiate, Savage Attacker) are not loaded. Moved forward because every new character needs it.",
    "CLEAR_REWARD": "Live defect: dungeon clear marks itself cleared (src/dungeon/dungeon_state.gd:372) before paying, and ignores add_item returning false on a full backpack, so a fragment can be lost. The loot room (:281) and event give_item (src/events/event_resolver.gd:615) also ignore it, and gold_ is parsed separately in each route. Build one deliver-or-refuse helper here, preflighting with PermanentProgressionRules.can_fit. PACK, EVENT_REWARD and MONSTER_REWARD use it. Moved forward.",
    "EVENT_REWARD": "Pay through the CLEAR_REWARD delivery helper.",
    "MONSTER_REWARD": "Pay through the CLEAR_REWARD delivery helper.",
}
STATUS = {"AMMO": "**Verified bounded CXM-01 delivery (2026-11-08)** in the [slice registry](../vocabulary-slices.md#exact-ammunition-spending-and-recovery). The planning target below is retained; catalog promotion, shop lot expansion and fired-ammo corrosion remain separate.",
          "CLEAR_REWARD": "**Partial CXM-02 delivery (2026-11-09)** in the [slice registry](../vocabulary-slices.md#dungeon-reward-delivery-or-refusal): `Inventory.grant_bundle` delivers dungeon clear and loot-room rewards whole or not at all, and the clear is recorded only after payment. Real boss-clear gameplay, checkpoint relaunch proof and the active/inactive policy remain.",
          "PACK": "**Partial CXM-03 delivery (2026-11-09)** in [progression choices](../../mechanics/progression-choices.md): generic `starting_equipment_choices` slots and one GP selector replaced the Bard/Barbarian branches. All 12 classes have their SRD kits and GP options (Fighter A/B/C via `starting_equipment_alternatives`), except Wizard B, which waits on a Spellbook ruling. Packs and their contents, Arrows, Quiver, Books, Pouch, Traveler's Clothes and the arcane-focus Quarterstaff are in the catalog; starting Arrows are stowed in the Quiver. Catalog bows don't spend Arrows yet. Background packages belong to CXM-04.",
          "BACKGROUND": "**Partial CXM-04 delivery (2026-11-09)** in the [slice registry](../vocabulary-slices.md#background-acquisition-at-creation): backgrounds are a loaded content type with a creation step; the four SRD backgrounds grant their ability increase, skills, tool, kit or 50 GP and fixed Origin feat once, and a background character takes no legacy species ability bonuses. Alert, Savage Attacker and Magic Initiate are owned but their rules wait for CXM-05, CXM-06 and CXM-60, so the fixed Initiate spell and ability choice is not delivered."}
# Owner-selected priority (2026-11-09): reward safety, then character origins.
FRONT = ["BASE", "AMMO", "CLEAR_REWARD", "PACK", "BACKGROUND", "INIT", "DICE"]


def write():
    CAPS.sort(key=lambda cap: (FRONT.index(cap["id"]) if cap["id"] in FRONT else len(FRONT), cap["order"]))
    for i, cap in enumerate(CAPS):
        cap["order"], cap["assignment"] = i, "REUSE" if not i else f"CXM-{i:02}"
        if cap["id"] in VALIDATION:
            cap["validation"] = VALIDATION[cap["id"]]
    missing = {"AMMO", "INIT", "DAMAGE_COPY", "DISPEL", "STORAGE"}
    content = {"PACK", "CHOICE", "COMPANION", "CATALOG", "JOURNEY"}
    facts = {"CARRY", "QUANTITY", "TOOL", "DETECT", "KNOWLEDGE", "SUPPLY", "BREATH", "REMAINS", "TRAVEL", "TRAP"}
    policy = {"COMPONENT", "ACTOR", "REST", "EVENT", "MONSTER_REWARD", "COMPANION", "TRAVEL", "TRAP", "REMAINS"}
    for cap in CAPS:
        cap["engine_state"] = ("existing_contract" if cap["id"] == "BASE" else
                               "missing_selected_generic_contract" if cap["id"] in missing else
                               "existing_contract_with_content_or_consumer_work" if cap["id"] in content else
                               "partial_contract_missing_or_unverified_named_hosts")
        cap["proof_state"] = "No gameplay acceptance performed here; reuse only the registry's named verified boundaries."
        if cap["id"] in facts and "source_fact" not in cap["work_kinds"]:
            cap["work_kinds"].append("source_fact")
        if cap["id"] in policy and "campaign_policy" not in cap["work_kinds"]:
            cap["work_kinds"].append("campaign_policy")
    # These relationships are conditional consumers, not a whole catalog gate.
    selected = {cap["id"]: cap for cap in CAPS}
    selected["MULTI"]["prerequisites"] = ["ACQUIRE", "CAST"]
    selected["CATALOG"]["prerequisites"] = []
    selected["CONTAIN"]["prerequisites"] = []
    selected["CONTAIN"]["conditional_prerequisites"] = {"FORM": "Only when the swallowing creature is an acquired form.", "PHASE": "Only Rope Trick's represented internal plane/access.", "BARRIER": "Only Rope Trick's specified inside/outside effect barrier."}
    selected["TRAVEL"]["prerequisites"] = ["SUPPLY"]
    selected["TRAVEL"]["conditional_prerequisites"] = {"COMMAND": "Only mount/created actor travelers.", "FORM": "Only effective form speed/body needs.", "KNOWLEDGE": "Only selected navigation/foraging/forecast outcomes, after campaign facts exist."}
    selected["SPECIES"]["conditional_prerequisites"] = {"FORM": "Only actual Large/Form traits.", "FALL": "Only flight/ending consumers.", "BACKGROUND": "Only exclusive ownership of creation ability increases, not completion of all background content."}
    selected["SPECIES"]["prerequisites"] = ["ACQUIRE", "LANGUAGE"]
    # A shared requirement is not a new parent-sized gate. Existing accepted
    # owners in `reuse` are the default prerequisites. Further work is needed
    # only for the concrete dependent consumer identified here.
    dependent = {
        "QUANTITY": {"CARRY": "Only admission/overflow into a selected measured container; burning fuel does not wait for all carrying rules."},
        "POSTHIT": {"REACTION": "Only an intervening Reaction on the same captured hit; own-turn post-hit casting can use existing hit events."},
        "DAMAGE_COPY": {"REACTION": "Only optional interrupted damage choices on a selected caller; automatic Warding Bond copying has no Reaction cost."},
        "DEFLECT": {"REACTION": "Only exact incoming-attack choice scheduling; Hellish Rebuke/Counterspell/falling conversions are not gates."},
        "WEAPON": {"AMMO": "Only ammunition weapons and their actual shot routes; melee properties can proceed independently."},
        "GRANTED_MOVE": {"MOVE": "Only an actual route requiring fallback climb/swim/jump/stand; floor movement reuses accepted S-179."},
        "FALL": {"REACTION": "Only Feather Fall/Slow Fall's actual fall-trigger choice.", "MOVE": "Only a new movement mode whose loss produces the selected fall."},
        "PHASE": {"FALL": "Only gas/flight ending or stone expulsion that actually needs falling; Blink/Misty arrival uses existing placement."},
        "BARRIER": {"PHASE": "Only Magic Circle's intercepted teleport attempt; Hut/Wind ordinary crossings need no Blink/gas work."},
        "REPAIR": {"OBJECT": "Only a missing exact target/part or damage fact for this repair; room copy targeting already exists. Fireball ignition is not a gate."},
        "TOOL": {"OBJECT": "Only the selected task's missing actual object mutation/target; existing Utilize supports independent tasks."},
        "ITEM_ATTACK": {"QUANTITY": "Only exact kit-use/portion counter needed by this item; discrete consumable copies reuse S-049.", "GRAPPLE": "Only Net restraint/escape relation; Holy Water/potions are independent."},
        "HAZARD": {"QUANTITY": "Only recoverable stock/fuel counter for the selected hazard.", "ITEM_ATTACK": "Only Oil dousing/thrown ignition; caltrop placement uses accepted Utilize."},
        "LIGHT": {"OBJECT": "Only a missing exact object-origin/cover control.", "QUANTITY": "Only fuel-powered items; spell emitters need no general fuel work."},
        "ZONE": {"BENEFIT": "Only the selected source speed/check/recipient benefit.", "LIGHT": "Only the selected light/obscuration emitter; other area payloads use accepted perception."},
        "REMOTE": {"LIGHT": "Only a missing sensor perception fact; accepted S-190 is reusable.", "REACTION": "Only familiar Touch delivery scheduling not already covered by native controls."},
        "DETECT": {"REMOTE": "Only an actual independent sensor origin; caster-origin detection is independent."},
        "KNOWLEDGE": {"LANGUAGE": "Only the selected communication route absent from accepted local speech.", "DETECT": "Only answers derived from a selected detection source; Augury/authored questions need no remote-sense gate."},
        "ILLUSION": {"KNOWLEDGE": "Only the selected per-observer discovery/answer consequence; reuse existing Study receipts.", "OBJECT": "Only a selected physical interaction target, not every damage spell."},
        "WARD": {"OBJECT": "Only a missing exact lock/object fact; ordinary room locks exist.", "LANGUAGE": "Only the selected password/message route, not Sending/Tongues generally."},
        "DISPEL": {"LIFETIME": "Only capture/validate source cast level on each owner actually being ended.", "LIGHT": "Only opposite-kind area overlap producers; ordinary Dispel source ending independent."},
        "STORAGE": {"WARD": "Only exact Glyph trigger/source-location record.", "DISPEL": "Only Glyph source ending by dispel; other light/curse owners do not gate storage."},
        "REST": {"WORK": "Only Prayer's ten-minute continuous-participant cast; no whole long-cast catalog gate."},
        "SUPPLY": {"QUANTITY": "Only selected physical intake/stock units.", "REST": "Only missing recipient restriction; successful Long Rest lifecycle is already accepted."},
        "BREATH": {"SUPPLY": "Only shared cause-specific exposure/deadline plumbing, not hunger/foraging or all food rules."},
        "CREATION": {"LIFETIME": "Only the actual output/granted-action source ending.", "QUANTITY": "Only food/water/batch outputs; spectral actions do not wait for gallons."},
        "CRAFT": {"TOOL": "Only this recipe's qualification/tool task.", "WORK": "Only actual site/time host needed; existing work support reusable.", "CREATION": "Only exact selected output-copy creation, not every magical controller."},
        "ACTOR": {"WEAPON": "Only the selected attack property/mastery absent from accepted profiles.", "REACTION": "Only an actual Reaction trait; printed statistics/simple actions can proceed independently."},
        "COMMAND": {"ACTOR": "Only chosen actor template/action kinds.", "REMOTE": "Only specified senses/Touch delivery; commands reuse existing actor authority."},
        "FORM": {"ACTOR": "Only legal selected source stat/trait template.", "ARMOR": "Only retained equipment/base-AC consumer.", "GRAPPLE": "Only a selected form's actual grapple action, not all form selection."},
        "REMAINS": {"ACTOR": "Only delayed/created Zombie template; Revivify restores original actor.", "REPAIR": "Only if an actual retained-piece fact is absent; revive refusal for missing parts does not require Mending."},
        "CAST": {"COMPONENT": "Only material/hand form absent for the selected permission/edit.", "POOL": "Only exact cost/exchange needed by the selected option.", "ROLL": "Only option's actual roll-choice host.", "LIFETIME": "Only selected duration/concentration owner."},
        "BOOK": {"CAST": "Only exact book-source preparation/permission, already accepted in bounded form.", "WORK": "Only copying/replacement/ritual site and time, not all long spells."},
        "CHOICE": {"CAST": "Only selected spell grant/parameter source.", "DICE": "Only actual Savage Attacker/GWF feat effect proof.", "GRAPPLE": "Only actual Grappler effect proof; acquiring other feats is independent."},
        "ACQUIRE": {"PACK": "Only concrete chosen equipment grant references; fixed primitive grants already accepted.", "CHOICE": "Only parameter/choice kinds in the source being acquired."},
        "BACKGROUND": {"PACK": "Only selected A package; GP alternative independent.", "CHOICE": "Only selected Origin feat parameters.", "ACQUIRE": "Only once-only background source grants/validation."},
        "SPECIES": {"ACQUIRE": "Only selected permanent and total-level trait receipt kinds.", "LANGUAGE": "Only creation/class language grant state; no remote-message gate.", **selected["SPECIES"]["conditional_prerequisites"]},
        "MULTI": {"ACQUIRE": "Only chosen secondary source/feature/subclass/resource kinds.", "CAST": "Only actual caster contribution/repertoire; accepted entry gate and noncaster progress independent."},
        "TRAP": {"WARD": "Only matching exact lock state/key policy.", "TOOL": "Only selected disarm/break task; no full tool catalog gate.", "REPAIR": "Only actual broken piece facts, not general Mending."},
        "EVENT": {"KNOWLEDGE": "Only a branch that grants/queries authored information.", "REST": "Only inn/rest service; other table routing independent."},
        "CLEAR_REWARD": {"EVENT": "Only selected generated/event child that owns this reward; native dungeon clear independent."},
        "EVENT_REWARD": {"EVENT": "Only exact pending child-encounter/parent continuation."},
        "MONSTER_REWARD": {"EVENT_REWARD": "Only bounty overlap if loot policy selects same encounter; first resolve policy."},
        "COMPANION": {"BACKGROUND": "Only selected legal default/origin source.", "SPECIES": "Only selected lineage/traits.", "MULTI": "Only if companion actually multiclasses; ordinary level-up sources suffice otherwise.", "CLEAR_REWARD": "Only roster-fragment predicate/delivery actually affected."},
    }
    for key, requirements in dependent.items():
        selected[key]["prerequisites"] = []
        selected[key]["conditional_prerequisites"] = requirements
    for key in ("PACK", "EVENT_REWARD", "MONSTER_REWARD"):
        selected[key]["prerequisites"] = ["CLEAR_REWARD"]  # one shared delivery helper
    policy = ("Prerequisites mean only the selected needed behavior, not completion of a whole referenced assignment or parent slice. "
              "Neutral loaded production fixtures can provide it without production catalogs. Numeric order picks ready work; "
              "independent ready work may proceed. CATALOG/JOURNEY are convergence checks, not gates on narrow promotion.")
    data = {"schema": "crown-capability-assignments/1", "status": "planning_only",
            "prerequisite_semantics": policy, "capabilities": CAPS}
    (HERE / "capabilities.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    lines = ["# Crown implementation assignments", "", "Planning only; no assignment was implemented or gameplay-accepted in this pass.", "", policy, "",
             "Each assignment's exhaustive consumers are the exact units selected by its capability ID in [requirements.json](requirements.json). "
             "Use `python docs/planning/crown-engine-mapping/build_mapping.py --capability AMMO` (substitute the ID) to print their file/pointers. "
             "The examples below explain the concrete behavior; the ledger retains every additional consumer/qualifier.", "",
             "Every implementation uses the supported [Windows runner](../../testing.md). Extend existing logic/viewport scenarios for actual regression risks; "
             "use renamed loaded definitions through ordinary controls, then actual source consumers. Refuse unsupported/stale inputs before unintended expenditure. "
             "Durable changes must pass both existing allowed checkpoint DTO routes and fresh-process recovery without replay; no new checkpoint, legacy migration or serialized pending chooser. "
             "Shared combat/persistence changes get one focused independent review per AGENTS.md. These are future checks, not results of this mapping pass.", ""]
    for cap in CAPS:
        lines += [f"## {cap['assignment']} — {cap['title']} ({cap['id']})", "",
                  f"Owner: **{cap['slice_owner']}**. Prerequisites: " + (", ".join(cap["prerequisites"]) or "accepted reuse only") + ".", "",
                  "Consumers: " + cap["concrete_consumers"], "", "Reuse: " + cap["reuse"], "",
                  "Deliver: " + cap["remaining"], ""] + (["Runtime status: " + STATUS[cap["id"]], ""] if cap["id"] in STATUS else []) + (["Source check (2026-11-09): " + cap["validation"], ""] if cap.get("validation") else []) + [
                  "Acceptance: " + cap["acceptance"], "",
                  "Evidence: " + ", ".join(f"[{Path(p).name}](../../../{p})" for p in cap["evidence"]) + ".", ""]
        if cap.get("conditional_prerequisites"):
            lines += ["Conditional dependencies: " + " ".join(f"{k}: {v}" for k, v in cap["conditional_prerequisites"].items()), ""]
    (HERE / "assignments.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    write()
    print(f"Wrote {len(CAPS) - 1} assignments plus accepted reuse.")
