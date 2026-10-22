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
cast. Mixed kinds currently share a size and command policy.

`placement` accepts `range_hexes` (1–24), `choose` (boolean) and `no_space`
(`refuse` or `spend`). Omitted fields mean adjacent placement, no chooser and
refusal before costs. The combat picker reserves one distinct cell per actor.
The placement/payment checks use actual occupancy, grid passability, room
walls, plane and the chosen body's vertical clearance. A stale/blocked choice
refuses before costs. A declared paid no-space outcome creates no actor/source
and consumes no remains. `_factory` and `_placement` live only on a cast copy.

`CreatedActorRules.attach` uses the actual chosen template's size. It rechecks
confirmed cells, falling back to legal nearby cells for encounter attachment;
with no destination an actor stays off-grid. Existing saved sources attach on
encounter entry before initiative. This is still a single-cell body model.
`ItemProjectionRules.attach` uses legal adjacent placement for the exact copy;
its full controls and failure policy remain separate work.

Optional `material_targets` declares `tags` (`corpse`, `bones`), `range` in
hexes, optional `creature_types`/`sizes`, and optional `kinds` mapping template
IDs to required tags. Actual nearby dead Characters and combat monster bodies
are candidates. Protected/used remains are excluded. Fewer remains cap the
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
| `initiative` | `owner_turn`, `after_owner`, `own` |
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

Ending control does not delete a creature whose source persists. Source ending
removes only its own actors, preserving projected item copies. Summons cannot
keep a defeated party in combat. Initiative rebuild includes a summon that
rolls ahead of the original leader in round one. Allowed checkpoint reloads
restore sources, HP and control deadlines; live combat order is not saved.
After-owner scheduling still needs an owner entry: summons entering with an
already downed/dead owner have no anchor and do not receive those turns.
Owner-turn actors likewise have no default trigger once the owner leaves
initiative. These S-157/S-158 limits remain in the roadmap.

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
