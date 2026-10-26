# Batch 073 build — S-119 explicit death or destruction without damage

Done means (verbatim): "Explicit death or destruction without damage (S-119): living, already-zero and ineligible targets, with no duplicate remains or effects."

Slice row: vocabulary-slices.md:323 (Explicit death/destruction without damage). Base: `batch-072-last-charge` @ 604e19b (PR #44 still open). Godot 4.7.2 headless. Card: Q-20261025-115746-b8f6.

## What changed
- Cleanup first: 036 spent-rod check relabelled ("kept []").
- New shared-spell effect `settle_death` (`ZeroHpAftermathRules.explicit_policy_error / explicit_target_error / explicit_cast_error / settle_explicit`); `settle` and `settle_explicit` share `_apply` (corpse, remains, gear, cause). No per-ID branches, every field authored.
- `SpellCastValidation` refuses ineligible targets before slot/Action; `_death_target` sees downed players and dead monsters.
- Fixtures `fixture:b073_word_of_ending` (death, ≤30 HP, not construct/undead, at_zero settle) and `fixture:b073_unmaking` (destruction, humanoid only, gear destroyed_except_magic, at_zero refuse).
- Contract: [explicit-death.md](../mechanics/explicit-death.md); slice boundary appended to row 323.

## Evidence
- Import ×2: no SCRIPT/Parse/Compile errors (logs /workspace/b073_logs).
- Logic: **6154 passed, 0 failed** (baseline 6133; +21 from `Batch073Checks`): 10 loader refusals; living monster and Character die once with remains/gear per policy; stale and repeat refused with nothing changed; downed Character settles under at_zero settle and is refused under refuse; 40 HP, undead, object, empty ground and non-humanoid refused, exactly 30 HP eligible; JSON DTO, forged cause refused, legacy corpse without cause_source loads.
- Scenarios (all exit 0): batch_073_explicit_death_flow (13 ok), batch_073_explicit_death_reload (2 ok, fresh process), batch_034_aftermath_flow, batch_059_corpse_limit_flow, batch_071_monster_max_hp_flow/reload, batch_072_last_charge_flow/reload.
- Live flow (real HUD casts): Cancel spends nothing; 40-HP, undead and not-listed targets refused before payment; 20-HP goblin killed outright (one slot + Action) and removed from initiative; recast at the corpse refused pre-cost; at_zero refuse leaves a downed ally downed and unpaid; Ending kills the downed ally once (serial 0→1); recast at the corpse refused; JSON DTO, real save/load and fresh process keep exactly one death.

## PARTIAL
- Object destruction (objects refused); successors on explicit death; Power Word Kill's "otherwise 12d12 Psychic" fallback; native Disintegrate/Power Word Kill not converted; multi-target not covered.

## Open questions
- Should over-threshold targets get an authored damage fallback (Power Word Kill) in a later slice, rather than being refused pre-cost?
- Should object destruction (e.g. Disintegrate on objects) be its own effect?
