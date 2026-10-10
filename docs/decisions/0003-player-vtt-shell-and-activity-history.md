# ADR-0003: Use a desktop VTT shell with persistent activity history

Date: 2026-08-10

Status: Accepted

## Context

The current player interface exposes separate screen-specific HUDs, transient
dice popups, and developer-facing text logs. Important information moves
between screens, roll arithmetic disappears, and the visual hierarchy does not
give the map a stable frame.

The Crown milestone is shared-keyboard hot-seat play on one desktop monitor.
Later networked multiplayer is also expected to use one desktop view per
player, rather than split-screen or per-character viewports.

## Decision

Player-facing gameplay will use one desktop-first virtual-tabletop shell:

- the world or tactical map is the primary surface;
- stable peripheral chrome holds party status, global context, actions, and a
  right-side activity rail;
- the activity rail contains a bounded, campaign-persistent history of
  structured activity records, including rolls;
- roll arithmetic is authored by the gameplay resolver and revealed on hover,
  keyboard focus, or pinned expansion; the UI does not reconstruct results;
- the milestone history capacity is 200 top-level activity records, trimming
  the oldest complete record when the limit is exceeded; and
- the first visual profile is dark-fantasy VTT chrome, implemented through
  semantic theme roles and swappable theme-profile resources rather than
  gameplay code branching on a theme name.

Mouse input is primary. Click and keyboard-focus paths must expose any
information available on hover. One shared world view remains the ownership
model for shared-keyboard hot-seat play.

The detailed target behavior and acceptance evidence are defined in
[Player UI Contract](../ui/PLAYER_UI_CONTRACT.md).

## Consequences

### Approved presentation refinement — 2026-10-04

The owner approved an ornate grimoire concept and the complete player journey:
soot/slate surfaces, parchment text, aged-brass engraved borders, serif
headings and clear sans body type. The concept's panels depict separate
screens. Its terrain/portrait illustration does not replace existing game art.
1080p is the primary target, 1280 x 720 the minimum, and larger native windows
gain board area. Title navigation leads into campaign setup; creation uses
five reversible steps with editable name and a persistent consequences panel.
The [saved comparison and acceptance](../ui/VISUAL_ACCEPTANCE.md) record the
implemented presentation. This refinement does not expand mechanics or save
schema scope.

- `Dice` remains an entropy primitive. Domain resolvers must publish the
  contextual record after modifiers, targets, and outcomes are known.
- Roll history becomes save data and needs a versioned plain-DTO boundary,
  validation, bounded loading, and fresh-process round-trip evidence.
- Combat, overworld, and dungeon screens must mount the same shell contract
  instead of independently positioning common controls.
- Rails scroll independently so the map does not move when history or party
  content overflows.
- Themeable widgets consume semantic roles or type variations. Hardcoded
  presentation colors in gameplay UI are contract violations, except for
  data-driven entity identity and world-state visualization.
- Networking, private/GM rolls, controller navigation, chat, and split-screen
  are not introduced by this decision.

## Alternatives considered

### Keep the transient dice popup and text log

Rejected. It loses provenance, fragments attention, and cannot explain how a
resolved total was produced after domain modifiers are applied.

### Let each gameplay screen own its own HUD layout

Rejected. Common actions and information continue to move between screens,
and every new screen creates another styling and interaction dialect.

### Hardcode a dark palette into each widget

Rejected. It would reproduce the current inconsistency under a better coat of
paint and make later themes an invasive rewrite.

### Build split-screen or controller-first navigation now

Rejected for this milestone. The accepted local multiplayer boundary is one
shared keyboard and one shared desktop view. These additions require separate
ownership and interaction contracts.
