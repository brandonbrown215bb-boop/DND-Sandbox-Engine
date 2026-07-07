# UI Overhaul — Research & Plan

> Scope: the user finds the current UI "far too cluttered and unintuitive."
> This doc (1) audits what the code actually does, (2) reviews Godot 4 UI
> patterns that fix the specific problems, and (3) lays out a concrete overhaul
> plan. Nothing here is implemented yet — it is a proposal for sign-off.

---

## 1. Current-state audit (what the code really looks like)

### Screens in the project (13 .tscn)
- `main_menu`, `main`
- `overworld`, `dungeon`, `combat`
- `ui/event_dialog`, `ui/shop`, `ui/character_creation`, `ui/settings_overlay`, `ui/dice_roll_display`
- `viewport_harness`, `test_runner` (test scaffolding)

### HUD architecture (read directly)
- `CombatHUD` and `OverworldHUD` both `extends CanvasLayer`.
- **`DungeonState` does NOT have its own HUD** — it references `$DungeonHUD` but
  types it `OverworldHUD` and just hides `btn_end_turn`. So the dungeon shows an
  overworld HUD (party list, rest/save/menu/settings/sheet buttons, a turn
  header) bolted onto a room map. That is a real smell, not a styling nit.

### Concrete anti-patterns found in the code

| # | Anti-pattern | Evidence | Why it hurts |
|---|--------------|----------|--------------|
| 1 | **No shared `Theme` resource** — every color is a hardcoded `add_theme_color_override` / `Color(...)` call scattered across runtime code | `overworld_hud.gd` L86, L106, L116; `combat_hud.gd` uses default `Theme` | Zero consistency. Change one color → grep the whole tree. No font/size/spacing system. Impossible to do dark/light or a11y passes. |
| 2 | **Deep absolute node paths as `@onready`** | `combat_hud.gd` L12-33: `$MarginContainer/HBoxContainer/ControlArea/VBoxContainer/ActionMenu/GridContainer/BtnAttack` | One scene rename or re-parent silently nulls the HUD. Fragile, unreadable, discourages restructuring. |
| 3 | **No `ProgressBar` for HP** — HP is text only ("HP: 12 / 20") in a `Label` | both HUDs; overworld sidebar L93 | Numbers don't scan at a glance during combat. Players want a bar + number. |
| 4 | **Everything visible at once / no contextual modes** | Combat: action panel + spell menu + feature menu + sidebar + initiative + log + hint all coexist; panels toggled by `visible=false` swaps | Cognitive overload. The eye can't find the active thing. No "combat mode" vs "inspect mode" vs "menu" distinction. |
| 5 | **Buttons scattered, inconsistent placement** | Overworld: 6 buttons (end_turn/rest/save/menu/settings/sheet) in a sidebar `VBox`; Combat: action grid bottom + settings/sheet elsewhere | No consistent action-bar position. User re-hunts buttons every screen. |
| 6 | **Plain `Label`/`RichTextLabel` logs only** | both HUDs `add_log()` | No severity color system beyond inline `[color=]` BBCode; not filterable; no icons. |
| 7 | **No icon usage** | none of the HUDs use `TextureRect`/icon fonts | Text-only buttons are slower to parse than icon+label; more clutter. |
| 8 | **Hardcoded sizes / fixed layouts** | `combat.tscn` 1280×720 hardcoded in harness; HUDs use fixed `MarginContainer` paths | No responsive scaling; breaks on odd resolutions. |
| 9 | **Node reuse by accident** | Dungeon reuses `OverworldHUD` wholesale | The dungeon inherits overworld affordances it doesn't want and hides one button — a maintenance trap and a sign the HUD layer needs real abstraction. |

### What is *good* and must be preserved
- Signal-based HUD → state decoupling (`action_selected`, `end_turn_pressed`, etc.) is correct architecture.
- `update_hud()` central re-render pattern is fine; the *content* is the problem, not the trigger.
- The harness already drives these HUDs and asserts on them — any redesign must keep the asserted node names / signals or update the harness (see §4).

---

## 2. Godot 4 UI patterns that directly fix the above

Sources: Godot Engine docs — *GUI skinning* (4.7), *Using Containers* (stable),
*Control node* reference; plus the `make-interfaces-feel-better` design-engineering
checklist (spacing, typography, hit areas, motion, concentric radius).

### Pattern A — One project `Theme` resource, applied at the root
- Create `res://theme/main_theme.tres`. Define **default types** for `Button`,
  `Panel`, `Label`, `RichTextLabel`, `ProgressBar`, `LineEdit` once: font, font
  sizes, `StyleBoxFlat` (bg color, border, corner radius), normal/hover/pressed
  colors.
- Apply it to the root `Control` of every screen (or set `ProjectSettings` →
  `gui/theme` so it's global). Godot cascades themes down the node tree
  ("as long as the chain of control nodes is uninterrupted, buttons use the
  style of the closest theme"). Per-screen overrides only where needed.
- **Payoff:** kills anti-pattern #1. Colors/fonts/spacing live in one file.
  Dark mode / a11y = swap one resource.
- **Cost:** one-time; needs discipline to *stop* using `add_theme_*_override`
  in code (keep overrides for genuinely dynamic state like "active player").

### Pattern B — Container-first layout, kill deep absolute paths
- Replace fixed `$MarginContainer/HBoxContainer/.../BtnAttack` with:
  - `VBoxContainer` / `HBoxContainer` with `separation` theme constant.
  - `GridContainer` for action buttons (already used — keep).
  - `PanelContainer` + `MarginContainer` for cards.
  - Anchors only at the *top* level (full-screen HUD dock), containers below.
- **Payoff:** kills #2 and #8. Re-parenting a button no longer nulls the script;
  layout adapts to content/screen size.
- Use **unique node names** (`%AttackButton` owner-unique) + `get_node("%AttackButton")`
  or `@onready` on *direct children only* so the path depth is at most 1–2.

### Pattern C — Contextual UI modes (don't show everything)
- Split the combat HUD into **modes** switched by a single `set_mode()`:
  - `MODE_SELECT` (root action buttons: Move / Attack / Spell / Feature / Dodge / End)
  - `MODE_TARGET` (instruction banner "Select a target hex" + confirm/cancel)
  - `MODE_INSPECT` (character sheet-style detail, no actions)
  - `MODE_MENU` (settings/sheet/save overlay)
- Only one mode's controls are visible/interactive at a time. The *selected*
  action (Attack) expands its sub-panel; others collapse.
- **Payoff:** kills #4. The eye always finds the active control. This is the
  single biggest "uncluttered" win.

### Pattern D — `ProgressBar` for all vitals, with number overlay
- HP/MP/slot uses become `ProgressBar` (or a custom `StatBar` with a centered
  `Label`). Color by ratio (green→yellow→red) via theme or a single tween.
- Tabular numerals (`font_variant` → tabular) so the number doesn't jitter.
- **Payoff:** kills #3. At-a-glance reading during fast combat.

### Pattern E — Consistent action bar + icon+label buttons
- Every gameplay screen shows a **bottom (or context-appropriate) action bar**
  at a fixed position with a consistent button order: primary action(s), then
  secondary (Spells/Features), then system (Sheet, Settings, Menu) right-aligned
  or in a gear.
- Buttons are **icon + short label** (Godot `Button` supports `icon` +
  `text`; pair with an icon font or `Texture2D`). 40–44px min hit area.
- **Payoff:** kills #5 and part of #7. Muscle memory carries across screens.

### Pattern F — Log as a styled, severity-aware panel
- Keep `RichTextLabel` but drive it through a tiny `LogPanel` wrapper:
  `log_info/warning/danger(msg)` → prepends a colored tag/icon + BBCode, caps
  history (ring buffer), auto-scrolls. Severity colors come from the Theme.
- **Payoff:** kills #6. Consistent, scannable, themeable.

### Pattern G — Motion & polish (from the design-engineering checklist)
- Enter/exit transitions on mode swaps and popups: opacity + small `translateY`,
  ~150ms, `ease-out`; interruptible. **Never `transition: all`** — name props.
- Subtle pressed state (`scale 0.96`) on tactile buttons; disable where it
  distracts.
- Concentric radius on nested panels (outer = inner + padding) for optical coherence.
- **Payoff:** kills the "flat/generic/unfinished" feel without adding clutter.

### Pattern H — Extract a real base HUD (fix the dungeon smell)
- Promote a `BaseHUD extends CanvasLayer` with: shared `Theme` hookup, the
  `LogPanel`, the system button row (Sheet/Settings/Menu/Save), and an
  `apply_mode()` stub. `CombatHUD`, `OverworldHUD`, and a new `DungeonHUD`
  extend it and add only what's unique.
- **Payoff:** kills #9 and de-duplicates the 6-button sidebar across 3 scenes.

---

## 3. Proposed target architecture

```
res://theme/main_theme.tres          # single source of visual truth
res://ui/
  base_hud.gd (CanvasLayer)          # LogPanel + system row + apply_mode()
  widgets/
    stat_bar.gd (ProgressBar+Label) # HP/MP reusable
    log_panel.gd (RichTextLabel)    # severity-aware ring buffer
    action_bar.gd (HBoxContainer)   # icon+label buttons, fixed order
  combat_hud.gd   extends BaseHUD   # modes: SELECT/TARGET/INSPECT/MENU
  overworld_hud.gd extends BaseHUD  # party cards (StatBars) + objective
  dungeon_hud.gd  extends BaseHUD   # room info + travel actions (new)
scenes/ (rebuild HUD subtrees with containers, root Theme applied)
```

### Per-screen redesign intent (high level)
- **Combat:** bottom action bar (Move/Attack/Spell/Feature/Dodge/End) + left
  slim party/monster vitals column (StatBars) + top intent banner + contextual
  target banner. Spell/Feature open as *popovers over* the bar, not separate
  full panels. Initiative as a compact ordered strip, not a text block.
- **Overworld/Dungeon:** left party column (StatBars + conditions as chips) +
  top objective + bottom action bar (Rest/Travel/Sheet/Settings/Menu). Dungeon
  gets its own HUD (no `btn_end_turn` to hide) with room-context actions.
- **EventDialog:** choice buttons as full-width cards (icon + title + one-line
  consequence hint), skill-check as a centered roll card. Already mostly there;
  restyle via Theme + spacing.
- **Shop / CharacterCreation:** already container-based; mostly Theme + spacing
  + icon pass. Lowest effort.
- **Settings:** already an overlay; ensure it uses the shared Theme and the
  same system-button language. This is where "save/load anywhere" lives (the
  gear button → Settings overlay already pauses the tree; add Load/Save
  slots there so every screen inherits it for free via BaseHUD).

---

## 4. Risk / harness impact

The viewport harness (`src/viewport_harness.gd`, now 12 named `test_*`) asserts
on HUD internals. A redesign will touch these asserted facts:
- `combat.hud.weapon_info`, `combat.hud.hint_label`, `combat.hud.btn_*` names,
  `combat.hud.log_text`, `combat.hud.update_hud(...)`.
- `overworld.hud.btn_rest/save/menu/settings/sheet`, `.player_list_container`,
  `.log_text`, `.objective_label`.
- `dungeon.hud.btn_end_turn` (will be removed — dungeon gets its own HUD).
Plan: keep the *public signal names* (`action_selected`, `end_turn_pressed`,
`save_pressed`, …) and the `@onready` node *names* stable where possible; update
the harness assertions only where the node genuinely moves. Add new assertions
for StatBars / modes as they land.

---

## 5. Execution plan (phased, each ends green)

**Phase 0 — Theme foundation (no behavior change)**
- Create `main_theme.tres`; apply globally. Move the existing hardcoded colors
  into it. Verify screens still look right + harness green.
- *Lowest risk, highest leverage.* Establishes the design language.

**Phase 1 — BaseHUD + widgets**
- `base_hud.gd`, `stat_bar.gd`, `log_panel.gd`, `action_bar.gd`.
- `OverworldHUD`/`CombatHUD` extend `BaseHUD`; swap manual log + 6-button
  sidebar for shared widgets. Harness updated.

**Phase 2 — Combat HUD modes**
- `set_mode(SELECT/TARGET/INSPECT/MENU)`; collapse spell/feature into popovers;
  initiative strip; StatBars for vitals. Harness updated.

**Phase 3 — Overworld/Dungeon parity + new DungeonHUD**
- Party cards → StatBars + condition chips; objective top; consistent action
  bar. `DungeonHUD` split out (removes the `btn_end_turn.hide()` hack).

**Phase 4 — Polish pass**
- Motion on mode/popup swaps, pressed states, concentric radius, tabular nums.
- Apply `make-interfaces-feel-better` checklist per screen.

**Phase 5 — EventDialog / Shop / Creation restyle**
- Theme + spacing + icon pass (lowest risk, mostly free once Theme exists).

---

## 6. Open questions for sign-off
1. **Scope of Phase 0 alone?** It delivers consistency + a design system with
   near-zero behavior risk. Recommend doing 0–1 first, then review before modes.
2. **Icon source:** icon font (e.g. FontAwesome via `bmfont`) vs. `Texture2D`
   sprites. Need your art direction or OK to use a free icon font.
3. **Color direction:** keep current palette, go darker "tabletop" feel, or
   let me propose 2–3 swatches?
4. **Resolution target:** lock 1280×720 with `expand` scaling, or true
   responsive (anchors + containers) for variable window sizes?

---

## Sources
- Godot Engine docs — *GUI skinning* (docs.godotengine.org/en/4.7/tutorials/ui/gui_skinning.html)
- Godot Engine docs — *Using Containers* (docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html)
- Godot Engine docs — *Control node* reference (anchors, size flags)
- `make-interfaces-feel-better` (Hermes skill) — spacing, typography, hit areas,
  motion, concentric radius, transition-scope checklist
- Direct code read: `combat_hud.gd`, `overworld_hud.gd`, `dungeon_state.gd`
