# Batch 054 acceptance: S-155 factory template/count choice (PR #26)

Reviewer: runtime-reviewer. Head reviewed: a4d96dc, stacked on #25 at 1967d11. Worktree: /tmp/rev_wt054.

## Verdict
ACCEPT. No defects found, so there are no review fixes.

## Verified
- **Before cost:** `choose_factory` runs inside `validate_and_choose`, ahead of `choose_placement` and payment.
  - Cancel and stale answers (popup serial or `commit_guard`) erase `_factory` and spend nothing.
  - Without a HUD, a cast with options or a count choice refuses before cost.
  - Production spells are `duplicate(true)` per cast (combat_hud, combat_command), so `_factory` can't leak into the catalog.
- **Invalid template/count:** `CreatedActorRules.create` refuses an undeclared template (`not_permitted`) or count (`count_not_permitted`) before writing a record. The loader and `SharedSpell.content_error` reject unknown keys, more than three options, duplicate ids and a non-bool `count_choice`.
- **Placement (053 rules):** `choose_placement` reserves distinct legal cells for the *chosen* template's size and count.
  - It is all-or-nothing. There is never partial creation.
  - If space is short, the `refuse` policy refuses before payment. The authored `spend` policy pays and creates nothing, as in 053.
  - The scenario proves two Hounds with one free cell leave the slot unspent.
- **ADR-0018:** no per-ID branches. Choices come from authored `options` and `count_choice` only.
- **Saves:** a legacy record without `template_id` resolves to the declared template.
  - `saved_record_error` refuses an empty or unknown `template_id` and any count outside the permitted set.
  - Actors and the attack profile read the record's template, including after a real save and load.
- **S-121:** still `Planned` in vocabulary-slices.md. 1967d11 only adds the exit-half card Q-20261021-043117-1c72 and the partial note. It is not marked done.

## Runs (N1)
- Import ran twice.
- Logic: 5516 passed, 0 failed. The gate shows 51 check scripts with 0 failed. That matches the 5508 baseline plus 8.
- Scenarios 031-054, each run alone: all 24 passed. 054 had 8 [ok] lines. Every scenario had 0 [FAIL] lines and 0 SCRIPT ERROR lines.
- No logic log contains SCRIPT ERROR.

## SRD 5.2.1 (checked against the PDF)
SRD 5.2.1 has **no** CR-limited, count-scaling conjure spell. The 5.2.1 version of Conjure Animals (p.117) creates one Large spectral pack, and you choose only how it looks. The real choice and count cases are:
- **Find Familiar (p.130):** you pick one of 11 listed forms "or another Beast that has a Challenge Rating of 0", plus a Celestial, Fey or Fiend type. That is more than the three-option cap, and the type choice is a second axis.
- **Animate Dead (p.108):** "two additional Undead creatures for each spell slot level above 3". The template (Skeleton or Zombie) depends on each target, so different creatures can have different templates. This batch picks one template for all of them.

The batch adds fixtures only and cites no SRD pages. Neither gap blocks S-155, because its finish line is authored options and counts.

## Decisions for Brandon
1. Should the three-option cap be raised, or should a shared template catalog come later? Find Familiar needs more than three options plus a creature-type choice.
2. Should one cast allow different templates per creature (Animate Dead)? Right now one cast creates one template.
3. Removing an option from content makes saves that chose it refuse to load. Is that the right policy?
4. Should an out-of-combat cast with options keep refusing until a non-combat chooser host exists?
