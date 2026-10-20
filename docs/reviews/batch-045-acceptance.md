# Batch 045 acceptance review: S-064 / S-168

Reviewer: Runtime Reviewer. Reviewed head 2de46a8 on 044 @ c3e88d1.

## Verdict
**Accept with review fixes R1 and R2.** These fixes are committed on top of the builder head.

## Pre-check: the 044 baseline
- I ran the logic suite on a clean c3e88d1 worktree, alone (no other Godot process): **5261 passed / 0 failed**.
- The builder's 3 LogPanel UI failures (5258/3) do not reproduce in isolation. They come from running suites concurrently, not from a regression in 044.
- I ran a cold `--import` three times (with `.godot` removed each time): exit 0 every time, with no segfault. A segfault seen elsewhere would be flaky Godot or concurrency, not code.

## Findings and fixes
- **R1 (defect, weak spot 2): tether range was checked only at round ticks.**
  - SRD 5.2.1 Grappled says the condition ends if the distance between the grappler and the target exceeds the grapple's range. That has no timing qualifier, so it applies immediately.
  - The S-168 finish line binds the captor, victim and anchor "with range".
  - Before the fix, a captor who walked or teleported away mid-turn left the victim restrained until the end of the round.
  - Fix: `CombatState._enforce_tether_range()` now runs on every `_update_grid_entities()`, which every move, teleport and forced-move path calls. It still also runs at the round tick.
  - The scenario check RT1 casts the tether, moves the captor out of range and calls only a grid update. The tether and its restraint end at once, and active time is not spent.
- **R2 (weak spot 3): escape always took the first binding tether.**
  - Escaping refers to an exact tether, and it never ended another source's restraint, so the finish line was met.
  - The engine still had no way to aim an escape at a particular tether.
  - Fix: `TetherRules.escape(..., source)` names the exact tether to escape.
  - The HUD and monster AI still use the first binding tether. That is a known limit, because there is no picker UI.
  - Covered by RT2: with two captors, escaping a named tether frees only that one. The other tether and the restraint stay, and retrying the escaped tether changes nothing.

## Notes
- **N1: tether capacity above 1 can't be reached.** Each tether is owned by its own concentration source, and a caster holds only one concentration. So `capacity` 2–4 passes the loader but can never take effect. A full-capacity recast is refused before cost (RT4 and the scenario), whereas the SRD would let a new concentration spell replace the old one. This is fixture semantics and needs an owner decision: either limit the loader to 1, or support capacity once multi-target concentration exists.
- **Fixture-only values:** no `bind_tether` or `active_time` appears in `data/core`. All values are fixtures, and no SRD numbers are claimed.

## Stress
- RT1 is in the scenario.
- The logic checks are:
  - RT2 (two checks): multiple tethers.
  - RT3: inclusive range, and a teleport one hex beyond breaks the tether and ends its concentration.
  - RT4: refusal before cost.
  - RT5: tampered DC, a missing concentration source and self-binding are refused.
  - RT6: a legacy save validates.

## N1 count
- Builder head: 5288 / 0, which is 5261 + 27.
- After review: 5294 / 0, which adds RT2–RT6.
