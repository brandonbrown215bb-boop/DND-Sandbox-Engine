# Parallel runtime and content-editor pipelines

Owner-requested split, 2026-10-18. This is an implementation ownership and
handoff plan, not additional runtime acceptance. It supplements the
[roadmap](../../roadmap.md); [ADR-0018](../decisions/0018-shared-data-driven-rules-runtime.md)
still governs the single rules runtime. Current accepted scope is recorded in
the [checkpoint](../operations/current.md), not copied into editor claims.

## Split and ownership

Luna owns what the game can execute. Antigravity owns how content is imported,
edited and exported. They can work concurrently without editing the same files.
They cannot eliminate the dependency between executable syntax and the editor:
explicit file handoffs replace simultaneous edits and guessed interfaces.

| Ground | Owner | Other pipeline |
|---|---|---|
| `src/`, `scenes/`, game configuration, game validation runners | Luna | Read only |
| `data/core/`, `data/mods/`, `data/fixtures/`, central content manifest | Luna | Read only; no automatic promotion |
| Existing engine/import scripts under `scripts/` and `src/` | Luna | Read only |
| `docs/mechanics/`, `docs/json_schemas/`, engine architecture/decisions, checkpoint, slice counts and roadmap | Luna | Read only; report discrepancies in its own handoff |
| Proposed `contracts/authoring/` snapshots, if needed for the first integration | Luna | Read only |
| New `tools/content_editor/` including app, tests, examples, staged conversions and documentation | Antigravity | Luna reads candidate exports and reports only |
| Existing source/reference material | Neither edits as routine editor work | Read selected records; honor generated-source boundaries |
| Quest Board | Each edits only its own claimed card | Read other cards; no shared coordination-card edits |

Paths above that do not exist are reserved ownership, not implemented tools.
In particular, no authoring-contract exporter, general pack validator or external
pack installation API currently exists. Do not claim one from this document.

Keep one exact next action per pipeline. Existing runtime review/claims remain
authoritative; the editor gets a separate card. This owner-requested concurrency
is the bounded exception to the usual single-ready-card working model.
No package installation, publication, deletion or hard-to-undo action is authorized.

## Luna brief: runtime, pack ingestion and production proof

Work in the game repository and follow AGENTS.md. Read the current checkpoint,
architecture, roadmap, relevant ADRs and your selected slice. Run the Quest Board
brief, respect claims, and claim your own bounded work before editing.

You own the game side of the full authoring pipeline:

1. Resolve the current runtime handoff before dependent work. At this plan's
   creation, the coordination card requests independent acceptance of Batch 024
   (S-054/S-055/S-063); it is not accepted merely because a builder finished it.
2. Continue remaining engine work by current slice prerequisites and production
   finish lines. Preserve accepted boundaries and add the actual host connections
   needed by selected mechanics. Do not convert the whole catalog as part of
   building a primitive, and do not add per-content-ID native implementations.
3. Deliver the small game-side pack boundary needed for editor integration as a
   separately claimed task. Use existing registries/validators. It needs an
   external additive-pack root, stable namespaced IDs, explicit replacements,
   composable class spell-list additions, and useful validation diagnostics.
   Validate candidate content before making it the accepted active set. Restart
   after pack changes is sufficient initially; no hot reload is required.
4. Own promotion and proportionate gameplay validation of completed staged content
   batches. Keep unsupported records out of working-content claims. Existing
   save/checkpoint and legacy guarantees remain authoritative.

The pack task can be selected between vocabulary batches; it must not expand a
named slice's acceptance count or stall all 143 remaining slices waiting for the
editor. The two lanes both advance toward the owner's complete SRD/PHB authoring
goal; neither is limited permanently to the first spell demonstration.

Publish the smallest useful authoring handoff when its backing behavior exists:
one actual pack example, syntax/units, supported operation-and-host combinations,
and the exact production validation command. Plain files are enough. If a
machine-readable snapshot is useful, place it under `contracts/authoring/` with
an explicit revision and source reference. Do not build a generic schema service
or a second language to describe the language. Unsupported combinations must
remain explicit. A schema alone does not establish rules support.

First editor-integration finish line: load an external one-spell pack without
editing game source or the central manifest; learn/prepare and cast it through
actual controls; save, restart and recover. A second pack must extend the same
class list without replacing the first pack's additions. Missing required content
must refuse the supported load path before replacing the active party.

For shared combat/persistence changes, retain the repository's focused independent
review policy. Keep raw evidence and final commands; do not label builder checks
as independent acceptance. Antigravity is not an overlapping gameplay reviewer.

Never edit `tools/content_editor/`. If its artifact is wrong, record the exact
file/record and required change on your own handoff; let its owner repair it.

## Antigravity brief: standalone editor and staged content

Build the content editor under `tools/content_editor/` only. Follow repository
instructions, run the Quest Board brief, and claim a separate editor card. Read
the [readiness review](../reviews/mod-pack-readiness-2026-10-18.md), current
authoring contracts and selected runtime records. Do not wait for the engine to
be complete before starting your independent work.

You own the authoring side of the full pipeline:

1. Create a standalone workspace for pack metadata, content browsing/search,
   import, duplicate-as-homebrew, editing and draft export. Use available tools;
   ask before installing dependencies. No hosted service, account system or
   game-scene UI integration is required for this first deliverable.
2. Read existing JSON records, keeping imported originals and editable drafts
   separate. Preserve IDs/references on edits; allocate a new stable namespaced
   ID when cloning into a new homebrew definition. Keep unknown fields and
   nested structures through import/edit/export. Renaming a label must not rename
   an identity or rewrite references silently. Never overwrite the source catalog.
3. Begin guided controls with ordinary shared spells and a small supported item
   subset. Expand toward classes, subclasses, feats/species, creatures and the
   remaining intended catalog as runtime contracts become usable. A type without
   an executable runtime registry can be browsed/staged; it is not game-ready.
   Unsupported mechanics remain identifiable drafts with precise missing support.
4. Prepare source-backed catalog conversions in small batches under your own
   staging directory. Preserve source identity and unresolved clauses. Start
   revised-class source tasks with `reference/2024/README.md` and only the selected
   class view. SRD 5.2.1 remains the staged rules authority; reference metadata,
   imported prose and Foundry flags do not certify rule correctness.
5. Export candidate packs for Luna's loader. Until that format exists, export
   an explicitly marked draft bundle of runtime-shaped records; do not invent
   a supposedly supported package API. Keep that export code small enough to
   adapt to the first real contract. Never edit the game's manifest to make your
   demo work. Export authored files only, not the core catalog.

First finish line: import representative existing spell/item JSON, clone one into
homebrew, edit supported values, save/reopen the draft and export it without
losing untouched fields or references. Verify round trips containing unknown
fields and nested arrays. Show precise unsupported/draft status. Record how to
run it using available dependencies. This deliverable needs no new engine syntax.

After Luna supplies the pack example and validation command, align your exporter
and show diagnostics in the editor. Structural checks may run locally, but Godot
owns executable gameplay validation. Keep editor checks distinct from engine
acceptance; do not simulate a second rules engine or award support from an
operation name. Keep guided fields tied to a pinned contract revision; adopt
new engine capabilities in deliberate updates rather than reading changing files
as an implicit always-current API.

Never modify game code, core data, existing schemas, the slice registry or the
checkpoint. Report an engine defect or missing contract in your own handoff
instead of fixing the other pipeline's files. Do not upload/publish anything.

## Handoff and eventual completion

Exchange files, not shared implementation edits:

- Luna -> Anti: pinned supported syntax/example plus production validator command
  and diagnostics. The initial minimum is the existing authoring documents and
  selected source/record snapshot; a new API is not a prerequisite to editor work.
- Anti -> Luna: candidate pack and source/record references, intended changed
  behavior, structural checks, and precise unresolved clauses.
- Luna -> Anti: validation results and exact unsupported combinations or defects.
  Each owner repairs its own files and records the next action on its own card.

The editor may inspect copied records while Luna changes the game; do not mutate
files that the other lane is validating. Version candidate exports by revision
and validate an unchanged candidate. Existing uncommitted work must be preserved;
creating a worktree does not automatically include it. Separate checkouts are
optional once the needed snapshot is available, not a prerequisite or permission
to reset/rewrite anything.

Final integration belongs to these same lanes: Anti produces the edited pack;
Luna proves installation, normal gameplay and permitted save/restart recovery;
Anti presents those results. Broad SRD/PHB coverage still requires complete
relevant mechanics, converted records and source-backed gameplay checks. This
split creates concurrency, not a claim that either half is already complete.
