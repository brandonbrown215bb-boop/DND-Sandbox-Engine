# Development

The supported Windows validation entry point is the PowerShell runner. Supply
the portable Godot console executable explicitly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 `
  'C:\path\to\Godot_v4.7-stable_win64_console.exe'
```

Useful bounded runs:

```powershell
.\run_tests.ps1 'C:\path\to\Godot_v4.7-stable_win64_console.exe' -Suite logic
.\run_tests.ps1 'C:\path\to\Godot_v4.7-stable_win64_console.exe'
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
