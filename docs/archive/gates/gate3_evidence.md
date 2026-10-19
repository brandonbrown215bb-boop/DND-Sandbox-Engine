# Gate 3 evidence

> **Archived material.** This preserves a past snapshot, not current instructions.
> Read the [current checkpoint](../../operations/current.md) and [roadmap](../../../roadmap.md) before acting.


> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

## Automated result

The current logic suite validates the implemented safe-save and campaign-state
boundary on Godot 4.7. The suite uses a disposable save slot and test-mode
restore so the active session is not replaced by a scene transition during the
round-trip assertion.

| Check | Result |
|---|---|
| Combat save rejection | Pass |
| Overworld save | Pass |
| Dungeon-entry checkpoint save | Pass |
| Plain DTO save payload | Pass; no `RefCounted` or `Vector2i` runtime values |
| Transactional test-mode load | Pass |
| Milestone and dungeon ledgers | Pass; values survive save/load |
| Stable party slots and companions | Pass; 521 logic assertions total |
| Repeated progression round-trip | Pass; reward ledger survives save, progress, save, and load |
| v1 compatibility fixture | Pass; `data/fixtures/save_v1_compat.json` validates without private paths |
| Rejected-save isolation | Pass; unsupported on-disk save leaves active state unchanged |
| Interrupted primary recovery | Pass; malformed primary falls back to `.sav.bak`, preserves slot discovery, and loads in test mode |
| Host process interruption | Pass; `scripts/validate_save_interruption.ps1` kills the real Godot process after backup staging, leaves `.sav.bak` plus `.sav.tmp`, and a fresh process restores the prior valid state |
| Fresh-process relaunch | Pass; `scripts/validate_fresh_relaunch.ps1` restores party identity, slot ownership, inventory, gold, round, campaign ledgers, and a derived next objective |

## Host interruption evidence

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_save_interruption.ps1 `
  "C:\Users\brand\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
```

The clean-room run used a unique temporary `APPDATA`/`LOCALAPPDATA` root and
the `gate3_interrupt` slot. The host killed the prepare process while the
previous primary had been renamed to backup and the new temporary save was
still present:

| Observation | Result |
|---|---|
| Primary after interruption | Absent |
| Backup after interruption | Present |
| Temporary save after interruption | Present |
| Fresh-process recovered round | `1` |
| Fresh-process recovered player | `Interruption Tester` |
| Fresh-process recovered defeated ledger | `goblin` |
| Fresh-process recovered milestone ledger | `enter_dungeon_1` |

The expected Windows certificate-store error and the existing DataLoader
quarantine warning were the only stderr output. The process boundary proof is
passing; the validator performs best-effort cleanup of Godot's paired Windows
processes after the recovery marker.

## Fresh-process relaunch evidence

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate_fresh_relaunch.ps1 `
  "C:\Users\brand\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
```

The validator staged `data/fixtures/save_v1_compat.json` under a unique
temporary `APPDATA`/`LOCALAPPDATA` root, enriched it through the normal load and
save path, then launched a separate recovery process. The recovery certificate
was:

| Observation | Result |
|---|---|
| Player identity | `Fixture Player` |
| `slot_0` owner | Local seat `0` |
| Current round | `4` |
| Inventory | `potion_healing` x1 and `73` gold |
| Defeated ledger | `goblin` |
| Milestone ledger | `enter_dungeon_1` |
| Cleared dungeon ledger | `ruins_of_ashvale` |
| Claimed reward ledger | `ruins_of_ashvale_fragment` |
| Next objective | `Next: The party clears the Ruins of Ashvale` was present |

The validator exited `0` and left no Godot processes running. The expected
Windows certificate-store error and existing DataLoader quarantine warning were
the only stderr output.

## Decision

`done`. SAVE-01 through SAVE-08 have implementation evidence; the core party
serialization boundary, compatibility fixture, malformed party-reference
rejection, rejected-save isolation, backup recovery, host process interruption,
and fresh-process relaunch are covered. Later content and manual co-op defects
remain downstream work and do not weaken this save-state gate.
