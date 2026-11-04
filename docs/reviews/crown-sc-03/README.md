# SC-03 — Lightning Bolt (shared), Shatter/Thunderwave blocked

Stacked on `codex/crown-spells-sc-02`.

## SC-02 tip re-run (before any SC-03 change)
- `shared_spell_flow` on SC-02 tip: PASS, 0 failed (`sc02-tip-shared_spell_flow.log`)
- `crown_sc_01_flow` on SC-02 tip: PASS, 0 failed (`sc02-tip-crown_sc_01_flow.log`)
- Known out-of-lane base failure (Bless downed-target, `conversion_batch_001_flow`) left untouched.

## Generic consumer added: caster-origin line area
- `area_selection {shape: "line", origin: "self", size: 1..40}` validated in `SharedSpell`.
- `EventResolver.resolve_area_selection` accepts self-origin lines.
- `Targeting.get_self_line_targets(origin, toward, length, grid)`: line extends from the hex beside the caster toward any chosen hex for the full length, excludes the caster, stops before a `blocks_sight` tile, clipped to the grid.
- `SpellCastTargeting` / `spell_cast_validation`: any on-grid non-origin hex within the line length picks the direction.
- No per-ID branches.

## Lightning Bolt (SRD 5.2.1)
`data/core/spells/crown_sc_03.json`, manifest override replaces `imported_spells.json#113`.
100 ft (20 hex) line from self, DEX save, 8d6 lightning, half on success, +1d6/slot above 3, V/S/M.

## Proof (`crown_sc_03_flow`, PASS) — real controls
Sorcerer 5 prepares via ordinary class selection; cast with spell select + hex click.
- Fail creatures at both ends of the line take 8d6; saver takes half; off-line creature and ally untouched; one slot + action paid.
- Slot 4: 9d6 range; sight-blocking wall stops the line before the far creature.
- Bad data (no origin, size 0) rejected; line geometry 20 hexes, caster excluded, any direction hex gives same line.
- Renamed copy `crown_sc_03:neutral_line` passes the production loader and resolves the same line via production targeting + `CombatAction.resolve_spell`. Class spell lists are ID-keyed, so a renamed ID cannot enter the picker (disclosed).
- Grid is radius 4, so the 20-hex line is clipped on the live board; full length proven in geometry check.

## Checks
- Logic suite: PASS (`logic.log`)
- Scenarios: crown_sc_03_flow, crown_sc_02_flow, crown_sc_01_flow, shared_spell_flow — all PASS, no SCRIPT/Parse/Compile errors.
- No save-data change.

## Blocked
- shatter: `blocked:` shared object-damage consumer (+ creature-type save disadvantage).
- thunderwave: `blocked:` self-cube + push op, object push, 300 ft noise consumers.
