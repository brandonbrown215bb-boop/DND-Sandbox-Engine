---
kind: architecture
verified_at_commit: working-tree-2026-08-10
scope:
  - src/**
---

# Architecture

## Purpose

This repository contains a Godot 4.7 top-down party game. The production
project is launched from `scenes/main.tscn`; the Gate 1 developer loop launches
the same project context through `scenes/parse_gate.tscn`,
`scenes/boot_gate.tscn`, `scenes/test_runner.tscn`, and
`scenes/viewport_harness.tscn`.

## Boundaries

Autoloads under `src/autoload/` own cross-scene state and services such as
`GameManager`, `PlayerManager`, `PartyManager`, `SaveManager`, `Settings`, and
`DataLoader`.

`ActivityHistory` owns the campaign-scoped player activity ledger. It assigns
stable monotonic sequence IDs, retains immutable copies of at most 200
top-level records, and exposes versioned JSON-safe snapshots. `ActivityRecord`
validates the shared DTO and the resolved roll payload; gameplay resolvers,
rather than `Dice` or presentation code, remain responsible for publishing
final outcomes.
Gameplay scenes under `scenes/` coordinate domain objects and UI modules under
`src/ui/`. `src/viewport_harness.gd` is test code: it instantiates real scenes
inside isolated `SubViewport` trees and never replaces its supervisor during a
test-mode victory or save/load round trip.

`DataLoader` loads sorted core and mod directories and requires every duplicate
ID to be named in `data/content_manifest.json`. Curated fields win approved
collisions; imported fields fill only missing descriptive metadata. Unsupported
effectless features are removed from player-facing class records until a
resolver or effect is curated.

`SaveManager` is the persistence boundary. It writes versioned plain DTOs only
from overworld or dungeon-entry checkpoint states. Campaign ledgers and
dungeon rooms are stored by stable IDs and arrays, never as live Godot objects.
Corrupt or unsupported saves are validated before active managers are changed.
Activity snapshots are prepared before manager mutation; malformed or future
activity records are omitted with diagnostics without rejecting a readable
campaign save.

`PartyManager` owns four stable party slots, character identity, companion
recruitment state, leadership, and the assignment of slots to local player
seats. Combat derives its participant list from the active party. The milestone
input contract is shared-keyboard hot-seat; physical device bindings remain
transient and their hardware acceptance is post-Gate 8.

`CombatState` coordinates the tactical scene and turn sequencing. Its mutable
per-turn action, bonus-action, and reaction budget lives in the narrow
`CombatTurnBudget` boundary, which is independently testable and does not own
presentation or combat resolution.

`DataLoader` validates cross-record references after all registries load. A
campaign cannot reach runtime with missing goal items, monsters, dungeon loot,
or event tables, and class spell access cannot name a missing spell.

## Data and Control Flow

Production boot enters `src/main.gd`, which transitions to the main menu during
normal play. Terminal defeat and completion states route to dedicated screens.
The Beckett addon is intentionally not enabled in the friend-facing project
configuration; local development can enable it explicitly in an editor copy.
The supported Windows Gate 1 runner starts each case in a fresh
Godot process, loads the project scene, waits for a marker, scans captured
output for unexpected errors, and fails on timeout or non-zero exit.
Save/settings tests use `user://`, while the runner redirects the Windows roots
behind `user://` per scenario.

## Invariants and Sharp Edges

`GameManager.test_mode` is a harness boundary, not a production save policy:
test-mode combat and load flows restore logical state without replacing the
harness scene tree. The runners must continue to accept a portable Godot path
through `GODOT_BIN` or an explicit argument and must not use a developer's real
profile data.

## Validation

See [validation](../operations/validation.md) and [testing](../testing.md).
