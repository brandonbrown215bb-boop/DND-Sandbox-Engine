# Batch 052 build: HUD mode and upgrade controls

Card Q-20261021-004820-732c. Stacked on #21 (batch-051-feat-acquisition @ 6537e97). #20 and #21 are still open, and 052 overlaps their files (test_runner.gd, viewport_harness.gd, run_tests.ps1, and the 051 feat path it lists).

## Finish line
During play, the combat HUD's feature list shows each owned mode_choice rule exactly once. That covers class, species, Origin feat, level-up feat and exact item copy. Each entry shows uses and remaining time, and offers Activate / Choose mode / Change mode / Switch mode / Choose upgrade. A popup offers Cancel plus exactly the legal options. A merged or suppressed item copy is listed disabled with "[Unavailable: merged|suppressed]". No test-only calls are needed.

## Design
- `ModeControls` (src/characters/mode_controls.gd) is the single view and entry point.
  - `rows`, `row`, `label`, `options`, `actions`.
  - `apply(actor, feature_id, kind, option, token)` calls the existing `FeatureModeRules.activate/choose/switch` and `RuleUpgradeRules.choose_alternative`.
- **Stale answers.** Every offer carries a token covering copy-active, active/mode/open, activation and event serials, the switch window, uses and the alternatives. If any of those change, the answer is refused as "stale" before anything is spent.
- **CombatHUD.**
  - `_show_feature_selection` lists the rows.
  - `request_mode_control` opens the popup and refuses an answer as stale when:
    - a newer mode popup has opened (serial), or
    - the active character has changed.
  - Cancel or closing the popup logs "canceled; nothing was spent."
- Upgrade options are offered only while the upgraded power is inactive (same rule as `choose_alternative`).

## Checklist
- (a) Cancel, a closed popup, an unknown option, an action that wasn't offered, a superseded popup, and a token gone stale after uses changed or suppression ended are all refused with uses, modes and alternatives unchanged. The scenario asserts uses are unchanged after Cancel and after answering a superseded popup.
- (b) No new record shapes. Modes and alternatives persist through the existing validated `feature_modes`/`rule_alternatives`.
- (c) Production callers: CombatHUD `_show_feature_selection`, `_on_feature_selected` and `request_mode_control` → `ModeControls`.
- (d) Real SaveManager save/load keeps the active mode, uses and chosen upgrade. The logic reload shows identical rows.
- Merged/suppressed gate: a suppressed copy and a copy merged into a form are both shown unavailable and spend nothing.

## Counts
- Fresh baseline 6537e97 (imported twice): 5462/0. Branch: 5477/0 (+15), 48 check scripts, 0 failed.
- Scenarios 031-052 run one at a time, all pass. 052: 9 ok.

## Limits
- Controls are in the combat HUD only. There is no overworld or character-sheet mode panel yet.
- Activation spends no action economy (mode rules declare no action_cost).
- There is no "end early" button (no rule declares dismissal at will).
- The level-up feat fixtures are fixture data, not SRD content.
