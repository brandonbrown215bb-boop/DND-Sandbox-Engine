# Batch 037 review: rest/activation mode choices (S-103) and rule parameter upgrades (S-084)

Independent review by Runtime Reviewer on 2026-10-20 of PR #4 (`batch-037-s103-s084`). The reviewed head is `e22215d`, and its base is `651e032`, the current 036 head, so no rebase was needed. Reviewer commits: `8719511` (stress cases) and `baaad06` (scenario reload).

**Recommendation: ACCEPT.** I found no blocking defect. The builder's weak spot is now closed by a real save/load in the scenario. This is reviewer evidence; counts change only on owner acceptance.

## Findings

| # | Severity | Finding | Status |
|---|---|---|---|
| W1 | Builder-flagged gap | The scenario never reloaded a save, so reload was proven only through logic-level `to_dict`/`from_dict`. The finish lines require that the parent use or lifetime does not restart and that a reload does not duplicate the base benefit. Those are save-path properties, so logic-only coverage was too weak. | Closed in `baaad06`. A recruited fixture-class companion activates `guard`, and the game saves through `SaveManager.save_game`. A tampered copy of the save (`mode: "bogus"`) is refused before the live party is replaced. The live state is then changed (mode dismissed, uses 0, Temporary HP 0), and `SaveManager.load_game` restores exactly: active `guard`, spent use (1), serial 1, deadline 60 s, Temporary HP 6. The loaded actor reselects without spending a use and swaps exactly one +2 AC grant. Scenario: 11/0. |
| F1 | Non-blocking, latent | `FeatureModeRules.saved_error` accepts only modes declared in the actor's **class** `features_by_level`. Any mode state owned by another source (subclass, species, feat, item, or the builder's appended scenario features) makes `save_game` reject the **whole save** ("feature mode references an unowned rule"). I hit this while writing W1, with the builder's fighter. No catalog content uses `mode_choice` yet. | Not fixed. Before a non-class host is wired, resolve ownership from the actor's real owned features, or drop orphaned state on restore instead of refusing the save. |
| N1 | Checked | 0 `SCRIPT ERROR` in every log. The totals reconcile: 4898 + 39 (builder) = 4937, + 21 (review) = 4958. | OK |

## Stress cases (`Batch037Checks.review_stress`, 21 assertions)

- **RV1:** a dead recipient, too many targets, an unknown mode and zero uses are each refused before any use, roll, Temporary HP or state change.
- **RV2:** activation at 0 HP is refused before cost when the mode declares that it ends at 0 HP.
- **RV3:** an active mode ends at 0 HP and its grant vanishes. Reactivating it is a new parent use with a new serial.
- **RV4:** the shared clock keeps the mode at 59 s and ends it, with its grant, after an hour. Production `advance_campaign_time` ticks party members through `SpellEffects.advance_time`. My first attempt used an actor outside the party and failed for that reason only; it was a test artifact, not a defect.
- **RV5:** a rest mode allows one choice per boundary. A reload keeps the closed choice and its single grant, and a Short Rest does not reopen a Long Rest mode.
- **RV6:** a mid-activation reload keeps one grant, the spent uses, the serial and the Temporary HP. A reselect after reload does not spend a use, and activating again while active is refused.
- **RV7:** tampered saves are refused (unknown mode, remaining time above the duration, inactive with a mode, unowned rule, unknown key). A legacy save without the field loads with no modes.
- **RV8:** a duplicated upgrade feature still applies once. The catalog `d6`/`uses` values are unchanged, and a reload neither duplicates the upgrade nor changes the maximum uses.

## Verified

- ADR-0018: there are two shared modules and no content-ID branching. Upgrades are recomputed from the owned features (`effective`) and never written into the catalog or the feature.
- Refusal before cost: every check in `activate` runs before `use_feature` and the die roll.
- SRD 5.2.1: rest and activation boundaries, keeping the larger Temporary HP (`max`), and mode replacement rather than stacking are all consistent with the rules.
- Legacy saves: `feature_modes` is optional and is validated on both SaveManager routes.

## Evidence (Godot 4.7.2, `/tmp/rev_wt037`)

| Run | `e22215d` | + review |
|---|---|---|
| Import | exit 0 | exit 0 |
| Logic | 4937 / 0 | **4958 / 0** |
| batch_037_mode_upgrade_flow | 6 / 0 | **11 / 0** |
| batch_036 / 035 / 034 / 033 / 032 / 031 | 7 / 9 / 10 / 70 / 33 / 25, 0 failed | same |
| batch_029 / batch_021 / shared_spell | 37 / 21 / 67, 0 failed | same |
| downed_area_damage_flow | 1 failed | identical to clean `origin/main` |
| party_recovery_flow | 2 failed | identical to clean `origin/main` |

## Proposed updates on owner acceptance (after VS-113 to VS-118)

- Registry entries:
  - S-103: `Verified (VS-119; class-owned rest/activation modes with AC/speed grants)`.
  - S-084: `Verified (VS-120; uses/targets/die/end_on upgrades of a mode rule)`.
- Counts: **120/226 accepted, 106 remain**. S-103 is P3 (+1) and S-084 is P2 (+1).
- Limits:
  - Class-owned modes only (F1).
  - AC/speed payloads only.
  - No HUD controls.
  - S-104/S-085 are open.
  - V-025, V-037 and V-055 remain partial.
