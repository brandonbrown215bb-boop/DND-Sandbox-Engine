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

## Beckett: live Godot access

The Beckett addon is not enabled by default. If local editor tooling is needed,
enable the addon in a developer-only project copy; do not commit that setting
into the friend-facing project configuration.

The 2026-10-19 local setup uses upstream **Beckett v1.16.0 Lite** from the
[tagged release](https://github.com/beckettlab/beckett-godot-mcp/releases/tag/v1.16.0).
The old v1.7.0 addon and original configuration are retained under
`.artifacts/beckett-update-v1.16.0/backup-v1.7.0/`. The enabled editor copy is
`.artifacts/beckett-editor/project.godot`; its Windows settings and game saves
use the adjacent `profile/` directory. Start it with
`& .\.artifacts\beckett-editor\Start-Beckett.ps1`. It serves authenticated MCP
on localhost port 8770. The ignored, project-scoped `.codex/config.toml` holds
the connection; reopen Codex after adding it so tools can be discovered.
The editor workspace is a **snapshot**, not linked source: copy newer source
into it while stopped and deliberately bring desired editor changes back to
the main working tree. Lite supports screenshots and live inspection; input
driving requires Full and was not carried over from the old addon. Verified
the MCP version/tool list, diagnostics, running-game connection, main-menu tree
and viewport capture; evidence stays in `.artifacts/beckett-update-v1.16.0/`.

### When to use it

Use Beckett for live UI bugs, screenshots, node/property inspection, runtime
errors with stack traces, engine/project class discovery, and editor scene
authoring. Use ordinary source tools and the existing headless checks when those
answer the question; Beckett need not run for every task. It supplements the
production checks rather than replacing gameplay or persistence verification.

### Connect from a new chat

Run commands from the repository root. Start the existing local editor if needed:

```powershell
& .\.artifacts\beckett-editor\Start-Beckett.ps1
```

The launcher reuses a running editor. Prefer normal graphical mode for viewport
captures. Discover exposed Beckett tools, then call `doctor` and `get_play_state`
before changing anything. If starting a new Codex session, have the server running
before MCP discovery. Native tool reconnection in an already-open chat is not
verified; do not repeatedly ask the owner to reload when the fallback works.

The authenticated Streamable HTTP endpoint is `http://127.0.0.1:8770/mcp`.
The connection lives in ignored `.codex/config.toml`; the live server token lives
in `.artifacts/beckett-editor/.beckett/token`. Read credentials programmatically;
do not print the config/token or copy credentials into documentation.

If native Beckett tools are absent, the existing standard-library Python client
can call the same MCP endpoint directly. This smoke check initializes the MCP
session, lists tools and calls engine/connection diagnostics without playing:

```powershell
python .\.artifacts\beckett-update-v1.16.0\verify_mcp.py
```

For individual tools, reuse that client's session and discover current schemas
instead of guessing arguments:

```python
import sys
sys.path.insert(0, '.artifacts/beckett-update-v1.16.0')
from verify_mcp import initialize, rpc

initialize()
tools = rpc('tools/list')['tools']
result = rpc('tools/call', {'name': 'get_play_state', 'arguments': {}})
```

The fallback also returns MCP content blocks: decode an image block's base64
`data` into a local PNG to inspect it; do not print the encoded image. Connection
refused usually means the editor/server is stopped. A sandbox socket-denied
error needs the normal tool permission flow, not a reinstall. These launcher,
profile and client paths are machine-local ignored artifacts; if missing on a
different checkout, report the missing setup rather than installing automatically.

### Working habits and limits

- Before verifying a new change, compare the relevant files with the editor
  snapshot. Refresh needed `src/`, `scenes/` or `data/` files while the editor is
  stopped, preserving its `project.godot`, addon, `.beckett/`, `.godot/` and
  `profile/` settings. Bring desired editor edits back to the main tree explicitly.
- Start a play test with `play_scene(quiet=true)` when no visible window is needed.
  Wait for `game_connected`, then the desired node; readiness can take repeated
  short `wait_until` calls. Do not interrupt a play session someone else started.
- Prefer `ui_snapshot` for visible controls and semantic states, `screenshot`
  for layout, `game_logs` for runtime output, and scoped `get_remote_tree` or
  `runtime_get_property` for live data. Use `help(tool=...)` for uncertain syntax.
- Address visible controls with the paths returned by `ui_snapshot`. A text
  selector can resolve an older hidden control with the same label.
- `validate_script` can compile-check in-memory content before any file write.
  Reflection tools include project `class_name` types as well as engine types.
- Lite's 56 advertised tools include editor authoring and live observation.
  Runtime calls, property writes and input automation are not advertised in Lite.
- Stop play sessions you started. Quiet off-screen startup FPS is not a normal
  gameplay benchmark. Raw local exploration evidence is retained under
  `.artifacts/beckett-exploration/`; its scratch scene stays in the editor copy.

## Windows renderer

Windows uses the Compatibility renderer through ANGLE/Direct3D 11, with a
60 FPS cap, as a workaround for an owner-reported desktop freeze under native
OpenGL. The original cause remains unconfirmed. For a deliberate native-OpenGL
comparison, `--rendering-driver opengl3` overrides the Windows project setting;
normal launches should use the configured ANGLE path. A successful launch alone does not prove the original freeze cause is resolved.
