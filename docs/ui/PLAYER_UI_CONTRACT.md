# Player UI Contract

- Status: Accepted for implementation
- Decision basis: [ADR-0003](../decisions/0003-player-vtt-shell-and-activity-history.md)
- Target: desktop monitor, mouse primary, 1280 x 720 minimum composition
- History capacity: 200 top-level activity records per campaign

## 1. Authority and scope

This document defines what a player must see and be able to do in the Crown
milestone interface. It is a target contract, not a claim that the current UI
already behaves this way. After approval it supersedes the target-state parts
of [UI Overhaul - Research & Plan](../UI_OVERHAUL_RESEARCH.md); that document
remains useful as historical audit and implementation research.

This contract covers:

- the persistent gameplay shell used by combat, overworld, and dungeon views;
- the activity rail and exact roll-breakdown behavior;
- shared component, interaction, modal, accessibility, and theme boundaries;
- the player-facing shape of menus and secondary gameplay screens; and
- evidence required before the redesign can be called shipped.

Implementation checkpoint: the versioned `ActivityRecord` boundary, bounded
`ActivityHistory` campaign store, and `SaveManager` round trip are implemented.
Resolver publication, the activity rail, the shared shell, and the visual
acceptance evidence remain future slices; this contract does not claim those
surfaces are shipped yet.

It does not add network multiplayer, split-screen, controller support, chat,
GM-only information, private rolls, or third-party theme packaging.

## 2. Player-experience invariants

1. **The board owns the room.** World and tactical play receive the largest,
   quietest area. Chrome frames play; it does not compete with it.
2. **Common information stays put.** Party, scene context, activity, and the
   primary action zone occupy consistent edges across gameplay scenes.
3. **The next action is legible.** The current actor and available primary
   actions are visible without opening a menu or reading the activity rail.
4. **Nothing important is hover-only.** Hover is the fast mouse path. Click,
   pinned expansion, and keyboard focus expose the same content.
5. **The UI reports resolved truth.** Cards display values emitted by gameplay
   resolution. Presentation code never re-rolls or re-computes outcomes.
6. **Interruption is survivable.** Changing scenes, opening a modal, saving,
   loading, or reading older activity does not discard context.
7. **A modal is actually modal.** When a modal is open, world input and
   underlying HUD actions are blocked until it closes.
8. **State is not encoded by color alone.** Text, iconography, shape, or
   position accompanies color for selection, danger, success, and ownership.

## 3. Gameplay shell

### 3.1 Reference composition at 1280 x 720

The reference geometry is a layout contract, not an instruction to use fixed
pixel positioning. Godot `Container` nodes own resizing.

| Region | Reference size | Behavior |
| --- | ---: | --- |
| Context bar | 48 px high | Always visible; scene, objective, round/turn, and global menu |
| Party rail | 72 px wide | Always visible; may expand to 224 px over the board |
| Activity rail | 320 px wide | Open by default; collapses to a 48 px edge tab |
| Action dock | 72 px high | Contextual actions for the selected/current character |
| Board | Remaining area | Never scrolls because a rail overflows |

At 1280 x 720 with both rails open, the board retains at least 888 x 600 px.
At wider resolutions, additional space goes to the board before either rail.
The activity rail may grow to 380 px above 1600 px viewport width. Chrome does
not scale indefinitely. Merely upscaling the 1280 x 720 canvas at a larger
window size does not satisfy this rule; the board must gain usable logical
space.

The player may collapse the activity rail. Its open/collapsed state and scroll
position persist for the current play session. The party rail expands as an
overlay so inspecting a character does not permanently shrink the board.

```text
+-------------------------- context / objective / turn ------------------------+
| Party |                                                            |Activity|
| rail  |                         BOARD                              | rail   |
| 72 px |                    world or tactical                       | 320 px |
|       |                                                            |        |
|       |                                                            |        |
|       |                                                            |        |
|       |                                                            |        |
|       +---------------- action dock / current actor ----------------+        |
+--------------------------------------------------------------------+--------+
```

### 3.2 Context bar

The left side identifies the current place or encounter. The center holds the
current objective or encounter state. The right side holds round/turn context
and one global menu button.

The context bar must not become a second action bar. Save, settings, character
sheet, return-to-menu, and quit live behind the global menu unless a scene
requires one of them as its primary task.

### 3.3 Party rail

Each occupied slot shows, in this order:

- portrait or stable silhouette;
- character name or an unambiguous shortened form;
- HP as bar plus current/max values;
- condition markers; and
- logical-seat ownership when more than one seat exists.

Current actor, selected character, downed state, and acting seat must remain
distinct visual states. Clicking a slot selects or inspects according to the
current scene; it never silently changes party leadership or seat ownership.

### 3.4 Action dock

The action dock mounts the existing contextual-action concept as one shared
component. It contains:

- the current actor identity and remaining action resources;
- three to six primary actions as icon-plus-label controls;
- an overflow control for lower-frequency actions; and
- a scene-specific end/confirm action at the far edge when one exists.

Unavailable actions remain in place when their location aids learning, but
show a concise disabled reason on hover/focus. A scene must not expose two
equally dominant confirm buttons.

Combat may add a compact initiative strip directly above the dock. Overworld
and dungeon views may replace that strip with travel, formation, or room
context. They do not rearrange the shell edges.

## 4. Activity rail

### 4.1 Purpose and contents

The activity rail is the recoverable account of what the game resolved. It
contains rolls, combat outcomes, healing, resource changes, important travel
or event results, and concise system notices. It is not debug output and does
not print stack traces, internal IDs, or implementation diagnostics.

For player-visible outcomes, structured cards replace the global transient
dice popup and legacy text log. Brief world-anchored callouts may reinforce an
outcome, but they cannot become a second competing history or obscure input.

The default tabs are:

- **All** - every player-facing record;
- **Rolls** - checks, saves, attacks, damage, healing, and table rolls;
- **Combat** - turn, condition, damage, healing, defeat, and resource events;
- **System** - save/load and other player-relevant state notices.

Filters change the view, not stored history. The Crown milestone has no
destructive player-facing "clear history" action.

### 4.2 Ordering and scrolling

Records are chronological, oldest at the top and newest at the bottom.

- If the player is at the bottom, a new record follows automatically.
- If the player has scrolled upward, the viewport does not move. A `New (N)`
  control appears and returns to the newest record when activated.
- Switching filters preserves an independent scroll position per filter for
  the session when the matching content still exists.
- Loading a campaign opens at the newest record. Scene transitions preserve
  the current rail position.
- The rail scrolls independently of the board and action dock.

### 4.3 Record-card anatomy

Every card has a collapsed summary that is useful without hover:

```text
+--------------------------------------+
| 12  Elowen - Longsword      HIT       |  outcome and actor
|     1d20 + 5 = 17 vs AC 14            |  concise resolved summary
|     8 slashing                         |  optional secondary outcome
+--------------------------------------+
```

Hovering or keyboard-focusing the arithmetic row opens a non-blocking detail
surface. Clicking the card pins the same detail inline until clicked again.

```text
Attack roll
  d20                     12
  Strength                 +3
  Proficiency              +2
  --------------------------------
  Final total              17
  Target AC                14
  Result                   Hit by 3

Damage
  1d8                       5
  Strength                 +3
  --------------------------------
  Slashing damage           8
```

Individual die results are shown for multi-die rolls. Kept, discarded,
critical, minimum, and maximum dice have labels or marks in addition to color.
Source labels use player language such as `Bless`, `Cover`, or `Proficiency`,
not resolver property names.

### 4.4 Grouping

One player intent produces one top-level card when its results belong together.
An attack card may contain attack and damage sections. A spell affecting many
targets may contain a parent summary with expandable target rows.

The 200-record capacity counts top-level cards. A complete parent and its child
rows are trimmed as one unit; history must never retain orphaned arithmetic.

## 5. Activity data contract

### 5.1 Ownership boundary

The component that knows the final gameplay outcome publishes the record.
`Dice` may generate primitive die results, but it does not know enough to
publish an attack, save, check, damage, or healing record on its own.

The resolver publishes exactly once after modifiers, target numbers, and
outcomes are settled. The UI renders the published values and does not infer
missing math. Records are immutable after publication except for explicit
version migration during load.

### 5.2 Versioned plain DTO

The implementation may use typed resources or classes internally, but the
persistence boundary is a versioned dictionary containing only JSON-safe
values. Its canonical top-level fields are:

| Field | Contract |
| --- | --- |
| `schema_version` | Positive integer; current writer version |
| `id` | Campaign-unique stable string |
| `sequence` | Monotonically increasing integer used for ordering |
| `category` | `roll`, `combat`, `world`, or `system` |
| `kind` | Stable subtype such as `attack`, `saving_throw`, or `damage` |
| `actor` | Optional stable character/entity reference plus captured display name |
| `targets` | Present array containing zero or more stable references plus captured display names |
| `title` | Player-facing short label |
| `summary` | Player-facing collapsed result |
| `outcome` | Optional stable result code plus player-facing label |
| `campaign_time` | Optional turn/day/scene context; not wall-clock authority |
| `scene_context` | Stable encounter, room, or region references when available |
| `payload` | Kind-specific resolved detail |
| `visibility` | `public`; reserved for future networking without enabling secrecy |

`schema_version`, `id`, `sequence`, `category`, `kind`, `title`, `summary`,
`targets`, `payload`, and `visibility` are required. `actor`, `outcome`,
`campaign_time`, and `scene_context` may be absent when they have no truthful
value. An empty string does not substitute for a missing optional value.

Captured display names preserve readable history if content labels change.
Stable references retain traceability. Missing optional references do not make
an otherwise readable historical card unloadable.

### 5.3 Roll payload

A roll payload contains:

| Field | Contract |
| --- | --- |
| `formula` | Player-readable formula at resolution time |
| `dice_terms` | Dice groups with count, sides, individual results, kept flags, labels, and subtotal |
| `modifiers` | Ordered player-facing label, signed value, and optional source reference |
| `natural_total` | Sum of kept dice before modifiers |
| `final_total` | Authoritative resolved total |
| `comparison` | Optional comparison kind, target value, margin, and result |
| `sections` | Optional nested resolved sections such as attack and damage |

Example shape:

```json
{
  "schema_version": 1,
  "id": "activity-004281",
  "sequence": 4281,
  "category": "roll",
  "kind": "attack",
  "actor": { "id": "pc-elowen", "name": "Elowen" },
  "targets": [{ "id": "goblin-3", "name": "Goblin" }],
  "title": "Longsword",
  "summary": "17 vs AC 14 - Hit",
  "outcome": { "code": "hit", "label": "Hit" },
  "visibility": "public",
  "payload": {
    "formula": "1d20 + 3 + 2",
    "dice_terms": [{
      "count": 1,
      "sides": 20,
      "results": [12],
      "kept": [true],
      "label": "d20",
      "subtotal": 12
    }],
    "modifiers": [
      { "label": "Strength", "value": 3 },
      { "label": "Proficiency", "value": 2 }
    ],
    "natural_total": 12,
    "final_total": 17,
    "comparison": {
      "kind": "armor_class",
      "target": 14,
      "margin": 3,
      "result": "hit"
    }
  }
}
```

### 5.4 Persistence and failure behavior

- Activity history is campaign-scoped and saved through `SaveManager` as a
  versioned plain DTO collection.
- Save/load preserves record order, the next sequence value, and every value
  required to display arithmetic after a fresh-process relaunch.
- The writer stores at most 200 top-level records. The loader also clamps to
  the newest 200 so older or externally modified saves cannot bypass the cap.
- A malformed record is skipped with a non-fatal diagnostic. One bad record
  must not prevent the campaign from loading or mutate active managers before
  save validation succeeds.
- Unsupported future record versions are not guessed at. They are omitted with
  a player-safe notice and a diagnostic suitable for test evidence.
- UI-only state such as filter, pinned cards, rail width, and hover state is not
  campaign save data.

## 6. Shared component contracts

| Component | Responsibility | Must not own |
| --- | --- | --- |
| `VttShell` | Stable edge layout, modal layer, board slot | Gameplay resolution |
| `ContextBar` | Place, objective, turn/round, global menu | Scene-specific action grids |
| `PartyRail` | Party summary and selection/inspect intent | Party mutation rules |
| `ActivityRail` | Filtering, scrolling, record presentation | Roll calculation or persistence writes |
| `ActivityCard` | Collapsed, hover/focus, pinned detail states | Domain labels inferred from raw IDs |
| `ActionDock` | Contextual action presentation and intent signals | Action validity or resource mutation |
| `ModalSurface` | Focus trap, dismissal policy, underlying-input block | Direct scene-tree replacement |
| `StatBar` | Labeled current/max visualization | Entity mutation |
| `Tooltip` | Short explanation anchored to a control | Sole access to required information |

Scene coordinators provide models and receive intent signals. Reusable UI
components do not reach through deep scene paths to gameplay nodes.

## 7. Secondary screen contracts

### Main menu

The first screen presents `Continue` when a valid campaign exists, `New
Campaign`, `Load`, `Settings`, and `Quit`. Mod diagnostics and content-collision
details move to a deliberately opened diagnostics surface, not the primary
menu.

### Character creation

Creation is a stepped, reversible flow with persistent visible progress. Each
choice shows its gameplay consequence before confirmation. Generated names are
editable and never replace intentional naming. Summary and backtracking are
available before committing the character.

### Camp roster

Camp roster remains a focused modal task. Character identity and status lead;
seat, companion, leadership, and formation controls are grouped by decision
rather than repeated as a dense row of equal-weight buttons.

### Character sheet, settings, shop, and event dialogs

These use the shared modal surface when invoked during play. Opening them
blocks underlying map and action-dock input. Close behavior, title placement,
spacing, and focus treatment are consistent.

Settings expose only working settings. `High Contrast` is either wired to a
complete profile and verified or absent from the player-facing surface.

### Terminal victory and defeat

Terminal screens state the campaign outcome, preserve access to relevant final
activity, and offer one obvious continuation path. They do not drop the player
onto a blank or generic scene.

## 8. Theme contract

### 8.1 Profile boundary

The shell consumes one `UiThemeProfile`-equivalent resource selected outside
gameplay widgets. The exact Godot class name may change, but the profile owns:

- a Godot `Theme` resource;
- semantic color and spacing tokens;
- typography roles;
- icon and decorative texture catalogs;
- sound and motion treatment for UI feedback; and
- a stable profile ID and display name.

Gameplay screens do not branch on that ID. Swapping profiles changes chrome
without changing gameplay scene code. Missing optional art falls back to a
neutral built-in treatment rather than breaking the control.

### 8.2 Semantic roles

Widgets consume roles or Godot theme type variations, including:

- `surface/base`, `surface/raised`, `surface/overlay`, `surface/selected`;
- `text/primary`, `text/muted`, `text/inverse`;
- `accent/primary`, `accent/secondary`, `focus/ring`;
- `state/success`, `state/warning`, `state/danger`, `state/info`;
- `border/subtle`, `border/strong`; and
- `space/1` through `space/6`, corner, elevation, and motion roles.

Runtime color overrides are reserved for data-driven identity colors and world
visualization such as ownership, faction, range, path, or hazard overlays.
Chrome state uses semantic roles.

### 8.3 Dark-fantasy baseline

These values establish direction and token relationships. Visual QA may adjust
them to meet contrast requirements without changing component code.

| Role | Baseline |
| --- | --- |
| `surface/base` | `#0C0D10` soot |
| `surface/raised` | `#17191F` iron |
| `surface/overlay` | `#20232B` slate |
| `text/primary` | `#E8E0D1` parchment |
| `text/muted` | `#AAA190` ash parchment |
| `accent/primary` | `#C69A4A` aged brass |
| `accent/secondary` | `#6F829C` cold steel |
| `state/success` | `#739B69` moss |
| `state/warning` | `#D19A52` ember |
| `state/danger` | `#B5524F` dried blood |
| `focus/ring` | `#F0C96D` candle gold |

Surfaces use restrained texture and ornament. Decorative frames cannot reduce
text contrast, shrink hit targets, or make repeated cards visually noisy.
Body copy uses a highly legible UI face; a display face may be used for short
titles only. The shipped profile enables readable font antialiasing.

## 9. Interaction and accessibility

- Mouse hit targets are at least 40 x 40 px at the 1280 x 720 reference size;
  primary buttons target 44 px height.
- Body text is at least 15 px equivalent at the reference size. Dense secondary
  labels may use 13 px only when they are not required to act.
- Every interactive control has normal, hover, pressed, keyboard-focus,
  selected, disabled, loading, and error treatment where those states apply.
- Tooltips appear after a short delay of roughly 350-500 ms and remain while
  the pointer moves into an interactive detail surface.
- Focus order follows visual reading order. Modals trap focus and restore it to
  their opener when closed.
- Escape closes the top dismissible layer. It never bypasses a confirmation
  that protects campaign state.
- Animation communicates relationship and state change, stays under 200 ms for
  routine chrome, and has a reduced-motion path.
- Text and essential icons maintain at least WCAG 2.2 AA contrast. Large
  decorative titles may use the large-text threshold; arithmetic may not.

Mouse-first does not mean mouse-exclusive. Full controller navigation is out of
scope, but keyboard focus must make hover detail testable and recoverable.

## 10. Acceptance evidence

The redesign is not accepted from a green logic suite alone. Evidence must
exercise production scenes and exact player-visible states.

### Shell and visual hierarchy

- Fresh captures at 1280 x 720 and 1920 x 1080 for main menu, character
  creation, overworld, dungeon, combat, camp roster, character sheet/settings,
  and terminal outcome.
- Captures show the activity rail open and collapsed, the party rail expanded,
  a modal over gameplay, and disabled/hover/focus action states.
- At 1280 x 720 the board remains at least 888 x 600 px with both rails open;
  no essential text clips and rails scroll independently.

### Activity and rolls

- A deterministic attack fixture proves displayed dice, modifiers, final
  total, comparison, margin, outcome, and damage equal resolver output.
- Hover, keyboard focus, and pinned click expansion reveal equivalent math.
- While reading older activity, new records do not steal scroll; `New (N)`
  returns to the bottom and resets correctly.
- Filtering never deletes records or changes their order.
- The 201st top-level record trims exactly the oldest complete card.
- Scene transition, save, fresh-process relaunch, and load preserve the newest
  200 records and exact arithmetic.
- A malformed record is skipped without losing the campaign; an unsupported
  future schema produces a safe notice and diagnostic evidence.

### Theme boundary

- A minimal second test profile swaps surface, text, accent, icon, and spacing
  treatments without editing gameplay scene code.
- A source check rejects new hardcoded chrome colors outside the approved
  data-driven exceptions.
- Contrast is measured for body text, arithmetic, buttons, focus rings, and
  state badges in the dark-fantasy profile.

### Input and continuity

- Opening every gameplay modal blocks map selection, movement, and action-dock
  activation beneath it; closing restores focus to its opener.
- Shared-keyboard seat and current-actor cues remain distinct through turns,
  save/load, recruitment, leadership change, and formation change.
- Production-path smoke is run in isolated profile roots so real player saves
  and settings cannot decide the result.

## 11. Implementation order

This order limits rework without turning the contract into one giant quest:

1. **Activity foundation:** immutable DTO, publisher boundary, bounded store,
   SaveManager round trip, and deterministic roll fixture.
2. **Shell skeleton:** shared container layout, modal layer, theme-profile seam,
   and empty activity/party/action slots.
3. **Combat vertical slice:** structured attack/damage cards, party rail,
   action dock, initiative context, and visual evidence.
4. **Overworld and dungeon adoption:** same shell, scene-specific context and
   actions, uninterrupted history.
5. **Secondary screens:** menus, creation, camp roster, sheets, settings,
   events, shop, and terminal states.
6. **Dark-fantasy finish:** licensed typography/icons/textures, motion/sound,
   contrast pass, and second-profile swap proof.

Each step receives its own Quest Board card and validation evidence. A later
step may refine art, but it may not violate the data, persistence, layout, or
interaction boundaries established here without a superseding decision.

## 12. Review choices still open

The contract intentionally leaves three art-direction choices outside the
architecture decision:

- final typefaces and licenses;
- final icon family and decorative texture language; and
- whether the 200-record capacity becomes player-configurable after Crown.

These choices do not block the activity foundation or shell skeleton.
