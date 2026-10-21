# Roadmap

Build one shared, data-driven D&D 2024 rules engine in Godot. JSON describes
rules; code interprets reusable operations and supplies world access. Prepared
content using completed capabilities must run without content-ID branches.
[ADR-0018](docs/decisions/0018-shared-data-driven-rules-runtime.md) owns this direction;
[ADR-0023](docs/decisions/0023-vocabulary-first-delivery-and-bounded-world-judgment.md)
retains vocabulary-first delivery, current save priorities, and Wish/illusion policy.

## Current work

Continue the engine backlog in the [slice registry](docs/planning/vocabulary-slices.md).
It owns requirements, prerequisites, completion status, counts and verified limits.
The selected work is the [merged-slice completion queue](docs/planning/vocabulary-slices.md#merged-slice-completion-queue):
finish the missing controls and target/source wiring from Batches 034–046, and
build the specific world capabilities those implementations still need. Reuse
completed pieces rather than repeating their proof because a broader requirement
remains open.

The three initial Grokbot handoffs and their playtest repairs landed in PRs
#16–19. Their [accepted boundaries](docs/planning/vocabulary-slices.md#pr16-18-validation)
retain the unfinished feat acquisition, mode/upgrade controls, volume and item
measurement/role work. Do not reassign completed chooser or ownership work.
Legal placement is the next additional shared world assignment.

The owner's instruction to review, fix and merge accepts the reviewed work when
that workflow completes. Record acceptance and its bounded limits in the slice
registry; do not add a separate owner sign-off after merging.

Start the ready assignments in that queue without waiting for a new engine
framework. The first shared world work is legal placement/outcome settlement
(S-121/S-122), reused by creation choices (S-155), real equipment drops and
item-form return (S-164/S-166). Created-actor command authority (S-156) can start
independently, then initiative/default behavior follows (S-157/S-158).

Extend existing room objects, areas and source-end records for located aftermath
(S-086/S-087/S-120), then object-anchored restraints (S-168/S-169). Multi-recipient
tethers first need one cast source retaining several recipients (S-144); they do
not need a general object system. Containment/release (S-170–S-172) and vessel
cargo/movement (S-167) follow placement and item reversion. Cast-local parameter
changes (S-126/S-127/S-140/S-141) form an independent branch. The queue owns each
assignment's narrower dependencies and checks; this is not a whole-phase gate.

1. Discover any missing requirement needed by the selected capability.
2. Build and verify that capability through production Godot paths. Neutral or
   renamed fixtures are valid consumers; per-slice catalog conversion isn't required.
3. Prepare source-backed executable data and translate content using those pieces.
4. Replace native content paths once their replacements cover the content using them.
   A gap exposed during conversion becomes concrete engine work.

The standalone content editor can progress alongside runtime work using current
contracts. Its draft exports do not imply game installation support. Keep the
runtime/editor [ownership and handoff boundary](docs/content_pipeline.md#runtime-and-editor-handoff).
Quest Board is optional when concurrent work needs coordination.

## Scope and deferred work

- SRD 5.2.1 governs the staged twelve-class milestone. Artificer, Mystic and later
  supplements remain outside it. Source gathering and content correctness are
  separate from engine completion.
- Crown remains a level 1–5 campaign for one to four shared-keyboard players and
  four stable party slots. Full campaign readiness isn't certified by slice tests.
- Owned creature/form controls, broader world/NPC/illusion interactions and
  unfinished Animate Objects integration retain their [documented limits](docs/mechanics/spell-foundations.md).
- External pack ingestion and composable class-list additions remain an
  [integration requirement](docs/content_pipeline.md#external-pack-integration), not an implemented API.
- Map wall/crossing import is future world integration. Reuse existing movement,
  geometry and visibility boundaries; see [map requirements](docs/architecture/README.md#map-integration).
- Keep existing save locations and checkpoint limits. Don't build migration or
  compatibility frameworks ahead of a feature that needs them.
- Controllers, networking, publication, friend runs and a new high-level campaign
  remain parked until wanted. Old gate sequences don't choose work.
