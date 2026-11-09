# Crown world, event and object candidates

**Current handoff:** the [cross-set engine mapping](../../crown-engine-mapping/README.md)
is complete as planning. Follow its [bounded queue](../../crown-engine-mapping/assignments.md),
starting with CXM-01/S-249 ammunition. The writing snapshot below and its unchanged
candidate rules/blockers remain inputs; no candidate is promoted or accepted.

**74 written candidates, outside production.** This is the final Crown catalog
writing pass. It reuses the full [spell](../crown-spells/README.md),
[character](../crown-characters/README.md), [equipment](../crown-equipment/README.md),
[reachable-item](../crown-reachable-items/README.md) and
[creature](../crown-creatures/README.md) candidates. It changes no engine behavior,
loaded data, saves or content availability and claims no gameplay acceptance.

Start with [the index](index.json), [world procedures](required-extensions.json),
[dependency map](dependency-map.json) and [acquisition links](acquisition-links.json).
JSON candidate paths are relative to this folder; pinned `path`/`sha256` sources
are repository-root paths. Retained inputs preserve their original conventions.

| Written set | Count |
|---|---:|
| World procedures and full source-context requirements | 13 |
| Campaign map (all 43 tiles) | 1 |
| Ruins of Ashvale, Caverns of Gloom, Tower of the Lich | 3 |
| Ashvale antechamber and all nine exact objects | 10 |
| Authored lava fissure | 1 |
| Dungeon generation, generated trap and generated loot procedures | 3 |
| Four full event tables | 4 |
| Every event, including the nested Fairy Court | 29 |
| Four milestone triggers and conjunctive campaign objectives | 5 |
| Three dungeon-clear rewards and quest-board bounty | 4 |
| Camp/inn/rest and supply consumers | 1 |
| **Total** | **74** |

All campaign/event seeds are retained unchanged with source pointers and hashes.
Every check, success/failure/direct consequence, empty leave branch, price,
condition, reward, monster multiplicity, surprise flag, weight and child event
remains present. Branch plans do not replace the complete input. Custom campaign
rules stay separate from SRD rules; Trapped Chest is not silently replaced with
the SRD Poisoned Needle or Poisoned Darts examples.

[Source pages](source-pages.json) retain complete selected SRD 5.2.1 contexts,
including exploration, marching order, travel rates/terrain, Search/Study,
objects, carrying, food/water, breathing, falling, burning, environmental hazards
and trap procedures. Full-width extraction accompanies column text so tables
split across columns remain available. The travel terrain table was visually
checked against the local PDF. Unselected trap/poison/other examples in page
context do not expand the Crown catalog.

The dependency map covers **all 183 spells and all 79 character candidates plus
the multiclass supplement**. Full rule bodies, authored operations and previous
blockers remain in those unchanged candidates, pinned by hash. The world domains
route actual requirements to these procedures: exact objects and quantities,
locks/wards, food/water and breathing, terrain/time, knowledge/languages and
secret messages, sensors/light, corpses, forms/actors and legal access/return.
Character source units retain their rule pointers and conservative routing
leads; an empty domain does not waive ordinary spatial, sensory or time facts.
Final cross-set engine mapping remains separate from this writing pass.

The **176 acquisition occurrences** link existing item/creature candidates;
repeated appearances and duplicate rewards remain separate occurrences. No new
equipment or monster catalog is minted here. Gold tokens represent currency,
not backpack item copies. Keys, both chest potions, body remains, cistern water,
food servings and barriers retain their exact room/source identities.

Material blockers carried forward:

- **Monster loot metadata does not prove payment.** No generic post-combat
  monster-loot settlement was established by the previous trace. Dungeon-clear,
  generated-room, event and bounty rewards have separate owners.
- Quest Board's `choice.reward` has no consumer in `EventDialog`. A victory-bound
  100-GP bounty is authored intent, not an established payout. `claim_reward`
  exists, but its current external call sites are harness checks. Actual dungeon
  clear uses `cleared_dungeons` and its own native payout, not that reward ledger.
  Attempted `add_item` plus a cleared/claimed flag does not prove delivery when
  inventory is full. Preserve the existing checks without certifying normal play.
- Town entry opens the shop directly. Loaded `town_events` and authored shop
  offers do not prove event delivery; the dialog has no shop dispatch. Dungeon
  generation selects `trapped_chest` directly rather than rolling the full table.
  Keep every loaded event and its routing gap, rather than drop unreachable rows.
- `reveal_map` yields resolver metadata without a dialog-to-overworld fog-reveal
  consumer. Fairy Court decline text supplies no return teleport. Nested popup
  state and continuation still need mapping. Flavor maps, journals, ghost advice,
  corpse history and NPC attitudes require actual facts before spells query them.
- Generated Trapped Chest has no spatial trap instance, split discovery/disarm
  procedure or authored reset policy. Event duration integers/custom buffs retain
  their original values; they are not automatically seconds, rounds or fully
  defined benefits. Inn `rest` calls feature reset, not the shared rest lifecycle;
  healer condition clearing is not proof of complete ailment/curse restoration.
- Five-mile travel needs actual pace/time and terrain procedures; movement points
  and End Turn advancing a day are not that procedure. Foraging yield, lost
  routes, weather/forecasts and terrain aliases require campaign facts. Water
  gallons and food servings must not become infinite stock or invented pounds.
- Ordinary locks, exact contents, source-owned areas, senses, Search/Study/Help,
  containment, actor creation, rest and survival hosts already exist. Reuse their
  verified limits. They do not certify every spell consumer. The source-backed
  Arcane Lock/Knock, Glyph, Mending, body knowledge, remote senses and movement
  requirements remain whole; no named-content executor is proposed.
- Preserve the custom bosses, pool weights and all dungeon metadata. Generation
  reads only boss monster ID, so Chief Skullcrush's `bonus_hp: 20` and boss display
  names need an actual consumer before claiming them. Lich Rejuvenation and its
  phylactery/finale policy remain unresolved. Objectives currently count fragments
  held by active characters, not the inactive companion roster.

Proposed once-only settlement belongs to an exact occurrence and recipient.
Repeat rolls of a random table are distinct from reopening/resuming that same
occurrence. No global once-per-event-ID restriction is invented. Preserve current
room clear, dungeon clear and milestone state; do not add another payout beside
an existing route. Allowed checkpoints and the 2024/legacy-save boundary remain
unchanged. The [consumer trace](consumer-trace.json) pins selected current code
and functions for these observations; it is static evidence, not runtime proof.

Run `python docs/planning/preparation/crown-world/check_candidates.py` from the
repository root. It checks full campaign/table/event/object coverage, every
branch plan, unchanged retained payloads and hashes, all spell/character rule
pointers, procedure links and acquisition reuse. Python checks authoring
structure and inventory only. No Godot run or gameplay/save test belongs to this
writing pass. Slice status and accepted boundaries are unchanged. The next work
is cross-set engine mapping, using the [Crown roadmap](../../crown-roadmap.md)
and [slice registry](../../vocabulary-slices.md).

This work includes material from the System Reference Document 5.2.1
(“SRD 5.2.1”) by Wizards of the Coast LLC, available at
[the official SRD page](https://www.dndbeyond.com/srd), licensed under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/legalcode).
The [official PDF](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf)
SHA-256 is `8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87`.
Adaptations add world operation plans, source routing and mapping notes;
custom Crown content retains its separate campaign authority.
