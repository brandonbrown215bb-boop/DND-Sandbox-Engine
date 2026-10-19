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

The review checks actual combat movement and loaded physical/spatial spell
selection, plus pure actor/object/copy queries. Placement uses the existing
single-cell token representation with vertical body clearance; it does not
reserve a multi-cell footprint for Large or larger bodies. No catalog conversion,
monster movement-mode AI, broad exploration-mode integration, phasing or
passenger movement is certified. Accepted paths still reserve their whole route
before opportunity/zone interruptions; this slice's zero-spend guarantee covers
initially refused movement, not refunds for an interrupted accepted route.

Current review evidence and slice disposition:
[Batches 029/030 review](../../.artifacts/planning/vocabulary-reports/batch-029-030-review.md).
