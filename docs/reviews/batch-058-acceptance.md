# Batch 058 acceptance (runtime-reviewer)

Verdict: ACCEPT. No defects found. Head reviewed: 9794b7c (stacked on #29 bb6970f).

## Runs (worktree /tmp/rev_wt058, imported twice)
- Logic suite: 5562 passed, 0 failed (+11 vs 5551 baseline, all batch_058).
- Scenarios 031-058, one at a time: 28/28 SCENARIO PASSED.
- N1: 0 SCRIPT ERROR across logic and scenario logs.

## Checks
- Finish line ("call out the creatures it can create in the data with no inherent limit"): met. The options cap is removed, and `mix` is data-declared with no per-ID branches.
- Refusal before cost: `_choose_mix` runs inside `choose_factory` (before placement and payment). Over-cap, zero, empty, negative (`_int` 0..64 bound) and undeclared kinds are refused by `mix_choice_error`. Cancel or stale answers spend nothing (the scenario asserts the slot is unspent).
- Upcast: the total is `mix.count` base 1 + 2/level, matching Animate Dead's +2 per slot above 3rd.
- Placement: mixed sizes are refused at load, so one reservation per cast keeps 053 placement all-or-nothing. Mixed-size placement is not built (documented limit).
- Saves: per-entry `template_id` is required and bounded to declared kinds, and HP is bounded per kind. A record-level `template_id` on a mix is refused. Legacy two-key entries still validate.
- Commands/initiative: `created_template_id` meta is read per actor by CreatedCommandRules and attack_profile. A shared command policy is enforced at load.

## SRD 5.2.1
- The Skeleton and Zombie fixture stats (AC/HP/speed/abilities/attack dice) match the SRD stat blocks. The fixture carries no page citations, so none needed correcting.
- Find Familiar is not added in this batch. The uncapped options list makes its forms list expressible. Its creature-type choice (Celestial/Fey/Fiend) has no building block yet.

## Decisions for Brandon
- `count_choice: true` lets an Animate Dead-style cast create fewer than the maximum. Is that OK?
- Find Familiar's creature-type choice needs a follow-up card if wanted.
