# Gate 4 evidence

## Party and local-control boundary

The production party path now keeps character identity, stable party slots,
local seats, companion state, leadership, and combat ownership separate. The
overworld HUD exposes the current leader and companion seat assignment; the
domain boundary allows companion reassignment but rejects attempts to move a
player-created character to another seat.

## Automated result

| Check | Result |
|---|---|
| Stable party slots | Pass - four ordered slots serialize by stable slot ID |
| Player character ownership | Pass - each created character remains tied to its creating seat |
| Companion recruitment | Pass - Crown companions fill empty slots without duplicate identity |
| Companion reassignment | Pass - companion ownership moves between joined seats and reports the new owner |
| Production companion lifecycle | Pass - Camp Roster UI recruits, declines/reconsiders, dismisses, replaces, and reassigns companions |
| Exploration leadership | Pass - leader moves the authoritative exploration position for the active party |
| Formation invariant | Pass - 1- and 4-member formation positions are deterministic and distinct; four occupied slots, leadership, and owners survive supported save/load before combat entry |
| Shared-keyboard hot-seat | Pass - every logical seat and all characters assigned to it receive their turns through the common keyboard controls |
| Spell ownership | Pass - the spell menu is rebuilt solely from the active character's owned spells and does not retain or duplicate rows |
| Roster modality | Pass - Camp Roster suspends map input and disables turn-changing controls until closed |
| Command boundary | Pass - exploration, event, inventory, and combat intents use validated command records |
| Viewport party smoke | Pass - four-member combat composition preserves ownership and distinct spawn positions |
| Logic suite | Pass - 534 assertions, 0 failures |

## Normal creation matrix

The focused `normal_creation_matrix` case runs the production main menu and
the production character-creation scene through the actual button signals. It
repeats the flow for one, two, three, and four local players, then verifies
the overworld start state, character ownership, stable slot ownership, and
the number of still-empty companion slots.

| Player count | Result | Empty companion slots |
|---:|---|---:|
| 1 | Pass - one created character reaches `OVERWORLD` and owns `slot_0` | 3 |
| 2 | Pass - two created characters reach `OVERWORLD` and own `slot_0`/`slot_1` | 2 |
| 3 | Pass - three created characters reach `OVERWORLD` and own `slot_0`/`slot_1`/`slot_2` | 1 |
| 4 | Pass - four created characters reach `OVERWORLD` and own `slot_0` through `slot_3` | 0 |

The run exited `0` with `NORMAL CREATION MATRIX PASSED: 1, 2, 3, and 4 players`.

## Production companion lifecycle

The overworld now exposes a dedicated **Camp Roster** overlay. Available Crown
companions can be recruited into an open slot under a chosen logical seat or
declined for later reconsideration. Recruited companions can be reassigned or
dismissed. When the party is full, an available companion can atomically
replace a recruited companion without exceeding capacity or losing the chosen
seat owner.

The focused `companion_lifecycle` viewport scenario drives the production
button and option signals. It proves a solo player can fill all three empty
slots and own every companion turn. It then proves two-player recruitment,
full-party replacement, Seat 1 to Seat 2 reassignment, dismissal, and the
return invitation. A declined state passes the supported save validator.

The rendered 1280x720 overlay was inspected for hierarchy, clipping, and action
legibility. The current complete Windows suite passed with `534` logic
assertions, all `19` isolated integration scenarios, and exit `0`.

## Manual closeout review (2026-08-10)

The normal creation matrix and `party_combat` focused Windows scenarios were
rerun against Godot 4.7 and both exited `0`. The first proves the production
main-menu and character-creation path for one through four local seats. The
second proves that a four-member party enters combat with distinct formation
positions and that one logical seat can own every active turn.

Shared-keyboard hot-seat is the accepted Gate 4 input boundary. Logical seats,
character ownership, leadership, and turn routing do not require separate
physical devices. The optional controller implementation remains present and
keeps physical IDs out of saves, but hardware acceptance is not part of this
gate.

The production `combat` scenario proves the held-turn disconnect/rebind path.
The production `party_combat` scenario now performs a supported save/load of a
four-member party, transferred leadership, and logical owners before proving
four distinct combat positions. The complete Windows runner passed all `19`
isolated scenarios after a flaky fixture was corrected to establish a living
owned combatant before simulating disconnect.

Physical controller binding, unplug/replug, device-specific routing, and
post-load rebinding have been moved to the post-Gate-8 roadmap. They do not
block the shared-keyboard milestone.

A manual recruitment and trial-combat pass confirmed that selecting **Recruit**
successfully adds the companion to the active party. It also found two blocking
normal-path defects that the focused scenario did not cover:

- `G4-FOCUS-01` is closed: the Camp Roster suspends map input, rejects direct
  movement and turn actions, disables the underlying controls, and restores
  them when closed. The focused lifecycle scenario covers the boundary.
- `G4-SPELL-01` is closed: both the backing spell registry and visible list are
  cleared on rebuild, and only `Character.known_spells` supplies rows. The
  focused party-combat scenario covers owner switching and repeated menu entry.

The original manual pass confirmed recruitment and exposed the two repaired
defects. Production-scene coverage now proves leadership, reassignment,
shared-keyboard ownership, supported save/load, and distinct formation.

## Decision

`done`. Two people sharing one keyboard is the accepted local multiplayer
contract. All Gate 4 exit criteria pass under that boundary: one-to-four
logical players, companion lifecycle and reassignment, leadership, full-party
combat entry, multi-character turn ownership, and supported save/load. Physical
controller testing is recorded as post-roadmap work.
