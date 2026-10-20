# Batch 038 review: per-hit/turn-start mode switches (S-104) and rule options/exclusive replacements (S-085)

Independent review by Runtime Reviewer on 2026-10-20 of PR #5 (`batch-038-s104-s085`). The head is `6c90575`, restacked onto 037 at `26c2ad6` and verified as an ancestor. Reviewer commits are `04b226b` (stress cases) and `b72f6d2` (R1).

**Recommendation: ACCEPT after R1.** This is reviewer evidence; counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| R1 | Defect | `RuleUpgradeRules.choose_alternative` changed the effective maximum uses but left held uses alone. For example: choose `alt_b` (uses +1), take a Long Rest (3 uses), then switch back to `alt_a`. The actor still held **3 uses against a maximum of 2**, and only a reload clamped them. Live state and reloaded state differed, and the actor got an extra activation. RW5 failed on `6c90575` (3 > 2). | Fixed in `b72f6d2`. Choosing an alternative now clamps the rule's pool to the new maximum, the same way `from_dict` does. Raising the maximum still grants nothing until the next rest. |
| F1 | Known limit (carried) | Saved mode, added-mode and alternative state is validated only against the actor's **class** `features_by_level` (`_declared`, `_declared_modes`, `RuleUpgradeRules.saved_error`). The build doc records this. It is not regressed beyond the two new lookups, and it **fails safe**: RW7 shows state owned by a non-class rule is refused, and `restore` yields `{}`. The alternative `restore` also yields `{}` on any tamper (RW6). The cost is that the whole save is refused, not corrupted. | Documented; fix in a shared owned-feature resolver before non-class hosts |
| N1 | Checked | 0 `SCRIPT ERROR` in every run. The totals reconcile: 4958 + 29 (builder) = 4987, then + 26 (review) = 5013. My 037 RV1–RV8 cases (21) and the 11-check 037 scenario pass unchanged on the 038 head. | OK |

The builder flagged that the 038 scenario covers reload in logic only. The 037 scenario's real SaveManager reload now runs on the 038 code (11/0), and RW3/RW4/RW6 cover reload of windows, switched modes and alternatives. That is enough for these finish lines; adding a scenario reload for 038 would be the next strengthening.

## Stress cases (`Batch038Checks.review_stress`, 26 assertions)

- **RW1:** with no window, or after an undeclared event, a switch is refused. A switch keeps uses, deadline, serial and roll. One window allows one switch, and a later event closes an older window.
- **RW2:** a real missed `resolve_weapon_attack` opens no hit window. A real hit opens one, which can be used for an added mode (`bulwark`).
- **RW3:** a mode removed by an upgrade is not a legal switch target. Reload keeps the switched mode, the window and exactly one grant, and a reloaded window is still single-use.
- **RW4:** a consistent saved window validates. A future serial, an unknown event, a window on an inactive mode and an extra key are each refused. Legacy state without windows or alternatives loads.
- **RW5:** the default alternative applies alone and alternatives never stack. Choosing another alternative grants no immediate use, and the new maximum fills at the next Long Rest. Switching away clamps held uses (R1). Choosing is refused while the mode is active and for unowned options.
- **RW6:** an owned alternative validates. A wrong id, a choice above the actor's level and a malformed key are each refused and restore nothing.
- **RW7 (F1):** state owned by a non-class rule is refused and not half-restored.

## Verified

- ADR-0018: the code is shared and data-declared, with no content-ID branches. Mode add/remove is order-independent and never drops below two modes. The catalog is unchanged.
- S-104: the parent cost, deadline, serial and roll stay fixed across a switch. Already-settled hits are not recomputed, and the hook runs only after settlement; misses return earlier.
- S-085: an exclusive group yields exactly one applying alternative, and the choice persists.
- SRD 5.2.1: no conflicts. These are engine policies for declared content.

## Evidence (Godot 4.7.2, `/tmp/rev_wt038`)

| Run | `6c90575` | + review |
|---|---|---|
| Import | exit 0 | exit 0 |
| Logic | 4987 / 0 | **5013 / 0** (5012 / 1 before R1) |
| batch_038_switch_option_flow | 7 / 0 | 7 / 0 |
| batch_037_mode_upgrade_flow | 11 / 0 | 11 / 0 |
| batch_036 / 035 / 034 / 033 / 032 / 031 | 7 / 9 / 10 / 70 / 33 / 25, all 0 failed | same |
| batch_029 / 021 / shared_spell | 37 / 21 / 67, all 0 failed | same |
| downed_area_damage_flow / party_recovery_flow | 1 / 2 failed | identical to clean `origin/main` |

## Proposed updates on owner acceptance (after VS-113 through VS-120)

- Registry: S-104 becomes `Verified (VS-121; own hit/turn-start switch windows)`. S-085 becomes `Verified (VS-122; add/remove modes and exclusive parameter alternatives)`.
- Counts: **122/226 accepted; 104 remain**. S-104 is P3 (+1) and S-085 is P2 (+1).
- Limits:
  - Class-owned rules only (F1).
  - No monster mode rules.
  - Extra Attack and base AC are not converted.
  - No HUD.
  - V-037 and V-055 remain partial.
