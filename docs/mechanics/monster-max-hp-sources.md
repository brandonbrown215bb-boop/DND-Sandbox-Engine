# Maximum-HP sources on monster records (S-130/S-131) — PARTIAL

Done means: "Monster maximum-HP effects (S-130/S-131): overlapping sources, removal order, clamps and zero-maximum consequences, through real combat."

## Contract

- `MaxHpSourceRules` accepts a `Character` or a monster combatant `Dictionary`
  (`max_hp`, `current_hp`, `temp_hp`, `is_alive`, `max_hp_sources`). The same
  formula, clamp, floor and zero-limit policies apply; there is no separate
  monster interpreter.
- Shared spells declare `{"type": "max_hp_source", "rule": {...}}`. The rule is
  validated by `MaxHpSourceRules.validate_rule`; unknown rule fields are now
  refused, and `amount: "damage_dealt"` is refused on spells (no damage step).
  The cast's `source_id` owns the entry; the spell record carries
  `max_hp_source = rule.id`, so `SpellEffects.remove` (concentration end,
  expiry, encounter end) removes exactly that source.
- New definitions require `combine`: `"highest"` means entries with the same
  declared rule id and kind do not stack; the largest request applies and the
  newest application wins equal ties (SRD 5.2.1 p.106). `"sum"` adds sources;
  absence retains that behavior only on the legacy runtime/save path. Display
  names do not determine equivalence. Reductions must also state `accumulate`
  to choose whether repeated applications of one exact source add together.
  Inactive entries keep their record (applied 0) and take over when the
  stronger one ends, so any removal order restores the correct maximum.
- Current HP is clamped to the new maximum; removal never raises current HP
  (only `raise_current` increases do, on apply, limited to the net growth of the
  maximum when replacing a weaker source).
- Zero maximum (SRD 5.2.1 p.17: "A creature dies if its Hit Point maximum
  reaches 0."): a `zero_limit` source that reaches 0 sets current/temp HP 0,
  `is_alive=false` and `zero_hp_aftermath = {outcome: death, remains, cause,
  cause_source}` once. Dead or already-settled records refuse new sources
  (`target_dead`). The link is not written after a zero-limit death, so ending
  the spell never revives the body.
- Persistence: monster records do not persist mid-encounter (encounter end
  removes their sources). Character recipients of the same effect persist via
  the DTO; `saved_link_error` refuses a link whose source is missing, has a
  different rule id, or whose spell does not declare that rule.

## PARTIAL

- Monster `turn_started` periodic/cure events are not dispatched to monster
  records.
- Monster-attack `max_hp_source` effects still target characters only.
- Item-granted maximum-HP sources on monsters: none exist; not built.
