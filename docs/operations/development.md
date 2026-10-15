# Development

The [current checkpoint](current.md) records accepted verification; the Quest
Board owns the exact next action under the [roadmap](../../roadmap.md).
Work solo by default; use a focused independent reviewer for shared combat rules
or persistence when the reviewer tooling is available. Missing optional grounding
tools do not block work. Historical gate reports are not current acceptance.

On this host, the owner's existing portable Godot is available at
`.artifacts/tools/godot/Godot_v4.7-stable_win64_console.exe` (ignored, not shipped).
`run_tests.ps1` discovers it without `GODOT_BIN` or a Godot entry on PATH. Discovery
order is explicit `-GodotPath`, `GODOT_BIN`, this project-local console executable,
then `godot`/`godot4` on PATH. An invalid explicit override fails rather than silently
using a different engine. The selected absolute executable path is printed.
The runner isolates save/settings profiles under `.artifacts/tests/<run-id>/`
inside the project by default. Older notes about requiring an outside-sandbox
profile are superseded; use the current runner before assuming a host issue.

The supported Windows validation entry point is the PowerShell runner. For the
existing project-local engine, a focused command needs no path setup:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 -Suite logic -LogicGroup spells
```

Useful bounded runs:

```powershell
.\run_tests.ps1 -Suite logic -LogicGroup spells
.\run_tests.ps1 -GodotPath '.\.artifacts\tools\godot\Godot_v4.7-stable_win64_console.exe' -Suite logic -LogicGroup spells
python .\src\generate_feature_matrix.py
```

The 5eTools importer requires an explicit source path and never uses a
developer-specific absolute path:

```powershell
python .\src\convert_all_5etools.py --external-data-dir 'D:\5etools-src\data'
```

Generated importer output is staged under `data/imported/` by default. To use a
separate staging root and report path:

```powershell
python .\src\convert_all_5etools.py `
  --external-data-dir 'D:\5etools-src\data' `
  --raw-dir '.\5etools raw' `
  --output-dir '.\.artifacts\imported' `
  --report '.\.artifacts\import-report.json'
```

The importer refuses `data/core/` output and writes a collision/coverage report.
Review staged output and the report against `data/content_manifest.json` before
any deliberate promotion into curated records.

Save writes use a temporary file plus a previous-save backup. Startup/load
recovery can use the backup if the primary file is interrupted or malformed;
the next successful save removes the backup after commit.

The Beckett addon is not enabled by default. If local editor tooling is needed,
enable the addon in a developer-only project copy; do not commit that setting
into the friend-facing project configuration.

Windows uses the Compatibility renderer through ANGLE/Direct3D 11, with a
60 FPS cap, as a workaround for an owner-reported desktop freeze under native
OpenGL. The original cause remains unconfirmed. For a deliberate native-OpenGL
comparison, `--rendering-driver opengl3` overrides the Windows project setting;
normal launches should use the configured ANGLE path. A successful launch alone does not prove the original freeze cause is resolved.
