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

The [Crown cross-set mapping](planning/crown-engine-mapping/README.md) now joins
all six completed writing passes to current shared contracts and verified slice
boundaries. Its [assignments](planning/crown-engine-mapping/assignments.md) start
with CXM-01/S-249 ammunition. The clause ledger, source/policy holds and future
checks are planning artifacts, not executable syntax, installation permission
or gameplay acceptance. No production candidates were promoted by mapping.

The final [Crown world/event/object set](planning/preparation/crown-world/README.md)
retains 74 non-loaded candidates and reuses the preceding complete candidate sets.
It preserves the map/dungeons, four event tables and all branches, generated
traps/loot, tactical objects, supplies/hazards, objectives and once-only reward
intent. Full rules, code/source pins, world dependencies and blockers remain
preparation. Monster loot and quest reward metadata do not prove payment.
The subsequent mapping is linked above; neither pass changes runtime contracts.

The [remaining Crown reachable-item set](planning/preparation/crown-reachable-items/README.md)
adds 73 candidates and links 29 existing equipment candidates. It retains
source acquisition evidence and maps all 183 spells' Material requirements;
custom rewards, out-of-band sold components and physical creations keep their
distinct source/lifetime limits. Nothing is loaded or enabled. Source/shop leads
and unchanged seeds are preparation, not a new production availability export.

The [Crown package-equipment set](planning/preparation/crown-equipment/README.md)
retains 105 non-loaded candidates, exact package alternatives and six full pack
lists. Existing item definitions/hashes and collision declarations are retained
as seeds alongside source facts, authoring plans and blockers. This writing pass
does not install items, repair runtime behavior or certify gameplay. It covers
character-package equipment; the later item and world sets are written separately.

The [Crown character/origin authoring set](planning/preparation/crown-characters/README.md)
retains the twelve class/subclass packages through level 5, multiclass grants,
eligible invocation/Metamagic options, nine species, four backgrounds and ten
feats. Like the [183 spell candidates](planning/preparation/crown-spells/README.md),
it stays outside `data/core` and `data/mods`. Authored operation plans are not
registered runtime syntax; retained definitions/drafts and explicit unsupported
clauses must be reconciled before deliberate promotion. Writing these sets did
not change engine behavior or run gameplay checks.

The [Crown creature/actor set](planning/preparation/crown-creatures/README.md)
retains 94 written records with separate campaign/SRD identities, complete
individual in-band selectors, full source bodies, unchanged donors, per-behavior
plans and blockers. Its spell/character dependency map and item reuse links
complete the creature-writing boundary without production enabling or gameplay
proof. Held swarms, companion choices, custom boss ambiguities and reward
settlement remain explicit. The world/event/object set above is now written too.

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

### Recovered local inputs — 2026-11-08

These locations were rechecked during the Crown recovery review. They reduce
source hunting and duplicate authoring; they do not supply production-ready
definitions. `.artifacts/` and `_staging/` are ignored, machine-local inputs.
Their presence here does not make them available in another checkout. Keep
selected authored candidates in tracked preparation files with source identity;
do not make ignored reports the only home of new content work.

| Need | Existing input and exact location | How to reuse it |
|---|---|---|
| Official in-scope rule bodies | `.artifacts/rules-authority/SRD_CC_v5.2.1.pdf` (364 pages); `source.txt` beside it records the source URL and SHA-256 `8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87`, rechecked against the PDF. | Read selected SRD pages before authoring. `source.txt` is provenance, not a full text extract; the neighboring text excerpt covers Hit Dice/rests only. A body absent from the revised class view is not necessarily unavailable locally. |
| Fighter/Wizard starting, multiclass and progression source preparation | `.artifacts/antigravity/progression-sources.md`; use `progression-sources-corrections-review.md` beside it, which supersedes the older corrections-required review. Packet SHA-256 `c223a0d6c5e9ad510a62826f3cf41a95d479fd5db4d882f844407235e0d0851c` and the two raw class-file hashes still match. | Reuse the corrected coordinates/tables. Its explicit missing-source questions and dated runtime observations are not rules answers or current behavior certification. The [revised class view](../reference/2024/README.md) remains the ordinary class entry point. |
| Existing descriptions, advancement and structured source records | `.artifacts/planning/foundry-modules-2026-10-17/phb/`: `classes.json`, `feats.json`, `origins.json`, `spells.json`, `equipment.json`, `actors.json`; `mm/actors.json` in the sibling directory. The folder retains `artifact-manifest.json`, `pack-inventory.json` and `report.md`. | Read these exported JSON snapshots offline; reopening the original databases is unnecessary for selected source lookup. Confirmed top-level records include 12 classes, 48 subclasses, 391 PHB spells, 77 feats, 15 species, 16 backgrounds, 127 PHB NPCs and 504 MM NPCs. All ten Crown feat names, Goliath/Orc and example eligible invocation/Metamagic bodies are present. These are broader donor sets: SRD authority and Crown eligibility still determine what to author. |
| Corrections to the proposed Foundry converter | `.artifacts/planning/foundry-2024-architect-review-response-2026-10-17.md`, with the sibling original report, observations and reproduction script. | Use the corrected source interpretations and omitted-rule findings. `scripts/audit_foundry_2024_converter.js` is a prototype: its advertised validation/readiness tiers were not production Godot validation, and its translations omitted or guessed behavior. Do not bulk-promote its output as completed candidates. |
| Prior actor/form, time/effect and world-interaction investigation | `.artifacts/planning/foundry-deep-review-2026-10-17/actors-inventory.md`, `time-effects.md`, `world-procedures.md`. | Reuse distinctions already investigated, such as form selection versus retained stats and area membership versus actual movement. These are dated observations about another implementation; current mechanics contracts own our syntax and supported behavior. |
| Historical per-record requirements and gaps | [Human adjudications](reviews/dnd-data-runtime-adjudications.json), [frozen inventory](reviews/dnd-data-runtime-inventory.json), [source ownership](reviews/dnd-runtime-source-ownership.json). | The 3,929 adjudications retain requirements, evidence and gaps across source records, not 3,929 accepted rules. Use them to locate prior findings, then reconcile selected records and current owners. Follow the [hash/re-review boundary](#historical-audit-inputs); do not refresh hashes merely to revive stale support claims. |
| Subclass/background candidate reuse | [Crown authoring reconciliation](planning/crown-roadmap.md#authoring-reconciliation--2026-11-08). | It distinguishes the nine older subclass drafts, newer Draconic preparation and four existing background candidates from missing authored behavior. Do not regenerate those starting records or mistake disabled/truncated drafts for complete rules. |

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
