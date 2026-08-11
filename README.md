# Top Down Party Game

Godot 4.7 top-down party game prototype for local 1–4 player Crown campaigns.

## Run

Open the project in Godot 4.7.x and run the main scene. For the supported
Windows validation loop, pass a portable console executable:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 `
  'C:\path\to\Godot_v4.7-stable_win64_console.exe'
```

Use `-Suite logic` for the fast parse, boot, and logic checks. Omit the suite
to run the complete isolated integration matrix.

## Current playable contracts

- The Lost Crown supports 1–4 local player seats.
- Four stable party slots can hold player characters and recruited companions.
- The overworld Camp Roster recruits, declines, dismisses, replaces, and assigns
  companions to logical local seats.
- Safe saves are available in the overworld and at dungeon-entry checkpoints.
- Defeat and provisional completion have visible terminal screens.
- Settings volume controls target distinct Master, SFX, and Music buses; audio
  assets remain optional, so missing sound files are reported and skipped.
- The current rules cohort proves Fighter, Rogue, Wizard, and Cleric mechanics,
  plus selected Barbarian, Monk, Paladin, and Ranger contracts, including
  Ranger Favored Foe and Hunter's Mark; unsupported active features remain
  unavailable rather than inert.

The project is still a development candidate. The remaining roadmap work covers
broader class coverage, campaign smoke from creation to completion, interruption
recovery, and fresh-clone/manual validation.

## Content and development boundaries

Runtime content is loaded from sorted `data/core` and `data/mods` roots with
explicit collision decisions in `data/content_manifest.json`. The 5eTools
importer requires an explicit `--external-data-dir`, stages output under
`data/imported`, and emits a collision/coverage report without writing inside
`data/core`. The Beckett addon is not enabled in the default project
configuration.

See [roadmap.md](roadmap.md), [testing](docs/testing.md), and
[development operations](docs/operations/development.md) for the current
contracts and known limits.
