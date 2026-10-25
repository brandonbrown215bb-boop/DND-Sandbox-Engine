# Batch 083 build: S-162 consumption reference update (#47 follow-up)

Stacked on `batch-082-interruption-boundary` (PR #55, incl. review commit d5bf285).
Card: Q-20261025-234321-e3f3.

## Done means
Brandon: "treating consumption as destruction is fine for now; don't add a consume cause until content needs it. Update the technical reference, which still says consumption lacks a cause."

## Changes
- `docs/mechanics/linked-removal-causes.md` (technical reference): PARTIAL no longer
  says component consumption and fuel use carry no cause. It now says consumption
  (consumables, fuel, components, resource payments) currently passes cause
  `destruction` (review commit eee958b) and a dedicated `consume` cause is deferred
  until content needs it. The caller list gains that row. Attach is still the only
  causeless removal.
- `docs/planning/vocabulary-slices.md` S-162 row: same note.
- No code change for consumption; no `consume` cause added.
- Historical review docs (batch-075-build/acceptance) are left as records.

## Review 082 nit (dice spaces)
Checked: validation (`SharedStepExecutor._formula`) strips all spaces, and the roller
(`Dice.parse_dice_details`, `Dice.maximum_dice_string`) also strips all spaces
(dice.gd:90, :140), so "12 d12" is read as 12d12 in both. They already agree; no
code change. `src/batch_083_checks.gd` pins this with 3 logic checks.

## Validation
- Godot 4.7.2 `--headless --import` x2: clean, no SCRIPT/Parse/Compile errors.
- Logic: 6336 passed, 0 failed (6333 + 3).
- Scenarios: batch_075_linked_removal_flow PASSED, batch_075_linked_removal_reload PASSED.

## PARTIAL
- Dedicated `consume` cause deferred until content needs it (per ruling).
