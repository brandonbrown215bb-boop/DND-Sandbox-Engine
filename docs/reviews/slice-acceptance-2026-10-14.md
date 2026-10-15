# Slice acceptance review and repairs — 2026-10-14

The owner clarified the requested four slices as S-025, S-041, S-091 and
S-092, then authorized repair of all findings. Rook reviewed the current source
and retained evidence; one independent reviewer checked S-025 and the final
shared roll/combat repairs. The original findings below describe the pre-repair
source. They are now closed by production fixes and regression checks.

## Final decision

| Slice | Decision |
| --- | --- |
| S-025 | Accept VS-28 within the combat shared-spell binding boundary; no new blocker found. |
| S-041 | Accept VS-31 for the documented shared-spell attack window/consumer boundary after repair. |
| S-091 | Retain accepted VS-29 for loaded EventDialog ability-check mode policy. |
| S-092 | Restore accepted VS-30 after native-use and conflicting-option repairs. |

At this repair review there were **31 accepted of 226, 195 not yet accepted**.
S-042 was a mistaken slice number in the original request and remains planned.
The later [Batch B review](../../.artifacts/planning/vocabulary-reports/batch-B-review.md)
accepts separately validated S-095 as VS-32, making 32/226 accepted and S-034
BUILD ready. The repairs and evidence below retain their original scope.

## Repairs and verification

- S-025 keeps host-only actor/action/invocation/item/source bindings separate
  from caller decisions. Exact-copy validation and `take_instance` payment
  retain the selected copy after consumption; captured continuations retain
  their original actor/target. Both material copies and distinct generated
  sources pass actual controls. No S-025 runtime correction was needed.
- Ordered attack effects now read the canonical child attack's receipt through
  the parent adapter, including attack-to-damage suspension and final resume.
  A new attack replaces the previous occurrence; a save or standalone damage
  step clears the attack window. Another recipient cannot inherit its facts.
- Both attack hosts apply explicit outcomes after native Shield/Peerless
  handling. A synthetic forced miss cannot consume an unused Peerless use;
  final-miss critical suppression and separately justified forced-hit criticals
  still apply.
- The loader rejects numeric/die/outcome conflicts and duplicate outcome
  declarations on the same source and attack domain, in either authoring order.
  The source-ID chooser therefore cannot display one operation and execute another.
- Integral numeric healing/Temporary HP normalize to integer text before the
  existing parser. Both Character and dictionary recipients receive the correct
  values. Fractional scalars still refuse. Loaded S-025 fixtures now exercise
  actual JSON numeric healing through the material-copy/Portent control route.

Final command, run once after the focused repairs:

```powershell
& .\run_tests.ps1 -Suite all -Scenario @('shared_entity_binding_flow','shared_spell_attack_bonus_flow','post_roll_die_bonus_flow','failed_save_numeric_bonus_flow','shared_fact_predicate_flow')
```

**Runner exit 0; bootstrap, 185-script parse, production boot, full logic
3,332 passed / 0 failed, and all five actual-control scenarios passed.** Logs:
`.artifacts/tests/bf854bf713dc498ab789ec6bb1a6cfe0/`; consolidated runner output:
`.artifacts/reviews/slice-acceptance-20261014/repair-validation-runner.log`.
The independent reviewer inspected current source and these final results and
recommended acceptance. Final logs have no script/runtime errors or test-owned
leaks. Expected adversarial refusal warnings and the existing 25 unsupported
feature warning remain.

The new regressions cover numeric healing/Temporary HP, fractional refusal,
direct authored attack/following effects, target and fresh-occurrence isolation,
both conflict declaration orders, and Peerless preservation in both attack
hosts. Real deferred-damage controls prove the attack effect and following
rider wait until the damage answer and settle once. Prior failing development
runs exposed regression-fixture setup mistakes (leftover Restrained and missing
effect source); both were corrected before the clean final run. They are not
counted as passing evidence.

Acceptance remains bounded to the documented hosts and fields. Other hosts,
general subscriptions, cast/source-end windows, cross-actor intervention,
additional damage measures, S-095 defensive edits and full parent-vocabulary
completion remain open. No durable state or save/checkpoint permission changed.

## Original findings — closed by this repair

### Closed P1 — S-041 window predicates silently skip valid effects

`SharedStepExecutor.SpellAdapter.resolve_attack_step` creates a child
`step_cast` at `src/combat/shared_step_executor.gd:1783`. The attack records
all five windows on that child. Effects at line 1815 use the adapter for the
parent cast, while `_read_resolution_fact` at line 250 reads that parent
cast's empty `resolution_window`. Resumed effects at line 1237 also use the
parent adapter. No receipt transfer connects these consumers to the child.

A production-Godot probe used a loaded attack definition and a valid ordered
attack with `temporary_hp: "7"`. Unguarded, the effect grants 7 Temporary HP.
Adding `when: {"fact":"resolution.window","eq":"post_damage"}` passes
content validation, hits, emits all five windows, but grants 0. A separate
following effect step with the same predicate also grants 0. This contradicts
the documented authored `resolution.*` consumer boundary. Flat guarded effects
are explicitly refused by validation and are not part of this finding.

Repair the actual ordered consumer's receipt binding, including deferred
settlement, without reusing a previous target/occurrence's window. Prove the
guarded effect through real cast/choice controls; checking receipt dictionaries
alone missed this defect.

Reproduction: `.artifacts/reviews/slice-acceptance-20261014/probe.gd`,
`probe.tscn`, and `probe.godot.log`. Godot 4.7 exited 0. The only warning was
the existing rejection of 25 unsupported effectless feature records.

### Closed P1 — S-092 forced miss wastes Combat Prowess / Peerless Aim

`src/combat/combat_action.gd:1251` and
`src/spells/spell_attack_resolver.gd:140` inject the selected outcome before
native reaction/Peerless handling, then reapply it afterward. A captured hit
forced to miss therefore enters `FighterRules.peerless_aim` as a miss. That
helper consumes the once-per-turn use and converts it to a hit, which the
following override immediately changes back to a miss.

The independent reviewer reproduced this in both weapon and shared-spell
attack hosts using a natural-20 provisional hit. Declining preserves the
Peerless use and leaves the outcome pool at 4. Choosing forced miss produces
a final miss, spends the selected pool to 3, and also marks the unrelated
Peerless use spent. The final miss prevents damage, but the additional native
resource expenditure is incorrect. Preserve native-stage ordering and apply
the final override at its documented stage; add a regression for both hosts.

Reproduction is retained in `.artifacts/review-s092-peerless/probe.gd`,
`probe.tscn` and `godot-verified.log`. Final Godot exit code was 0, with only
the existing effectless-feature warning. Earlier probe cleanup errors are
superseded by this clean final run.

### Closed P1 — S-092 can display force-hit but execute a numeric bonus

`src/autoload/data_loader.gd:857` accepts a feature with numeric attack bonus
and outcome override operations for the same attack domain. The override
branch omits the conflict guard used by numeric operations. Both offered
options therefore share one source-instance ID. `CombatHUD` at line 1554
keys its menu labels by that ID, so the later override label replaces the
numeric label. `SpellDamageRolls` at line 749 settles the first matching
option, which is the numeric bonus.

The independent review probe combined the loaded neutral outcome source with
a valid +1 shared-spell attack bonus. Validation returned no error and both
operations were offered under `review:mixed`. Natural 2 / total 4 against
AC 19 paid for +1 and missed, despite the menu's force-hit label. The clean
log above retains this as `REVIEW_MIXED`. Reject conflicting same-domain
operations per source before they enter this source-ID-only chooser, and
check both authoring orders so ordering cannot bypass the guard.

### Closed P2 — Integral JSON healing mismatch

`src/spells/shared_spell.gd:242` stringifies a JSON numeric scalar before
passing it to the dice parser. An accepted `{"type":"heal","value":5}`
decodes as a float and heals zero: a probe target at 1/20 HP remains at 1
instead of reaching 6. Integer text and dictionary formulas avoid the defect.
This predates these slices and does not invalidate the accepted S-024/025
predicate/identity scope. This was retained as an explicit parser repair and is now fixed above; the
fixture changes exercise numeric input rather than hiding the mismatch. The same probe
and log above retain this reproduction.

## Earlier retained evidence

The original BUILD/VALIDATE reports remain under
`.artifacts/planning/vocabulary-reports/S-025-validation.md`,
`S-041-validation.md`, `S-091-validation.md` and `S-092-validation.md`.
The prior review's reproduction probes remain retained; the final source and
clean batch above supersede their failing behavior.

CodeGraph was attempted: its database indexes Python/Liquid, not GDScript;
no callable query CLI was available. Agent Ground status tooling was also
unavailable. Review used source and production Godot evidence instead.
