# Batch 046 build: S-066 / S-169

Base: `batch-045-s064-s168` @ 864610f (stacks on #13).

## Selection
| Slice | Deps | Decision |
|---|---|---|
| **S-066** Qualified work/study progress | S-064 (045, #13), S-032 (Verified VS-100) | **Chosen.** It is the root of the work thread and unblocks S-067, which in turn unblocks S-198 and S-207. |
| **S-169** Escape/rescue and destroyed-anchor cleanup | S-168 (045, #13), S-119 (034, #1) | **Chosen.** It completes V-064 and unblocks S-171. |
| S-197 Liquid/fuel quantities | S-196 (043), S-064 (045) | Ready, but not chosen. It is narrower (fuel quantities only) and unblocks nothing listed. Next candidate. |
| S-067 | S-066 | Not ready until this batch is accepted. |

There are no collisions with the exclusions. Tether `capacity` behavior is unchanged (045 N1 is pending Brandon).

## Design
### S-066 `WorkRules` (src/characters/work_rules.gd)
- **Item policy:** `work {required_seconds, daily_seconds, participants?, concentration?, on_interrupt: keep|reset}`. DataLoader validates it.
- **Copy state:**
  - `work_progress_seconds`
  - `work_active`
  - `work_participants` (the worker first)
  - `work_day` and `work_day_seconds`
- **Accrual:** `settle`, driven by `GameManager.advance_campaign_time`, accrues only eligible time:
  - The worker carries the copy at hand (equipped or in the backpack, not stowed).
  - Every participant is a conscious party member.
  - If the policy sets `concentration`, the worker holds no spell concentration.
  - At most `daily_seconds` accrue per campaign day. The rest of the day counts as rest, and a reset does not refund the day's allowance.
  - Too few participants means waiting: nothing accrues and nothing is lost.
  - Accrual stops exactly at `required_seconds`.
- **Interruption:** each case follows the authored `on_interrupt` policy (keep or reset). The triggers are:
  - stopping
  - the copy changing hands
  - a participant dropping
  - concentration
  - combat start (`CombatState._interrupt_work_for_combat`)
- **Stowing:** an active work copy can't be stowed (`ContainerRules.put_error`).
- **HUD (local room):** Start work, Join work (joins the selected party member's work), Stop work.

### S-169 tether rescue and cleanup (`TetherRules`)
- **New optional effect fields:**
  - `rescue: ["STR"|"DEX"]`: another creature may pull the victim free.
  - `hp: 1-100`: the tether's own hit points.
- **Damage routing:** `rescue(rescuer, victim, captors, "check"|"strike", source?)` routes to one exact tether.
  - `check`: the rescuer's best declared ability against the tether DC.
  - `strike`: the rescuer's weapon damage plus STR (characters) or melee attack damage (monsters), applied to the tether's hp.
  - Only that tether ends. The concentration ends if no targets remain, and other restraints stay.
  - The captor and the victim can't rescue.
- **Callers:**
  - Monster AI: `CombatState._try_monster_rescue_tether`. An ally next to a tethered monster spends its turn to strike, otherwise to pull.
  - Players in combat: `_try_rescue_tether`. Clicking an adjacent tethered ally spends the Action.
  - Local room HUD: Rescue and Cut tether, aimed at the selected party member.
- **Destroyed victim:** `enforce_range` (run on every grid update and round tick) releases a dead monster victim's tether.
- **Destroyed or moved anchor:** a knocked-out captor ends concentration through the existing knock-out route, which frees only that captor's victims. Moving the anchor out of range was already covered by 045 R1.
- **Saves:** the remaining tether `hp` is saved as the record's 9th key and validated against the spell. A missing value or one above the spell's maximum is refused.

## Mandatory checklist
- **(a) Refuse before paying.**
  - `TetherRules.rescue_error` runs before the Action is spent in `_try_rescue_tether`, before the monster's turn is used, and before any HUD time is charged. A refusal result has no `seconds`.
  - Scenario: "refused rescue leaves the Action unspent". Logic: "the captor and the victim cannot rescue; refusal spends nothing".
  - `WorkRules.start_error` and `join_error` refuse before any state changes. Logic: "starting work on a copy not at hand refuses with nothing changed".
  - Stowing active work is refused before anything moves. Scenario: "refused stow leaves the active work and its progress untouched".
- **(b) Records validated.**
  - `WorkRules.record_error` is called from `InventoryCopies.record_state_error`.
  - Logic checks cover a carried copy, six tampered variants, and a copy nested in a container.
  - Tether `hp` goes through `TetherRules.saved_error` in both SaveManager paths, as before.
- **(c) Production callers.** The coverage grep found every public function in WorkRules and every new TetherRules function called from non-test code or from such a function. The callers are:
  - game_manager, combat_state
  - local_room_view, container_rules
  - inventory_copies, data_loader
- **(d) Real persistence.** The scenario does a real `SaveManager.save_game`/`load_game` with two active works, one of them a group work, with no cache clearing. It then asserts exact progress and participants, resumed accrual, and a per-work reset.

## Validation (all Godot runs strictly one at a time)
- **Full logic suite:** 5325 passed, 0 failed.
- **Fresh 864610f baseline, run alone:** 5294 passed, 0 failed.
  - The delta is +31, matching the 31 `check.call` lines in batch_046_checks.gd.
- **Scenarios:**

  | Scenario | ok |
  |---|---|
  | 031 | 25 |
  | 032 | 33 |
  | 033 | 70 |
  | 034 | 10 |
  | 035 | 9 |
  | 036 | 7 |
  | 037 | 11 |
  | 038 | 7 |
  | 039 | 10 |
  | 040 | 13 |
  | 041 | 11 |
  | 042 | 9 |
  | 043 | 11 |
  | 044 | 12 |
  | 045 | 16 |
  | 046 | 15 (12 own plus 3 shared 036 cast confirmations) |
  | shared_spell_flow | 67 |

  There were 0 FAIL lines.
- **Error grep:** 0 SCRIPT ERROR / Parse Error lines.

## Values
- Every number is a fixture value: required, daily and participant counts, tether hp 5, and the rescue DC, which is the spell save DC.
- No SRD numbers are claimed.
- No SRD 5.2.1 crafting or downtime times are used, because the fixture work items aren't SRD content.

## Limits
- Work exists only on item copies. "Proximity" means the copy is carried at hand. There is no spatial co-location check for participants, beyond them being conscious party members.
- Work accrues only through campaign-time advances, and combat interrupts it. Completion only marks the copy complete; S-067 owns completion firing once, deadlines and materials.
- The HUD Join work targets the selected party member's first active work.
- Rescue and Cut in the local room skip the adjacency check (the party shares the room). In combat, rescue is adjacency-checked.
- A player can rescue only a tethered player, since only players cast tethers. In the scenario, the monster-ally rescue is the live combat route.
- `strike` uses only weapon or melee damage and ignores damage types and resistances. There is no attack roll against the tether: damage applies automatically.
- The destroyed-anchor case uses the captor-as-anchor knock-out route. There are no separate object anchors.
- Tether capacity semantics are unchanged (pending decision).
- Item types are fixtures (F3).
