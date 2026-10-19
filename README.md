# Crown & Company

Godot 4.7 top-down party game prototype with local 1–4 player Crown campaigns.
The shared data-driven rules runtime is partly implemented and already used by
selected spells and features. Older named helpers still run unmigrated behavior;
neither the engine vocabulary nor the content catalog is complete.

## Start here

Agents read [AGENTS.md](AGENTS.md) first, then the
[roadmap](roadmap.md), [current checkpoint](docs/operations/current.md) and
[architecture map](docs/architecture/README.md). The Quest Board records the
selected task and ownership. Read the selected slice and relevant contract next;
do not reconstruct the current plan from old reports.

For rule-source preparation, start with the selected class in
[the 2024 reference view](reference/2024/README.md). Those files contain only
the revised records from the local mixed-edition extracts. They are reference
material, not official SRD verification or runtime definitions.

| Folder | What belongs there |
|---|---|
| `src/`, `scenes/`, `assets/`, `theme/`, `addons/` | Game implementation, presentation and existing addons. |
| `data/core/`, `data/mods/` | Loaded game definitions. They describe current implementation, which can still differ from the intended rules. |
| `data/fixtures/` | Test definitions exercising real runtime paths; not ordinary campaign content. |
| `reference/2024/` | Reproducible revised-only class references and original-source coordinates. |
| `5etools raw/` | Original mixed-edition import inputs, retained unchanged. Use the revised view for ordinary source tasks. |
| `docs/` | Current contracts, plans, architecture and documentation map. |
| `docs/archive/` | Historical gates, reports, old checkpoints and completed prompts. Read only when a current task needs that evidence. |
| `scripts/`, `run_tests.ps1` | Development tools and supported Windows verification entry point. |
| `_staging/`, `.artifacts/`, `dogfood-output/`, `playtest-evidence/` | Staged content or retained work/evidence, not current instructions. |

Root `items.json`, `loot.json`, `races.json` and `skills.json` are retained
reference/import inputs; they are not substitutes for loaded definitions or
official rule sources. Do not relocate them without checking their consumers.
The [documentation map](docs/README.md) locates the remaining contracts.

## Run

Open the project in Godot 4.7.x and run the main scene. Windows is the supported
validation host; supply a portable console executable:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 `
  'C:\path\to\Godot_v4.7-stable_win64_console.exe'
```

Use `-Suite logic` for parsing, boot and logic checks. The default also runs
the isolated integration matrix. See [testing](docs/testing.md) for focused runs.

## Current playable boundaries

- One to four logical seats share a keyboard and four stable party slots.
  Camp Roster recruits and assigns companions; one leader controls exploration.
- Safe saves exist in the overworld and at dungeon-entry checkpoints.
  New campaigns use schema 2 under `user://saves/dnd2024/`; legacy files remain
  untouched and incompatible. Active combat/local-room saves are unavailable.
- Crown progression is level 1–5. Defeat and provisional completion have
  visible screens; full campaign readiness and rules fidelity are not certified.
- Creation offers twelve core classes, all partial. Selected progressions
  reach level 20 with curated choices; see [mechanics contracts](docs/mechanics/README.md).
- Ordinary spells can use validated [shared JSON execution](docs/mechanics/shared-spells.md),
  including bounded ordered attack/save steps. General class/creature execution
  and many world interactions remain unfinished; each contract states its limits.
- The approved grimoire shell includes campaign activity history. Presentation
  evidence and limits live in [visual acceptance](docs/ui/VISUAL_ACCEPTANCE.md).

Runtime content loads from sorted core/mod roots with explicit manifest
collisions. The importer stages output and never overwrites curated core data;
see [content pipeline](docs/content_pipeline.md) and [authoring](docs/modding_guide.md).
The Beckett development addon is disabled by default. Publishing, controllers
and networking remain parked until wanted.
