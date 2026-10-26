# Batch 081 acceptance review (PR #54, card Q-20261025-230738-c635)

**Verdict: ACCEPT (PARTIAL, as declared). No code defects; reviewer added tests only (82218e0).**
Judged against Brandon's ruling **as quoted by the builder** in the PR (reviewer did not see the original message).

## Evidence (Godot 4.7.2, import x2, sequential, worktree)
- Logic: **6319 passed, 0 failed** (6316 + 3 reviewer checks). No SCRIPT ERROR.
- Scenarios PASS: batch_081_declared_fallback_flow/_reload, batch_073_explicit_death_flow/_reload, batch_075_linked_removal_flow/_reload.
- bard_action_flow: FAIL, single [FAIL] "The healed Prone recipient can decline standing". bard_action_flow is on main's known-70 list (batch-066-acceptance.md). Not a regression; Words of Creation kill passes.

## Focus areas
1. **Fallback validation**: refuses unknown keys, bad `when`, no HP limit, numeric damage, unknown/missing damage_type, missing damage, `0d12`, `-1d12`, `12d13`, `""`, `12d12x` (reviewer check). `fallback` is only a settle_death key; other effects reject it via their own key lists. 100 HP dies, 101 takes fallback. 100 HP + 50 temp HP still dies, temp HP cleared (073 rule holds). Fallback at 101 HP with 200 temp HP is absorbed by temp HP first and counted once in `damage`. Dead targets are refused before cost. Nit: a flat string like `"5"` passes as fallback damage (the shared `_formula` allows constants). That's harmless.
2. **Refusal before cost**: slot and Action counts checked live. Covered: dead creature (PWK), no fallback above the limit, creature target for destroy_object, plus the reviewer's magical dropped object and second cast at the destroyed square. Worn/carried objects aren't reachable as grid targets; that's covered only at the rules level.
3. **Magical refused outright**: the ruling doesn't mention magic objects. Refusing them is conservative and matches the existing combat-object route (`can_damage` already excludes magical, and `is_magical` falls back to the item definition, so legacy data without the flag is still caught). The refusal is surfaced in the orange combat log ("X is magical and not affected."). No other caller of settle_destruction was added.

## ADR-0018 / SRD
- No power_word_kill id branch remains in src/ outside tests (spell_resolver keeps only power_word_heal). Disintegrate stays native (declared partial).
- SRD 5.2.1 Power Word Kill (from memory; page unconfirmed): dies at 100 HP or fewer, otherwise 12d12 Psychic. Matches.
- Legacy PWK corpse without cause_source loads (builder check); reload scenarios pass.

## Open for Brandon
- Should magical objects ever be destroyable by explicit destroy_object (needs a ruling + item text)?
- Should fallback damage reject flat constants?
- Card for converting native Disintegrate to destroy_object/settle_death.

## Proposed counts
Logic 6319/0.
