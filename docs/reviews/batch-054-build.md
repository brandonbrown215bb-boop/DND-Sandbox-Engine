# Batch 054 build: S-155 factory choices/count and creation refusal

Card Q-20261021-043826-70bf. Stacked on #25 (batch-053-legal-placement @ 1967d11), because #25 is still open and this builds on its placement code.

## Scope (S-155 row)
"Select permitted template/options/count, validate actual space/exclusions before creation, and create only the declared actors with unique identities."

## Design
- **Authored options.** A `create_actor` effect may declare `options`: up to three alternative templates, each validated like the main template, with unique ids. It may also declare `count_choice` (bool).
  - The permitted counts are exactly the count formula, or 1..formula when `count_choice` is true.
  - `SharedSpell.content_error` refuses unknown keys and bad options.
- **Cast flow.** `SpellCastChoices.choose_factory` runs in `validate_and_choose`, before `choose_placement`, so before any payment.
  - "Choose a creature" lists Cancel plus exactly the declared templates.
  - "How many to create?" lists Cancel plus the permitted counts.
  - Cancel, or a stale answer (newer popup or turn ended), spends nothing.
  - Placement then reserves space for the *chosen* template's size and count. Not enough legal space refuses before payment under the authored `refuse` policy.
- **Creation.** `CreatedActorRules.create` refuses an undeclared template or count and leaves no record.
  - A non-default choice is recorded as `created_actors.template_id`.
  - Actor ids stay `<source>:actor:N`, so they are unique per cast.
  - Forbidden creation features are still excluded per template.
- **Rebuild and saves.** Actors, attack profile and saved-record validation read the record's chosen template. A legacy record without `template_id` uses the declared template.

## Checklist
- (a) Refusals happen before payment.
  - The scenario asserts the slot is unspent after Cancel, after a superseded popup, and after two Hounds were chosen with one free cell.
  - It asserts exactly one slot is paid for one Hound and for one Owl.
- (b) Saved `created_actors` records go through `saved_record_error`, which refuses an unknown or empty `template_id` and refuses zero or too many actors.
  - These are spell-effect records, not inventory copies. No new inventory record goes through `record_state_error`.
- (c) Production callers: `validate_and_choose` → `choose_factory`; `SharedSpell` create_actor → `create(..., chosen_count)`; the loader → `options_error`.
- (d) A real save and load rebuilds the chosen Owl. The transient `_factory` choice is not saved.
- Merged/suppressed gate: not relevant. There are no item features or modes here.

## Counts
- Fresh baseline 1967d11 (imported twice): 5508/0.
- Branch: 5516/0 (+8), 51 check scripts, 0 failed.
- Scenarios 031-054 pass one at a time with the scenario gate. 054: 8 ok.

## Limits
- Templates must be authored inline. There is no shared template catalog or per-option count/level formula beyond each template's own `count`.
- Single-cell bodies only (from 053). No multi-cell Large+ space.
- Out-of-combat casts with options or `count_choice` refuse, because there is no HUD to ask.
- No SRD summon content is added; this uses fixtures only.
