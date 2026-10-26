# Created actors, placement and command controls

This is the bounded executable contract reviewed across PRs #25–37. The
[slice registry](../planning/vocabulary-slices.md#pr25-37-validation) owns
acceptance and remaining scope. Neutral fixtures prove the engine paths;
they do not certify an SRD spell conversion.

## Factory and legal arrival

A shared spell's `create_actor` effect declares `template`, optional `options`
and `count_choice`. Templates supply size, type, ability scores, movement, AC,
HP, count and attack data. Counts use `{base, per_level, max?}` formulas.
Option IDs must be unique; there is no fixed option-list length. An optional
`mix: {count: {base, per_level, max?}}` allows several declared kinds in one
cast. Each template keeps its own authored size, command and initiative policy.

`placement` accepts `range_hexes` (1–24), `choose` (boolean) and `no_space`
(`refuse` or `spend`). Omitted fields mean adjacent placement, no chooser and
refusal before costs. The combat picker reserves one complete footprint per actor.
The placement/payment checks use actual occupancy, grid passability, room
walls, plane and the chosen body's vertical clearance. A stale/blocked choice
refuses before costs. A declared paid no-space outcome creates no actor/source
and consumes no remains. `_factory` and `_placement` live only on a cast copy.

`CreatedActorRules.attach` uses the actual chosen template's size. The supported
hex policy treats Tiny, Small and Medium as one cell; Large as a radius-1 disk
(7 cells); Huge as radius 2 (19 cells); and Gargantuan as radius 3 (37 cells).
Every axial cell is checked for bounds, passability, room walls, plane, vertical
clearance, living bodies and blocking objects. Footprints cannot overlap other
actors or reservations. Confirmed cells are rechecked, with legal nearby
fallback for new encounter attachment; with no destination an actor stays
off-grid. Existing saved sources attach on encounter entry before initiative.
`ItemProjectionRules.attach` rechecks the exact copy's chosen or saved room
cell, falling back to a legal nearby cell on encounter entry. A new activation
checks placement before payment through the item controls below.

## Exact item bond and projection controls

Combat **Features** and the local room's **Use item control** chooser offer
Bond/Release for applicable source-declared item bonds and Project/Dismiss for
supported `actor_projection` definitions. Labels include the full stable copy
identity, so equal item and form names remain independently selectable. Bonds
use `BondRules` capacity, eligibility, uniqueness and replacement policies;
they add no resource pool. These controls cover item bonds, not actor bonds.

An `actor_projection` may additionally declare:

```json
"placement": {"range_hexes": 2, "choose": true, "no_space": "refuse"},
"activation": {"action_cost": "magic", "charges": 1, "bond_id": "declared:bond"},
"dismiss_cost": "bonus_action"
```

These fields are optional. Placement defaults to the existing adjacent,
automatic, unpaid-refusal policy. Activation and dismissal costs default to
`none`; supported action costs are `none`, `action`, `bonus_action`, and `magic`.
Magic spends the ordinary Magic action budget, including its Action Surge
restriction. `charges` is a nonnegative integer paid from that exact copy by
the existing inventory charge API. Optional `bond_id` requires the current
source-declared bond to that copy. Required item attunement is checked for the
acting owner. Charged projections with last-charge aftermath remain unsupported.

Every chooser includes Cancel. Closing it also cancels. Confirmation rechecks
the owner, exact payload, source/bond eligibility, attunement, current form,
turn, resources and live destination before commitment. A changed/occupied
chosen cell refuses unpaid even with `no_space: spend`. When no cell exists
from the outset, `spend` offers explicit confirmation, pays the authored cost
once, and leaves the original copy held without creating a form. Automatic
placement confirms a reserved cell and rechecks it before payment.

Room controls pay exact-copy charges but have no initiative action budget or
campaign-clock advancement. Their actors are drawn and reserve room cells in
the existing `created_actor_positions` map, retaining their identity through
encounter entry and allowed checkpoints. World-origin copies keep their world
IDs. Dismissal calls the same legal-return API described below; a blocked return
leaves the form and dismissal cost unchanged. No return creates a new item.

## Exact item-form return

An item's `actor_projection` still requires one `template`. Optional `reversion`
declares the S-166 lifecycle; definitions without it keep full form HP on each
projection, discarded overflow and backpack-only return. Existing projection
saves keep their `copy` and `actor` records.

```json
"reversion": {
  "hp_reset": "full",
  "overflow": "original",
  "original_hp": 12,
  "on_end": "return",
  "on_zero_hp": "return",
  "destination": "backpack_or_ground",
  "no_space": "defer",
  "range_hexes": 1,
  "size": "tiny"
}
```

All fields shown except `original_hp` are required. Supported policies:

| Field | Behavior |
|---|---|
| `hp_reset` | `full` remembers the template maximum on return; `preserve` remembers remaining form HP. Preserved zero HP refuses another projection. This does not refill item charges or owner resources. |
| `overflow` | `discard`, or `original` to subtract damage remaining after temporary HP and form HP from the original copy. `original` requires `original_hp` (1–1,000,000); other modes forbid it. Existing `combat_object_hp`, then `physical.hp`, overrides this initial HP. Original HP reaching zero destroys that exact copy. |
| `on_end`, `on_zero_hp` | Independently `return` or `destroy`. Destruction is authored behavior, never a placement fallback. |
| `destination` | `backpack`, `ground`, or `backpack_or_ground` (bag first). Ground means the nearest legal distinct cell within the declared range of the form's captured ending position in its persistent room and plane, excluding the ending cell. |
| `no_space` | Only `defer`: a blocked voluntary ending leaves the living form unchanged. Lethal damage ends the actor and retains its original copy plus settled overflow and ending location until return becomes legal. |
| `range_hexes`, `size` | 1–24 and a supported physical size. Ground return reuses `PlacementRules` reservation and confirmation with live geometry, clearance, occupants and blocking objects. Existing ground copies and persisted summon positions also reserve their cells. |

Return selects and rechecks its destination before removing the projection
record. It transfers the original identity and entire copy payload through
ordinary exact inventory receipt or `LocalRoomRules.placed_item`; it never
creates a replacement copy or forces an overlap. Ground return requires a
represented persistent room; an unavailable host/location defers safely.
Damage and overflow settle once in `Character.take_damage`, after temporary HP
and zero-HP replacements. Repeated ending/retry callbacks do not damage the
original again. Callbacks retained across activations can pin the copy's
`item_form_serial` through `revert`'s optional `expected_serial` argument.

Returning to the backpack preserves the exact copy's bonds. Ground return or
declared destruction releases only that copy's bond entry without invoking
linked-mate disposal. Identical copies keep separate actors, HP and ending
records. Pending lethal returns save their exact copy, settled item HP and
captured location; malformed fields and duplicate identities fail normal save
preflight. SaveManager settles returns before capturing any world ledger, so
a save-time return into a dormant room survives fresh-process recovery.

This covers single-cell actor projections, their normal combat/room controls
and returns. Actual containment admission/capacity is documented in [containment](containment.md).
Internal harm and release use that containment contract. Projected vessel cargo,
passengers, movement and separately declared endings extend this exact-copy
lifecycle through [projected vessels](projected-vessels.md). Real catalog
conversion remains separate until a complete source-backed consumer works.

The local-room exploration host also exposes these factories through the room's
spell controls, including rooms with no eligible remains. It offers only the
declared templates and counts, reserves enough distinct cells before asking for
locations, then checks the acting character's
current room position, occupancy, walls, plane and clearance again before
casting. Counts use the slot that will actually be spent. A mixed-capable spell
creates the one kind selected in the room picker; combinations of different
kinds in one cast still use the combat picker. A newly blocked footprint cell, cancellation or changed remains allocation
leaves the cast unpaid. Authored `no_space: spend` pays once and creates no
source. `choose: false` uses the nearest legal reserved cells after the factory
confirmation; `choose: true` asks for each cell on the room map only after that
confirmation. Switching the acting character cancels the pending creation before
either character pays. Created actor IDs and
their room cells live in the room DTO; their source and HP remain in the
character DTO. Encounter entry rechecks and uses those room cells when legal.
The room display and movement treat those cells as occupied. When an encounter
ends, the room host captures every persistent spell-created actor's current
combat cell, including summons first created during that encounter. Exploration
and later encounters restore that saved cell after checking its full footprint;
if blocked, ordinary legal fallback placement applies. This adds no new summon
scheduler or catalog conversion.
Actor source records, slot costs, room cells and
removed material bodies pass the production SaveManager checkpoint and a fresh
process reload without replaying creation or consuming remains again.

Represented overworld travel uses the same reservation query against the live
map grid and actual player positions. Random-location event arrivals choose
only among passable legal tiles on the party's represented plane. An authored
coordinate is accepted only when that tile exists and remains legal; missing
or unknown coordinates leave the party in place. An explicit destination must
contain exactly two integral numeric coordinates; malformed destinations refuse
instead of selecting a random arrival. Omitting the destination selects the
event's random-arrival behavior. The settled party coordinate
survives the supported overworld SaveManager checkpoint. This does not create
an overworld creature-following or general spell-arrival system.

### Teleport arrival (Batch 066)

A `teleport` spell effect declares its own reach and sight requirement:
`{"type": "teleport", "distance": <hexes 1-200>, "requires_sight": <bool>?}`.
There is no engine default distance: the loader refuses a teleport effect
without `distance`, with unknown fields or with a non-boolean `requires_sight`,
and the cast refuses it before any cost. `TravelPlacementRules.destination_error`
refuses, in order: no authored reach, the same space, off-map, beyond the
authored distance, not visible when `requires_sight` is true (line of sight
only; PARTIAL: lighting, Blinded and invisibility are not consulted), then
`PlacementRules.legal_error` for the traveler's complete size-based footprint
(tile, walls, plane, clearance, living occupants and their footprints, blocking
objects), ignoring the traveler's own body. Combat checks this at target
validation and again immediately before the slot is committed, so a stale
destination refuses with the slot and Bonus Action unspent; the arrival is
marked settled on its `SpellCastContext`, so the resolver never moves or charges
the same invocation twice. The local-room host (`LocalRoomRules.cast_teleport`)
uses the same rules against `ContainmentRules.placement_state` (party, familiars,
steeds, created creatures and actors, objects) before `spend_spell_slot`.
Forced movement (spell push, Push mastery, barbarian push) stops before a step
whose full footprint is not legal; a body that already overlaps something at its
start is not trapped by that pre-existing overlap. Find Steed arrival still checks only its
center cell (PARTIAL).

Exit-before-settle (S-121, card Q-20261021-043117-1c72) is verified only for
the combat save-exit host (`s121_exit_placement_flow`). Engulf/swallow escape
exits are PARTIAL: no engulf or swallow host exists in the runtime yet, so no
required escape space is resolved before such an outcome settles.

Optional `material_targets` declares `tags` (`corpse`, `bones`), `range` in
hexes, optional `creature_types`/`sizes`, and optional `kinds` mapping template
IDs to required tags. Actual nearby dead Characters and combat monster bodies
are candidates. Protected/used remains are excluded, including room objects
whose `preserved_until` deadline has not elapsed. Reservation and consumption
read the live room object, so protection applied during a choice prevents its
use. Fewer remains cap the
cast's count; zero refuses. Before payment, exact distinct bodies are reserved,
including when several kinds need the same tag. Only a created source consumes
those reservations, once. Party bodies use the saved `transformed_undead`
restriction; monster-body use lasts only for the encounter. Smaller material-
capped counts remain valid after reload even for an authored fixed count.

## Exact commands and turns

Each template may declare `command`:

| Field | Supported values |
|---|---|
| `cost` | `action`, `bonus_action`, `magic`, `none` or synonym `free` |
| `order_costs` | Per-order override using the same costs |
| `range_hexes` | 1–24 |
| `orders` | `attack`, `dodge` |
| `default` | `dodge`, `none` |
| `control_seconds` | 6–86400; commands stop at the saved deadline |
| `initiative` | `owner_turn`, `after_owner`, `own`, `shared_count` |
| `initiative_group` | Required only for `shared_count`: `owner` or `roll` |
| `owner_incapacitated`, `owner_dead`, `control_expired` | `dodge`, `none`, `attack_nearest`; omitted means the declared default |
| `concentration_end` | `end`; source cleanup ends its actors |

Compatibility defaults are Bonus Action, 12 hexes, Attack/Dodge, Dodge and
owner-turn timing. New source-backed content should explicitly declare policy.
The HUD targets exact actor IDs, so equal names remain independently selectable.
Wrong owner/turn, incapacitation, range, unaffordable costs, invalid targets,
cancelled/stale popups and repeated commands refuse before payment. Magic uses
the existing `magic_action` budget and cannot spend an Action Surge action.

Owner-turn commands resolve immediately and uncommanded defaults run at owner
turn end. These actors clear Dodge at the next owner turn and tick conditions
once at owner turn end even if commanded or incapacitated. After-owner and
independent actors have their own tracker entries and budgets. Orders are paid
once on the owner's turn, then recheck control/owner state and target reach on
the creature's turn; lost authority invokes the declared fallback. Pending
orders are transient and not saved.

`shared_count` gives each exact cast source a group. `initiative_group: owner`
uses the owner's count and places its members after the owner and legacy
after-owner actors. `initiative_group: roll` rolls d20 + DEX once per source per
encounter. Its DEX comes from the first authored member's chosen template,
including mixed casts, even if another member joins first. Separate casts never
merge, including casts of the same definition or groups tied on the same count.
Groups stay contiguous; ties use DEX, source ID and member ID. Owner-linked
groups follow their anchor, ordered by source ID and then member ID.

Every member gets its own normal turn, Action/Bonus Action/reaction budget,
turn history and start/end condition boundaries. A shared count supplies no
shared action pool. Existing command costs and queued-order authority checks
still apply independently to each member. The group does not interrupt the
owner's ongoing turn; sorting or rebuilding it leaves the owner's paid work,
pending choices and budgets alone, including across controller reconnection.

The first actual turn at a numeric count closes that count to first-time
arrivals for the round, including arrivals into a new group or an existing
group after an unrelated tied combatant began. These members first act next
round. Thus a newly cast owner-count group during the owner's turn waits until
the next round; use `after_owner` for the existing immediate-after-owner timing.
Already-enrolled members keep pending turns when removed and reattached;
members whose turns began cannot restart them in that round. Empty-group
reconstruction retains its original count without another roll. Death removes
the member from initiative, while source ending removes only that source's
members. All of this history lasts for the encounter and clears at a new one.

Ending control does not delete a creature whose source persists. Source ending
removes only its own actors, preserving projected item copies. Summons cannot
keep a defeated party in combat. Initiative rebuild includes a summon that
rolls ahead of the original leader in round one. Allowed checkpoint reloads
restore sources, HP and control deadlines; live combat order is not saved.
Removing an owner from initiative retains a hidden scheduling-only slot while
living owner-linked actors or timed created sources need it. Independently
rolled actors keep their own counts; the slot only ages their source. It preserves the original combat ID,
initiative position and consumed-round state. Owner-turn actors run their normal
default and condition tick there; after-owner and shared-owner-count actors retain their separate turns,
budgets and order. The slot advances combat history without starting an owner
turn, restoring owner resources or replaying an interrupted action. Created-actor
source durations still age once at their normal start/end expiry boundary.

If a downed/dead owner has no entry when an encounter starts, one shared slot is
created at the end of initiative, with after-owner actors immediately following
it. No owner initiative roll, recovery or action runs. Healing an unavailable
owner or explicitly re-entering initiative restores that same slot without
resetting its consumed-round state or budgets. Control expiry and owner state
continue to select the source-declared behavior; they do not destroy persistent
creatures. Ending a source removes its own actors, and the scheduling-only slot
leaves once no living linked actors or timed created sources need it. Scheduling state remains transient.

## Declared reaction triggers

Spells with `casting_time: reaction` may declare `reaction_trigger` with an
`event`, optional `range_feet` (5–1000 in steps of 5) and `requires_sight`.
Events are `on_attacked`, `on_hit_by_attack`, `on_damaged_by_creature` and
`on_hit_with_attack`. No undeclared trigger is supplied by this path.

An activation mode may declare `costs.switch: reaction` only with an
`on_hit_with_attack` trigger and a `hit` switch window. It pays through that
trigger's confirmation; ordinary HUD/room presses cannot spend this cost.

Offers and confirmation check owner state, Reaction availability, trigger and
spell range, sight, casting eligibility and target restrictions. The live host
rechecks current positions and turn after the prompt. Cancel/refusal spends
nothing; confirmation spends the selected payment and Reaction once, closes
the event and resolves the spell without a second slot charge. Self spells
target the reactor; supported single-target spells target the event's source.

This host currently fires for monster weapon attacks on players and the main
player weapon hit. `on_attacked` is before the attack; the other incoming
events are after settlement and cannot change the triggering hit. Area,
creation, projection, formula-input and spatial reaction hosts are unavailable
here. Legacy Shield/Counterspell and other existing reactions keep their own
paths. Additional delivery routes and real Hellish Rebuke cast permission
remain in the roadmap.
