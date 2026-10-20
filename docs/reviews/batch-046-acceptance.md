# Batch 046 acceptance review: S-066 / S-169

Reviewer: Runtime Reviewer. Reviewed head 53a33fc on 045 @ 864610f. Every Godot run was done alone.

## Verdict
**Accept with review fix R1.** The fix is committed on top of the builder head.

## Finding
**R1 (defect, S-066 finish line "actual eligible work"): the same hours could be counted twice.**
- A character could accrue the same hours on several works at once:
  - by starting a second work while one was underway (two tomes)
  - or by working their own copy while also being a participant in another character's group work
- The builder's own scenario relied on it. Character a kept studying the tome while helping on the frame, so the tome's expected 3600 + 1800 counted 1800 s that were also spent on the frame.
- SRD 5.2.1 downtime activities are one at a time.

**Fix:**
- `WorkRules.busy_on` makes `start_error` and `join_error` refuse a character who is already a participant in any active work. The refusal happens before anything changes.
- `WorkRules.party_error`, run from `InventoryCopies.ownership_error` in both SaveManager paths, refuses a save that double-books a participant.

**Checks:**
- RW1–RW3 fail at 53a33fc (5331/3) and pass with the fix.
- The scenario now:
  - asserts that a busy helper is refused and must stop first
  - keeps the group work's participants across a real save/load
  - adds RW10: a group-work participant can't start a second work

## Probes that passed (no defect)
- **RW4:** tampered progress (negative or above the required time) and a day ledger above the daily allowance are refused.
- **RW5:** a partial span that crosses midnight splits into each day's ledger.
- **RW6:** a captor dropped to 0 HP by real `take_damage` loses concentration, and the victim is freed.
- **RW7 (045 R2 interplay):** with two tethers, cutting a named source leaves the other tether and its restraint.
- **RW8:** an incapacitated rescuer is refused before cost.
- **RW9:** partial tether hp persists. Zero hp and hp above the maximum are refused.
- **045 R1:** grid-update range enforcement and the new destroyed-victim release share `enforce_range`. RT1–RT6 stay green.

## Notes (owner decisions or known limits)
- **N1: rest and ritual time count as work.**
  - Rest and ritual time go through `advance_campaign_time`, so they accrue work. The daily cap bounds the total.
  - SRD 5.2.1 allows reading as a Short Rest activity, and up to 2 hours of light activity during a Long Rest. Whether full-attention study counts is a policy question, not a clear defect.
  - The overworld day turn (86400 s) is the main way time accrues.
- **N2:** the work's `concentration` gate applies only to the worker. Helpers may concentrate on a spell while helping.
- **N3:** the participant list isn't checked against the copy holder in saves. A forged worker is interrupted on the first settle (under reset, that loses progress), so there is no gain.
- **Fixture-only values:** no `work` or `bind_tether` appears in `data/core`.

## N1 count
- The builder reported 5325 / 0 (5294 + 31). I didn't run the builder head as-is: my pre-fix probe (builder head plus the RW checks, without the fix) got 5331 passed / 3 failed (5334 − 9 RW checks = 5325), consistent with the builder's count.
- After review: 5334 / 0 (+9 RW1–RW9).
- Scenario 046 has 16 ok lines: 13 of its own, including RW10, plus 3 shared 036 cast confirmations.
