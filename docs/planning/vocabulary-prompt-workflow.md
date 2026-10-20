# Vocabulary batch build and review workflow

Use this workflow for the currently selected vocabulary batch. The roadmap and
Quest Board choose work; this guide does not dispatch it or establish gameplay
support. Build and production validation may share an owner-authorized builder
chat; independent review and acceptance reconciliation remain separate.

The original A-I prompt pack is [archived and completed](../archive/planning/vocabulary-next-26-prompts.md).
The retained [031–033 prompts](vocabulary-batches-031-033.md) are completed.
Batches 031/032 are [accepted](../../.artifacts/planning/vocabulary-reports/batch-031-032-acceptance-review.md)
as VS-107–110; owner-authorized [033 acceptance](../reviews/batch-033-acceptance.md)
adds VS-111/112 after independent repair re-review. No further batch is selected;
the owner and roadmap choose later work.

## Starting a fresh chat

1. Work in this repository and follow AGENTS.md. Read `docs/operations/current.md`,
   `docs/architecture/README.md`, `roadmap.md`, ADR-0018 and ADR-0023 once. Read the
   selected slice and its V-series parent in the delivery plan/checklist. Read
   only the relevant mechanics contract and source after that; don't repeat a
   corpus audit. Use the currently selected batch, its accepted prerequisites
   and review findings; archived prompt queues do not choose work.
2. Run the Quest Board brief as your own actor. Reuse and claim the existing
   selected-slice card, or add one if absent. Respect another actor's live claim.
   BUILD, VALIDATE and REVIEW share a card with an exact stage in `next_action`.
   An owner-authorized combined BUILD/VALIDATE run records both stages; a card
   labeled review alone is not proof that production validation happened.
3. Attempt Agent Ground status once if callable. Try CodeGraph first when
   available and check language coverage. At preparation its database indexes
   Python/Liquid, not GDScript; use `rg` and source for game behavior. Missing
   tools do not justify installation or rebuilding indexes.
4. Verify prerequisites against the latest accepted evidence, not this pack's
   preparation date. A passing build is not an accepted prerequisite. If an
   earlier slice is already accepted, inspect its boundary and reuse it instead
   of building it again. If the same stage has already passed on unchanged
   relevant source, review the retained proof instead of running it again.

## Keeping the work bounded

- Work solo. These prompts do not authorize subagents, ongoing orchestration,
  background jobs, scheduled work or messages to other chats. A batch REVIEW is
  a separate fresh chat with an independent reading of the retained work.
- BUILD implements only the named operation and its necessary production hooks.
  Reuse the loader, commands, roll/cost owners, damage settlement, source/copy
  identities and checkpoint paths. Inspect what already exists before adding
  code. No universal event bus, parallel interpreter, wholesale combat rewrite
  or new dependency is a prerequisite.
- Use small neutral and renamed definitions loaded through DataLoader, with a
  meaningful amount, predicate, policy or ability difference. Do not branch on
  their IDs, modify shipped class/spell/monster catalogs, or convert content as
  part of the vocabulary task. Proposed syntax in old design documents is not
  executable syntax. Document the syntax actually implemented.
- The repository's SRD 5.2.1/core-12 direction remains authoritative. These are
  generic capability probes, not certification of the example named rules.
  If implementing a named rule becomes necessary, verify its intended source
  clause first. Do not infer an absent rule body from its name or memory.
- Unknown facts and missing/wrong-kind entities cannot grant eligibility.
  Caller/HUD metadata cannot replace owned authoritative definitions, costs,
  actors or occurrences. Validate malformed definitions before costs/effects.
  Revalidate selected live sources before RNG/payment as the operation requires.
- Queries, decline, refusal, canceled targeting, replay, teardown and an old
  answer against a new request must preserve the correct state. Original action,
  source payment, roll and final consequences happen only as declared and once.
  Do not make a new roll merely to reconstruct an earlier result.
- New durable state must retain owner/source/recipient, quantities, payload and
  clock/boundary through allowed checkpoints without reacquisition or replay.
  Refuse malformed loads before replacing the live session. Test a fresh-process
  recovery when a slice adds durable state; reuse relevant proof if it adds none.
  Requests/menus/turn locks remain transient. Preserve legacy saves and existing
  namespaces; add no migration framework or mid-combat/mid-choice save permission.
- Preserve unrelated work. No deletion, installation, publishing, commits,
  destructive cleanup or changes hard to undo are authorized by these prompts.
  Avoid generating copies or large diagnostics without a concrete need.

## BUILD finish line

Implement, add focused development checks that protect the new behavior, and
update the relevant authoring contract. Record changed files, implemented entity
and host coverage, exact syntax, supported and unsupported cases, focused Godot
evidence and the exact next action. If the owner authorizes BUILD plus production
VALIDATE in this chat, perform the VALIDATE finish line below and leave the card
in REVIEW for independent reconciliation. Otherwise move/handoff the slice card
with separate VALIDATE as next action. Do not update accepted counts or start the
next slice.

## VALIDATE finish line

Begin after BUILD, in a separate chat unless the owner authorized both stages
together. Read the card/report, source and fixtures.
Check behavior through the real supported selection/input/command/choice route,
not merely a directly called helper. Automated viewport harness controls count
when they exercise that route; manual clicking is not required for every check.
Inspect actual receipts, state and once-only cost changes, not just a summary.

Use the existing Windows Godot runner and current test manifest. Read
`docs/operations/validation.md` and the runner parameters before invoking it.
Current focused forms include:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 -Suite logic -LogicGroup spells
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 -Suite integration -Scenario <actual-registered-scenario>
```

These are forms, not new scenario names or a hard-coded executable location.
On this host the existing console executable is
`.artifacts/tools/godot/Godot_v4.7-stable_win64_console.exe`, verified as
`4.7.stable.official.5b4e0cb0f`. The runner now discovers it automatically after
explicit `-GodotPath`/`GODOT_BIN` and before PATH. If working with an older runner,
pass the path explicitly:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run_tests.ps1 -GodotPath '.\.artifacts\tools\godot\Godot_v4.7-stable_win64_console.exe' -Suite logic -LogicGroup spells
```

Empty `GODOT_BIN` and missing PATH entries alone do not establish an unavailable
engine. Check the documented existing portable path and run `--version` before
declaring a host blocker; do not install/download a replacement. This ignored
host tool is not guaranteed in another checkout. If neither a documented local
tool nor an explicit/configured executable exists, record that actual limitation.
Use the existing configured/available Godot binary. The runner owns bootstrap,
project parse and boot gates. Run affected logic groups and the targeted scenario;
do not invoke the full default suite or rerun unchanged broad groups merely to
obtain another green log. Python inventory/schema checks do not prove gameplay.

Inspect stdout, stderr, markers and actual process exit. Assertion failure,
unexpected runtime/parse/resource errors, timeout, missing markers and test-owned
leaks fail acceptance. Respect only the runner's explicit warning policy.
Equal random faces are legal: measure RNG calls/rolled faces correctly, and do
not assert a rerolled die must show a different number. Verify fixtures' actual
costs and HP/max-HP after acquisition before attributing failures to runtime.

If a test fails, diagnose the state/receipt and correct the demonstrated test or
runtime defect; never weaken an assertion just to turn it green. Rerun the affected
case and required gates on the resulting source. If a wrapper hangs, inspect the
owned runner and child status. Do not launch a duplicate while it is still running.
After a child has definitively exited, the existing direct helper can establish a
missing process result; preserve logs and report the wrapper limitation honestly.

Leave a concise validation report at
`.artifacts/planning/vocabulary-reports/<S-ID>-validation.md`, with changed files,
commands, artifact paths, actual host/controls, expected versus observed important
receipts/costs, current-source pass/fail result and limitations. Update the slice
card to REVIEW with that report and the next batch review action. If the current
source and production validation satisfy the entire selected slice's declared
finish line, a separate validation chat may record its exact VS entry,
verified slice state, derived counts and current checkpoint. That precise acceptance
is enough for the next dependent BUILD; the card remains REVIEW until the batch's
independent shared-boundary review. No root supervisor or extra chat per card is
needed. Use current registries to allocate IDs and derive counts, not predicted
numbers in this pack. Then stop.

For an owner-authorized combined builder chat, leave acceptance reconciliation to
independent review and do not change counts. Do not inflate counts or close a
broad V-series parent. A strict subset may be
useful evidence, but cannot silently replace the planned slice's finish line.
If a required host/capability remains missing, record partial/blocked work precisely
and do not let dependent slices treat it as accepted. Previously passed validation
awaiting evidence acceptance may be reconciled by the next fresh chat using the
same bounded REVIEW contract before its own BUILD, without repeating green tests.

## REVIEW finish line

Use the explicit review prompts in the pack. Review retained reports, selected
source and actual-control evidence together, focusing on a concrete shared
boundary. Review is not another broad acceptance suite. Run a targeted reproduction
only for a specific unresolved concern or changed affected code. Fix reproduced
shared-boundary defects and check the affected cases; reuse everything else.

When source and current evidence satisfy the declared slice, reconcile its exact
VS entry, slice state and counts, current checkpoint, any affected authoring docs
and Quest Board cards. Derive counts from the current plan; never assume the next
VS number or overwrite concurrent acceptances. State remaining parent/host scope.
Replace stale checkpoint/queue text instead of appending diaries. Do not mark a
full slice verified for a narrower unacknowledged subset. Leave one next action
and stop; don't launch or message the next worker.

Reuse per-slice acceptances already recorded by separate VALIDATE chats; don't
count them again. If batch review disproves an acceptance, correct its status and
dependent readiness honestly until the defect receives current-source proof.

A source/owner-policy question parks only its affected scope. Independent ready
rows can proceed after checking their actual prerequisites. If a fix would exceed
the authorized slice, name the exact missing decision or follow-up instead of
quietly growing the task.

## Known findings to carry

- S-025 is accepted as VS-28 after its own `shared_entity_binding_flow` control
  and focused spells logic passed. The current evidence and limits are in
  `.artifacts/planning/vocabulary-reports/S-025-validation.md`; do not repeat
  those green runs. Subsequent independent review reconfirmed S-025 and repaired
  S-041/S-092. S-041 is VS-31 and S-092 is restored as VS-30 after full logic
  and five actual-control routes passed. See the
  [acceptance review](../reviews/slice-acceptance-2026-10-14.md). Test actual
  authored consumers when changing windows, not only emitted dictionaries.

- S-024 is now accepted as VS-27; its completed card is
  `Q-20261014-000538-3d5c`. Focused BUILD was 1008/0; actual-control
  validation was 11/0 at `.artifacts/tests/0a100c3d32f940e0963733ee0068fb4f/`.
  Reuse this acceptance before S-025; do not rebuild or revalidate S-024 because
  an older prompt file says review or validation is still dispatched.
- The integral JSON numeric healing defect is closed. SharedSpell normalizes
  accepted integral scalars before parsing, preserving the dice/formula paths.
  Character/dictionary regressions and loaded numeric S-025 control fixtures
  passed in the final review batch; fractional values still refuse. This is a
  bounded parser correction, not a general numeric-schema or catalog conversion.
- The previous reroll runner stream failed to close after children exited. Keep
  the owned-runner status/exit evidence distinct from gameplay assertion success.
  This does not justify duplicate tests or unrelated process termination.
