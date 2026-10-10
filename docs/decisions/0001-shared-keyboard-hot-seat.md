# ADR-0001: Shared-keyboard hot-seat is the milestone local multiplayer boundary

Date: 2026-08-10

Status: Accepted

## Context

Gate 4 originally required physical controller binding, disconnect/reconnect,
and post-load device rebinding acceptance. The game already models logical
local seats separately from characters and party slots. Two people can play
the current turn-based game adequately by sharing the keyboard, while physical
controller validation requires representative hardware and device-specific UX
that is not necessary to prove the Crown milestone.

## Decision

The Gate 4 and Crown milestone local multiplayer contract is shared-keyboard
hot-seat play. One to four logical seats may own characters and companions, and
all seats use the common keyboard controls on their assigned turns.

Physical controller binding, seat-selection UX, device-specific command
routing, unplug/replug recovery, and post-load device rebinding are deferred to
later owner-selected controller work. Existing optional controller code may remain, but it
does not constitute a milestone dependency or a supported hardware claim.

## Consequences

- Gate 4 is judged on logical seat ownership, shared-keyboard turns, companion
  assignment, leadership, formation, and persistence.
- Save files continue to exclude physical device IDs.
- Controller-specific defects and manual hardware reviews do not block the
  Crown milestone.
- Future controller work must preserve the separation between physical devices,
  logical seats, party slots, and characters.
