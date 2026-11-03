# Fresh Ziva sessions

`tools/ziva_session.py` starts a new conversation in the running Ziva Godot
editor without computer use. It uses the local panel's private production RPC
API, verified against Ziva v3.3.3 on 2026-11-02. This is separate from Ziva's
public MCP tools, which expose Godot operations but no chat creation tool.

From the project root:

```powershell
python tools/ziva_session.py new --title 'Inspect the character chooser' --mode ask --prompt 'Inspect the character chooser and explain the current behavior. Do not edit files.'
python tools/ziva_session.py new --title 'Bounded implementation task' --prompt-file .artifacts/ziva-task.txt
python tools/ziva_session.py list
python tools/ziva_session.py status CHAT_ID
```

`new` sends the initial prompt without a chat ID, history, fork parent or resume
cursor. Ziva creates the conversation and native model session. The launcher
returns the new chat ID immediately; `status` reads its latest transcript,
running state, and pending questions/permissions. It does not answer approvals.
It does not select the chat in the dock or stop another conversation's work.
Use a bounded task that avoids files another running chat owns.

The default route is `ext:chatgpt:gpt-6-luna`, standard tier, high reasoning,
matching the owner's existing connected Codex Luna chats. `--model`, `--effort`
and `--mode` override this for the new chat only. The launcher never silently
falls back to a hosted model. Provider allowance still applies; this connection
does not establish that model requests are free.

Fresh means no inherited conversation history. Ziva still supplies its system
prompt, project instructions, current editor context and enabled project
memories. This tool does not change the global memory setting.

The default local origin is `http://127.0.0.1:7012`; override it with
`--url http://127.0.0.1:PORT` before the subcommand if Ziva moves ports. Check
Ziva's current settings/logs for its actual origin. Only loopback HTTP is
accepted, and the bootstrap project path must match this checkout.

This private interface can change after a Ziva update. Never retry a failed
`new` blindly: a timeout can occur after creation. Run `list` and inspect the
new conversation first. No database edits or plugin binary changes are needed.

## Verified boundary

Created an Ask-mode connection-check chat, explicitly using the existing Luna
route. It returned a new chat ID and native session ID, contained exactly one
user message and one assistant reply, had no older messages, and finished idle
with `ROOK_FRESH_SESSION_OK`. No editor tools or gameplay changes were requested.
Static inspection of the shipped panel established `chats/sendPrompt` and
`chats/snapshot`; live RPC calls established creation and reply retrieval.
Investigation artifacts are ignored under `.artifacts/ziva-native/`.
