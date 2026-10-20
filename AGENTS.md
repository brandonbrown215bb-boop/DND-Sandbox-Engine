# AGENTS.md — Rook

This is a hobby game: one shared, data-driven D&D 2024 rules engine in Godot.
Talk plainly. Prefer the simple thing that works; don't invent work, layers,
or hypothetical scale problems. Say what's broken and what we'll notice.

## Start here

- Follow the owner's request and [roadmap.md](roadmap.md). Read the selected
  [slice](docs/planning/vocabulary-slices.md) and relevant technical reference;
  don't reconstruct priorities from old reports or completed conversations.
- [ADR-0018](docs/decisions/0018-shared-data-driven-rules-runtime.md) owns the
  shared-runtime direction. JSON defines rules; GDScript supplies generic
  operations and world hooks. New supported definitions must not require
  branches or registration for their spell, class, feature, item or monster ID.
- Delivery remains vocabulary-first: implement and verify the engine pieces,
  prepare executable data, then replace the hardcoded paths. Production-path
  fixtures can prove a slice; catalog conversion is separate. Keep native paths
  until their replacements handle the content that still uses them.
- SRD 5.2.1 is the staged core-12 rules authority; Artificer and Mystic remain
  outside that milestone. Source tasks start at [reference/2024/](reference/2024/README.md)
  and the selected class view. Existing data and reference metadata aren't proof
  of rule correctness. Wish/illusion policy remains in ADR-0023.

## Working rules

- Work solo by default. For shared combat rules or persistence changes, use one
  focused independent reviewer with a concrete question and reproducible checks.
  If reviewer tooling is unavailable, continue solo and state that limitation.
- Quest Board is optional for actual concurrent work. Solo work, planning and
  routine reviews need no card. When coordinating there, inspect current claims,
  respect occupied scope, and leave the next action for work you hand off.
- Runtime work owns game source, loaded data and runtime contracts. The editor
  pipeline owns `tools/content_editor/`; exchange candidate exports and pinned
  examples rather than editing each other's files. See [content pipeline](docs/content_pipeline.md).
- Source and production Godot checks determine behavior. [Architecture](docs/architecture/README.md)
  locates code; [mechanics](docs/mechanics/README.md) describes executable syntax
  and limits. Read only what the task needs. If `.codegraph/` exists, try it first
  when it indexes GDScript; otherwise use `rg`. Missing tools aren't a blocker.
- Preserve unrelated work and generated/source boundaries. Preserve legacy saves;
  new campaigns use the 2024 namespace, with no automatic migration. Existing
  source identity, once-only costs and allowed-checkpoint guarantees still apply.
- Ask before deleting files, installing tools, publishing, or making changes that
  are hard to undo, unless the owner has already authorized that action. Keep
  tokens and machine-local configuration out of tracked files.

## Checks and finishing

- Use the supported Windows Godot runner for gameplay and save checks. Python
  validates structure and inventory, not a second implementation of the rules.
  See [testing](docs/testing.md) and [development](docs/operations/development.md).
- Run checks relevant to the changed behavior. Add regression tests for actual
  failures or likely breakage; don't chase counts or repeat green runs without
  new evidence. Documentation-only work needs link and consistency checks.
- Update the technical reference whose behavior changed. Slice status and its
  verified boundary belong in the slice registry; broad requirements belong in
  the vocabulary checklist. Don't duplicate receipts across guides.
- Finish with a short conversation result or existing PR description: what works,
  material limits, and relevant checks. No PR, separate build/acceptance report,
  owner-decision record, or quest card is required for ordinary work. Raw logs
  belong in ignored artifacts. Only durable design decisions need an ADR.

## Beckett

Use Beckett when live Godot observation or editor authoring helps. Routine source
edits and headless checks don't need it. Follow [the connection recipe](docs/operations/development.md#beckett-live-godot-access),
keep tokens private, and keep Beckett disabled in the main project. Its isolated
editor is a snapshot: refresh relevant source before claiming current behavior,
preserve local configuration/save profiles, and bring intended edits back
explicitly. Lite doesn't automate runtime input. Stop play sessions you start.
