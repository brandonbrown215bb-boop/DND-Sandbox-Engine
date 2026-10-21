# Batch 055 acceptance review (S-156 command authority)

PR #27, card Q-20261021-051202-9317. Reviewed head 774e14a, base 39b8304 (#26). Reviewer: runtime-reviewer.

## Verdict
ACCEPT after R1. S-156 finish line met: commands go to the exact owned actor id (two same-named wolves stay separate), the declared owner cost (action / Bonus Action / none) is charged once after full validation, uncommanded actors take the declared default at the end of the owner's turn, and control expiry stops commands without deleting the creature.

## Defects fixed
- **R1** — an incapacitated (e.g. Stunned) created actor could still be commanded; the owner's Bonus Action was spent and the actor attacked or dodged. It also took the default Dodge. SRD 5.2.1 (Incapacitated: no actions) forbids both. `command_error` now refuses it before cost, and `apply_defaults` skips it. Added one logic check.

## Probes (all refused before cost unless noted)
Not the owner's turn, a stranger's command, an unowned or forged actor id, an undeclared order, no or dead target, out of range, already commanded this turn, no budget, an unconscious owner, a dead actor, expired control. The `command_created_actor` whitelist entry carries only actor_id/order/target_id. Every authority check runs again in `issue` against `active_character`, so a forged payload can't command a non-created actor or skip turn checks. No per-ID branches. Legacy saves: `control_until` is optional unless the template declares `control_seconds`, and only the new fixture does.

## SRD 5.2.1
- Typical summon spells: no action to command, default Dodge. Representable as `cost: none, default: dodge`.
- Animate Dead: Bonus Action to command, and a creature with no command only defends itself. Representable as `bonus_action` / `none` with nearest behavior.
- The build cites no page numbers.
- **Gap:** summons don't act on their own initiative turn; orders resolve right away on the owner's turn (deferred to S-157, as documented).

## Counts
- Logic: 5526/0 at 774e14a, then 5527/0 after R1. 0 SCRIPT ERROR.
- Scenarios 031-055 all PASSED, run one at a time, with 0 SCRIPT ERROR.

## Decisions for Brandon
1. Unauthored templates default to a Bonus Action command cost. Most SRD summon spells cost no action. Should the default be `none`?
2. Adding `control_seconds` to an existing template later makes saves without `control_until` fail to load. Should that be a migration or a refusal?
3. Owner death leaves the creatures in place and uncommandable until the source ends. Concentration loss goes through the existing source cleanup. Is that acceptable until S-158?
