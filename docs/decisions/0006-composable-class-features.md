# ADR-0006: Bounded class-feature foundation

Date: 2026-10-03
Status: Partially superseded by [ADR-0018](0018-shared-data-driven-rules-runtime.md), 2026-10-09

## Original problem and delivered boundary

Monk and Fighter repeated activation/training/resource wiring. Reconstruction
replayed permanent Monk grants, Wholeness could spend twice, and subclass grants
were bundled into base progression. A resolver string alone did not execute a rule.

The accepted first foundation reused Character, commands, CombatState,
CombatAction, CombatTurnBudget and SaveManager. `ClassFeature` validates owned
self-activation records, action/resource budgets and supported effects before
committing costs once. Character owns pools, level-scaled capacity and rest
recovery. `ClassProgression` shares subclass selection and stable choice
entitlements. Base and subclass registries remain separate.

Shared operations include bounded self-healing, Temporary HP, conditions,
modifiers and declared resource restoration. Common passive/check and aura
operations reuse shared character/event/combat queries. Targeted actions and
unusual timing still have native helpers in the current implementation.
The [authoring guide](../modding_guide.md) describes the supported current subset.

## Still-binding guarantees

- Resolve the owned production definition; do not trust supplied costs or grants.
- Validate eligibility before cost; commit an activation's action/resource once.
- Restore remaining uses without refilling; level-up adds only gained capacity.
- Reconstruct membership and derived values without replaying permanent grants
  over saved scores, inventory or gold.
- Grant only the selected subclass's features; unknown enabled operations or
  missing referenced content fail rather than exposing description-only support.
- Shared typed-damage settlement owns mitigation and HP mutation; source-specific
  cleanup preserves overlapping unrelated conditions.

Keep schema 2 and the 2024 namespace. Earlier schema-2 Fighter/Monk saves may
recover previously implicit Champion/Open Hand selection at eligible levels;
explicit selections remain unchanged. Missing selected content rejects preflight.
This does not repair inflated historical scores, migrate legacy saves, add
arbitrary scripts or promise required pack-version enforcement.

## Superseded policy

The original permission to keep unusual class mechanics permanently in trusted
native helpers is superseded for the target runtime. A narrow native helper
remains a maintenance path for unmigrated behavior, not the default for new
features. ADR-0018 requires generic data-defined workflows/policies and source
instances. A unique feature is not an exception to that boundary.

The current allowlisted executor is useful migration input; it is not the final
rules language. Evolve shared capabilities when actual rules need them, without
building a second interpreter or extracting unrelated combat code in advance.
Class acceptance diaries belong in mechanics audits and the checkpoint.
