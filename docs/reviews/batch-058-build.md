# Batch 058 build: S-155 summon creature lists (uncapped options, mixed kinds)

Card Q-20261021-124426-05d8. Stacked on #29 (batch-057-mode-costs @ bb6970f, accepted, not merged), because #25-#29 are still open and this edits the 054 factory code.

## Finish line (Brandon, verbatim)
"Summon spells should specifically be able to call out the creatures it can create in the data with no inherent limit in the building blocks."

## Design
- **No option cap.** `create_actor.options` may list any number of templates. The S-155 "up to three" refusal is gone. A non-list is still refused, as are duplicate ids and broken templates. The 054 loader check now refuses a non-list instead of four options.
- **Mixed kinds (`mix`).** A `create_actor` effect may declare `"mix": {"count": {base, per_level, max?}}`. One cast then creates any combination of the declared templates (the main template plus its options), up to that shared total. With `count_choice`, the total is 1..N; otherwise it is exactly N.
  - The loader refuses: a mix with extra keys or a bad formula; fewer than two templates; templates of different sizes (one placement reservation per cast); and templates with different command policies (one control record per cast).
  - All of this is driven by JSON. There are no per-ID branches.
- **Cast flow.** `SpellCastChoices._choose_mix` runs inside `choose_factory`, so before placement and any payment. It asks "How many <Kind>? (up to N)" for each declared kind; the last kind's lower bound keeps the total legal. Cancel or a stale answer spends nothing, and an illegal total is refused before payment. Placement reserves the chosen total.
- **Creation.** `CreatedActorRules.create(..., chosen_mix)` → `_create_mixed` refuses an undeclared kind, an empty or zero mix, or a total outside the permitted counts, and leaves no record. Each actor entry stores its own `template_id`, and ids stay `<source>:actor:N`.
- **Per-actor reads.** `actors()` rebuilds each entry from its own kind. `attack_profile` and `CreatedCommandRules._template` read the actor's own template.
- **Saves.** A mixed record's entries must carry a declared `template_id`, and HP is bounded by that kind's maximum. A record-level `template_id` is refused on mixed records. Legacy single-kind records (two-key entries, optional record `template_id`) validate and load exactly as before.

## SRD 5.2.1
- Fixture `fixture:b058_raise_bones` is shaped like Animate Dead: level 3, one creature, plus two per slot level above 3rd.
- Skeleton: Medium Undead, AC 14, HP 13, Speed 30 ft (6 hexes), STR 10 DEX 16 CON 15 INT 6 WIS 8 CHA 5, Shortsword 1d6 Piercing.
- Zombie: Medium Undead, AC 8, HP 15, Speed 20 ft (4 hexes), STR 13 DEX 6 CON 16 INT 3 WIS 6 CHA 5, Slam 1d8 Bludgeoning.
- Template attacks carry only dice and type. The damage modifier and attack bonus are not modeled by templates (owner-linked as in 054).

## Checklist
- (a) Refuse before paying. The scenario casts at a 4th-level slot and asserts the slot is unspent after Cancel at the Zombie count. Logic asserts that too many, an undeclared kind, an empty mix, or a zero mix create nothing and leave no record.
- (b) Saved `created_actors` records go through `saved_record_error`. Tampered kind, missing kind, record-level kind on a mix, HP over the kind's maximum, and too many actors are all refused. These are spell-effect records, not inventory copies, so `record_state_error` does not apply.
- (c) Production callers:
  - `choose_factory` → `_choose_mix` / `_mix_total` / `mix_choice_error`
  - SharedSpell create_actor → `create(..., mix)` → `_create_mixed`
  - the loader → `options_error` → `mix_error`
  - `counts` → `is_mixed`
- (d) A real save and load (`SaveManager.save_game`/`load_game`) rebuilds Skeleton 1/14, Zombie 2/8, Zombie 3/8. The transient `_factory` is not saved. Logic reload keeps per-actor HP. No cache clearing.
- Merged/suppressed item gate: not relevant. There are no item-granted effects.

## Counts
- Baseline: #29 head 7f6b159, from the reviewer's acceptance run: 5551/0. bb6970f adds only the acceptance doc.
- Branch (imported twice): logic 5562 passed, 0 failed (+11, all 058).
- Scenarios 031-058 run one at a time: 28/28 SCENARIO PASSED.
- 0 SCRIPT/Parse/Compile errors in all logs.

## Limits
- Mixed templates must share a size and a command policy. Mixed-size placement and per-kind control are not built.
- The total uses one `mix.count` formula. There are no per-kind caps. Each template's own `count` is still validated but is unused by mixed casts.
- No core Animate Dead spell is added. Its 24-hour control renewal and corpse/bone targets are out of scope, so this is a fixture only.
- Out-of-combat mixed casts refuse (no HUD to ask), as in 054.
