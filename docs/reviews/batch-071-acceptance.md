# Batch 071 acceptance: S-130/S-131 monster maximum-HP sources (PR #43)

Reviewer: Runtime Reviewer. Card Q-20261020-164642-1964 claimed (until 2026-10-26 06:27 CDT). Reviewed head 15de239 (code 7f7125a), stacked on #42 (26c8f3a, which adds only `.questboard/quests/Q-20261025-102842-b171.md`).

Finish line (verbatim): "Monster maximum-HP effects (S-130/S-131): overlapping sources, removal order, clamps and zero-maximum consequences, through real combat."

## Verdict: ACCEPT, no defects. S-130/S-131 PARTIAL as declared.

## Verified
- `combine: "highest"` (SRD 5.2.1 same-name effects don't combine; the most potent applies): the larger reduction wins regardless of order, not the first; ties keep the first instance; when the stronger ends the weaker resumes (20→11, end strong→16, end both→20). Current HP is never raised by a reduction ending.
- Legacy `sum` default: no shipped (non-fixture) content declares `max_hp_source`; only fixtures batch_035 drainer and batch_039 withering use it, so nothing shipped stacks wrongly today.
- Zero maximum: a zero_limit source taking the maximum to 0 kills once (is_alive false, temp HP cleared, `zero_hp_aftermath` dust); a second application returns `target_dead`; the source is kept so a later spell end never restores a dead body. A non-zero_limit reduction floors at 1 by design (content-declared policy).
- Temp HP / healing: current HP clamps to the reduced max; healing uses max_hp so can't exceed it.
- Refusal before cost: `cast_error` runs in `validate_creatures_and_components` before slot payment (dead / zero-max / Aura of Life).
- Save/load: monster records aren't persisted mid-encounter (PARTIAL, proved on a character recipient); `saved_error` accepts suppressed highest increases with applied 0.
- No per-ID branches in production code (fixture IDs appear only in batch_071 checks/controls).

## Tests (Godot 4.7.2, imported twice)
- Logic: 6111 passed, 0 failed (builder 6104 + 7 review stress checks `_review_stress`). No SCRIPT ERROR.
- Scenarios run alone, all pass with no SCRIPT ERROR: batch_071_monster_max_hp_flow, _reload, batch_031/035/036/037/038/039/044/045/047, batch_070 flow + reload, shared_spell_flow. **No regressions.**

## Open for Brandon
- Should `combine` be required for new max-HP content (builder's question)? Recommend yes; a missing field silently stacks.
- Stronger same-name increase replacing a weaker one with raise_current raises current HP by the full new amount (clamped to max): small overheal vs SRD. Accept or card?
- Cards: monster periodic/cure events, monster-attack max-HP sources on monsters, monster records saved mid-encounter.
