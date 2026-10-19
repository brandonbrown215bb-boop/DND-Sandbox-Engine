# Spell delivery status and shared behavior backlog

Reviewed 2026-10-06. The single status register is [spell_status.json](spell_status.json); this report and the spell section of the feature matrix are generated views of it.

All unique core spell IDs; one row per ID, with actual core-12 casting-class membership. Rules completeness is deliberately uncertified.

**No spell is certified fully rules-complete by this reconciliation.** A recorded gameplay slice is useful progress, not a completed SRD audit. The 809-row repair snapshot is a historical missing-membership list, not the current spell denominator. The older canonical artifact has 338 distinct IDs; the loaded registry has 362. Current production class lists contain 898 memberships. Those sets must not be mixed into one completion percentage.

## Current verification boundary

Recorded slices refer to historical passing checks. Parsing is restored. The source-owned batch has dedicated effect and live encounter checks; see their evidence paths. Historical slices retain their older evidence and limitations. Availability is exported from the production gate, independently of delivery status. This is not a fresh audit of every SRD clause.

Production casting currently enables 133 explicit gameplay slices and refuses 229 spell IDs before costs. Availability is not full rules certification. Raw class memberships and existing saves retain the full catalog.

## Status totals

| Delivery status | Unique spells | Meaning |
|---|---:|---|
| recorded_slice | 113 | Reviewed dated evidence for a working gameplay slice; remaining limitations and full rules audit stay open. |
| existing_checks_need_audit | 12 | Existing resolver/class-flow checks, but no reconciled complete spell audit. |
| implemented_unverified | 0 | New implementation awaiting a valid Godot gameplay run. |
| blocked | 11 | Known incomplete or unsupported behavior; production availability gate refuses before costs. |
| unimplemented_exposed | 0 | Known absent core effect still exposed to casting (should remain zero). |
| needs_audit | 226 | Loaded/listed; production behavior and rules completeness not yet established. |

## Dependency waves

The [current roadmap](../../roadmap.md) controls delivery. The historical [foundation plan](spell-foundations.md) retains capability gaps and wave groupings, not a live execution order. Catalog `dependency_plan` entries retain minimum requirements and exclusions; they do not select implementation work or certify a spell. Foundation status, availability and production evidence remain separate.

| Capability | Wave | Foundation status |
|---|---:|---|
| Authored five-foot room geometry | 1 | bounded_version_verified |
| Persistent doors, containers and loose objects | 1 | bounded_version_verified |
| Individual owned item copies and transactions | 1 | bounded_version_verified |
| Campaign clock and exploration cast application | 1 | partial |
| Components, focuses, tools, hands and usable supplies | 2 | planned |
| Magic item copies, charges, attunement and curses | 2 | planned |
| Shared lighting, sight, cover, senses and sensors | 2 | planned |
| Complete condition consequences and removable sources | 2 | partial |
| Creature/object targets, multiple areas and damage packets | 2 | partial |
| Environmental operations and quantified food/water | 3 | planned |
| Durable areas, barriers and boundary entry | 3 | partial |
| Movement modes, elevation, falling and mounts | 3 | partial |
| Owned creatures, commands and familiar abilities | 4 | partial |
| Bodies, resurrection eligibility and reversible forms | 4 | partial |
| Languages, recognition, attitudes and illusion discovery | 4 | planned |
| Campaign knowledge and tracked communication | 5 | partial |
| Known travel destinations and authored other spaces | 5 | planned |
| Stored event subscriptions and exceptional outcomes | 5 | planned |
| Additional transformation forms and target contracts beyond first version | 4 | excluded_first_version |
| Individually authored exceptional world operations beyond first version | 5 | excluded_first_version |

Repair snapshot reconciliation: 809 class/spell rows map to 337 unique runtime IDs; 0 unresolved names and 0 missing class memberships. Exact unresolved entries, if any, are retained in the register. This checks names/access only.

The delivery status describes evidence; cast availability separately controls whether a character may choose or cast the spell. Unaudited records remain in the inventory and raw class lists, but unavailable IDs are refused before costs. Mending and Invisibility no longer return effectless success.

## Batches by shared behavior

Every spell has one primary planning family. Counts therefore add up without duplicates. Families are inferred from current records and documented gaps; each member still needs its own rule audit. Recorded slices also retain their documented gaps. Secondary requirements (components, timers, saves, persistence) may cross families.

The Recorded slices column counts only `recorded_slice` status. Without recorded-slice status includes `existing_checks_need_audit`: those spells may already be available and have gameplay checks. These columns measure reviewed evidence, not whether a family has any implementation.

| Family | Total IDs | Recorded slices | Without recorded-slice status | Shared next work |
|---|---:|---:|---:|---|
| Timed effects, repeat saves and source tracking | 45 | 27 | 18 | The seven-spell source-owned batch, including the rays and Hold spells, is delivered as bounded slices. Reuse SpellEffects and SpellEncounterLifecycle for remaining spells; audit individual expiry, repeat-save and campaign-persistence gaps. |
| Conditions, control and forced movement | 41 | 13 | 28 | Share eligible-target saves, condition consequences on both sides, repeat saves, damage breaks and constrained movement. Keep exceptional orders narrow. |
| Persistent areas, walls and triggered damage | 45 | 14 | 31 | The encounter-local zone lifetime, movement/turn triggers, trigger caps, terrain costs and concentration cleanup are delivered. Reuse CombatSpellZones, SpellZoneTerrain and SpellZoneConjurations; audit each remaining spell's geometry, triggers and lifetime before enabling it. |
| Summons, companions and created combat entities | 17 | 2 | 15 | Find Familiar and Animate Dead have verified bounded Crown room/encounter slices. Created Undead retain existence after control expiry. Find Steed retains existing checks awaiting full audit. Animated objects and other created creatures remain open. Modern Conjure records remain in the area family. |
| Light, visibility and detection | 27 | 13 | 14 | Obscuration, Invisibility, sense and detection slices now affect gameplay. Reuse their source-owned effects and SpellEncounterPerception; audit terrain line of sight, object visibility, missing sense outcomes and individual spell gaps. Light markers alone remain partial. |
| Objects, inventory and environmental changes | 26 | 4 | 22 | Wave 1 ordinary rooms/objects/copies are the first implementation card. Finish their acceptance and campaign-time/exploration-casting foundations before separate Arcane Lock, Knock, Mage Hand and Mending integrations. Identify and Goodberry retain their recorded limits. |
| Dialogue, illusions and belief | 18 | 1 | 17 | Reuse recipient/creature interaction, language, perception and explicit illusion outcomes. Store markers separately from actual belief or interaction effects. |
| Campaign information and communication | 14 | 2 | 12 | Reuse the campaign clock and delivery ledger where suitable; add explicit information/recipient outcomes rather than success-only casts. |
| Movement, terrain, travel and other spaces | 31 | 1 | 30 | Share movement modes and restrictions locally; keep campaign destinations, route validation and inter-plane travel separate from a combat teleport. |
| Death, bodies and transformations | 16 | 3 | 13 | Party corpse identity/time, willingness, preservation and bounded Revivify/Gentle Repose now have production paths. Other bodies, created-undeath integration and reversible forms remain open; retain original character identity. |
| Wards, dispelling and restoring state | 9 | 3 | 6 | Share effect identity/source, eligible removal, immunity, spell-level checks and item attunement where modeled; distinguish condition removal from full curse resolution. |
| Weapon-triggered and repeated attacks | 15 | 1 | 14 | Reuse confirmed-hit riders, action/reaction timing, slot scaling and condition cleanup; avoid casting a weapon buff as an immediate ordinary damage spell. |
| Exceptional world or action rules | 6 | 0 | 6 | Keep explicit supported modes for these unusual spells. Do not build a universal rule engine as a prerequisite for ordinary combat spells. |
| Immediate attacks, saves, healing and area selection | 52 | 29 | 23 | Audit complete target sets, shapes, split damage, extra effects, thresholds and upcasting using existing resolution blocks. A positive damage roll alone is insufficient. |

## Practical delivery order

1. Wave 1 foundations: finish Ashvale's ordinary room/object/item loop, then campaign time and exploration casting. Arcane Lock, Knock, Mage Hand, Mending, item-target and timed-effect integrations have separate cards; later requirements keep them partial/unavailable.
2. Wave 2 foundations: components/equipment, magic items, shared perception, condition consequences and full targeting. Integrate the named spells only after the foundations have gameplay and persistence evidence.
3. Wave 3 foundations: environmental resources/operations, durable areas/barriers and movement modes. Preserve current area trigger caps and concentration cleanup.
4. Wave 4 foundations: owned creatures/commands, bodies/forms and authored NPC/illusion interactions. Expanded forms retain explicit exclusions.
5. Wave 5 foundations: campaign knowledge/messages, destinations/refuges/planes and individually scoped stored triggers/exceptional outcomes. Wish duplication uses completed paths; other outcomes remain unsupported.

Finish a wave's supported integrations and explicit dependency deferrals before opening the next wave. Resume class expansion when its specific blockers are resolved. A foundation does not certify its spells.

Use the [spell extension guide](../../src/spells/README.md) for implementation homes and cast ordering. [Current checkpoint](../operations/current.md) records the latest validation and known baseline/intermittent failures; focused acceptance does not mean the full suite is green. [Roadmap](../../roadmap.md) owns milestone priorities and the Quest Board owns the exact next action.

No wholesale combat extraction, new service, or universal effect language is required. Do not let a safe-refusal check advance a spell into the recorded-playable count.

## One row per spell

Class names are actual runtime memberships; an empty list means the spell is outside these eight core casting-class lists. Evidence is retained in JSON. The detailed limitations below override optimistic imported metadata.

### Timed effects, repeat saves and source tracking

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `aid` | 2.0 | recorded_slice | slice available | bard, cleric, druid, paladin, ranger | Production picker applies an eight-hour source-owned increase to current and maximum Hit Points on up to three party characters. A level-3 production cast verifies +10 HP, one slot cost and expiry restoration. Other creatures and party NPCs outside combat entities are not targetable; component inventory enforcement and full clause audit remain open. |
| `armor_of_agathys` | 1.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `aura_of_life` | 4.0 | recorded_slice | slice available | cleric, paladin | Gameplay implementation slice: a 30-foot Emanation follows the caster for 10 minutes with Concentration. Party Characters in range gain Necrotic Resistance, cannot have their Hit Point maximum reduced, and regain 1 Hit Point if they start their turn at 0 Hit Points. These source-owned protections refresh as the aura moves and clear when range or Concentration ends. Only party Characters and combat time are modeled; persistent campaign-time effects and full SRD clause audit remain open. |
| `bane` | 1.0 | recorded_slice | slice available | bard, cleric, warlock | Production picker covers a failed Charisma save, two targets with a level-2 slot, one shared slot cost and source-owned concentration. Each attack/save subtracts a fresh d4. Material component inventory enforcement and complete clause audit remain open. |
| `barkskin` | 2.0 | recorded_slice | slice available | druid, ranger | Available gameplay slice: Barkskin is a Bonus Action on a willing living party member and sets an Armor Class floor of 17 for one hour. Character and monster attack resolution honor the floor; higher AC is unchanged. Bark-like appearance and material inventory are not modeled; Barkskin uses the shared timed spell-effect and save-validation path, and the full clause audit remains open. |
| `beacon_of_hope` | 3.0 | recorded_slice | slice available | cleric | Production selection covers any tracked party Character or combat monster within 30 feet, including an eligible downed Character. Targets gain Wisdom-save and Death Saving Throw Advantage, and covered healing paths maximize their dice through shared and combat healing handlers. Lasts up to one combat minute with Concentration cleanup. Campaign-time persistence, untracked creatures, material inventory enforcement and the full SRD clause audit remain open. |
| `blade_ward` | 0.0 | recorded_slice | slice available | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `bless` | 1.0 | recorded_slice | slice available | cleric, paladin | Chosen-creature targeting, 60-second duration, source ownership and saved party expiry; costly Holy Symbol is descriptive metadata, not an enforced inventory requirement. |
| `blur` | 2.0 | recorded_slice | slice available | sorcerer, wizard | Live combat verifies Disadvantage against the caster, with immunity for Blindsight and Truesight within range, plus one-minute Concentration cleanup. Combat terrain has no line-of-sight model; the full clause audit remains open. |
| `crusaders_mantle` | 3.0 | needs_audit | unavailable | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `death_ward` | 4.0 | recorded_slice | slice available | cleric, paladin | Production casting wards a tracked creature with an eight-hour source-owned effect. When damage after resistance and Temporary Hit Point absorption would reduce a living target to 0 Hit Points, the target remains at 1 Hit Point and the effect is consumed. Unused wards expire on the shared clock. The 2024 SRD text does not include the older instant-death exception; other non-damage death rules are outside this spell slice. Full clause audit remains open. |
| `divine_favor` | 1.0 | recorded_slice | slice available | paladin | Production Paladin cast is a Bonus Action that spends one level-1 slot and gives the caster a source-owned one-minute effect. Every weapon hit adds a separately mitigated 1d4 Radiant packet, including critical hits. Recasting replaces the prior Divine Favor source. The implemented attack path covers combat weapon attacks; attacks outside combat and the full SRD clause audit remain open. |
| `elemental_weapon` | 3.0 | needs_audit | unavailable | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `enhance_ability` | 2.0 | recorded_slice | slice available | bard, cleric, druid, ranger, sorcerer, wizard | Production casting spends a Magic Action and slot to grant one or more tracked party characters Advantage on ability checks using one selected ability for up to one hour with Concentration. Upcasting adds one target per slot level; each target can receive a different ability. Targets must be tracked party characters; material inventory, campaign persistence and full SRD clause audit remain open. |
| `enlarge/reduce` | 2.0 | needs_audit | unavailable | bard, druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `expeditious_retreat` | 1.0 | needs_audit | unavailable | sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `false_life` | 1.0 | recorded_slice | slice available | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `fire_shield` | 4.0 | needs_audit | unavailable | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `foresight` | 9.0 | needs_audit | unavailable | bard, druid, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `glibness` | 8.0 | needs_audit | unavailable | bard, warlock | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `guidance` | 0.0 | recorded_slice | slice available | bard, cleric, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `haste` | 3.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `heroes_feast` | 6.0 | needs_audit | unavailable | bard, cleric, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `heroism` | 1.0 | recorded_slice | slice available | bard, paladin | Production casting spends a Magic Action and slot to establish Concentration on one or more willing tracked party characters for up to one minute. Targets are immune to Frightened and at the start of each turn gain Temporary Hit Points equal to the caster's captured spellcasting ability modifier (without reducing a higher existing amount). Current SRD text leaves remaining Temporary Hit Points when the spell ends. Upcasting adds one party target per slot level. Campaign-time persistence, material inventory and the full SRD clause audit remain open. |
| `hex` | 1.0 | needs_audit | unavailable | warlock | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `holy_aura` | 8.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `hunters_mark` | 1.0 | blocked | unavailable | ranger | Unavailable: the exposed implementation only adds its damage through a test helper and records a 10-round mark. It does not add Force damage on every weapon or spell attack roll, grant tracking-check Advantage, move the mark after a target drops, or apply the 8/24-hour upcast durations. Correct SRD metadata is recorded; casting is refused before costs until combat and campaign-time tracking cover those effects. |
| `longstrider` | 1.0 | recorded_slice | slice available | bard, druid, ranger, wizard | Combat speed bonus; no general campaign-clock expiry for spell conditions. |
| `mage_armor` | 1.0 | recorded_slice | slice available | sorcerer, wizard | Available gameplay slice: Mage Armor sets an unarmored willing party member's base AC to 13 + Dexterity for eight hours, retains shield AC, and ends early when armor is donned. Material inventory is descriptive metadata; dismissal and the full clause audit remain open. |
| `magic_weapon` | 2.0 | recorded_slice | slice available | paladin, ranger, sorcerer, wizard | Production casting spends a Magic Action and slot to enchant a tracked party character's equipped nonmagical main-hand weapon for up to one hour with Concentration. The effect adds +1 at slots 2-3, +2 at slots 4-5 and +3 at slots 6+, to attack and damage rolls, and makes the weapon magical. Only the equipped main-hand weapon is selectable; off-hand/monster items, material inventory, campaign-time persistence and full SRD clause audit remain open. |
| `mind_blank` | 8.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `mirror_image` | 2.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `protection_from_energy` | 3.0 | recorded_slice | slice available | cleric, druid, ranger, sorcerer, wizard | Combat duration; campaign-clock expiry not connected. |
| `protection_from_evil_and_good` | 1.0 | recorded_slice | slice available | cleric, druid, paladin, warlock, wizard | No possession or source-aware existing charm/fear save benefits. |
| `protection_from_poison` | 2.0 | recorded_slice | slice available | cleric, druid, paladin, ranger | Single poison condition; no separate poison sources or non-spell poison saves. |
| `ray_of_enfeeblement` | 2.0 | recorded_slice | slice available | warlock, wizard | Failed-save concentration repeats CON saves; successful-save attack penalty expires at the caster's next start. No general inactive-caster combat clock. |
| `ray_of_sickness` | 1.0 | recorded_slice | slice available | sorcerer, wizard | Source-owned poison expires at the end of the caster's next turn and preserves unrelated poison. |
| `regenerate` | 7.0 | recorded_slice | slice available | bard, cleric, druid | No body-part regrowth; one-minute casting approximated by an action; combat timer only. |
| `resistance` | 0.0 | recorded_slice | slice available | cleric, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `sanctuary` | 1.0 | recorded_slice | slice available | cleric | Production casting spends a Bonus Action and level-1 slot to ward one tracked combat creature for one minute. Attack rolls and directly targeted damaging spells must pass the ward's captured Wisdom save DC; the supported failed-save choice is losing the attack or spell. Area spells are not blocked. The ward ends when its target attacks, casts a spell, deals damage or expires; taking damage alone does not end it. Selection is limited to tracked combat creatures; alternate-target selection, component inventory and the full SRD clause audit remain open. |
| `shield` | 1.0 | existing_checks_need_audit | slice available | sorcerer, wizard | The Reaction is offered for Magic Missile and spell attacks. It spends only when a triggering attack hits, applies +5 AC against that attack and later attacks, or prevents all Magic Missile damage, and lasts until the start of the target's next turn. The full clause audit remains open. |
| `shield_of_faith` | 1.0 | recorded_slice | slice available | cleric, paladin | Source-owned AC ward on party or monsters; monster effects are intentionally discarded at encounter end. |
| `shillelagh` | 0.0 | recorded_slice | slice available | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `stoneskin` | 4.0 | needs_audit | unavailable | druid, ranger, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `warding_bond` | 2.0 | needs_audit | unavailable | cleric, paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Conditions, control and forced movement

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `animal_friendship` | 1.0 | recorded_slice | slice available | bard, druid, ranger | Source-owned charm and party-damage break; transient monster/NPC effects are discarded at encounter end, so 24-hour world friendship is not implemented. |
| `antipathy_sympathy` | 8.0 | needs_audit | unavailable | bard, druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `bestow_curse` | 3.0 | needs_audit | unavailable | bard, cleric, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `blindness/deafness` | 2.0 | recorded_slice | slice available | bard, cleric, sorcerer, wizard | Available gameplay slice: the caster chooses Blinded or Deafened; a failed Constitution save applies the selected condition with a source-owned one-minute effect, and a successful Constitution save at the end of a target's turn ends only that target's effect. A level-3 live cast verifies two targets, captured save DC and one slot/Magic-action cost. Combat creatures and hex range are required; terrain visibility and the full clause audit remain open. |
| `calm_emotions` | 2.0 | needs_audit | unavailable | bard, cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `charm_monster` | 4.0 | recorded_slice | slice available | bard, druid, sorcerer, warlock, wizard | Production casting targets tracked combat creatures of any type. A failed Wisdom save applies a source-owned Charmed condition for up to one hour; the caster's monster target avoids the charmer, and damage from the player party ends the effect. The current SRD save Advantage clause is exercised for monster combat targets. General Friendly behavior and target awareness after expiry are not modeled; target sight, component inventory and full SRD clause audit remain open. |
| `charm_person` | 1.0 | recorded_slice | slice available | bard, druid, sorcerer, warlock, wizard | Production casting targets one or more tracked combat Humanoids. A failed Wisdom save applies a source-owned Charmed condition for up to one hour; the caster's monster target avoids the charmer, and damage from the player party ends the effect. The current SRD save Advantage clause is exercised for monster combat targets. General Friendly behavior and target awareness after expiry are not modeled; target sight, component inventory and full SRD clause audit remain open. |
| `color_spray` | 1.0 | recorded_slice | slice available | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `command` | 1.0 | recorded_slice | slice available | bard, cleric, paladin | No language/hazard interpretation; dropped items have no pickup flow. |
| `compelled_duel` | 1.0 | needs_audit | unavailable | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `compulsion` | 4.0 | needs_audit | unavailable | bard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `confusion` | 4.0 | needs_audit | unavailable | bard, druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `contagion` | 5.0 | needs_audit | unavailable | cleric, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `crown_of_madness` | 2.0 | needs_audit | unavailable | bard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `dissonant_whispers` | 1.0 | needs_audit | unavailable | bard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `dominate_beast` | 4.0 | needs_audit | unavailable | druid, ranger, sorcerer | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `dominate_monster` | 8.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `dominate_person` | 5.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `entangle` | 1.0 | recorded_slice | slice available | druid, ranger | Available gameplay slice: Entangle creates a concentration-linked 20-foot square (approximated by a radius-two hex area), adds Difficult Terrain, and applies source-keyed Restrained on failed initial Strength saves. Restrained creatures have Speed 0 and can spend an Action on Strength (Athletics) to escape; monsters make the escape check on their turn. Map edges clip the area to existing hexes; exact square geometry remains outside the slice. |
| `enthrall` | 2.0 | needs_audit | unavailable | bard, warlock | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `eyebite` | 6.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `fear` | 3.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `flesh_to_stone` | 6.0 | needs_audit | unavailable | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `friends` | 0.0 | needs_audit | unavailable | bard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `geas` | 5.0 | needs_audit | unavailable | bard, cleric, druid, paladin, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `grease` | 1.0 | recorded_slice | slice available | sorcerer, wizard | Combat applies Dexterity saves on creation, entry and turn end, prone on a failed save, and Difficult Terrain. Grease now transfers its footprint, save DC and remaining duration through room return and validated JSON room-state round-trip, then restores into an encounter while active. Local exploration applies Difficult Terrain and resolves entry/re-entry Dexterity saves, applying Prone on a failure; end-of-turn saves are not modeled there. Full square geometry and clause audit remain open. |
| `hold_monster` | 5.0 | recorded_slice | slice available | bard, sorcerer, warlock, wizard | Source-owned paralysis and repeated Wisdom saves; sight checks handle Invisible only, without terrain occlusion. |
| `hold_person` | 2.0 | recorded_slice | slice available | bard, cleric, druid, sorcerer, warlock, wizard | Humanoid-only source-owned paralysis and repeated Wisdom saves; sight checks handle Invisible only, without terrain occlusion. |
| `hypnotic_pattern` | 3.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `irresistible_dance` | 6.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `mass_suggestion` | 6.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `power_word_stun` | 8.0 | recorded_slice | slice available | bard, sorcerer, warlock, wizard | Available creature gameplay slice: targets at 150 HP or fewer are Stunned without an initial save and repeat Constitution saves at the end of their turns until they succeed; targets above 150 HP have Speed 0 until the caster's next turn. Cover/visibility beyond Invisible checks and full clause audit remain open. |
| `sleep` | 1.0 | recorded_slice | slice available | bard, sorcerer, wizard | Available gameplay slice: each chosen creature in the 5-foot Sphere makes a Wisdom save; a failed save imposes Incapacitated until the target's next turn, then a repeat save can impose Unconscious on a second failure. Damage or an adjacent party-controlled creature's action to shake ends the effect. Creature immunity and hex area handling use curated game data; monster AI does not choose the wake-up action, and terrain occlusion/full clause audit remain open. |
| `slow` | 3.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `stinking_cloud` | 3.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `suggestion` | 2.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `tashas_hideous_laughter` | 1.0 | needs_audit | unavailable | bard, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `telekinesis` | 5.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `thorn_whip` | 0.0 | needs_audit | unavailable | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `vicious_mockery` | 0.0 | recorded_slice | slice available | bard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `web` | 2.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Persistent areas, walls and triggered damage

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `antilife_shell` | 5.0 | existing_checks_need_audit | slice available | druid | Bounded combat slice: a one-minute, caster-centered 10-foot aura blocks affected player/monster crossing, blocks melee and opportunity attacks across the barrier, exempts the caster/Constructs/Undead, blocks the modeled push path, and ends if caster movement sweeps an affected creature across the boundary. Ranged and Reach attacks pass. Other forced-movement paths, room transfer, and a full clause audit remain open. |
| `antimagic_field` | 8.0 | needs_audit | unavailable | cleric, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `aura_of_vitality` | 3.0 | needs_audit | unavailable | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `black_tentacles` | 4.0 | recorded_slice | slice available | wizard | Available gameplay slice: Black Tentacles creates a 20-foot square (approximated by a radius-two hex area), adds Difficult Terrain, and applies source-owned Restrained on failed initial or repeated Strength saves. Entry and end-of-turn triggers allow one save per creature per turn; party creatures can spend an Action on Strength (Athletics) to escape and monsters attempt the check on their turn. Levels 5-6 last 8 hours without Concentration, levels 7-8 last 24 hours, and level 9 lasts until dispelled. These long-duration zones exist only in the current encounter, area geometry and terrain visibility are approximated, the material component is not enforced, and the full clause audit remains open. |
| `blade_barrier` | 6.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `call_lightning` | 3.0 | needs_audit | unavailable | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `cloud_of_daggers` | 2.0 | recorded_slice | slice available | bard, wizard | Gameplay implementation slice: casting damages creatures in the selected 5-foot hex; entering, ending a turn there, or teleporting the Cube over a creature can damage it once per turn. On later turns the caster can spend a Magic action to teleport the Cube up to 30 feet. The 5-foot Cube is approximated as one hex, vertical placement is unavailable, concentration removes the caster-owned zone, and the full clause audit and gameplay verification remain open. |
| `cloudkill` | 5.0 | recorded_slice | slice available | sorcerer, wizard | Gameplay implementation slice: the 20-foot-radius Sphere damages creatures when it appears, moves over them, when they enter, or when they end a turn inside; one Constitution save per creature per turn is shared by all triggers. It drifts 10 feet away from the caster at the start of later turns and ends with the caster's Concentration. The area is projected onto a flat hex map; Heavily Obscured vision and strong-wind dispersal are not enforced, and the full clause audit remains open. |
| `conjure_animals` | 3.0 | recorded_slice | slice available | druid, ranger | Gameplay implementation slice: the selected Large spectral pack lasts up to 10 minutes, damages creatures when it moves within 10 feet, when they enter that area, or end a turn there, and shares a once-per-turn Dexterity save cap. It can move up to 30 feet for free after the caster moves once per turn; the caster has Strength-save Advantage within 5 feet. Hexes approximate the Large pack and 10-foot boundary, and the combat map has no creature sight check; the full clause audit remains open. |
| `conjure_celestial` | 7.0 | recorded_slice | slice available | cleric | Gameplay implementation slice: a 10-foot-radius, 40-foot-high Bright Light cylinder lasts up to 10 minutes with Concentration. Visible creatures can receive Healing Light (4d12 + spellcasting modifier) or Searing Light (6d12 Radiant, Dexterity save for half); movement, entry and end-turn triggers share a once-per-turn target cap, and the caster can move the cylinder up to 30 feet after moving. The hex map flattens the cylinder, visibility is not modeled, and the full clause audit remains open. |
| `conjure_elemental` | 5.0 | recorded_slice | slice available | druid, wizard | Gameplay implementation slice: the caster chooses Air (Lightning), Earth (Thunder), Fire, or Water (Cold) and summons a Large intangible spirit in a clear space for up to 10 minutes with Concentration. When a creature enters its space or starts its turn within 5 feet while it has no creature Restrained, it makes a Dexterity save; failure deals 8d8 damage and applies source-owned Restrained. A Restrained target repeats the save at the start of its turns; failure deals 4d8 and success ends this spirit's Restrained effect. Under SRD 5.2.1, higher slots add 1d8 per level to both damage amounts. The Large space is approximated by seven hexes, creature visibility is not modeled, and the full clause audit remains open. |
| `conjure_fey` | 6.0 | recorded_slice | slice available | druid | Gameplay implementation slice: a Medium spirit lasts up to 10 minutes with Concentration, attacks when it appears and after a later-turn Bonus Action teleport up to 30 feet, and a hit deals Psychic damage plus the spellcasting modifier. Under SRD 5.2.1, higher slots add 1d12; a hit applies Frightened through the caster's next turn. Visible-space and line-of-sight checks are not modeled, the Medium spirit uses one hex, and the full clause audit remains open. |
| `conjure_minor_elementals` | 4.0 | recorded_slice | slice available | druid, wizard | Gameplay implementation slice: a 15-foot Emanation follows the caster for up to 10 minutes with Concentration. Each attack that hits a creature inside adds 2d8 Acid, Cold, Fire, or Lightning (chosen for that attack); higher slots add 1d8 per level above four. Enemy movement inside costs an extra 5 feet. The Emanation is projected as a three-hex radius, and the full clause audit remains open. |
| `conjure_woodland_beings` | 4.0 | recorded_slice | slice available | druid, ranger | Gameplay implementation slice: a 10-foot Emanation follows the caster for up to 10 minutes with Concentration. Entering its area, its movement over a creature, and ending a turn inside can trigger one Wisdom save per target per turn; the save deals 5d8 Force on failure or half on success, with +1d8 per slot above four. The caster can take Disengage as a Bonus Action. The Emanation is projected as two hexes, and creature visibility/choice plus the full clause audit remain open. |
| `control_water` | 4.0 | needs_audit | unavailable | cleric, druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `cordon_of_arrows` | 2.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `delayed_blast_fireball` | 7.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `earthquake` | 8.0 | needs_audit | unavailable | cleric, druid, sorcerer | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `flaming_sphere` | 2.0 | needs_audit | unavailable | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `forbiddance` | 6.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `glyph_of_warding` | 3.0 | needs_audit | unavailable | bard, cleric, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `guardian_of_faith` | 4.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `guards_and_wards` | 6.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `gust_of_wind` | 2.0 | needs_audit | unavailable | druid, ranger, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `hallow` | 5.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `hunger_of_hadar` | 3.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `incendiary_cloud` | 8.0 | needs_audit | unavailable | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `insect_plague` | 5.0 | needs_audit | unavailable | cleric, druid, sorcerer | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `magic_circle` | 3.0 | needs_audit | unavailable | cleric, paladin, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `moonbeam` | 2.0 | recorded_slice | slice available | druid | Available gameplay slice: Moonbeam resolves the initial Constitution save and half damage, then tracks a concentration-linked Cylinder that can be moved up to 60 feet with a later-turn Magic action. The area moving over a creature, a creature entering it, and ending a turn inside it can trigger damage, once per combat turn; damage scales above a level-2 slot. Failed saves revert Wild Shape and prevent re-shaping until the target leaves the Cylinder. The 5-foot radius is approximated by a seven-hex area; vertical height and Dim Light rendering are not modeled. |
| `plant_growth` | 3.0 | recorded_slice | slice available | bard, druid, ranger | Available gameplay slice: the action-cast Overgrowth mode applies a 4x movement cost in a 100-foot Sphere and combines by the strongest terrain cost without stacking with Difficult Terrain. Overgrowth is instantaneous and remains in the encounter after rounds advance. The combat map assumes normal plants everywhere, clips the area to existing hexes, and does not model excluded subareas or Enrichment's 8-hour casting and 365-day harvest benefit; combat-scene destruction discards the area. |
| `prismatic_wall` | 9.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `sleet_storm` | 3.0 | recorded_slice | slice available | druid, sorcerer, wizard | Available gameplay slice: a 20-foot-radius, 40-foot-high Cylinder creates a Difficult Terrain zone. Creatures make one Dexterity save per turn on first entry or at turn start; failed saves cause Prone and end that creature's Concentration. The zone lasts 1 minute, or 2 minutes with Extended Spell, and ends with the caster's Concentration. The current hex projection is a 20-foot-radius ground disk; obscured vision, flame extinguishing, vertical targeting, monster spell Concentration and terrain visibility are not enforced, and the full clause audit remains open. |
| `spike_growth` | 2.0 | recorded_slice | slice available | druid, ranger | Available gameplay slice: Spike Growth creates a concentration-linked, source-keyed 20-foot Sphere that adds Difficult Terrain and deals 2d4 Piercing damage for each five-foot hex a creature travels inside it. The live movement flow verifies teleport landings do not count as travel and ending concentration removes the zone. Map edges clip areas to existing hexes; camouflage recognition and some non-path forced movement remain outside the slice. |
| `spirit_guardians` | 3.0 | recorded_slice | slice available | cleric | Gameplay implementation slice: a 15-foot Emanation follows the caster for up to 10 minutes with Concentration. The caster designates combat creatures unaffected; other creatures take Radiant or Necrotic damage on a failed Wisdom save, half on a success, when they enter or end their turn in the Emanation, or when it moves onto them. A target saves once per turn; slots above three add 1d8. In-area movement costs twice as much for affected player and monster movement. Character alignment is not stored, so the caster chooses the alignment damage at cast time; vision outside the combat-creature list and the full clause audit remain open. |
| `storm_of_vengeance` | 9.0 | needs_audit | unavailable | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `sunbeam` | 6.0 | needs_audit | unavailable | cleric, druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `symbol` | 7.0 | needs_audit | unavailable | bard, cleric, druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `tsunami` | 8.0 | needs_audit | unavailable | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `wall_of_fire` | 4.0 | needs_audit | slice available | druid, sorcerer, wizard | Bounded gameplay slice verified 2026-10-08: the production record selects two in-range endpoints up to 60 feet apart and resolves initial Dexterity-save damage. Its slot-scaled zone and saved Concentration owner survive combat-to-room transfer and character/room reload. First entry into the wall and ending a turn in its danger footprint deal full Fire damage with separate trigger ledgers and no further save. The danger side is one adjacent five-foot caster-facing strip. Choosing either side, the full ten-foot strip, ring form, opaque wall, exact 20-foot height, 1-foot thickness, vertical targeting and non-hex geometry remain open. Material component ownership and a full clause audit remain open. |
| `wall_of_force` | 5.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `wall_of_ice` | 6.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `wall_of_stone` | 5.0 | needs_audit | unavailable | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `wall_of_thorns` | 6.0 | needs_audit | unavailable | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `wind_wall` | 3.0 | needs_audit | unavailable | druid, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Summons, companions and created combat entities

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `animate_dead` | 3.0 | recorded_slice | slice available | cleric, wizard | Verified bounded Crown room slice: one-minute level-3 casting on recorded Humanoid remains, Gentle Repose refusal, lasting Skeleton/Zombie identity/HP, Bonus-action attack/Dodge orders, independent initiative, 24-hour control expiry to a hostile actor, up-to-four renewal before expiry and entrance disk reload. Higher-slot multi-body casting, arbitrary orders/default hazard avoidance, durable creature conditions/equipment, overworld encounters and long-cast interruption remain open. See docs/mechanics/animate-dead-2024.md; full rules completeness remains uncertified. |
| `animate_objects` | 5.0 | blocked | unavailable | bard, sorcerer, wizard | Unavailable: the game has no targetable nonmagical object ownership, worn/carried/fixed state, size-cost selection, animated-object ally turn, Bonus Action command/Dodge behavior, or reversion and damage carryover. Cast remains refused before costs. |
| `arcane_hand` | 5.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `arcane_sword` | 7.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `awaken` | 5.0 | needs_audit | unavailable | bard, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `create_undead` | 6.0 | needs_audit | unavailable | cleric, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `faithful_hound` | 4.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `find_familiar` | 1.0 | recorded_slice | slice available | wizard | Verified bounded slice: four curated forms, hour/ritual room casting with consumed incense, form/type replacement, distinct ordinary/Wild Companion lifetime, pocket controls, borrowed combat sight, supported Touch delivery and authored skill Help; safe disk reload and next encounter verified. Other forms, equipment/conditions, special jumping/ceiling/web clauses, local scouting/audio and long-cast interruption remain open. See docs/mechanics/find-familiar-2024.md; full rules completeness remains uncertified. |
| `find_steed` | 2.0 | existing_checks_need_audit | slice available | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `giant_insect` | 4.0 | needs_audit | unavailable | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `phantom_steed` | 3.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `planar_ally` | 6.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `planar_binding` | 5.0 | needs_audit | unavailable | bard, cleric, druid, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `simulacrum` | 7.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `spiritual_weapon` | 2.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `summon_dragon` | 5.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `unseen_servant` | 1.0 | needs_audit | unavailable | bard, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Light, visibility and detection

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `arcane_eye` | 4.0 | blocked | unavailable | wizard | Behavior audit: no sensor/vision payload or dedicated production handler. |
| `beast_sense` | 2.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `clairvoyance` | 3.0 | needs_audit | unavailable | bard, cleric, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `continual_flame` | 2.0 | needs_audit | unavailable | cleric, druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `dancing_lights` | 0.0 | recorded_slice | slice available | bard, sorcerer, wizard | Visual combat markers; no illumination/stealth/visibility effects. |
| `darkness` | 2.0 | recorded_slice | slice available | sorcerer, warlock, wizard | Production casting creates a source-owned 15-foot-radius magical Darkness Sphere for up to 10 minutes with Concentration. It obscures creatures in the area for combat attack modifiers and dispels overlapping modeled Light, Produce Flame and Dancing Lights effects. Hex footprints approximate Sphere geometry; object targeting/covering, Darkvision-specific environmental sight, terrain occlusion, visuals and full clause audit remain open. |
| `darkvision` | 2.0 | recorded_slice | slice available | druid, ranger, sorcerer, wizard | Production casting grants a source-owned Darkvision condition to a touched party creature for eight hours, and active effects extend its exploration visibility to 150 feet. Focused/live checks cover exact expiry. The game does not distinguish ambient bright/dim/dark lighting, model sensing in darkness during combat or advance spell time while outside combat; material component enforcement and full clause audit remain open. |
| `daylight` | 3.0 | needs_audit | unavailable | cleric, druid, paladin, ranger, sorcerer | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `detect_evil_and_good` | 1.0 | recorded_slice | slice available | cleric, paladin | Live combat maintains a 30-foot sense for tracked Aberrations, Celestials, Elementals, Fey, Fiends, and Undead, plus modeled Hallow zones, for up to 10 minutes with Concentration. Creature type and location update as tracked entities move. Material barriers and untracked creatures or Hallow areas are not represented; full clause audit remains open. |
| `detect_magic` | 1.0 | recorded_slice | slice available | bard, cleric, druid, paladin, ranger, sorcerer, warlock, wizard | The live slice senses tracked creature spell effects and positioned spell areas within 30 feet, then spends a separate Magic action to reveal their schools. There is no terrain sight/material barrier model, and unattached objects or magic-item auras are not represented. Full clause audit remains open. |
| `detect_poison_and_disease` | 1.0 | recorded_slice | slice available | cleric, druid, paladin, ranger | Live combat reports tracked Poisoned conditions and poisonous or venomous monsters identified from their poison-damage attacks or poison effects within 30 feet, updating their locations during movement; the effect lasts up to 10 minutes with Concentration and is ritual-eligible. Loose poison sources, disease state, magical contagions, material barriers and yew-leaf inventory enforcement are not modeled. The full clause audit remains open. |
| `faerie_fire` | 1.0 | recorded_slice | slice available | bard, druid | Production casting selects a directed 20-foot Cube, applies source-owned outlines to creatures that fail Dexterity saves, suppresses Invisible benefits, and gives attackers Advantage when resolving attacks against affected targets. Concentration ending clears effects. Combat creatures only; hex grid approximates square geometry, objects and emitted light are not rendered, true sight occlusion and material inventory are not modeled, and full clause audit remains open. |
| `find_traps` | 2.0 | needs_audit | unavailable | cleric, druid, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `fog_cloud` | 1.0 | recorded_slice | slice available | druid, ranger, sorcerer, wizard | Production casting creates a source-owned Heavily Obscured Sphere for one hour; each slot level above 1 increases its radius by 20 feet. Entering or leaving updates obscured combatants, weapon/spell attacks apply the SRD Advantage and Disadvantage cancellation, and ending Concentration removes the zone. Hex footprints approximate Sphere geometry; true line-of-sight targeting, strong-wind dispersal, visual rendering and full clause audit remain open. |
| `greater_invisibility` | 4.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `invisibility` | 2.0 | recorded_slice | slice available | bard, sorcerer, warlock, wizard | Production casting applies a source-owned Invisible effect to selected combat creatures for up to one hour; higher slots add one target each. Attacks against Invisible targets have Disadvantage, and an Invisible attacker has Advantage, then loses the effect after its attack roll. Dealing damage or casting another spell also ends the affected target's effect; ending Concentration clears remaining targets. This slice covers tracked combat entities and uses the current combat visibility rules; gear invisibility, material component inventory, true terrain occlusion and a full SRD clause audit remain open. |
| `light` | 0.0 | recorded_slice | slice available | bard, cleric, sorcerer, wizard | Caster-hex object stand-in; no hostile object save, coverings or real visibility. |
| `locate_animals_or_plants` | 2.0 | needs_audit | unavailable | bard, druid, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `locate_creature` | 4.0 | needs_audit | unavailable | bard, cleric, druid, paladin, ranger, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `locate_object` | 2.0 | needs_audit | unavailable | bard, cleric, druid, paladin, ranger, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `mislead` | 5.0 | needs_audit | unavailable | bard, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `nondetection` | 3.0 | needs_audit | unavailable | bard, ranger, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `pass_without_trace` | 2.0 | needs_audit | unavailable | druid, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `produce_flame` | 0.0 | recorded_slice | slice available | druid | Held/hurled flame and marker; no illumination/visibility effects. |
| `scrying` | 5.0 | needs_audit | unavailable | bard, cleric, druid, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `see_invisibility` | 2.0 | recorded_slice | slice available | bard, sorcerer, wizard | Production casting grants the caster a source-owned one-hour sense that allows perception of Invisible creatures at any modeled combat distance, removing the Invisible target's attack Disadvantage against them. Invisible objects and Ethereal Plane awareness/appearance are not modeled; terrain sight, material components and the full clause audit remain open. |
| `true_seeing` | 6.0 | recorded_slice | slice available | bard, cleric, sorcerer, warlock, wizard | Production casting grants a selected party creature source-owned Truesight perception of Invisible targets within 120 feet for one hour. The 25+ GP mushroom powder is required and consumed before slot/action costs. Darkness, visual illusions, magically transformed forms, Ethereal Plane entities and object sight are not represented by combat state; terrain line of sight and full clause audit remain open. |

### Objects, inventory and environmental changes

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `alarm` | 1.0 | needs_audit | slice available | ranger, wizard | Unavailable: the game has no persistent door/window/area ward target, creature entry/touch trigger, exclusion list, or audible/mental alert delivery. Its 30-foot range, minute casting time, ritual option, components and 8-hour duration are recorded, but no effect can be applied to the current world model. |
| `arcane_lock` | 2.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `create_food_and_water` | 3.0 | needs_audit | unavailable | cleric, paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `create_or_destroy_water` | 1.0 | needs_audit | slice available | cleric, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `creation` | 5.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `druidcraft` | 0.0 | needs_audit | unavailable | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `elementalism` | 0.0 | needs_audit | unavailable | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `fabricate` | 4.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `goodberry` | 1.0 | recorded_slice | slice available | druid, ranger | Live combat creates a saved pool of ten Goodberries that expire after 24 hours. A party member can take a Bonus Action to eat one and regain 1 Hit Point; the earliest-expiring berry is spent first. Nourishment and berry transfer are not modeled, and ordinary nonpriced Material-component ownership (mistletoe) is not enforced by the shared inventory rules. The full clause audit remains open. |
| `heat_metal` | 2.0 | needs_audit | unavailable | bard, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `identify` | 1.0 | recorded_slice | slice available | bard, wizard | Live combat spends a minute maintaining contact with a carried item or adjacent living creature, then reports the item's catalog description/structured properties or tracked ongoing spells on the creature. The pearl is nonconsumed. Item data has no general structured attunement, charge, ongoing-spell or spell-creator fields; item catalog text is included. Ritual casting is recorded but not offered in the current combat flow. Losing contact or Concentration interrupts the cast. The full clause audit remains open. |
| `illusory_script` | 1.0 | needs_audit | unavailable | bard, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `instant_summons` | 6.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `knock` | 2.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `mage_hand` | 0.0 | recorded_slice | slice available | bard, sorcerer, warlock, wizard | Marker movement/dismissal; no carrying, doors, containers or loose objects. |
| `magic_mouth` | 2.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `mending` | 0.0 | blocked | unavailable | bard, cleric, druid, sorcerer, wizard | No damaged-object state; explicitly unavailable before costs. |
| `move_earth` | 6.0 | needs_audit | unavailable | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `nystuls_magic_aura` | 2.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `passwall` | 5.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `prestidigitation` | 0.0 | recorded_slice | slice available | bard, sorcerer, warlock, wizard | Cosmetic marks/images; no fire, cleaning, temperature or inventory interaction. |
| `purify_food_and_drink` | 1.0 | needs_audit | slice available | cleric, druid, paladin | No food/drink contamination target state; explicitly refused before costs. |
| `secret_chest` | 4.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `stone_shape` | 4.0 | needs_audit | unavailable | cleric, druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `tensers_floating_disk` | 1.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `thaumaturgy` | 0.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Dialogue, illusions and belief

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `disguise_self` | 1.0 | blocked | unavailable | bard, sorcerer, wizard | Behavior audit: no appearance/disguise payload or dedicated production handler. |
| `dream` | 5.0 | needs_audit | unavailable | bard, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `hallucinatory_terrain` | 4.0 | needs_audit | unavailable | bard, druid, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `major_image` | 3.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `minor_illusion` | 0.0 | recorded_slice | slice available | bard, sorcerer, warlock, wizard | Sound/image marker; no audio, investigation or physical-interaction outcome. |
| `mirage_arcane` | 7.0 | needs_audit | unavailable | bard, druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `modify_memory` | 5.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `phantasmal_force` | 2.0 | needs_audit | unavailable | bard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `phantasmal_killer` | 4.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `programmed_illusion` | 6.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `project_image` | 7.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `seeming` | 5.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `silent_image` | 1.0 | blocked | unavailable | bard, sorcerer, wizard | Behavior audit: no image/illusion payload or dedicated production handler. |
| `speak_with_animals` | 1.0 | needs_audit | unavailable | bard, druid, ranger, warlock | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `speak_with_dead` | 3.0 | blocked | unavailable | bard, cleric, wizard | Behavior audit: no corpse dialogue payload or dedicated production handler. |
| `speak_with_plants` | 3.0 | needs_audit | unavailable | bard, druid, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `weird` | 9.0 | needs_audit | unavailable | warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `zone_of_truth` | 2.0 | needs_audit | unavailable | bard, cleric, paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Campaign information and communication

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `animal_messenger` | 2.0 | recorded_slice | slice available | bard, druid, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `augury` | 2.0 | needs_audit | unavailable | cleric, druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `commune` | 5.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `commune_with_nature` | 5.0 | needs_audit | unavailable | druid, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `comprehend_languages` | 1.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `contact_other_plane` | 5.0 | blocked | unavailable | warlock, wizard | Unavailable: the spell can prompt for or resolve the save, but does not let the caster ask up to five questions or receive answers. Question-limit metadata is recorded; casting is refused before costs until the question and answer flow exists. |
| `detect_thoughts` | 2.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `divination` | 4.0 | needs_audit | unavailable | cleric, druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `find_the_path` | 6.0 | needs_audit | unavailable | bard, cleric, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `legend_lore` | 5.0 | needs_audit | unavailable | bard, cleric, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `message` | 0.0 | recorded_slice | slice available | bard, druid, sorcerer, wizard | Party-only temporary whisper/reply; no NPC dialogue or barrier rules. |
| `sending` | 3.0 | needs_audit | unavailable | bard, cleric, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `telepathic_bond` | 5.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `tongues` | 3.0 | needs_audit | unavailable | bard, cleric, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Movement, terrain, travel and other spaces

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `astral_projection` | 9.0 | needs_audit | unavailable | cleric, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `banishment` | 4.0 | needs_audit | unavailable | cleric, paladin, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `blink` | 3.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `demiplane` | 8.0 | needs_audit | unavailable | sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `dimension_door` | 4.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `etherealness` | 7.0 | needs_audit | unavailable | bard, cleric, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `feather_fall` | 1.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `fly` | 3.0 | needs_audit | slice available | sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `freedom_of_movement` | 4.0 | existing_checks_need_audit | slice available | bard, cleric, druid, ranger | Bounded movement slice: a production cast grants the target a Swim Speed equal to its Speed and ignores modeled Difficult Terrain in combat and local-room movement for one hour. Characters with the spell also resist spell-sourced Paralyzed and Restrained conditions. Other magical Speed reductions, escape from nonmagical restraints, non-Character targets, and a full clause audit remain open. |
| `gaseous_form` | 3.0 | needs_audit | unavailable | sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `gate` | 9.0 | needs_audit | unavailable | cleric, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `jump` | 1.0 | recorded_slice | slice available | druid, ranger, sorcerer, wizard | Production picker and level-2 two-target cast are verified. Once per turn, a character can leap up to six horizontal hexes for two movement points when walking cannot reach the landing; intermediate impassable hexes can be crossed and opportunity attacks still resolve. The map has no elevation, and there is no explicit option to spend the leap when walking is already sufficient. Material component inventory enforcement remains open. |
| `leomunds_tiny_hut` | 3.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `levitate` | 2.0 | needs_audit | slice available | sorcerer, wizard | Behavior audit: no levitation/movement payload or dedicated production handler. |
| `magnificent_mansion` | 7.0 | needs_audit | unavailable | bard, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `maze` | 8.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `meld_into_stone` | 3.0 | needs_audit | unavailable | cleric, druid, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `misty_step` | 2.0 | existing_checks_need_audit | slice available | ranger, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `plane_shift` | 7.0 | needs_audit | unavailable | cleric, druid, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `private_sanctum` | 4.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `reverse_gravity` | 7.0 | needs_audit | unavailable | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `rope_trick` | 2.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `spider_climb` | 2.0 | needs_audit | slice available | sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `teleport` | 7.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `teleportation_circle` | 5.0 | needs_audit | unavailable | bard, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `transport_via_plants` | 6.0 | needs_audit | unavailable | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `tree_stride` | 5.0 | needs_audit | unavailable | druid, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `water_breathing` | 3.0 | needs_audit | unavailable | druid, ranger, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `water_walk` | 3.0 | needs_audit | slice available | cleric, druid, ranger, sorcerer | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `wind_walk` | 6.0 | needs_audit | unavailable | druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `word_of_recall` | 6.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Death, bodies and transformations

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `alter_self` | 2.0 | recorded_slice | slice available | sorcerer, wizard | Production picker casts the Natural Weapons option with selected Slashing, Piercing or Bludgeoning damage. Unarmed Strikes use 1d6 plus the caster's spellcasting modifier and the source-owned option expires when concentration ends or after one hour. Aquatic Adaptation, Change Appearance and changing the option during the spell are not modeled; material inventory and full clause audit remain open. |
| `animal_shapes` | 8.0 | blocked | unavailable | druid | Unavailable: no spell-grade creature transformation supports any willing target, Beast stat replacement, chosen Beast forms up to CR 4, form-HP temporary hit points, duration, and later Magic-action form changes. Existing Wild Shape only supports a Druid's learned forms and spends a class resource, so it is not used as a substitute. The spell is refused before costs. |
| `clone` | 8.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `feign_death` | 3.0 | needs_audit | unavailable | bard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `gentle_repose` | 2.0 | recorded_slice | slice available | cleric, paladin, wizard | Verified bounded party preservation: original corpse time/identity, consumed two-coin packet, ten-day saved interval, accumulated protected time, recast/expiry eligibility and safe checkpoint continuity. Normal room ritual after reload is verified: 606 seconds, consumed component, no slot. Cast interruptions remain open. Undeath protection exposes a shared check; created-undead integration and automatic decay remain open. |
| `imprisonment` | 9.0 | needs_audit | unavailable | warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `magic_jar` | 6.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `polymorph` | 4.0 | needs_audit | unavailable | bard, druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `raise_dead` | 5.0 | needs_audit | unavailable | bard, cleric, paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `reincarnate` | 5.0 | blocked | unavailable | druid | No corpse/death-time, consumed oils or safe species replacement; explicitly refused before costs. |
| `resurrection` | 7.0 | needs_audit | unavailable | bard, cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `revivify` | 3.0 | recorded_slice | slice available | cleric, druid, paladin, ranger | Verified bounded party recovery: recorded recent death, spirit willingness and remains restrictions, one original Character restored with 1 HP, one diamond/slot/action, and safe corpse checkpoint continuity. Old unknown death times and expired/ineligible bodies refuse before cost. Arbitrary world/NPC corpses, full injury consequences and complete general death/spell audit remain open. |
| `sequester` | 7.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `shapechange` | 9.0 | needs_audit | unavailable | druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `true_polymorph` | 9.0 | needs_audit | unavailable | bard, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `true_resurrection` | 9.0 | needs_audit | unavailable | cleric, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Wards, dispelling and restoring state

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `counterspell` | 3.0 | recorded_slice | slice available | sorcerer, warlock, wizard | Available gameplay slice: visible eligible V/S/M spell casts within 60 feet prompt a party Counterspell user with a Reaction and a level-3+ slot or free cast. The caster makes a Constitution save against the counterspeller's DC; a failure dissipates the spell and refunds its spell slot, while the counterspell's resource and Reaction remain spent. Blinded and Invisible checks apply, but terrain occlusion and enemy Counterspell reactions are not modeled; full clause audit remains open. |
| `dispel_evil_and_good` | 5.0 | needs_audit | unavailable | cleric, paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `dispel_magic` | 3.0 | needs_audit | unavailable | bard, cleric, druid, paladin, ranger, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `globe_of_invulnerability` | 6.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `greater_restoration` | 5.0 | needs_audit | unavailable | bard, cleric, druid, paladin, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `lesser_restoration` | 2.0 | needs_audit | unavailable | bard, cleric, druid, paladin, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `remove_curse` | 3.0 | recorded_slice | slice available | cleric, paladin, warlock, wizard | Clears one modeled condition; no curse sources or item attunement. |
| `resilient_sphere` | 4.0 | recorded_slice | slice available | cleric, paladin, wizard | No globe carrying/rolling or object targets; party willingness assumed. |
| `silence` | 2.0 | needs_audit | unavailable | bard, cleric, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Weapon-triggered and repeated attacks

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `blinding_smite` | 3.0 | needs_audit | unavailable | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `branding_smite` | 2.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `divine_smite` | 1.0 | existing_checks_need_audit | slice available | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `dragons_breath` | 2.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `ensnaring_strike` | 1.0 | needs_audit | unavailable | ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `flame_blade` | 2.0 | needs_audit | unavailable | druid, sorcerer | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `hail_of_thorns` | 1.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `lightning_arrow` | 3.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `searing_smite` | 1.0 | needs_audit | unavailable | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `shining_smite` | 2.0 | needs_audit | unavailable | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `thunderous_smite` | 1.0 | needs_audit | unavailable | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `true_strike` | 0.0 | recorded_slice | slice available | bard, sorcerer, warlock, wizard | Available gameplay slice: uses a proficient equipped weapon, spellcasting ability for its attack and damage, and the level 5/11/17 Radiant dice. The caster chooses weapon or Radiant damage type; shared attack reactions and eligible weapon riders apply. Weapon range comes from game equipment data; targets must be combat creatures, monster AI reactions and the full clause audit remain open. |
| `vampiric_touch` | 3.0 | needs_audit | unavailable | sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `witch_bolt` | 1.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `wrathful_smite` | 1.0 | needs_audit | unavailable | paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Exceptional world or action rules

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `befuddlement` | 8.0 | needs_audit | unavailable | bard, druid, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `contingency` | 6.0 | needs_audit | unavailable | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `control_weather` | 8.0 | needs_audit | unavailable | cleric, druid, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `forcecage` | 7.0 | needs_audit | unavailable | bard, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `time_stop` | 9.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `wish` | 9.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

### Immediate attacks, saves, healing and area selection

| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |
|---|---:|---|---|---|---|
| `acid_splash` | 0.0 | recorded_slice | slice available | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `arms_of_hadar` | 1.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `blight` | 4.0 | recorded_slice | slice available | druid, sorcerer, warlock, wizard | Creature behavior; nonmagical plant objects absent. |
| `burning_hands` | 1.0 | recorded_slice | slice available | sorcerer, wizard | Available creature gameplay slice: the self-originating 15-foot Cone resolves Dexterity saves, Fire damage, half damage on a save, and +1d6 damage per slot. Ignition of flammable unattended objects, cover/visibility and full clause audit remain open. |
| `chain_lightning` | 6.0 | existing_checks_need_audit | slice available | sorcerer, wizard | Available bounded combat path: select a visible first creature or object within 150 feet, then distinct secondary targets within 30 feet of that first target; level 7 allows five total targets. Exact identities distinguish creatures, authored room objects, and carried or dropped copies. Unscored objects fail Dexterity saves and damage settles against object HP. Secondary-effect previews, additional target combinations, non-hex geometry, cover and full clause audit remain open. |
| `chill_touch` | 0.0 | recorded_slice | slice available | sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `chromatic_orb` | 1.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `circle_of_death` | 6.0 | recorded_slice | slice available | sorcerer, warlock, wizard | Available creature gameplay slice: the 60-foot Sphere applies Constitution saves, Necrotic damage, half damage on a save, a 2d8-per-slot upcast and requires the carried 500 GP black-pearl powder without consuming it. Object effects, cover/visibility and full clause audit remain open. |
| `cone_of_cold` | 5.0 | recorded_slice | slice available | druid, sorcerer, wizard | Available creature gameplay slice: the self-originating 60-foot Cone resolves Constitution saves, Cold damage, half damage on a save, and +1d8 damage per slot. Cover/visibility and full clause audit remain open. |
| `conjure_barrage` | 3.0 | needs_audit | unavailable | outside core lists | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `cure_wounds` | 1.0 | recorded_slice | slice available | bard, cleric, druid, paladin, ranger | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `disintegrate` | 6.0 | recorded_slice | slice available | sorcerer, wizard | Creature damage and healing block; no general object/force-object or restoration modes. |
| `divine_word` | 7.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `eldritch_blast` | 0.0 | recorded_slice | slice available | warlock | Available gameplay slice: beams scale to 2/3/4 at character levels 5/11/17, each has an independent attack roll, and the player may assign each beam to a creature. Agonizing Blast damage applies per hit. Shield can be used when a beam hits and its AC applies to later beams. Visibility/line of sight and the full clause audit remain open. |
| `finger_of_death` | 7.0 | blocked | unavailable | sorcerer, warlock, wizard | Unavailable: the resolver applies damage but cannot create and own the Zombie that appears when this spell kills a Humanoid. The SRD Zombie outcome is recorded; casting is refused before costs until created creatures and their orders are supported. |
| `fire_bolt` | 0.0 | recorded_slice | slice available | sorcerer, warlock, wizard | 120-foot range (24 five-foot hexes) is corrected. Object ignition, line of sight and full clause audit remain open. |
| `fire_storm` | 7.0 | needs_audit | unavailable | cleric, druid, sorcerer | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `fireball` | 3.0 | existing_checks_need_audit | slice available | sorcerer, wizard | Uses a 150-foot target range and a 20-foot sphere (30 and 4 five-foot hexes). Creature cover, flammable-object ignition, and full clause audit remain open. |
| `flame_strike` | 5.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `freezing_sphere` | 6.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `guiding_bolt` | 1.0 | recorded_slice | slice available | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `harm` | 6.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `heal` | 6.0 | recorded_slice | slice available | cleric, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `healing_word` | 1.0 | recorded_slice | slice available | bard, cleric, druid | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `hellish_rebuke` | 1.0 | needs_audit | unavailable | warlock | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `ice_knife` | 1.0 | recorded_slice | slice available | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `ice_storm` | 4.0 | needs_audit | unavailable | druid, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `inflict_wounds` | 1.0 | recorded_slice | slice available | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `lightning_bolt` | 3.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `magic_missile` | 1.0 | existing_checks_need_audit | slice available | sorcerer, warlock, wizard | The player assigns each base or upcast dart to a creature, including repeat targets; per-target damage is aggregated once. An active or accepted Shield prevents the darts. Visibility/line-of-sight and full SRD audit remain open. |
| `mass_cure_wounds` | 5.0 | recorded_slice | slice available | bard, cleric, druid | Available gameplay slice: selects a point within 60 feet, then allows up to six chosen creatures in the 30-foot-radius Sphere to regain 5d8 plus the spellcasting modifier, with +1d8 per slot level above five. The hex Sphere approximates table geometry; targets must be combat creatures and the full clause audit remains open. |
| `mass_heal` | 9.0 | needs_audit | unavailable | cleric | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `mass_healing_word` | 3.0 | recorded_slice | slice available | bard, cleric | Available gameplay slice: lets the caster choose up to six visible creatures within 60 feet; each regains 2d4 plus the spellcasting modifier, with +1d4 per slot level above three. Character and monster healing use the shared combat effect path; targets must be creatures present in combat and the full clause audit remains open. |
| `melfs_acid_arrow` | 2.0 | recorded_slice | slice available | wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `meteor_swarm` | 9.0 | existing_checks_need_audit | slice available | sorcerer, wizard | Four distinct visible 40-foot Sphere centers select correctly, overlap hexes deduplicate, and each creature makes one Dexterity save whose Fire/Bludgeoning packets settle separately. Authored unattended room objects take separately mitigated damage and flammable objects gain a saved burning flag. Dropped combat gear and other object records are not enumerated, so casting remains gated before costs. |
| `mind_spike` | 2.0 | needs_audit | unavailable | warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `poison_spray` | 0.0 | recorded_slice | slice available | druid, sorcerer, warlock, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `power_word_heal` | 9.0 | recorded_slice | slice available | bard, cleric | Bard live acceptance verifies two chosen creatures, a downed ally, full HP recovery, optional Reaction standing and one slot/action cost. Dead/disintegrated party targets are refused; sight handles Invisible only, without terrain occlusion. Full clause audit remains open. |
| `power_word_kill` | 9.0 | recorded_slice | slice available | bard, sorcerer, warlock, wizard | Bard live acceptance verifies two chosen creatures at the HP threshold and one slot/action cost; focused checks verify outright party death, bypassing death saves. Above-threshold damage uses the existing resolver. Full clause/visibility audit remains open. |
| `prayer_of_healing` | 2.0 | needs_audit | unavailable | cleric, paladin | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `prismatic_spray` | 7.0 | needs_audit | unavailable | bard, sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `ray_of_frost` | 0.0 | recorded_slice | slice available | sorcerer, wizard | 60-foot range (12 five-foot hexes) is corrected. Visibility and full clause audit remain open. |
| `sacred_flame` | 0.0 | recorded_slice | slice available | cleric | No cover model to exercise the cover exception. |
| `scorching_ray` | 2.0 | existing_checks_need_audit | slice available | sorcerer, wizard | The player assigns each base or upcast ray to a creature, including repeat targets; per-target attacks are resolved separately. Shield can be used when a ray hits and its AC applies to later rays. The full clause audit remains open. |
| `shatter` | 2.0 | existing_checks_need_audit | slice available | bard, sorcerer, wizard | Available creature gameplay slice: a 10-foot Sphere applies Constitution saves, Thunder damage, half damage on a save, Construct save Disadvantage, and the SRD's 1d8-per-slot upcast. Nonmagical unattended objects are not modeled as damageable combat targets; visibility/line of sight and the full clause audit remain open. |
| `shocking_grasp` | 0.0 | recorded_slice | slice available | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `sorcerous_burst` | 0.0 | recorded_slice | slice available | sorcerer | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |
| `spare_the_dying` | 0.0 | recorded_slice | slice available | cleric, druid | Stabilizes a downed party character, persists the Stable state, and resumes death saves with one failure if damaged; range scales to 30/60/120 feet at levels 5/11/17. The game does not track the SRD's 1d4-hour recovery to 1 Hit Point or stable non-party creatures. |
| `starry_wisp` | 0.0 | recorded_slice | slice available | bard, druid | 60-foot range corrected. Creature hits suppress Invisible benefits; object targeting, dim-light presentation and line-of-sight occlusion remain outside the current combat model. |
| `sunburst` | 8.0 | recorded_slice | slice available | cleric, druid, sorcerer, wizard | Live combat resolves its 60-foot Sphere, radiant damage with Constitution save for half, source-owned Blinded for one minute on a failed save, and end-of-turn Constitution saves that end only that cast's condition. It removes overlapping magical Darkness and preserves zones outside the Sphere. The hex map approximates Sphere geometry; cover, material-component inventory and the full clause audit remain open. |
| `thunderwave` | 1.0 | recorded_slice | slice available | bard, druid, sorcerer, wizard | Available creature gameplay slice: the 15-foot Cube points away from the caster, failed Constitution saves take Thunder damage and are pushed 10 feet, successful saves take half damage only, and upcasting adds 1d8 per slot. Hex-grid cube geometry approximates a three-by-three footprint. Unsecured object movement and the 300-foot audible boom are not modeled; full clause audit remains open. |
| `vitriolic_sphere` | 4.0 | needs_audit | unavailable | sorcerer, wizard | Full per-spell rules audit remains open; do not infer completeness from fields or check totals. |

## Updating the register

Export the initialized production DataLoader by running `res://scenes/spell_inventory_export.tscn` through `scripts/invoke_godot_case.ps1` in Scene mode (the direct `--script` exporter crashes on this Godot 4.7 Windows build). Then run `python scripts/generate_spell_status.py --runtime .artifacts/spell-status/runtime.json`. Update reviewed evidence/limitations in that generator when a slice ships, and regenerate `docs/feature_matrix.md` with its existing generator. Keep runtime exports and logs in ignored `.artifacts/`. Reconciliation never enables a spell or replaces a Godot gameplay check.
