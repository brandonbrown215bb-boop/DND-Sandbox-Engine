# SC-02 — Attack-and-damage spells (stacked on SC-01)

| Spell | Status | Notes |
|---|---|---|
| ice_knife | converted | Shared ordered steps: ranged spell attack 1d10 Piercing, then hit-or-miss DEX save area step (sphere radius 1 hex = 5 ft, centred on the attacked creature) for 2d6 Cold, **no damage on success** (SRD 5.2.1), +1d6 Cold per slot above 1. Range corrected 30 ft → 60 ft. |
| magic_missile | blocked | shared per-dart target allocation consumer |
| scorching_ray | blocked | shared per-ray target allocation consumer |
| eldritch_blast | blocked | shared per-beam allocation + character-level beam count |
| melfs_acid_arrow | blocked | shared miss-damage scale + target-turn-end delayed damage |
| sorcerous_burst | blocked | shared damage-type choice + exploding dice cap |

Engine changes: the per-ID legacy splash in `spell_cast_areas.gd` is skipped for shared definitions (otherwise the burst would apply twice). Logic and mixed-encounter checks updated from the native splash fields to the shared step shape (and from half-on-save to SRD no-damage-on-success).

Proof (`crown_sc_02_flow`): real picker + hex click, one slot and action per cast, hit (piercing + cold), adjacent failing creature cold only, adjacent saver untouched, 10 ft away untouched, caster/ally untouched, miss still bursts, slot 3 burst 4d6, renamed neutral definition through the production loader.

Saved data: instantaneous spell, no durable record — no save-format change.

Not proven live: out-of-range refusal (combat grid is radius 4 hexes, < 60 ft); range asserted as data. 

Logs: logic.log (6935 passed, 0 failed), crown_sc_02_flow.log, mixed_mechanics_encounter.log, conversion_batch_001_flow.log (2 failures pre-existing on the SC-01 tip: Bless downed-creature `targets` script error).
