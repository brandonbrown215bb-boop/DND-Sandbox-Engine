# Post-combat victory state contract

Evidence for `Q-20260810-163315-4a24`, reproduced against Godot
`4.7.stable.official.5b4e0cb0f` on Windows.

## Reproduction boundary

The probe uses the production `dungeon.tscn` and `combat.tscn` scenes,
`GameManager.enter_dungeon`, the dungeon's real combat-entry path, the shared
`CombatState._check_battle_end_conditions()` terminal method, the production
`BattleResultOverlay`, and the production Continue signal. It explicitly keeps
`GameManager.test_mode = false`. The encounter result is controlled after
scene spawn so the state-boundary observation cannot stall in unrelated AI or
reaction UI.

```powershell
$env:APPDATA = (Resolve-Path '.artifacts/normal-victory-appdata').Path
$env:LOCALAPPDATA = (Resolve-Path '.artifacts/normal-victory-localappdata').Path
& 'C:\Users\brand\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe' `
  --headless --path (Get-Location).Path `
  'res://scenes/normal_victory_contract_probe.tscn'
```

The probe exited `0`. The expected Windows certificate-store error and the
existing DataLoader quarantine warning were the only unrelated stderr output.

## Contract observation

| Boundary | Expected | Observed |
|---|---|---|
| Victory payoff | Visible `VICTORY` overlay with Continue and Main Menu | Pass: overlay visible; title `VICTORY`; subtitle present; both buttons present |
| Combat input | Disabled while the result overlay owns input | Pass: combat input was `false` |
| Combat result | Victory registered defeated monster and preserves character state | Pass: defeated `zombie`; HP `10000/10000`; feature uses retained; no spell slots in this fighter fixture |
| Continue transition | Return to the dungeon state | Pass: `COMBAT -> DUNGEON`; returned scene input was enabled |
| Dungeon room reconstruction | The pending room is present and can be completed | Fail: `rooms_type=Dictionary`, `rooms_count=0`; `Pending combat room 1 was not found` |
| Encounter ledger | Returned room is cleared and pending combat is reset | Fail: `room_cleared=false`, `pending_combat_room_id=1`, `boss_defeated=false` |
| Player position | Party remains on the resolved room | Pass: `(-1, 0)` survived the transition |
| Rewards and campaign progress | Apply only after the resolved room is found; no duplicate reward | Not reached: room completion failed before the normal reward boundary |

## Root boundary

`DungeonState._save_dungeon_state_to_manager()` stores `rooms` as a Dictionary
whose values are live `Room` objects. On return, `DungeonState._ready()` only
restores `active_dungeon_state.rooms` when it is an Array of DTOs; a Dictionary
falls through to `rooms = {}` while `pending_combat_room_id` remains `1`.
`_complete_pending_combat()` then cannot find the room. This leaves an empty
or grey dungeon presentation with an unresolved encounter even though the
combat overlay and scene transition themselves completed.

## Follow-up

Focused repair card: `Q-20260810-180454-f183`, **Restore dungeon room state
across combat victory return**. The repair must preserve the DTO persistence
boundary and add normal-mode proof for cleared-room state, pending-combat
reset, party position, rewards, character resources, and input recovery.

## Repair result

The focused repair accepts both the live in-memory `Dictionary[Vector2i, Room]`
state used across scene transitions and the Array-of-DTO form used by restored
saves. The normal-mode probe now reports:

```text
PERSISTENCE active_dungeon_state rooms_type=Dictionary rooms_count=5
DUNGEON_AFTER state=DUNGEON room_id=1 party_position=(-1, 0) room_cleared=true pending=-1 boss_defeated=false input=true
NORMAL_VICTORY_CONTRACT_PASSED
GODOT_EXIT=0
```

The Windows logic gate also passed `534 passed, 0 failed`. The repair card is
in `review` pending normal-play visual confirmation; the original contract
card remains in `review` as the evidence record.
