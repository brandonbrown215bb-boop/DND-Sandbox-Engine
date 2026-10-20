# Content pipeline

This describes current loading, not the target interpreter's proposed pack API.
`DataLoader` reads sorted content-type directories under `data/core/`, then
`data/mods/`. It registers stable IDs and validates record/reference contracts
before exposing the loaded registries. Named mod pack folders are not recursive.

## Collisions and support

Every duplicate must name a winner and all replaced sources in
`data/content_manifest.json`. Curated winning fields stay authoritative;
approved descriptive sources fill missing fields only. Filesystem order is
not precedence. Manifest pack metadata/layers are current loading boundaries,
not a user-facing pack manager or implemented version-migration system.

Base and parent-linked subclass registries stay separate. Enabled unknown
operations/resolvers and invalid references fail validation. Unsupported
effectless features remain quarantined. A native resolver label selects only
an already wired path, never arbitrary content code. Current loader curation
and named helpers are migration inputs under
[ADR-0018](decisions/0018-shared-data-driven-rules-runtime.md).

Shared spell definitions use `SharedSpell.content_error`; valid operations
determine availability without per-ID registration. Native spells still use
bounded `SpellSupport` slices. Registry presence, schema shape and availability
are distinct from full gameplay/rules acceptance. Read
[executable spell syntax](mechanics/shared-spells.md) and current source.

`DataLoader.get_registry_hash()` supports deterministic reload comparison.
Production creation, actions and save preflight must prove actual behavior;
inventory counts and Python mirrors cannot certify it. Do not regenerate
support status from newly written but unverified hooks.

## Import staging

For ordinary revised-class source preparation, use the
[2024 reference view](../reference/2024/README.md). It selects revised records
without translating them and maps them back to unchanged mixed-edition inputs.
The view is outside runtime loading and does not certify official SRD coverage.
The importer below still consumes its original explicit raw/external inputs;
do not treat source-view generation as content promotion.

`src/convert_all_5etools.py` requires `--external-data-dir`, accepts explicit
raw/output roots, and defaults output to `data/imported/`. Output/report paths
inside `data/core/` are refused. Directory discovery is sorted.

Each run writes `import_report.json` unless `--report` supplies another
non-curated path. It records counts, skipped records, source/import duplicates
and collisions with existing core content. Review staged output against actual
rule sources and the manifest before deliberate promotion. Translation must
not invent rule semantics or present truncated prose as source certification.
See [development commands](operations/development.md),
[private-content boundary](private_content_boundary.md) and the dated source
inventories linked by the design documents.

## Runtime and editor handoff

Runtime work owns `src/`, `scenes/`, game configuration/runners, loaded data,
the central manifest and runtime schemas/contracts. The editor pipeline owns
`tools/content_editor/`, including its app, tests, draft workspaces and candidate
exports. Each side reads the other's files and reports required changes rather
than editing overlapping scope. Concurrent work may use Quest Board for claims.

The runtime side supplies a pinned example, supported syntax/units/hosts and
production validation command. The editor side supplies an unchanged candidate
export with source identity, intended behavior, structural checks and unresolved
clauses. Validate that revision; each side fixes its own files. Plain files are
enough—no contract service or automatic API discovery is required.

Import/edit/export must preserve unknown fields, nested arrays, IDs and
references. Cloning allocates a new namespaced identity; label changes don't
silently rename IDs. Keep originals separate from drafts and never overwrite
the source catalog. Unsupported mechanics remain explicit drafts. Until a real
pack contract exists, exports are draft bundles, not installable game packs.

## External pack integration

The current loader has no external additive-pack installation boundary, ZIP
installer or enable/disable flow. Manifest pack metadata does not supply one.
Class-list overrides replace whole arrays rather than composing additions;
`spell_list_ids` is the current picker input, while older curated access fields
are not an editor API. Structural validity isn't executable support.

The first integration needs an external folder format, namespaced IDs, explicit
replacements, composable class-list additions and production diagnostics for
rejected/unsupported records. Validate a candidate set before accepting it;
restart after pack changes is enough. Do not build a dependency solver, hot
reload or migration framework for the first trial.

The concrete integration check is one editor-authored spell: export, install
without editing source or the central manifest, learn/prepare, cast through
normal controls, save, restart and recover. A second pack must add to the same
class list without replacing the first. Missing required content must refuse
before replacing the active party. Keep the same definitions installed during
a campaign; pack updates/removals aren't save migrations.

The 2026-10-18 readiness inspection also found warning-only feature quarantine,
live-registry mutation during reload, and incomplete item/type schemas. These
are dated findings to reproduce when implementing the boundary, not claims
that the editor or a schema already validates a complete installed content set.

## Source findings to retain

The 2026-10-11 audit found abbreviated/guessed importer output: class features
above level 5 could be dropped, descriptions truncated, activation/recovery
inferred from prose, and creature attacks synthesized from heuristics. Species
and external references mix versions; many traits remain descriptive. These
are historical findings to verify for selected inputs, not a fresh defect list.
An engine can't recover omitted rules by executing incomplete data faithfully.

PHB/MM Foundry packs are candidate donors for descriptions, advancement,
spell lists, actions and wall geometry. Foundry effects/flags aren't executable
support in this engine. Preserve source identity and complete relevant clauses;
resolve only the source gaps needed by selected mechanics. Item/book references
still need their own intended sources; Ravenloft is optional later material.
Don't import freeform scripts or silently drop unresolved mechanics.

## Historical audit inputs

`docs/reviews/dnd-data-runtime-adjudications.json` contains human judgments
bound to exact source records. Its matching `dnd-data-runtime-inventory.json`
and `dnd-runtime-source-ownership.json` are frozen inputs, not current support
certification. Keep them together; changing an input or a recorded runtime hash
requires actual re-review, not a hash refresh to force a passing result.

`python scripts/audit_dnd_descriptions.py` writes derived coverage CSV/JSON and
review units under ignored `.artifacts/rules-runtime-audit/`. It still refuses
when its snapshot, source ownership, source files or runtime evidence no longer
match. The retained historical runtime evidence is stale against current code.
Reusing it requires re-review; regenerating a report is not a new catalog audit.
Committed coverage exports and original research reports remain available through Git.
