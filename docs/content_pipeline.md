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
