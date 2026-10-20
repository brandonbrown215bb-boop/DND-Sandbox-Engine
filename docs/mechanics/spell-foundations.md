# Spell dependency foundations

These are supported world behaviors and remaining integration requirements,
organized by their original foundation families. The [roadmap](../../roadmap.md)
selects work; the old wave/card sequence does not. Rules authority remains
[SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf).
A bounded foundation doesn't certify every spell or every mode that uses it.

## Wave 1 — Local spaces, objects, inventory and time

| Card | Playable foundation and completion boundary | Separate spell integrations |
|---|---|---|
| W1-F1 Local spaces | One authored five-foot hex room, individual party positions, walls, exits, door, chest and loose objects. Exploration and combat share cells and object identities. Combat return retains changes. Generated dungeon layout and claimed rewards survive exit, checkpoint save and revisit. | Replace caster-position stand-ins with legal creature/object targets. |
| W1-F2 Objects | Inspect/open/close, ordinary locks, matching keys and tool checks; pick up/place/transfer loose copies and container contents. Record material, size, weight, attachment, damage and contents. | Arcane Lock, Knock, Mage Hand, Mending: ownership, exemptions, suppression/expiry, reach/weight and eligible repairs. |
| W1-F3 Item copies | Stable identity plus catalog definition; selected-copy equip/unequip/transfer/consume/buy/sell/container operations. Full destination refuses before losing anything. Older schema-2 saves reconstruct one copy per occurrence, with no replayed grants. | Individual material consumption, carried-object targeting and temporary weapon enchantments. |
| W1-F4 Time and casting | Six-second local actions, one-minute room moves, six seconds per completed combat round; declared rest/travel/casting/study durations. One expiry owner per effect. Exploration coordinator validates, commits once and applies real results. | Identify and detection outside combat; effectful rituals; Longstrider, Protection from Energy and other timed effects across scenes/rests. |

First card acceptance is the key → unlock/open door → open chest → retrieve
selected copy → combat → return → entrance → exit → checkpoint save → revisit
loop. It establishes ordinary interactions before enabling lock spells.
Tool-proficiency bonuses, combat-time ownership and exploration casting are
still separate unfinished requirements; object metadata alone implements no
spell, environmental operation or object-damage clause.

## Wave 2 — Equipment magic, perception, conditions and targeting

| Card | Playable foundation and completion boundary | Separate spell integrations |
|---|---|---|
| W2-F1 Equipment/components | Structured component requirements, class focuses, pouches, tools and explicit available hands. Expand carried packs exactly once. Supported supplies have actions; unsupported supplies remain inspectable and unusable. **Bounded version verified:** spell preflight checks hands, class-compatible carried focuses/pouches and exact copies for priced/consumed Material; pack expansion creates individual copies transactionally; room inventory exposes Inspect, Expand, Use and Place; contextual climbing tools and crowbar prying resolve through skill checks. Remaining limits are listed in the current checkpoint. | Shared casting preflight applies component rules to enabled spells, including Beast Spells and Subtle Spell. Full clause audits and rules completion remain separate. |
| W2-F2 Magic items | Ring of Protection, Wand of Magic Missiles and Sword of Vengeance have individual saved copies. **Bounded version verified:** one-hour attunement, three-item cap, Ring of Protection's worn-copy bonuses, seven-charge Wand state and dawn recovery, and Sword of Vengeance curse-bound attunement with Remove Curse release. **Wand activation implemented and Godot-verified:** a held copy offers 1–3 charge choices, casts Magic Missile through shared targeting, skips ordinary components, and spends charges from that copy after spell validation. | Identify targets a particular carried copy and reports its charge/attunement state; Detect Magic reports carried item auras; Remove Curse releases cursed item attunement. Sword of Vengeance's forced-retaliation behavior remains open. The Wand's last-charge d20 destruction rule follows the [2024 Basic Rules item text](https://www.dndbeyond.com/sources/dnd/br-2024/magic-items-a-z). |
| W2-F3 Perception | Walls and closed doors share a grid sight-block check. Encounter/room ambient light can be authored as bright, dim or dark. In natural darkness, carried Torch/Lantern and modeled spell lights illuminate their bright/dim radii; attacks against known unseen targets remain legal with Disadvantage, while sight-required spells and Counterspell refuse unseen targets. Innate and spell Darkvision use their stated ranges. Magical Darkness remains opaque to nonmagical light; Darkness disperses overlapping Light whether either spell is cast second. Torch and Hooded Lantern copies retain fuel and identity. **Bounded version verified.** Dim-light Perception checks, dropped-light placement, cover, ordinary NPCs and positioned sensors remain open. | Light, Dancing Lights, Darkness, Darkvision, Fog Cloud, See Invisibility, True Seeing, Arcane Eye; Cloudkill/Sleet Storm obscuration. Only modeled combatants and explicitly sight-required spells use the shared visibility query. No full perception or sensory simulation is claimed. |
| W2-F4 Conditions | **Bounded source slice verified:** condition immunity now applies to Characters at the shared condition boundary, and removing one named condition source preserves overlapping sources. Abjure Foes tracks its living caster, prevents a frightened monster from moving closer, applies its visible-source attack penalty, and clears only that source on damage/expiry. Sunburst now resolves its 60-foot Sphere, Radiant damage, Blinded condition, end-of-turn Constitution saves, one-minute target-owned expiry, and overlapping magical Darkness removal. Broader Frightened/Charmed/Blinded/Deafened consequences, captured save ownership, disease sources and other spell-specific endings remain open; there is no complete condition-clause audit. | Abjure Foes, charm, Protection from Evil and Good, restoration/removal, Sunburst. Existing slices are partial and retain their named gaps. |
| W2-F5 Target resolution | **Partial foundation:** selectors validate target types, range, multi-target caps, projectile assignments, four distinct visible Meteor Swarm Sphere centers, overlap deduplication, mixed damage packets and stable object/copy identities, including collocated choices. Meteor Swarm resolves player and monster saves/damage plus eligible unattended objects in the four-Sphere union, ignites flammable objects, and excludes magical/carried objects. Chain Lightning resolves up to five distinct targets at level 7 through creatures, room objects, and exact carried or dropped copies; every secondary target is within 30 feet of the first target. Both end-to-end casts passed Godot and are enabled for these supported combat paths. Secondary-effect previews remain open. | Meteor Swarm and Chain Lightning are enabled for their verified supported combat paths; other unsupported environments and unmodeled outcomes remain outside their rules-status claims. Preserve ordinary attacks/projectiles/healing.

### Wave 2 checkpoint and explicit deferrals

The supported first versions in W2-F1 through W2-F5 are delivered and verified. These bounded slices do not certify complete 2024 spell rules. Carry these concrete gaps forward without blocking the next foundation wave:

The [2026-10-07 review and correction evidence](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine/blob/d823423d979f7c566d7511801bd560f5dafb95ee/docs/reviews/spell-foundations-wave2-2026-10-07.md)
closes five defects inside those versions: Chain Lightning's secondary radius
is measured from its first target; sight is required only where declared;
curse-bound equipment cannot be replaced; natural light uses actual emitters
and target illumination; and special senses retain wall obstruction. Unseen
spell attacks apply the visibility modifiers, and True Strike uses its equipped
weapon as its Material component without requiring a separate pouch.

- **W2-F1:** full clause-by-clause component audits for every enabled spell, and all material-item interactions beyond implemented priced/consumed components and carried class focuses.
- **W2-F2:** Sword of Vengeance's retaliation behavior comes from the Dungeon Master's Guide rather than the project's SRD 5.2.1 rules authority; defer until that source is explicitly in scope. The existing magic-item spells cover only the documented carried-copy paths.
- **W2-F3:** per-hex environment editing, Dim Light Perception penalties, dropped-light placement, cover, ordinary NPCs, positioned sensors, and Arcane Eye's remote sensor behavior.
- **W2-F4:** broad condition consequences, saved-source attribution, disease state, and unmodeled spell-specific condition endings; keep condition and spell completeness uncertified.
- **W2-F5:** exact non-hex area geometry, cover, all creature/object combinations, and richer target previews. Meteor Swarm and Chain Lightning remain available only for their tested combat paths.

These are intentional scope limits, not claims that the rules are complete. W2 remains available for later follow-up; Wave 3 may proceed against its own foundation boundary.

## Wave 3 — Environment, persistent areas and movement

**Supported first versions delivered and verified, 2026-10-08.** See the
[review and correction evidence](https://github.com/brandonbrown215bb-boop/DND-Sandbox-Engine/blob/d823423d979f7c566d7511801bd560f5dafb95ee/docs/reviews/spell-foundations-wave3-2026-10-08.md).
This completes the foundation gate; named spell integrations keep their own
clause checklists, later dependencies and exclusions.

| Card | Playable foundation and completion boundary | Separate spell integrations |
|---|---|---|
| W3-F1 Environment | Fire Bolt, Fireball and Burning Hands damage/ignite eligible unattended objects. Exposed fire can spread locally; saved burning timers settle missed ticks and Extinguish/Rain end flames. Authored food, water, poison/disease contamination, Sight Rot, purification, cleaning and one-hour warming/cooling change actual objects. Consumable rations, food/water stock and Goodberries change saved size-based intake; deadlines, Exhaustion and recovery locks alter actual characters. Authored surface heat is separate from traversal, has damage/vertical reach, respects defenses and survives checkpoints. The Ashvale lava fissure damages Water Walk users on entry and continued exposure. | Prestidigitation, Purify Food and Drink, Create or Destroy Water, Goodberry and ignition spells retain their bounded paths. Other contamination sources, object transformations and environmental spell clauses remain separate. |
| W3-F2 Areas/barriers | Room areas retain footprint, caster/source, campaign expiry and trigger ledgers. Ten zones transfer through encounter return and JSON reload: Fog Cloud, Darkness, Cloud of Daggers, Spike Growth, Entangle, Black Tentacles, Grease, Sleet Storm, Moonbeam and Wall of Fire. Every concentration transfer has a saved owner; ending Concentration elsewhere removes only its source, and unloaded records expire on campaign time. Alarm wards follow room/combat crossings and door actions. Timber and masonry barriers share saved health, material, height, defenses and thresholds; destruction opens passage/sight, while glass can transmit sight and still block movement. Wall of Fire's real two-endpoint cast and separate full-damage entry/end-turn triggers pass the live scenario. | Alarm delivery is bounded to logged room/combat alerts. Spell-specific area geometry, indefinite lifetimes, visual effects, remaining zone transfers and full barrier spell modes retain explicit deferrals below. |
| W3-F3 Movement | Saved walk/climb/swim/fly speeds, five-foot floor/altitude records, wall heights and ceilings constrain room/combat movement. Fly requires sufficient altitude to cross walls/raised ground; loss of flying magic causes a fall. Levitate has local vertical controls, gentle descent and surface-constrained horizontal movement. Misty Step validates visible, unoccupied legal landing before slot use. Find Steed mount/dismount spends half Speed and transports its rider. Water Walk permits authored liquid surfaces without heat immunity. Spell/weapon/Repelling Blast pushes check each cell for occupancy, walls, Antilife Shell, falls and crossed hazards. Elevation/surfaces appear on the 2D map. | Fly, Spider Climb, Freedom of Movement, Water Walk, Misty Step, Levitate and Find Steed retain bounded paths; complete spell volumes, forms, routes and restrictions require individual integrations. |

### Wave 3 checkpoint and explicit deferrals

The supported foundation behaviors below are verified at their stated boundaries. Do not interpret
this as complete 2024 spell support. Carry forward the following named work:

- **W3-F1:** disease/poison sources beyond authored Sight Rot, general world
  weather/temperature, every food/water spell mode and exact cube geometry.
  The fissure's `1d4` heat and five-foot reach are authored encounter values.
- **W3-F2:** other combat-zone transfers; ninth-level until-dispelled Black
  Tentacles; Antilife Shell room transfer; Alarm recipient location, actual
  hearing and sleep/NPC state. Exact spheres/cylinders/volumes, cover, local
  Sleet Storm obscuration and Moonbeam illumination remain open. Wall of Fire
  uses a five-foot line and one caster-facing adjacent strip: a chosen side,
  full ten-foot danger strip, ring, opaque wall/vertical targeting, 20-foot
  height and one-foot thickness need its separate integration. The initial
  appearance permits a Dexterity save; ongoing entry/end-turn damage does not.
- **W3-F3:** full obstacle/canopy and creature-volume geometry, arbitrary
  physics/dragging and other movement spell modes. Levitate cannot be cast
  from the combat picker; an existing effect retains its controls there.
  Local exploration resolves hazards in its six-second action cadence rather
  than providing a complete initiative simulation.

The accepted headless checks include refusal without resource spending and
real safe checkpoint disk reload. Full clause audits and manual visual
checks remain separate from these historical results.

## Wave 4 — Creatures, bodies, forms and social interaction

W4-F1's first lifecycle slice adds stable familiar identity/HP, legal placement
before spending, Crown room summon/dismiss/recall/release controls, independent
initiative and owner-seat combat commands, pocket recall without initiative
rerolls, automatic Dodge while the owner cannot command, source-owned Help
cleanup, encounter return, validated checkpoint reload, and Long Rest/death
cleanup. Steeds retain room position/HP across encounters, survive a downed
owner, and cannot prevent a party-wipe defeat. See
[ADR-0014](../decisions/0014-owned-creature-lifecycle.md).

Four curated familiar forms now supply movement,
Darkvision and skill modifiers; combat offers borrowed senses and supported
Reaction-based Touch delivery. Authored exploration checks offer proficient
familiar Help. Ordinary Find Familiar has hour/ritual room controls, consumed
incense, form/type replacement and a lifetime distinct from Wild Companion.
See [the clause checklist](find-familiar-2024.md) for exclusions and the
requirements below for remaining world behavior. Other creature
families, their independent control expiry, equipment/condition gaps and the
bodies/forms and NPC/illusion foundations retain the open requirements below.
No complete spell or campaign readiness status is promoted.

The party-body portion of W4-F2 now records actual death separately from
unconsciousness, retains remains/time/willingness/restrictions, and provides
bounded Revivify/Gentle Repose controls with refusal before cost and safe body
checkpoint continuity. Stable recovery has a retained deadline. See
[party recovery clauses and limits](party-recovery-2024.md). Created-undeath
consumption/protection and independent control expiry now have a bounded
[Animate Dead integration](animate-dead-2024.md). Animated-object reversion,
Finger of Death's created Zombie and curated reversible forms remain open.
Animate Objects has partial, unvalidated rules/lifecycle hooks after a usage
limit interruption; its casting controls and dedicated checks are unfinished.
Normal casting, owner-following initiative, commands and room controls remain
unverified. Its allowlist entry is not evidence that those paths work.

| Card | Playable foundation and completion boundary | Separate spell integrations |
|---|---|---|
| W4-F1 Owned creatures | Extend familiar/steed ownership, placement, initiative, commands/defaults, duration, dismissal and death cleanup. Familiar senses, touch delivery and Help on supported checks. Command/control expiry is distinct from creature existence. | Find Familiar, companion gaps, Animate Dead, Animate Objects, Finger of Death's Zombie. Explicit stat blocks/control rules. |
| W4-F2 Bodies/forms | Persistent corpses with death timestamp, remains, willingness and recovery restrictions. Keep character identity; reversible form statistics, form HP, equipment, size/senses/movement. Start with party resurrection eligibility and curated Beast forms. | Revivify, Gentle Repose, Speak with Dead, Regenerate, Alter Self, Polymorph. Animal Shapes, Reincarnate and higher forms retain additional target/form dependencies. |
| W4-F3 NPCs/illusions | Stable NPC identity, languages, knowledge, attitude and recognition; authored request/deception responses. Observable illusion content, per-observer discovery, Investigation and physical interaction. Appearance affects recognition; markers do not automatically create belief. | Comprehend Languages, Tongues, Message, Charm Person/Monster, Disguise Self, Minor Illusion, Silent Image. Refuse unauthored outcomes clearly. |

## Wave 5 — Campaign information, travel and exceptional rules

| Card | Playable foundation and completion boundary | Separate spell integrations |
|---|---|---|
| W5-F1 Knowledge/messages | Authored campaign/NPC facts; stable recipients/locations; messages, replies, attempts and expiry retained. Bounded question counts and truthful unknown outcomes where allowed. | Contact Other Plane, Sending, Speak with Dead, Augury and divination; each spell's own limits. |
| W5-F2 Destinations/spaces | Known destinations, location knowledge/travel eligibility, arrival/occupants/duration/return checks. One linked refuge and one authored other-plane destination through existing scene transitions. | Travel/teleport spells, Tiny Hut, Rope Trick, Banishment and planar routes, separately audited. |
| W5-F3 Triggers/exceptions | Explicit subscriptions to entry/touch/damage/cast/death/time, with source/permitted response. Authored weather and one temporary protected action sequence; no universal rule language. | Glyph of Warding, Contingency, Control Weather, Time Stop individually; Wish duplication through completed spell paths. Other Wish operations stay unsupported. |

## State and acceptance

Inventory retains catalog-ID projections for existing weapon/armor queries and
adds copy-based operations. Room-map coordinates, local tactical coordinates
and overworld miles remain distinct. Plain saved room/object/copy records live
in the existing campaign ledger; live nodes and transient cast contexts do not.
Keep the 2024 namespace and safe-save restrictions, preserve legacy saves and
do not introduce mid-combat saving or automatic migration of legacy rules.

Every foundation needs a normal player path, an important refusal/failure and
a safe-save/reload path for durable state. Every integration needs an SRD
clause checklist against its production record. Required regression scenarios:

- Duplicate copies with distinct charges/attunement, full inventory refusal,
  exact reload without duplicated benefits.
- Door/key/chest/item changes survive combat, dungeon exit and revisit without
  regenerated layout or repeated rewards.
- Player attacks, monster combat targeting, Counterspell visibility, and sight-required spell targeting use the same wall and authored-natural-darkness visibility checks. Light markers and exact carried copies supply the configured bright/dim radii; magical Darkness is unaffected by mundane light.
- Portable-light copies retain identity and burn time; exploration reveal uses their dim radius and combat markers follow the carrier. This does not verify dim-light disadvantage, NPC vision, dropped-light placement, cover, or sensor behavior.
- Time advances once across actions, rounds, travel, rests, study and reload.
- Invalid/cancelled selections spend nothing; multiple targets spend once.
- Overlapping conditions, zones, summons and equipment remove only their source.
- Ineligible resurrection/form targets refuse without identity/state corruption.

Godot proves gameplay and saving. Python checks catalog/dependency inventory
and JSON shape. Run affected parser/boot and integration gates proportionately;
keep existing baseline failures explicit. One focused independent reviewer is
used for save migrations/shared combat when configured contracts are available.
Contracts were unavailable for this first implementation, so it was checked solo.

The [spell register](spell_status.json) maps every catalog ID to a named
`Wn-S-<spell-id>` follow-up, minimum capability checklist, later dependencies
and first-version exclusions. Evidence status, availability and rules completion
remain separate. The checklist is planning input; an empty clause checklist
means the complete audit has not occurred. Use the existing
[spell extension guide](../../src/spells/README.md) for casting/resolution homes.

No new service, external narrator, general physics simulation, wholesale
combat extraction or full dungeon redesign is part of this work.
