# Godot GUI Playtest Report

## Startup Repair Follow-up — 2026-10-08

**PT-001 is resolved in the current working tree.** The two invalid multi-value string-format expressions in `AnimatedObjectRules.attack_profile` now use GDScript arrays. A fresh normal visible launch reached the main menu. Through computer-use, New Campaign opened, the party size changed from two seats to one, Randomize All created a character, and Confirm Character entered the overworld. Clicking an adjacent tile moved Gimble Oakshield from (0, 0) to (1, 0), spent one movement point, and opened Mysterious Shrine. Leave it alone displayed its outcome, and Close returned to the overworld with the moved position retained. No runtime script/engine errors were logged during these interactions.

Repair verification: project bootstrap, all **167 scripts** in the project-context parse gate, production boot gate, **387 world logic checks with zero failures**, and the automated `crown_smoke` scenario passed. Automated scenario results supplement the GUI observations; they do not constitute a full human gameplay pass. Logs: `.artifacts/tests/7f118fa669e146f6828fbd20878175f8/`. The standalone `--check-only --script` attempt after editing reported a missing autoload (`PartyManager`); the repository's project-context gate supersedes that context-free diagnostic.

GUI evidence: [main menu](playtest-evidence/06-fixed-main-menu.jpg), [character creation](playtest-evidence/07-fixed-character-creation.jpg), [overworld](playtest-evidence/08-fixed-overworld.jpg), [movement/event](playtest-evidence/09-fixed-movement-event.jpg), [return after event](playtest-evidence/10-fixed-event-return.jpg), and [repaired runtime log](playtest-evidence/godot-runtime.log).

Current verdict: **startup and entry to interactive gameplay are restored; the broader playtest remains incomplete.** Combat, inventory, settings, save/load, death/recovery, campaign completion, and full exploratory/stress passes still require GUI testing. Animate Objects remains unfinished. The immediate next action is to continue the normal-player pass from the overworld. The remaining sections preserve the original pre-repair observations and coverage, not the current startup verdict.

## Original Pre-repair Session

Date: 2026-10-08 (America/Chicago). Tester: Codex, using the installed Windows computer-use skill and its `@oai/sky` runtime.

## Executive Summary

**Verdict: the current working tree is not playable.** Godot creates a visible interactive window, but it remains blank before the main menu. This occurred on both normal launches, including a fresh launch after an editor import refresh. Actual mouse clicks and keyboard inputs were sent to the selected game window and checked with screenshots. No player, map, menu, objective, or actionable UI appeared.

One confirmed **P0 startup blocker** prevents all gameplay. A targeted Godot parser check identifies invalid syntax at `src/characters/animated_object_rules.gd:107`. Dependent scripts cannot compile, GameManager fails to instantiate, and the bootstrapper errors before opening the menu.

The main loop and major mechanics could not be exercised. Three pass approaches were attempted at the startup boundary; **three full gameplay passes were not completed**. Source inspection and diagnostic commands supplied context and explained the observed failure; they are not gameplay evidence. No source code, existing assets, or project configuration was intentionally edited. No saves were created or loaded through gameplay.

## Environment and Intended Loop

- Installed executable: `.artifacts/tools/godot/Godot_v4.7-stable_win64.exe`, Godot 4.7 stable, official build `5b4e0cb0f`.
- Visible game window: `Top Down Party Game (DEBUG)`, approximately 1280 × 720 client area.
- Runtime renderer: Compatibility, ANGLE/D3D11, NVIDIA GeForce RTX 5060 Ti.
- Normal entry: `project.godot` → `scenes/main.tscn` → `src/main.gd` → main menu.
- Project context: development prototype of a turn-based D&D-inspired party RPG for 1–4 local seats. The documented loop is campaign/party creation, overworld travel and events, dungeon exploration and hex combat, rewards/rest/equipment, safe saving, and defeat or provisional completion.
- Input inspection: `ui_click` maps to left mouse. The camera script handles WASD/arrows, right/middle mouse panning, and wheel zoom directly. None of these gameplay controls was validated in a rendered world.
- Current operations documentation explicitly records interrupted Animate Objects implementation and says prior accepted test results do not validate this working tree.

## Test Passes and Actual Interaction

| Pass | Actions and observations | Outcome |
|---|---|---|
| A — Normal player | Launched the normal project, selected and focused its returned window, inspected the blank screen. Pressed Escape, then Enter, capturing the result after each. | Blocked before menu; no visible response. |
| B — Exploratory player | Clicked the blank client area at window-relative (640, 370), checked the result, inspected logs, performed a normal editor import refresh, closed with Alt+F4, and relaunched the same production entry. | Same blank window in a new process; refresh did not recover access. |
| C — Stress tester | On the second launch, double-clicked (640, 370), then pressed Tab and Enter in separate observed steps. | No visible focus, menu, or recovery. Gameplay stress cases remained inaccessible. |

Only the startup window was visited. No campaign, overworld, dungeon, combat encounter, or terminal screen was reached. Each gameplay input above was followed by a fresh screenshot; no successful interaction was inferred from sending an input.

## Test Coverage

| Feature/mechanic | Actions attempted | Expected behavior | Observed behavior | Result |
|---|---|---|---|---|
| Window launch/rendering | Two normal visible launches | Window appears | Titled window rendered | PASS |
| Main menu startup | Waited across observations on both launches | Main menu with actionable controls | Blank client area, persistent startup errors | FAIL |
| Startup keyboard/mouse recovery | Escape, Enter, click; then double-click, Tab, Enter | Usable menu/navigation after successful boot | No visible change; boot already failed | PARTIAL |
| Close and fresh relaunch | Alt+F4, then launch same project | Old process closes; new window appears | New window ID observed, same blocker | PASS |
| Campaign and character creation | Could not reach menu | Create party and start campaign | Inaccessible | NOT TESTED |
| Settings, audio, pause, in-game quit/restart | Escape tried only at failed startup | Accessible controls in their normal states | No menu; no audio evaluation | NOT TESTED |
| Movement, camera, collisions, world boundaries | No world available | Movement/panning and legal traversal | Inaccessible | NOT TESTED |
| NPCs, room objects, events, shops, companions | No campaign available | Interactive exploration and roster controls | Inaccessible | NOT TESTED |
| Combat, abilities, targeting, resources | No encounter available | Turns, costs, attacks, damage and feedback | Inaccessible | NOT TESTED |
| Inventory/equipment, progression, objectives | No character available | Persistent equipment and campaign progress | Inaccessible | NOT TESTED |
| Health, death/recovery, defeat, completion | No encounter available | Correct terminal/recovery behavior | Inaccessible | NOT TESTED |
| Save/load and fresh-process continuity | No playable state available | Safe checkpoint and reload | No gameplay save/load attempted | NOT TESTED |
| Gameplay edge cases | Only repeated startup clicks possible | No softlocks or invalid actions in active play | Startup blocker prevents evaluation | NOT TESTED |

## Confirmed Bugs

### PT-001 — P0 — Startup stops at a blank window

**Description:** The game opens a window but never displays the main menu, preventing all normal play. The process stays open; this is a startup failure rather than an observed process crash.

**Reproduction:**

1. Use this current working tree with installed Godot 4.7 stable.
2. Launch `.artifacts/tools/godot/Godot_v4.7-stable_win64.exe --path "C:\Users\brand\Documents\linux\Top Down Party Game"` with no alternate scene or test flag.
3. Observe the titled game window and wait for startup.
4. Press Enter or Escape, or click inside the client area.
5. Close the window, perform a normal editor import if desired, and repeat the production launch.

**Expected:** Bootstrap transitions to a usable main menu. **Actual:** Only a blank dark/gray client area appears; inputs do not reveal controls.

**Reproducibility:** 2/2 visible production launches; also persists after the normal editor refresh. The focused parser diagnostic reproduces a syntax error independently.

**Evidence:**

- [Initial startup screenshot](playtest-evidence/01-startup-blank.jpg)
- [No visible input response](playtest-evidence/02-input-no-response.jpg)
- [Fresh launch after import](playtest-evidence/03-fresh-launch-after-import.jpg)
- [Repeated clicks](playtest-evidence/04-repeated-input-blocked.jpg)
- [Tab/Enter recovery attempt](playtest-evidence/05-tab-enter-no-recovery.jpg)
- [First runtime log](playtest-evidence/godot-runtime-first-launch.log) and [second runtime log before repair](playtest-evidence/godot-runtime-second-launch-before-fix.log)
- [Targeted parser log](playtest-evidence/animated-object-parse.log): `Expected closing ")" after grouping expression` at `animated_object_rules.gd:107`.
- [Unrestricted editor import log](playtest-evidence/editor-import-unrestricted.log): compilation failure remains after normal initialization.

**Supported cause:** Line 107 supplies two formatting arguments as a parenthesized comma expression: `% (2 + extra, 3 + int(record["ability_mod"]))`. Godot rejects this syntax. Line 108 has the same construction and should be inspected with it. GameManager references this class; logs show its compilation and autoload failure, followed by `Invalid access to property or key 'test_mode' on a base object of type 'Nil'` at `src/main.gd:13`.

**Suggested correction — Fix now:** Correct both multi-value format operands using GDScript array syntax, then run parse/boot validation and relaunch the ordinary main scene visibly. Further errors may appear after this first parser failure is removed; this report does not claim that changing two lines alone restores playability. No correction was applied during the playtest.

## Gameplay and Usability Feedback

The visible failure gives a first-time player no explanation, retry action, or route to a menu. They cannot distinguish loading from a failed boot. Addressing the startup defect is the immediate priority; clearer failure feedback is worthwhile when touching startup handling, where feasible.

Controls/responsiveness, objective clarity, pacing, combat feedback, audio, balance, and navigation cannot be judged from the blank window. No subjective gameplay conclusions are claimed. Animate Objects and other Wave 4 gaps are documented implementation limits, not additional bugs established by this session.

## Recommended Priorities

1. **Fix now:** Repair the parser blocker and resolve subsequent startup errors until the normal menu appears.
2. **Fix now:** Resume actual GUI testing from character creation through exploration, at least one combat, inventory/rest, and safe save plus fresh-process reload. Then perform exploratory and stress passes in active gameplay.
3. **Fix when touched:** Make recoverable startup failures visibly understandable; keep a visible main-scene boot check in the development acceptance workflow.

## Evidence and Verification Boundaries

Screenshots are original computer-use captures saved as JPEG, matching the runtime's returned MIME type. Evidence is excluded from Godot resource importing using `playtest-evidence/.gdignore`. Logs include diagnostic commands as supplementary evidence only; no automated combat, direct scene jumping, or state manipulation was used.

The first headless editor import encountered sandbox restrictions accessing Godot's local editor data. It was rerun with approved access. Those permission messages in `editor-import.log` are environmental diagnostics, not extra game bugs. A temporary screenshot extension mismatch during that first import was corrected and is likewise not a project defect.

CodeGraph was attempted but its command was unavailable. No callable Agent Ground status tool was found. Repository docs and focused source reads were used instead. No subagents were needed. Existing unrelated working-tree changes were preserved.

**Next action:** After the owner repairs startup, rerun this playtest on the production entry; all gameplay coverage above remains outstanding.
