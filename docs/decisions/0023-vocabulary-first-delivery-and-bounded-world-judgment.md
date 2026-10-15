# ADR-0023: Vocabulary-first delivery and bounded world judgment

Date: 2026-10-12
Status: Accepted direction; implementation staged

## Context

The owner wants the code building blocks needed to express rules in data, then
a roadmap for building and checking those blocks. The earlier audit expanded
into individual-content verification and runtime probes. The owner separated
vocabulary discovery, implementation, vocabulary checks and content conversion,
and resolved the remaining planning questions in discussion.

## Decision

**Aim to express the intended rules through reusable, composable operations.**
There is no permanent list of mechanics excluded merely because they are unusual.
Distinguish composition of existing operations, a missing generic operation,
a missing represented world fact/action, and a genuinely interpretive outcome.
An instruction to create a wall needs actual room geometry behavior; combining
damage and condition operations cannot supply it. Add a concrete world capability
when the selected rule needs it. Do not build a universal world simulation first.

Rules may combine ordinary comparisons, boolean conditions, arithmetic and
declared result references. The concrete authoring syntax is settled during
implementation of a selected vocabulary batch. Never substitute a content-ID
branch for a missing building block.

**Use proper resolution stages.** Roll, determine hit/save outcome, calculate
damage, settle damage and handle aftermath are separate windows. A provisional
hit changed to a miss must not consume damage prevention. Resolve detailed
precedence when actual selected rules interact; exhaustive hypothetical reaction
ordering is not a prerequisite for the first vocabulary batch.

**Save compatibility is not a delivery priority in the current hobby project.**
The owner states there are no existing player campaigns or players to preserve.
Do not build migration/version frameworks or require a compatibility planning
exercise before implementing ordinary rule state. Keep state ownership, uses,
targets, clocks and Short/Long Rest or minute/hour wiring correct. Store the state
needed by the current campaign at allowed checkpoints and validate loading before
replacing the live session. A timer without its source or recipient is insufficient.

This priority change does not authorize deleting files, rewriting unrelated saves
or adding mid-combat/mid-decision saving. Existing save locations and current
checkpoint boundaries remain unless a future feature actually changes them.

**Illusions use observer-specific discovery and bounded behavior.** Suspicion
can cause an observer to investigate; Intelligence can influence that decision.
High Intelligence is not automatic truth detection or an unconditional investigation
of every illusion. Context can be represented with a few concrete facts. Apply
the selected spell's written discovery/interaction rule to determine the outcome
and retain what that particular observer learned. Identify missing facts/actions
in the vocabulary list rather than silently invent a threshold in place of a rule.
This does not require an elaborate general AI or human GM interface up front.

**Wish supports executable ordinary uses and campaign-authored special outcomes.**
The campaign may supply available outcomes, requirements, costs, restrictions
and actual effects using supported operations. If no applicable campaign outcome
exists, the ordinary supported uses remain available. A prose promise is not an
executed world change. Spell-specific consequences and unsupported ordinary uses
must be identified when this capability is selected. A general free-text Wish
interpreter or GM workflow is not required before bounded support.

**Missing descriptions are a separate later source task.** Locate the intended
2024 bodies and add any distinct vocabulary they reveal, including gaps in the
illusion/Wish policy. Names, incomplete extracts and proposed syntax are not
complete rule bodies. No testing, definition mutation or per-record correctness
ledger belongs to this source-discovery task.

## Delivery and acceptance boundary

The [roadmap](../../roadmap.md) selects small capability batches from the
[vocabulary checklist](../reviews/dnd-code-vocabulary-gap-checklist.md).
Build the selected shared capability, check that vocabulary in a separate
bounded validation step, then translate content that requires it. Representative
small fixtures can exercise the vocabulary without making catalog-wide rewrites
part of the engine task. Existing useful paths remain reuse points.

Discovery, planning and completed code are distinct from verified behavior.
Production Godot checks still own gameplay evidence when the validation step is
reached. Unknown support remains unknown until then. This ADR supplies direction,
not executable syntax or a new support claim.

## Affected earlier decisions

- ADR-0018's one shared runtime, source identity, single execution owner and
  generic world-capability direction remain binding. This ADR clarifies delivery
  and supersedes any interpretation requiring a universal GM/adjudication
  interface before bounded illusion or campaign-authored Wish behavior.
- The save-isolation and allowed-checkpoint boundaries in ADR-0004 and later
  state ADRs remain. Blanket compatibility/version planning as a prerequisite
  for every new state capability is superseded by the owner's current priority.
  No migration or destructive file work is authorized by this decision.
- ADR-0019–0022 remain accepted evidence for their bounded implementations;
  they do not certify the broader vocabulary list.
- Older design phase sequences and audit completion targets do not override
  the roadmap or turn source discovery into runtime verification.
