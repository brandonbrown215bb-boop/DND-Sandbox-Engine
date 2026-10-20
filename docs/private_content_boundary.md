# Private-content boundary

This is a repository inventory and replacement boundary, not a license or
clearance opinion. Human review must confirm provenance and permitted
redistribution before any public release.

## Repository-owned engine and campaign code

The original engine and product-specific code lives under `src/`, `scenes/`,
`project.godot`, `run_tests.ps1`, `scripts/`, and the repository-owned test
fixtures under `data/fixtures/`. The Crown campaign graph and its required
events, dungeons, companions, ledgers, and rewards are product-specific data in
`data/core/campaigns/the_lost_crown.json`. These paths must not require raw
source archives or a developer workstation at runtime.

## Imported or potentially third-party-derived content

The following paths require provenance and replacement review before
redistribution:

- `5etools raw/` contains raw class records retained for conversion and review;
  the runtime does not load this directory.
- `data/core/classes/` includes generated or imported class records.
- `data/core/items/imported_*.json`, `data/core/monsters/imported_monsters.json`,
  and `data/core/spells/imported_spells.json` contain imported content records
  used by the runtime registries.
- Historical import research (available in Git) and converter scripts describe or transform
  imported data but do not establish permission to redistribute it.

The `data/imported/` output area is generation-only and ignored. The importer
requires an explicit external source directory and must not write into
`data/core/`; see `docs/operations/development.md` and
`docs/content_pipeline.md`.

## Runtime separation and replacement contract

`DataLoader` loads `data/core/` and optional `data/mods/` at runtime, validates
duplicate IDs through `data/content_manifest.json`, and quarantines unsupported
effectless features. It does not read `5etools raw/` or an external source
archive during normal launch. A replacement content pack must preserve the
validated engine-facing schemas, stable IDs referenced by Crown campaign data,
cross-record references, and the supported rules contracts; it may replace
imported records without changing engine code when the replacement satisfies
those contracts.

The repository currently has no claim that every imported record is cleared for
public distribution. Keep the imported/raw paths separable, do not merge them
into private engine code, and record any approved replacement or removal in a
future provenance decision before publication.

## Human review

Reviewers must identify the source and permission status of every imported/raw
path, decide whether the current private repository may retain it, and approve
the replacement/removal plan. This card does not close Gate 8 by inference from
file layout or from a passing runtime test.
