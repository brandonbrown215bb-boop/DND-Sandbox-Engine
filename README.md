# Crown & Company

Godot 4.7 top-down party game prototype with local 1–4 player Crown campaigns.
Development is moving toward one shared data-driven rules runtime. The current
game still has partial rules and named helpers; the target interpreter is not
implemented. Start with the [documentation map](docs/README.md),
[roadmap](roadmap.md) and [current checkpoint](docs/operations/current.md).

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
- Ordinary spells can use validated [shared JSON execution](docs/mechanics/shared-spells.md).
  Mixed attack/save sequences, general data-defined class/creature rules and
  many world interactions remain unfinished.
- The approved grimoire shell includes campaign activity history. Presentation
  evidence and limits live in [visual acceptance](docs/ui/VISUAL_ACCEPTANCE.md).

Runtime content loads from sorted core/mod roots with explicit manifest
collisions. The importer stages output and never overwrites curated core data;
see [content pipeline](docs/content_pipeline.md) and [authoring](docs/modding_guide.md).
The Beckett development addon is disabled by default. Publishing, controllers
and networking remain parked until wanted.
