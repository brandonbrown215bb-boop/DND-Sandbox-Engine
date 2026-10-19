# Foundry data and map adoption

Future work recorded 2026-10-17 at the owner's request. The
[roadmap](../../roadmap.md) selects implementation; the
[slice registry](vocabulary-slices.md) owns finish lines and acceptance. This
plan adds no accepted capability, changes no slice prerequisite and selects
no next batch. The baseline remains **69/226 accepted; 157 not yet accepted**.

## What the source discovery changes

The locally inspected dnd5e 6.0.6, PHB 2.2.0, MM 1.4.0 and Ravenloft 1.0.1
packages are candidate source inputs. PHB has all 12 intended class and 48
subclass records, feature descriptions, advancement relationships and spell-list
pages. MM provides structured monster actions and references to PHB spells.
Ravenloft adds optional character/adventure material and authored scene geometry.
Records and metadata are not independent certification of complete rule clauses
or gameplay. SRD 5.2.1 remains the staged milestone's authority; Artificer and
later supplements remain outside that milestone.

This reduces manual source hunting and data entry. It does not remove action,
cost, choice, timing, source-ownership or save behavior from the engine. Read
and pin the selected rules before implementing or converting their clauses.

The retained local investigations are supporting evidence, not runtime
dependencies or required files for another developer:

- `.artifacts/planning/foundry-review-2026-10-17/review.md`
- `.artifacts/planning/foundry-modules-2026-10-17/report.md`
- `.artifacts/planning/foundry-walls-2026-10-17/findings.md`

## Impact on slices and batches

| Work | Foundry's useful input | Consequence for the engine plan |
|---|---|---|
| Accepted S-045/S-046 choices and S-047/S-048 progression (including Batch 018) | PHB choice, ItemGrant, Trait, ScaleValue and level relationships | Reuse accepted operations for compatible converted definitions. Full subclass/casting progression and feature-bearing secondary classes are not certified by the existing bounded host. No acceptance is revoked or broadened by an import. |
| Accepted S-006/S-007 pools/rest and S-049/S-050 carriers | Uses maxima/recovery arrays and item/effect ownership | Translate eligible values into our contracts; retain exact copies, spent quantities and existing recovery rules. Item/cast carriers currently support bounded fixed AC/walking-speed payloads, not arbitrary Foundry enchantments. |
| 019: S-042/S-072/S-073 endings; 020: S-074/S-075/S-080 suppression/auras | Durations, expiry flags, dependency references and effect descriptions | Useful examples for the existing finish lines. Foundry dependency cleanup is opt-in and its flags do not supply our exact-source ending/suppression behavior. Keep the scheduled work. |
| 021: S-134/S-135/S-137 casting permissions/payment/preparation; 022: S-138/S-139/S-136 slots/uses/rituals | Cast UUIDs, spell-list pages, class advancement and limited-use records | Strong source-preparation benefit. Resolve the real owning source, ability, list, payment and casting restrictions in our runtime. A spell reference is not an executable permission. Existing order/prerequisites remain. |
| 023/024 exchanges and recovery | Consumption targets, formulas and rest/dawn recovery arrays | Reuse authored examples while implementing the planned atomic exchange and timed recovery contracts. Do not copy actor-local first-match source resolution where our exact-copy identity matters. |
| S-126/S-127 profiles and S-140/S-141 cast-local changes | Weapon enchantments, attack/damage overrides and Cast parameters | These planned slices remain the route to broader weapon/cast projections. They are not already covered by the accepted additive-stat carriers. |
| 025/026 dice and repeat outcomes; 027 linked protections | Damage parts, effect references, duration/recovery descriptions | Better authoring inputs, but no generic automatic repeat-save, dice interception or exact linked-benefit implementation is supplied by the pack format. No slices are skipped. |
| 028: S-146/S-148/S-149 substitutions/child actions; 029 cast interruption/payment | Multiple activities, forward/cast references and manual consume/refund workflows | Keep our parent-budget, exactly-once continuation and declared settlement rules. Multiple buttons are not an ordered program; manual refund is not automatic outcome-based payment. |
| S-154–S-158 creation/commands and S-163/S-164 forms | Summon profiles, matching parameters and transform policies | Supplies concrete inputs. Factory placement, ownership, AI/control, initiative, reversion and cleanup still need the planned hosts. |
| 030: S-032/S-033/S-179 physical facts/space/movement | Sizes, material/geometry records, speeds and terrain examples | Useful sample data. Keep the three original finish lines; do not silently add a scene importer or all P7 barriers to this batch. |
| S-184/S-185/S-190 crossings, barriers and obstruction | Wall/door segments, region boundaries and separate blocking channels | Future world integration below. Basic map walls do not finish selective magical barriers, all trigger scopes or observer-specific exceptions. |
| S-214/S-215 tables and S-222/S-223 referenced procedures | Weighted table rows and references between activities/actors/spells | Retain exact missing-child/capability refusal. Ingesting a table or resolving an ID does not establish support for its result. |

Other slices retain their current requirements. A source-backed exception found
during a selected task may reveal missing behavior; first map it to an existing
finish line. Add/refine scope only when that behavior cannot fit an existing
row. Import format differences alone do not justify new gameplay slices.

## Source tasks and offline conversion

- **SRC-01:** PHB is an available donor for intended maneuver, Metamagic,
  invocation, Fighting Style and feat descriptions. Locate the selected exact
  records and references before calling that source gap resolved.
- **SRC-03:** PHB/MM provide candidate revised spell/monster bodies and structured
  discriminators. Preserve source identity and distinguish a description from an
  actual executable activity.
- **SRC-04:** Advancement records and journal spell lists help repertoire and
  progression preparation. Conflicting clauses, multiclass rules and missing
  exception text still need explicit resolution.
- **SRC-02:** Some item data is available, but PHB/MM do not supply every missing
  magic-item, artifact or external-book body. Ravenloft is not a DMG replacement.

None of these source tasks is marked complete by this plan. The exporter and
converter are content tooling outside the 226 gameplay-slice denominator.
They follow [content staging](../content_pipeline.md): explicit external inputs,
output outside data/core, review before promotion and declared collision winners.
No Foundry dependency is introduced at game launch.

A future converter must handle array/map advancement layouts, legacy/named
effect changes, cross-pack UUIDs and typed host defaults. Emit our existing
validated schemas for supported behavior and retain precise unsupported
requirements. Do not import freeform scripts, guessed AI or silently discarded
effects as working content. Renamed definitions must use the same generic
operations as existing content under ADR-0018.

Accepted slice evidence remains valid for its original host. A converted record
is a new consumer and needs proportionate production proof of its represented
behavior. If a broader consumer exposes a reproduced engine defect, repair and
check that boundary; do not automatically reopen every accepted slice or rerun
all earlier suites.

## Further subsystem research

The [2026-10-17 systems review](../reviews/foundry-systems-adoption-review-2026-10-17.md)
maps suppression, recovery, spell wrappers, dice, forms, summons, enchantments,
regions, perception, inventory and procedures to the existing slices. Consult
the relevant source chain when selecting that work; this adds no implementation,
acceptance or change in delivery order.

## Future wall and crossing integration

Foundry walls are scene-coordinate segments with separate movement, sight,
light and sound restrictions. Doors change the same segment's state. The
inspected stock movement path constrains supplied waypoints; it is not the
route-search engine to replace our A*.

The first selected map task should retain wall geometry aligned with one
background image and the hex overlay, while using existing door objects,
movement budgets and terrain costs. A common segment query must feed:

1. Player and AI path/reachability calculations.
2. Actual permitted movement, including refusal without distance expenditure.
3. Line of sight/target visibility using its own obstruction channel.

First-sample proof should cover a solid boundary, a movement-blocking but
see-through window, a closed/open/locked door, corners/narrow passages and
creature clearance. Door state changes must refresh paths and visibility;
supported durable door state must recover through existing allowed checkpoints.
Resolve map scale/origin and walls bisecting hexes explicitly; do not replace
thin walls with whole blocked cells and call the geometry equivalent.

This work aligns with S-179/S-184/S-185/S-190. Its world hooks may be delivered
in a bounded selected task without completing every broader magical barrier
or observer capability. Conversely, a working ordinary door is not acceptance
of those broader slices. Respect their prerequisites when claiming them.

Sound/light attenuation, directional sense thresholds, levels/surfaces,
pass-through exceptions, moving barriers and arbitrary scene behaviors are
separate scope when selected. Simple authored portals/elevation entry changes
can be translated into supported declarative operations rather than a script
executor. No implementation or map import starts with this planning change.
