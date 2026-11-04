# SC-01 evidence (base main 6a47efa)

Generic piece: shared `grant_condition` accepts an optional
`expiry: {"boundary": "caster_turn_start"|"caster_turn_end", "turns": 1..10}`,
mapped onto the existing caster-owned SpellEffects boundary records
(`expiry_phase` start/end, `remaining_seconds = 6 × turns`). No new saved fields; records
use the already-persisted `expiry_phase` / `remaining_seconds` shape.

| Spell | Status |
|---|---|
| ray_of_sickness | converted (curated winner `data/core/spells/crown_sc_01.json#1`; SRD 5.2.1 range 30 ft = 6 hexes, was 12) |
| chill_touch, ray_of_frost, shocking_grasp, starry_wisp, vicious_mockery, true_strike | blocked (exact consumer in CSV) |

Proof `crown_sc_01_flow` (real spell picker + `_on_hex_clicked`, one slot/action per cast):
out-of-range refusal before payment, miss, Poison immunity, upcast 3d8 hit with an
overlapping longer Poisoned source, next-attack Disadvantage, target turn boundaries
not advancing a caster-owned timer, caster start not ending an end expiry, expiry at end of
caster's next turn removing only the ray's source, unrelated next attack without
Disadvantage, renamed neutral definition through the production loader, malformed
expiry rejection, overworld save → load → save, and fresh-process (`CROWN_SC_01_RECOVER=1`)
recovery + expiry + save. Level-5 caster: no cantrip scaling applies (level-1 spell); slot
scaling is checked.

`mixed_mechanics_encounter` relied on the old 60-ft range; it now stands the target within
30 ft for the Ray cast and restores its position.

Pre-existing base failures (also fail on 6a47efa, unchanged): `spell_effect_lifetime`,
`runtime_connection_repairs_flow`; known `ranger_action_flow`, `local_room_object_flow`.

Not done: no old-main `.sav` containing a native Ray of Sickness record was round-tripped;
the record schema is unchanged and such a record (expiry_phase "start", seconds from the old
10-round native duration) still passes `spell_effect_persistence` validation by inspection only.
