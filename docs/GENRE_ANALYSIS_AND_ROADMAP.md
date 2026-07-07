# Genre Analysis & Fun Roadmap — Top Down Party Game

> Source: deep web research (2026-07-07) on sibling titles + game-design consensus on
> what makes turn-based tactical combat fun, compared against the current UI/feel state
> of this project.

## Verdict

The UI is **more complete than the fun gap suggests**. Combat HUD already ships the bones
siblings ship with: initiative order with a turn pointer, a stats sidebar
(HP/AC/speed/spell slots/features/conditions), weapon+range readout, a full character
sheet, and animated dice rolls (nat-20 gold / nat-1 red). The tactical foundation is real
— movement highlights, reachable-hex calc, AOE cones/spheres, pathfinding.

The gap is **feel and payoff**, not function. Toggles for `screen_shake` and
`damage_numbers` exist in settings, but floating damage numbers are **never wired into
combat**. The defeat path is a silent `return_to_menu()`. No health bar over a unit, no
enemy intent preview, no demo ending. That is the difference between "works" and "lands."

## Sibling reference set

- **Solasta: Crown of the Magister** — closest cousin (5e SRD, tile combat). Verticality
  (high/low ground), environment interactions (push/knockback), **reaction system**
  (opportunity attacks, counterspell prompts), manual rolls with visible
  advantage/disadvantage, fog of war + line of sight, color-coded state. Ships a dungeon
  maker + Steam Workshop. Solasta 2 announced (EA 2026).
- **Baldur's Gate 3** — surfaces/hazards (fire/oil/water), climb/vault, **reaction
  prompts**, the world reacts to rolls.
- **Wildermyth** — fun via *story attachment* (papercraft, legacy characters), not just
  systems.
- **Battle Brothers** — fun via *tension + consequence* (morale, permanent injuries,
  flanking, no hand-holding).
- **For the King / Iratus** — overworld exploration + roguelike consequence loops.

Design-consensus takeaways: depth of tactics (positioning, terrain, counters) +
**readable state** (whose turn, who can act, HP at a glance) + **feedback/juice**
(numbers, shake, anim) + **a reason to care** (goal / character).

## Current state vs siblings

| Layer | Present | Sibling bar | Status |
|---|---|---|---|
| Action UI (attack/spell/dodge/features/end) | yes | same | MET |
| Initiative order + turn pointer | yes | same | MET |
| Stats readout (sidebar + sheet) | yes | full sheet | MET |
| Dice feedback (animated, nat-20/1 color) | yes | same | MET |
| Tactical grid (move/attack/AOE highlights, pathfinding) | yes | same | MET |
| Floating damage numbers | toggle only, not wired | on every hit | MISSING |
| Screen shake on hit | toggle only, not wired | on impact | MISSING |
| Health bars over units | none | always | MISSING |
| Enemy intent preview | none | telegraphed | MISSING |
| Move-path preview on hover | none (commit blind) | hover path | MISSING |
| Victory / defeat screen | silent menu return | payoff screen | MISSING |
| Overworld goal / objective tracker | none tracked | visible goal | MISSING |
| First-time guidance | none | tutorial hints | MISSING |

## Roadmap to a *fun* start-to-finish demo

### P0 — juice + payoff (cheap, high impact, makes it feel alive)
1. Wire the existing `damage_numbers` / `screen_shake` settings into combat: floating
   combat text on hits, camera shake on damage, hit-flash + death-fade on sprites.
   Plumbing is half-there; mostly connection.
2. Health bars over each unit (HP at a glance — single biggest readability win).
3. A real demo arc with an ending: overworld objective tracker ("Reach the dungeon →
   defeat the boss"), and victory/defeat screens with "Return to Menu / Play Again"
   instead of a silent kick. Dungeon already has `boss_defeated` + "crown fragment"
   flavor — surface it as the win beat.

### P1 — readability + guidance
4. Enemy intent preview (what the monster will do next turn: move / attack / cast).
5. Move-path preview on hover before committing the click.
6. Attack-range highlight ring (range already enforced — show it; float an "out of
   range" note instead of a silent log line).
7. Two-line first-turn hints ("Click an enemy in range to attack", "End Turn when
   done") — contextual, dismissible.

### P2 — the fun ceiling (depth)
8. Terrain / cover / verticality, surfaces / hazards, reaction system (opportunity
   attacks), flanking — the Solasta/BG3 differentiators.
9. Light narrative attachment (event text already exists) so the player cares who
   dies — Wildermyth's lesson.

## Recommended start

P0 items 1–3 are the fastest path from "it runs" to "someone wants to keep playing."
Most plumbing exists; it is connection + a victory screen.
