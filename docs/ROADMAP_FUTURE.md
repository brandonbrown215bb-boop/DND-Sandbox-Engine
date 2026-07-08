# Future Roadmap — Proposed Projects

*Generated 2026-07-08 from a full doc-dive + live-code audit of the project.*
*Status of existing phases: Phase 1 [x], Phase 2 [x] (marked complete this pass),
Phase 3/4/5 partially spec'd, mostly unimplemented. The items below are NEW
project proposals, scoped against what the code already supports. Each lists the
concrete entry point so it isn't vaporware.*

---

## F1. Hot-Seat Local Multiplayer — [proposed]

**Why:** `player_manager.gd` already declares its purpose as "active player state
for hot-seat local multiplayer" but the single-active-player assumption is baked
into every HUD (`overworld_hud`, `combat_hud`, `dungeon_hud` all show "active
player"). This is the single biggest un-built design intent in the codebase.

**What:**
- `PlayerManager` already tracks `party: Array[Character]` and `active_player`.
  Add turn-passing between *human* seats (not just AI), with a "pass to next
  player" affordance on the overworld/combat HUDs.
- Disable fog-of-war / info for non-active seats where it makes sense (each seat
  sees only its own characters' sheets).
- Persist seat assignments in `save_manager.gd` (it already serializes party +
  levels; add a `seats` field).

**Entry points:** `src/autoload/player_manager.gd`, the three HUD `_ready()`s that
bind `active_player`, `src/autoload/save_manager.gd`.
**Risk:** medium — touches HUD bindings and save schema (additive field,
backwards-compatible).
**Prereq:** ActionBar mounted (F4) gives a clean "pass turn" slot.

---

## F2. Quest / Objective Tracker — [proposed]

**Why:** The game has events (`event_system.gd`, 4 event tables) and a campaign
(`The Lost Crown`) but no player-facing objective log. Players can't see what
they're working toward between events.

**What:**
- A `QuestLog` autoload tracking active/completed objectives, fed by
  `event_system` outcomes and `game_manager` milestone signals.
- A collapsible `QuestPanel` widget (sibling of `LogPanel`/`ActionBar`) anchored
  top-right, toggled from `ActionBar`.
- Campaign milestones currently hardcoded in `game_manager` — surface them as
  trackable objectives.

**Entry points:** `src/events/event_system.gd` (outcome emission),
`src/autoload/game_manager.gd` (milestones), new `src/ui/widgets/quest_panel.gd`.
**Risk:** low-medium. Pure additive UI + a thin autoload.

---

## F3. Achievements & Meta-Progression — [proposed]

**Why:** `save_manager.gd` already persists `achievements` (the CHANGELOG notes
"progress, levels, locations, inventory, achievements" round-trip). The data slot
exists; nothing writes to it yet.

**What:**
- Define an achievements table in `data/` (mirror the existing `classes`/`races`
  JSON pattern `DataLoader` already consumes).
- Fire achievement checks from existing signals: first crit, first shop
  purchase, survive a wilderness ambush, clear the campaign.
- A small `AchievementsToast` (reuse `FxLayer` / floating-text infra from Phase 4)
  and a codex panel.

**Entry points:** `src/autoload/save_manager.gd` (achievements field already
serialized), `src/autoload/data_loader.gd` (table load pattern), existing combat/
event signals.
**Risk:** low. The hard part (persistence) is already done.

---

## F4. ActionBar HUD Mount + Icon System — [proposed]

**Why:** `ActionBar` (`src/ui/widgets/action_bar.gd`) is built and unit-tested but
**not mounted** — the HUDs still hand-build button rows. The blocker is art
direction on icons (UI_OVERHAUL_RESEARCH.md §6, open question 2).

**What:**
- Decide an icon source: (a) a small hand-drawn set committed to `assets/icons/`,
  or (b) text-only glyphs (unicode/ASCII) as a stopgap that ships today.
- Mount `ActionBar` into `combat_hud` / `overworld_hud` / `dungeon_hud` with a
  consistent slot order: primary (attack/cast/move) → secondary (rest/sheet) →
  system (menu/settings) right-aligned via `push_right()`.
- Keep existing `btn_*` node names as aliases during migration so the viewport
  harness assertions stay green, then retire them.

**Entry points:** the three HUD scenes + `src/ui/base_hud.gd` (host the bar once).
**Risk:** medium (layout churn) but contained — `ActionBar` is already tested.
**Decision needed:** icon art direction (user sign-off).

---

## F5. VFX & Audio Layer (Phase 3, unblocked partially) — [proposed]

**Why:** Phase 3 is spec'd but blocked on *assets* (no sprites/audio in
`assets/`). The *code hooks* for VFX partially exist (floating damage numbers,
screen shake, `FxLayer` from Phase 4).

**What (asset-free first):**
- Wire `AudioManager` (already has `play()` methods) to **silent no-op + log**
  until audio files land, so the call sites are correct and the harness can
  assert "audio event fired" without files.
- Add particle emitters as **code-only** (CPUParticles2D) for spell cast / crit,
  gated behind the existing `Settings` "show effects" toggle.
- Once art lands: drop `.ogg`/`.png` into `assets/` and flip the no-ops to real
  loads.

**Entry points:** `src/autoload/audio_manager.gd`, `FxLayer`, `src/autoload/
settings.gd` (effects toggle), `src/ui/widgets/`.
**Risk:** low for the asset-free stub layer; the real polish waits on assets.

---

## F6. Encounter & Boss Designer (Phase 4 depth) — [proposed]

**Why:** AI profiles (healer/caster/cowardly) and one boss room exist, but no
multi-phase boss or environmental hazards — the roadmap's most exciting combat
content is unbuilt.

**What:**
- `AIBrain`/`ai_controller.gd`: extend behavioral profiles to read ally HP and
  cast heals (healer), maintain range + AoE (caster), flee below HP threshold
  (cowardly). The profiles are stubbed; flesh them out against the existing
  `CombatAction` / spell system.
- Multi-phase boss: a `BossPhase` resource (HP thresholds → behavior swaps, summon
  adds at 50%). Drive via `game_manager` milestone signals.
- Environmental hazards: a `Hazard` autoload ticking on turn start (reuse the
  existing `Resource Depletion` / condition tick pattern from Phase 1b).

**Entry points:** `src/combat/ai_controller.gd`, `src/autoload/game_manager.gd`,
the Phase 1b condition-tick loop.
**Risk:** medium. Self-contained against existing combat API.

---

## F7. Mod Manager & Visual Editors (Phase 5) — [proposed]

**Why:** `DataLoader` already ingests `data/*.json` (classes, races, items,
spells, monsters, events). User mods are a small step from there — a loader that
merges `data/mods/*` into the same tables.

**What:**
- `ModManager` autoload: scan `data/mods/`, validate schema against the existing
  loaders, merge into `DataLoader` tables at boot, enable/disable from a menu.
- Visual editors are the heavy lift: a `MapCreator` (paint hex terrains, place
  towns/dungeons — reuses `hex_grid.gd` paint API if it exists) and a
  `ContentBuilder` for classes/monsters. These can be *separate editor tools*
  (run under `--editor`, not the game) to avoid bloating the runtime.

**Entry points:** `src/autoload/data_loader.gd`, `data/` schema, `hex_grid.gd`.
**Risk:** high for editors (separate tooling), low for the manager/merge.

---

## Prioritization (suggested)

| Priority | Project | Effort | Blocker |
| :--- | :--- | :--- | :--- |
| P0 | F4 ActionBar mount (text-glyph stopgap) | M | icon decision (or ship text-only) |
| P0 | F3 Achievements | S | none (persistence exists) |
| P1 | F2 Quest tracker | M | none |
| P1 | F5 Asset-free VFX/audio stubs | M | none (waits on assets for real) |
| P1 | F6 Encounter/boss depth | M | none |
| P2 | F1 Hot-seat MP | L | F4 (turn slot) |
| P2 | F7 Mod manager | M | none; editors are separate tooling |

*Suggested first commit: F3 (achievements) + F4-text-only — both ship with zero
new assets and immediately make the game feel like it has a "meta" loop.*
