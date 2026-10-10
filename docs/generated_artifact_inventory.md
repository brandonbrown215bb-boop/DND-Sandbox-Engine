# Generated repository artifact inventory

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

Inventory captured from the working tree on 2026-08-10. This is a cleanup
proposal, not permission to delete files. The existing dirty worktree and
tracked evidence must be preserved until the review below is accepted.

| Path or pattern | Observed role | Proposed disposition | Reason / next check |
|---|---|---|---|
| `.godot/` | Godot editor/import/shader cache; about 150 files in this checkout | Ignore and remove only from a clean publication tree | Already ignored. Never use it as fresh-clone evidence. |
| `.artifacts/` | Disposable save/profile and probe output; about 4 KB observed | Keep ignored; remove or archive after evidence review | Already ignored. Inspect named probe output before disposal. |
| `dogfood-output/` | Tracked screenshots, `.import` sidecars, and a report from manual/dogfood validation | Retain the report and intentionally selected screenshots; review generated sidecars | Existing evidence is useful, but the tracked set needs an explicit owner and retention decision. |
| `dogfood-output/gate1-*` | Runner-owned logs and per-case user-data roots | Ignore/remove after the evidence snapshot is accepted | `.gitignore` already targets this output pattern. |
| `.pytest_cache/` | Local Python test cache | Ignore and remove | It is not source or a fixture; the ignore rule is currently missing from `.gitignore`. |
| `icon.svg.import` and `dogfood-output/**/*.import` | Godot-generated import metadata | Review for removal and a repository-wide ignore rule | These are generated sidecars, not authored assets; do not remove while checking tracked evidence. |
| `btnroll_probe.gd.uid` | Root-level UID with no matching root probe source observed | Review as an orphan; remove only after confirming no scene/reference needs it | Do not delete generated metadata during this inventory pass. |
| `src/**/*_probe.gd`, `scripts/validate_*.ps1`, `scenes/*probe*.tscn`, `data/fixtures/` | Repository-owned validation fixtures and supported probes | Retain and document | These are named evidence paths, not disposable output. |
| `docs/`, `roadmap.md`, `.questboard/quests/` | Durable docs and shared coordination state | Retain | They record contracts, evidence, and current work ownership. |
| `.agents/`, `.cursor/`, `.obsidian/`, `.codegraph/` | Agent/editor/index state | Retain locally or exclude from a publication candidate according to project policy | These are not runtime game assets; `.codegraph/` is rebuildable and `codegraph_setup/` is embedded tooling. |
| `codegraph_setup/` | Embedded external tooling checkout | Keep outside the game publication boundary; do not treat as game source | Already ignored by `.gitignore`; verify publication excludes it. |

## Current boundary

No deletion was performed. The only directly actionable follow-up is a
reviewed cleanup patch that adds missing ignore coverage, decides whether
tracked dogfood screenshots are intentional deliverables, and removes only
validated generated sidecars/orphans with path checks. The cleanup card must
remain separate from this inventory.
