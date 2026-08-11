# ADR-0002: Crown-band Wild Shape scope

Date: 2026-08-10

Status: Proposed - human review required

## Context

The current Druid record exposes `druid_wild_shape` at level 2 as an active
feature, but its `effects` array is empty. DataLoader therefore quarantines it
from player state. The engine already has character temporary hit points,
inventory persistence, the production monster registry, and shared combat
actions, but it has no form-state or equipment-snapshot boundary.

The Crown band needs a small, testable Wild Shape contract before any form is
made selectable. The contract must not imply that every imported beast, monster
rider, or mid-combat save rule is already supported.

## Proposed decision

The first Crown-band implementation is intentionally limited to one form:

- **Form roster:** `wolf` only, using the existing core monster record. It is
  available from Druid level 2 through level 5. `giant_spider` and imported
  beasts remain out of scope until player-facing attack-rider contracts exist.
- **Form hit points:** roll the Wolf record's `2d8+2` hit-point expression once
  when the form is entered. Store the result as `wild_shape_temp_hp`; do not
  replace the character's normal `max_hp` or `current_hp`.
- **Damage and reversion:** damage is absorbed by the form hit points first.
  When they reach zero, the Druid immediately reverts and any excess damage is
  applied to the character's normal hit points. Reversion also occurs when the
  Druid dismisses the form or combat ends.
- **Equipment:** equipped and backpack items remain owned and unchanged while
  shaped. The form cannot use the character's weapons, armor, or spells. The
  character identity, party ownership, conditions, and save identity remain
  attached to the Druid.
- **Actions:** entering the form costs a bonus action, matching the current
  Crown action record. Dismissing the form also costs a bonus action. A form
  exposes only the Wolf's ordinary Bite attack through the shared player combat
  action path; it does not use monster AI, loot, or private attack shortcuts.
- **Duration:** one active form lasts at most 10 combat rounds. The timer is
  visible in the character/combat feedback and expires through the same reversion
  path as damage or dismissal. A second form cannot be layered on the first.
- **Uses:** the Druid has two Wild Shape uses. The uses restore on the existing
  rest-reset boundary; a future short-rest versus long-rest distinction is a
  separate contract and is not implied here.
- **Save/load:** supported saves occur only at overworld or dungeon-entry safe
  boundaries. A Druid must be reverted before one of those checkpoints, so an
  active form is not serialized in the current save DTO. If mid-combat saves are
  later admitted, the DTO must carry the form ID, remaining rounds, temporary HP,
  and reversion state before that capability is enabled.

## Consequences

- `druid_wild_shape` remains quarantined until this proposed contract is
  accepted and implemented with a normal player path.
- The first implementation can reuse the existing Wolf record without
  promoting imported beasts or inventing a general polymorph framework.
- Tests must cover form entry, bonus-action cost, two-use restoration, timer
  expiry, damage carry-over, equipment preservation, combat-end reversion, and
  the supported save boundary.
- The character sheet and combat HUD must show the active form, remaining form
  hit points, remaining rounds, and the two-use resource clearly enough for
  human review.

## Human review questions

1. Accept the Wolf-only roster for the first Crown band, with Giant Spider
   deferred until its player attack riders have a shared contract.
2. Accept bonus-action entry/dismissal, 10-round duration, and two uses restored
   by the current rest boundary.
3. Accept the safe-boundary rule that shaped state cannot be serialized until a
   future mid-combat save contract exists.

