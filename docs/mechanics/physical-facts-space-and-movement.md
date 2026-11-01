# Physical facts, space, and movement

Specification and runtime contracts for Batch 030:
- **S-032** (V-005): Physical size, mass, material, thickness, and equipment/worn/carried/fixed facts.
- **S-033** (V-005): Plane, location, and available-space facts without entity creation/movement side effects.
- **S-179** (V-069): Walking, climbing, swimming, flying, and hover speeds, surface/hand requirements, terrain costs, and refusal spending 0 distance.

## 1. Physical facts and unknown value refusal (S-032)

Physical eligibility facts describe intrinsic dimensions, composition, and relation to actors for characters, monsters, world objects, and inventory items.

### Properties

- `size`: Standard D&D size category: `"tiny"`, `"small"`, `"medium"`, `"large"`, `"huge"`, `"gargantuan"`.
  - Characters query race base size, modulated by runtime conditions (`enlarge` steps up one size, `reduce` steps down one size).
  - Monsters query definition size.
  - Objects and items query record size or item definition.
- `mass_lb`: Weight/mass in pounds.
  - Characters query explicitly represented mass; a race/size does not invent a weight.
  - Objects and items query explicit `weight_lb` or item definition weight.
- `material`: Physical substance: `"flesh"`, `"bone"`, `"metal"`, `"iron"`, `"wood"`, `"stone"`, `"glass"`, `"crystal"`, etc.
  - Creature type and name do not invent composition. Unrepresented material is unknown.
  - Objects and items query explicit material or definition.
- `thickness_inches`: Physical thickness of the barrier or object in inches.
- `equipment_status`:
  - `worn`: Item is worn by an actor.
  - `carried`: Item is carried/held in inventory by an actor.
  - `fixed`: Object is immobile or fixed in place (fixtures, anvils, terrain).
  - `loose`: Object is unattended on the ground (`not worn and not carried and not fixed`).

### Refusal of eligible-only actions on unknown values

Actions or spell steps requiring physical criteria (e.g. Catapult requiring a loose unattended object up to 5 lbs, Shatter targeting metal/crystal objects) evaluate filters against target facts:
- If a required physical property is missing or unknown on the target, the action/step **refuses eligibility** (`eligible: false`, `reason: "Target [fact] is unknown."`).
- Unknown facts cannot make an action eligible.
- `reject_unknown: false` is rejected. Invalid, negative or nonfinite measurements
  remain unknown. Dropped/owned copy projections preserve missing facts.
- Status checks require the facts they use: `fixed: false` alone proves
  `not_fixed`, but cannot prove that the copy is also unworn and uncarried.

## 2. Plane, location, and available-space facts (S-033)

S-033 provides side-effect-free querying of placement facts:
- `plane`: Declares the operational plane (e.g. `"material"`, `"ethereal"`). Default is `"material"`. Queries between differing planes are refused without cross-planar traversal.
- `location`: Returns actual plane, grid coordinates, elevation, and altitude.
- `is_space_available`: Evaluates whether a body of a given size category can occupy a target position on a plane:
  - Grid bounds and passability.
  - Solid room walls and fixed barriers.
  - Vertical ceiling clearance against body size minimum requirements (Tiny: 2 ft, Small: 4 ft, Medium: 6 ft, Large: 10 ft, Huge: 15 ft, Gargantuan: 20 ft).
  - Occupancy: another living creature blocks end placement, including Tiny bodies.
  - Fixed blocking objects with HP > 0.
  - **Side-effect-free**: Querying available space does not move, create, or modify any entities or grid tiles.

`plane`, `same_plane_as_caster` and integral `clearance_feet` requirements run
through actual spell targeting and ordered recipients. Missing grid/location
refuses a required placement query. Unlocated actors report `location_known: false`.

## 3. Speeds, modes, surface/hand requirements, and terrain costs (S-179)

S-179 governs mode selection, surface traversal requirements, terrain multipliers, and movement execution budgets:

### Movement modes and speeds
- Supported modes: `"walk"`, `"climb"`, `"swim"`, `"fly"`.
- Declared speeds:
  - Walking: Character base speed (hexes * 5 = feet).
  - Climbing: Character declared climb speed (or monster climb speed).
  - Swimming: Character declared swim speed (or monster swim speed).
  - Flying: Declared fly speed (or monster fly speed), with explicit `hover` boolean.
- The combat picker also exposes ordinary climbing/swimming using walking
  allowance at the additional per-step cost below. Changing modes retains spent
  distance and grants a Dash allowance once; prone mode changes preserve it too.

### Hand and surface requirements
- **Climbing**:
  - Requires 2 free hands (hands not holding weapons or shield). Wielding a two-handed weapon or weapon+shield leaves 0 free hands and refuses climbing.
  - Spider Climb spell overrides hand requirements (0 hands needed).
  - Sheer or slippery surfaces cannot be climbed without a declared climb speed or Spider Climb.
  - Inverted ceilings require Spider Climb or specialized ceiling adhesion.
- **Walking**:
  - Cannot walk on liquid (water/acid/lava) without Water Walk.
- **Swimming**:
  - Requires a liquid or submerged environment.
- **Flying**:
  - Requires declared fly speed > 0.
  - Refused if creature is prone (without hover), restrained, paralyzed, or petrified.

### Terrain and mode cost calculation
- Base cost per 5-foot hex: 5 ft (1.0 hex).
- Mode multiplier:
  - Walk: 1.0x (5 ft).
  - Climb without climb speed: 2.0x (10 ft per hex, 1 extra foot per foot moved). With climb speed: 1.0x (5 ft).
  - Swim without swim speed: 2.0x (10 ft per hex). With swim speed: 1.0x (5 ft).
  - Fly: 1.0x (5 ft).
- Terrain costs:
  - Difficult terrain adds +1.0x base (+5 ft / +1.0 hex).
  - Climbing without climb speed in difficult terrain stacks to 3.0x (15 ft per hex).
  - Flyers **ignore ground difficult terrain** (cost remains 1.0 hex / 5 ft).

### Movement refusal policy
- If a movement attempt is refused for any reason (insufficient remaining budget, illegal surface, missing free hands, occupied space, impassable wall):
  - **0 distance is spent** (`spent_distance_feet: 0`).
  - **Remaining movement budget is untouched** (`remaining_budget_feet == initial_budget`).
  - **Unrelated modes are completely unaffected**.

## Verified host and limits

Shared creation/arrival now consumes these queries through
[placement and factory controls](created-actors-and-placement.md#factory-and-legal-arrival).
It reserves distinct size-based footprints and rechecks occupancy, walls,
plane and the chosen template's clearance before payment. S-121 now uses the
same query for a successful numeric save's required exit: it captures the
original roll/total/DC, suspends before damage or failed-save effects, offers
only legal destination cells, and rechecks the actor's location, size, plane,
the complete footprint, occupancy, walls and declared clearance after the choice. The actor moves once
only after that check. If no exit is legal, the authored `no_space_outcome`
either changes the save to failure or preserves its captured outcome. Save-bonus
costs whose policy depends on the final outcome stay reserved until exit
settlement, then commit or refund against that outcome.
Settlement resumes the original saving-throw context, retaining its source and
slot receipts without repeating Sanctuary, interruption checks or cast costs.

The verified S-121 host is a flat, single-target numeric saving throw in combat
and local-room exploration. The room host binds the saved party coordinates,
room plane and live grid, and the actual room-map choice/cancel control resumes
the captured continuation. Stepped, multi-target, attack, repeat-save, missing-
save and recipient-exemption combinations are rejected. Cancellation,
stale/duplicate answers and destinations that become occupied, blocked or too
small for declared clearance refuse without movement or premature consequences.
While the room map choice is open, competing room controls are disabled;
closing the room cancels the captured continuation. Ordinary room healing and
buff casts retain their existing Cast route.
Containment and swallowing remain outside this slice.

The review checks actual combat movement and loaded physical/spatial spell
selection, plus pure actor/object/copy queries. Ordinary movement uses the existing
single-cell token representation. Creation and required save exits use the
[explicit size-based footprint policy](created-actors-and-placement.md#factory-and-legal-arrival);
ordinary movement does not yet enforce those footprints. No catalog conversion,
monster movement-mode AI, broad exploration-mode integration, phasing or
passenger movement is certified. Accepted paths still reserve their whole route
before opportunity/zone interruptions; this slice's zero-spend guarantee covers
initially refused movement, not refunds for an interrupted accepted route.

Current review evidence and slice disposition:
[Batches 029/030 review](../../.artifacts/planning/vocabulary-reports/batch-029-030-review.md).

Containment admission uses the same size/plane facts. Internal bodies report no
external position through `PhysicalFactsRules.get_location`; their container
identity and separately queried external origin are retained. Internal bodies
do not reserve their remembered entry cell. See [containment](containment.md).

## Declared spatial trigger scopes (S-184)

`SpatialTriggerRules` supplies source-owned policy limits and delivery receipts.
`CombatSpellZones` and `LocalRoomAreas` consume them for declared damage areas;
native catalog zones retain their existing resolvers. A source-end `room_area`
child can now declare this executable data:

```json
{
  "id": "embers",
  "type": "room_area",
  "kind": "trigger_damage",
  "trigger_scope": "declared",
  "amount": 3,
  "damage_type": "fire",
  "radius_hexes": 1,
  "duration_seconds": 120,
  "trigger_limit": 100,
  "trigger_policies": [
    {
      "id": "contact",
      "events": ["entry", "end_turn"],
      "boundary": "turn",
      "limit": 1
    }
  ]
}
```

`trigger_limit` remains required by the room-area producer's legacy shape;
declared areas use each policy's `limit` and `boundary` instead of that lifetime
counter. Policy IDs must be distinct within a source. All events listed in one
policy share its limit; separate policies have separate limits and deliveries.

| Event | Actual observation |
|---|---|
| `entry` | Actor changes from outside to inside the represented area. Teleport arrival can enter; cells between its endpoints do not trigger. |
| `crossing` | An actual movement step changes inside/outside membership in either direction. Teleports do not cross intervening space. |
| `first_approach` | First actual move to an inside cell within the declared turn/lifetime allowance, including movement that starts inside. Area movement and teleport arrival do not count. |
| `start_turn`, `end_turn` | The affected actor starts/ends its turn inside. Merely refreshing membership does not emit a turn event. |
| `area_enter` | Explicit area movement newly covers a stationary actor. It never borrows `entry`, `crossing` or `first_approach`. |

| Boundary | When that exact source/policy/actor allowance renews |
|---|---|
| `event` | A new accepted movement/area-motion/turn event; duplicate callbacks remain the same event. |
| `turn` | Next initiative turn, regardless of whose turn it is. |
| `actor_turn` | Next turn of the affected actor. Other actors' turns leave it spent. |
| `source_turn` | Next turn of the area's `caster_id`, including its retained scheduling-only owner interval. |
| `lifetime` | Never within this exact source. A new source owns a new allowance. |

Combat uses encounter identity plus initiative round/active actor for the turn
boundary. Repeated start callbacks cannot invent another turn. Represented
rooms persist an encounter serial so a fresh process cannot reuse old combat
movement receipts. Character IDs stay stable; encounter monsters receive an
encounter-qualified trigger identity, so a later encounter's `monster_0` cannot
inherit another monster's lifetime limit. Actor/source-owner clocks remain with
the room across encounter entry/exit and advance only when that actor actually
starts a turn. Room exploration advances declared clocks through its actual
**End Turn** control: end triggers use the old interval, then that actor starts
the next interval. Campaign seconds and movement clicks alone do not reset it.

Accepted combat movement steps carry their own event identity. The area reserves
its source/policy/actor/event receipt and allowance before damage or any awaited
concentration prompt. Combat and room recipients, geometry and clocks for that
event are captured before the first await. Repeated delivery, replay after a turn
reset, and cleanup during a suspended callback cannot deliver it twice. Source
removal/expiry invalidates queued deliveries; it leaves other sources intact.
Events predating creation cannot become entries into the newly created source.
Start/end boundary events are captured even if no area is present, so a newly
created area cannot retroactively consume a repeated callback for a passed turn.

The combat factory `add_trigger_area` accepts the same validated child declaration
under an exact source ID. `move_trigger_area` moves such an encounter area;
`move_room_trigger_area` delivers motion of an existing room area to the encounter's
live participants. `LocalRoomAreas.move_area` is the synchronous room hook. These
are represented circular areas with a center and radius. Moving a room child
preserves its captured `created_center` separately from its legal current center.
Source-end choices retain the existing parent slot and child receipts; a resumed
or stale answer cannot recreate the area or repay its cast.

Hazard outcomes retain HP loss as `damage` and damage taken after resistance,
immunity and wards as `resolved`. Concentration uses `resolved`, including
damage absorbed by Temporary HP. Combat uses its existing reaction prompts;
room movement, turn and area-motion deliveries use the same concentration
rules synchronously, without optional reaction prompts. A failed check cleans
the exact concentration source and its recipients.

Durable room records retain policy receipts, counters and clocks at existing
allowed checkpoints. Pending deliveries and malformed clocks/ledgers refuse
checkpoint loading/saving; this adds no mid-combat save permission. Runtime
contexts and delivery wrappers are not saved. Combat movement still reserves
the accepted route's normal movement allowance before interruptions; lethal
hazards stop the route at the actual entered cell, without replay/refunding the
reserved route. Room movement charges the steps actually taken.

The SRD distinctions are taken from
[SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf):
Guardian of Faith p.137 (first nearby movement versus turn start), Black Tentacles
p.113 (entry/end and one save per turn), Cloudkill p.116 (area movement separately
from entry), Web p.174 (first entry versus turn start), Wall of Fire p.172 (first
entry plus a separate end trigger), and Wall of Ice pp.172–173 (passing through
residue). These clauses motivate distinct policies; they do not certify those
whole spells. Antipathy/Sympathy pp.109–110 retains its separate creature-kind,
forced movement and temporary-immunity requirements.

Verified behavior and production checks belong in the
[S-184 boundary](../planning/vocabulary-slices.md#spatial-trigger-scopes).
This delivery supplies fixed typed damage consumers and the reusable claim/settle
boundary. General save/condition/choice payload authoring, automatic appearance
events, arbitrary wall-edge/segment geometry, selective barriers, destructible
sections, passenger/follower movement, required-save-exit relocation, broader
travel hosts and catalog conversion remain separate. `appearance` is rejected
as an unsupported policy event. Existing native spell behavior is not converted
or recertified by these declarations.
