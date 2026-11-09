# Crown cross-set engine mapping

**Mapping/planning only, 2026-11-08.** All six written sets are mapped against
the current checkout and the [slice registry](../vocabulary-slices.md).
Nothing here implements, installs, loads, enables or gameplay-accepts content.
The [Crown roadmap](../crown-roadmap.md) still owns scope; the registry still
owns slice acceptance. No slice counts/statuses change.

The mapping selected **CXM-01: exact ammunition spending and recovery** first in
[the ordered assignments](assignments.md#cxm-01--exact-ammunition-spending-and-recovery-ammo).
A subsequent implementation now supplies its [verified S-249 runtime boundary](../vocabulary-slices.md#exact-ammunition-spending-and-recovery)
using exact copies, budgets and clock. Remaining assignments stay queued. The
mapping pass authorized planning only; it did not implement or enable content.
General liquids/fuel, backgrounds, multiclassing and whole S-237 were not gates.

## Source check, 2026-11-09

The assignments were checked against `src/`. Most gaps are real. Many
"Deliver" items already exist as native per-ID code, so they are replacement
work. Each assignment's **Source check** line names those native paths, and
assignments must not build a second path beside them. Changes from that review:

- **CLEAR_REWARD moved to CXM-02** and owns the one deliver-or-refuse helper.
  PACK, EVENT_REWARD and MONSTER_REWARD now hard-require it. This also fixes a
  live defect: a dungeon clear with a full backpack can lose a fragment.
- **BACKGROUND moved to CXM-04**, followed by its origin-feat consumers INIT
  (Alert) and DICE (Savage Attacker). There is no background host yet, and only
  Skilled is a loaded feat.
- The [operation crosswalk](op-crosswalk.md) maps the authored operation names
  to existing ops and lists the per-ID engine paths to retire.

## What is mapped

| Written set | Unique records | Exact source retained |
|---|---:|---|
| [Spells](../preparation/crown-spells/README.md) | 183 | All 1,103 rule text units, casting headers, authored sequences, current-contract drafts and extension requirements |
| [Characters](../preparation/crown-characters/README.md) | 79 + multiclass supplement | All 121 feature bodies; acquisition/casting/HP/mastery tables, 22 invocations, 10 Metamagics, nine species, four backgrounds, ten feats and language rules |
| [Equipment](../preparation/crown-equipment/README.md) | 105 | Complete facts/operations, 16 class/background packages, six packs, choices and blockers |
| [Reachable items](../preparation/crown-reachable-items/README.md) | 73 new | 29 package candidates reused without duplication; all 183 material routes, reachability and creation boundaries |
| [Creatures](../preparation/crown-creatures/README.md) | 94 | Complete behavior sequences/statistics, custom/SRD distinctions, legal selections, held swarms and gear/loot links |
| [World](../preparation/crown-world/README.md) | 74 | Map/dungeons, all four tables/29 events and child branches, generation, nine objects, procedures, milestones, objectives and rewards |
| **Total** | **609 including multiclass** | **608 indexed candidates plus one supplement; 178 distinct item/choice records** |

[requirements.json](requirements.json) is the tracked clause/consumer ledger:
6,247 exact-pointer units, including 136 original extension groups, their
additional source/policy blockers, and the full dependency/acquisition edges.
These are trace units, **not** an acceptance denominator or a count of gaps.
One source sequence may need several capabilities; a heading alone may need none.
The full pointed sequence and all its source qualifiers remain mandatory.

[capabilities.json](capabilities.json) and [assignments.md](assignments.md) group
shared requirements into 71 ordered assignments plus accepted reuse. Each records
the narrow slice owner, current operations/controls/hosts, missing or unverified
behavior, concrete consumers, prerequisites and reproducible future acceptance.
They select continuations of existing owners; they are not 71 new engine slices.
Candidate operation names remain authoring intent, never registered opcodes.

## How to read the ledger

Each candidate has its original path and SHA-256. Each unit identifies a JSON
pointer and capability facets. Spell text units preserve their `rNNN` identities;
feature units preserve feature ID/class threshold; world branch units point back
to the exact retained seed branch. A sequence's facet means that capability is
needed somewhere in that complete sequence, not that every sentence needs it.
For example, Aid's individual `r001`–`r004` routes distinguish recipient selection
from max/current-HP and slot scaling; Quest Board distinguishes combat launch,
unconsumed `choice.reward`, and `reveal_map`.

The capability records supply each unit's assessment: `engine_state`, `reuse`,
`remaining`, `work_kinds` and `proof_state`. Distinguish:

- **Engine extension:** missing operation, parameter, event producer or controller
  on the named host. An absent generic damage-copy contract is different from an
  already implemented damage split.
- **Content wiring:** definition, declared grant, loaded ID or call-site connection
  missing. A missing Arrows seed or ignored `bonus_hp: 20` is not an unknown rule.
- **Source fact:** material, weight, knowledge, stock or other required fact is
  absent/conflicting. Keep it unknown; don't invent eligibility or quantities.
- **Campaign policy:** source leaves a choice, or custom Crown rules need one.
  [Unresolved decisions](unresolved.md) names the affected rows and exact inputs.
- **Gameplay proof:** a relevant production control/host/checkpoint has not been
  demonstrated. Source inspection is evidence of code/contracts, not gameplay.

Missing-definition blockers explicitly override to content wiring. Other blockers
remain at their full source pointers; their original label does not prove engine
absence. Dependency/acquisition rows marked `relation_only` preserve complete
inventory/routing evidence; they are not claims that every listed candidate needs
every domain. Empty upstream domains waive no normal space/time/sense/source rule.
CATALOG and JOURNEY are convergence assignments, so they have no invented per-rule
engine consumers. Actual consumer requirements live in the preceding rows.

To inspect exact consumers from the repository root:

```powershell
python docs/planning/crown-engine-mapping/build_mapping.py --consumer fighter
python docs/planning/crown-engine-mapping/build_mapping.py --consumer warding_bond
python docs/planning/crown-engine-mapping/build_mapping.py --capability AMMO
python docs/planning/crown-engine-mapping/build_mapping.py --check
```

Use original file/pointer identity, not generated `RNNNNN` ordering, as the durable
reference. `--check` reconstructs the crosswalk in memory and compares source pins,
coverage and prerequisite order without writing or running Godot. Planning-only
`plan.py` and `routing.py` contain the authored assignments/routes; regenerate their
JSON/Markdown first, then the ledger after deliberately reviewing a source change.

## Current reuse and limits

| Current boundary | Reuse it; finish only the named consumer |
|---|---|
| S-235/S-246/S-248 and Crown S-247 | Shared condition/AI/check/save spine and Open Hand are delivered. Level-17 Quivering Palm remains outside Crown. A condition flag does not execute Fear/Command or every source ending. |
| OA-01–OA-13; S-237/S-238 partial | Actions/Ready, bounded cover, room Search/Help/Utilize, Study, local speech/hearing and Influence are real controls. Further tool effects, written/remote facts, geometry and sound hosts remain distinct. |
| S-233/S-242; G2/G3/G4 | Generation, feat prerequisite/repeat controls, class choices, Skilled and multiclass entry code exist. Background type, source feats/species and secondary feature acquisition remain; don't rebuild those controls. |
| S-134–S-139 and S-140/S-141 subsets | Source permissions, separate repertoire/slots/Pact/free uses exist. Free player-HUD cast fields and flat-condition lifetime edits do not establish costed Metamagic or every host/lifetime owner. |
| S-154–S-158/S-122 | Factory/footprints, exact commands, authored costs and bounded turns/defaults/position recovery exist. Remaining source templates, autonomous tasks and actor parameters are continuations. |
| S-163/S-164/S-168–S-172/S-167 | Forms/equipment pickers, persistent-room exact drops, tethers, containment/internal harm/legal release and vessel cargo are accepted. Source Wild Shape/swallow/Rope Trick/disk rules still need wiring/proof. |
| S-070/S-071 subset | Actual rest lifecycle, actor-specific four-hour duration, mixed Hit Dice/recovery exist. Prayer benefit-only rest is open; inn feature reset is not a completed Long Rest. |
| S-184/S-190/S-191 | Spatial receipts and observer senses are accepted within their documented hosts. Exact spell zone payloads, selective barriers, remote origins and light-level dispelling are not implied. |
| S-250/S-252 and item-copy work | Range/Heavy, don/doff, compartments, attachments and property loss exist. Ammunition, worn penalties, quantity/fuel/carrying and real item/tool uses retain their specific gaps. |
| SC-01–SC-07/support-10 | Shared weapon attack/projectiles/delayed damage/type choices/leaps/object damage/push, condition choices/stages and repaired curse packet/paid-slot state exist. Retained partial consumers stay in the conversion CSV; old failure/held prose does not erase newer code. |

Evidence paths in each assignment and hashes in the ledger bind this mapping to
current source/contracts. The old audits and queue remain source/discovery history,
not runtime status authorities. No old failure was reclassified as a reproduced
defect, and no old gameplay receipt was enlarged to cover these candidates.

## Settlement and compatibility boundaries

**Monster loot metadata does not prove payment.** No generic settlement is
established. **Quest Board bounty metadata has no established payment consumer.**
The current `claim_reward` external callers are harness checks; its existence is
not actual bounty delivery.

Dungeon-clear payout (`cleared_dungeons`), generated-room loot/clear, event branch
effects, pending child-encounter bounty, and proposed monster loot are separate
routes. CLEAR_REWARD, EVENT_REWARD and MONSTER_REWARD preserve that separation.
One recipient/occurrence must be delivered successfully before its receipt says
it is paid; attempted `add_item` plus a flag is not proof when inventory is full.
Repeated table rolls are separate occurrences, reopening the same roll is not.

Existing native behavior stays until its shared replacement covers its consumers.
Legacy saves remain untouched; new campaigns retain the 2024 namespace. Exact
source/actor/item identity, once-only costs/rewards and preflight-before-mutation
remain requirements. Only existing overworld/dungeon-entry checkpoints are legal;
combat, active rooms, events and pending decisions gain no save permission.

## Checks performed

Structural/source/link checks only: six-set membership, deduplicated item reuse,
all 1,103 spell units/121 feature bodies, every authored sequence and retained
blocker, exact JSON pointers, full supplemental maps, pinned source/contracts and
ordered prerequisite references. The original creature/world candidate validators
and local documentation links are checked separately. No engine changes, loaded
data changes, save changes, installation, publishing or Godot/gameplay run occurred.
