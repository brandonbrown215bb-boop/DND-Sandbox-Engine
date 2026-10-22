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

The initial Grokbot handoffs and playtest repairs landed in PRs #16–19.
PRs #20/#24 close the test-harness false-pass gaps; #21/#23 add bounded chosen-feat
acquisition and combat mode/upgrade controls. Their
[accepted boundaries](docs/planning/vocabulary-slices.md#pr20-24-validation)
retain fixture-only feat proof, missing backgrounds and feat mechanics, action
costs for real mode content, and volume/item measurement/role work. Do not
reassign completed chooser, ownership or control wiring.

PR #22 also repairs dawn recovery for exact projected item copies, preserving
their remembered capacity through save/load, reversion and re-equipping.

PRs #25–37 supply bounded combat placement/factory choices, exact created-creature
commands and turn policies, authored mode/command costs, room mode controls and
reaction triggers. Their review repairs and remaining work are tracked in the
[PR25–37 review boundary](docs/planning/vocabulary-slices.md#pr25-37-validation).
PRs #25–37 are merged with the review repairs and accepted within that boundary.
Unfinished scope below does not block acceptance of the delivered subset.

Still needs to be done from that queue: S-121 exit placement before final
save/outcome settlement; S-122 normal item-projection placement controls and
failure/payment policy; exploration creation placement; multi-cell bodies and
mixed-size/per-kind summon policies; S-157 shared-count variants beyond the
implemented timings; and S-158 owner-turn behavior after an owner leaves the
tracker, plus linked summons entering an encounter with an already downed/dead
owner who has no initiative entry. Real catalog conversions, Find Familiar's
creature-type choice, overworld/sheet mode controls, group mode recipients and
end-early controls also remain. Outside-combat activation time is displayed but does not advance the
campaign clock. Reaction commands and reaction delivery through additional
attack/damage routes remain unfinished; Hellish Rebuke still has no supported
cast permission. Do not reassign delivered pickers, command identities or costs.

The owner's instruction to review, fix and merge accepts the reviewed work when
that workflow completes. Record acceptance and its bounded limits in the slice
registry; do not add a separate owner sign-off after merging.

Start the ready assignments in that queue without waiting for a new engine
framework. Continue legal exit/outcome settlement (S-121), the remaining
placement hosts (S-122), real equipment drops and item-form return (S-164/S-166).
Reuse the delivered combat factory (S-155), command authority (S-156) and
bounded turn/default policies (S-157/S-158) for their remaining consumers.

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
