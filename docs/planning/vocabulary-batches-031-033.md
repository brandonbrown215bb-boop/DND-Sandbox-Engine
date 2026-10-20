# Luna handoffs: vocabulary batches 031–033

Prepared 2026-10-19 at the owner's request after local checkpoint `aee56c0`.
These are three BUILD plus production-VALIDATE prompts, each suitable for a
fresh Luna chat. Independent review and acceptance remain separate. Preparation
adds no runtime support or accepted slices.

Current status: [independent acceptance](../../.artifacts/planning/vocabulary-reports/batch-031-032-acceptance-review.md)
accepts 031/032 as VS-107–110. Owner-authorized
[033 acceptance](../reviews/batch-033-acceptance.md) adds VS-111/112 after
independent repair re-review, bringing the total to 112/226. All three prompts
are completed. The preparation baseline and prompts below are retained as the
original handoff, not current dispatch instructions; no further batch is selected.

| Batch | Selected slices, in order | Accepted external prerequisites | Review question |
|---|---|---|---|
| 031 — Linked damage | S-111, S-112 | S-109, S-026 | Does one original occurrence split/redirect at the declared stage while preserving each recipient's independent settlement and once-only parent work? |
| 032 — Absorption and countereffects | S-113, S-114 | S-109, S-034 | Do replacements and follow-ups use the exact declared damage measure and preserve finite, source-specific causal behavior? |
| 033 — Zero-HP replacement | S-117, S-118 | S-004, S-109, S-090 | Is replacement decided before zero-HP consequences, with exact-source attempt/payment/reset history and no double settlement? |

Run them one at a time, with independent review between batches because they
touch the same damage boundary. The registry does not make 032 or 033 depend on
all earlier batches in this pack; inspect the current accepted prerequisites and
carry forward any relevant review repairs. The baseline is 106/226 accepted.
Acceptance of all six existing slices would produce 112/226, leaving 114; this is
a conditional scope count, not a delivery or acceptance promise. Allocate actual
VS IDs from the current register during independent acceptance.

The game-side external pack connection remains a separate integration task.
These prompts preserve the runtime/editor ownership split and do not authorize
edits to `tools/content_editor/`.

## Batch 031 — Split and redirect incoming damage

```text
Luna, build and production-validate Batch 031: S-111, then S-112. Finish this
batch and leave it ready for independent review. Do not start Batch 032.

Work in C:\Users\brand\Documents\linux\Top Down Party Game. Follow AGENTS.md.
Read roadmap.md, docs/operations/current.md, docs/architecture/README.md,
ADRs 0018/0023, and docs/planning/vocabulary-prompt-workflow.md. Then read
S-111/S-112 in docs/planning/vocabulary-slices.md and V-017 in the vocabulary
checklist. Verify S-109 and S-026 against their accepted production boundaries.
The reviewed starting checkpoint is aee56c0, with 106/226 accepted. Use the
current working tree; preserve later work and do not reset to that commit.
Run the Quest Board brief as Luna and claim or create this batch's card.

Scope:
- S-111: split one eligible incoming damage occurrence among actual linked
  recipients, with explicit split stage, eligibility and rounding. Conserve
  the amount at that stage; each recipient's later defenses can change its
  final loss. Preserve typed components and original cause/source identity.
- S-112: redirect a declared share or the whole incoming amount to another
  eligible actor. Revalidate the exact link and recipient after any choice.
  Missing, ineligible or refused recipients follow the authored fallback.
- Neither operation rerolls/replays the attack, hit riders, parent action or
  original payment. Each recipient settles mitigation, wards, Temporary HP,
  HP loss, concentration and zero-HP consequences once where applicable.

Inspect CombatAction's damage boundary, SpellDamageRolls, SharedStepExecutor,
source-owned grants and existing actor identity handling before editing.
Pin the selected SRD 5.2.1 clauses and state the declared order; imported prose
and existing helper behavior are not rules authority. Build generic operations
with loaded neutral and meaningfully changed/renamed consumers. No content-ID
branches, second damage engine, universal event bus or wholesale combat rewrite.

Prove the selected production hosts through actual weapon and flat/ordered
shared-spell controls. Cover odd rounding, mixed types, different recipient
defenses, full/partial transfer, source removal, stale recipient choices,
overlapping links, cancellation and suspension/resume without duplicate costs.
Inspect raw/prevented/absorbed/resolved/HP-loss receipts for each recipient and
their parent occurrence. A helper-only test is not normal-control proof.

Use the existing Windows run_tests.ps1, affected logic groups and a registered
bounded batch scenario. Preserve the checkpoint's dice/critical-history fixes.
Add only regression checks needed for this behavior. Any newly durable link
must retain exact source/recipient and lifetime through an allowed checkpoint
and fresh-process recovery; malformed loads must preserve the live party.
Keep pending choices transient and retain existing save boundaries.

Work solo. Keep shipped catalogs, tools/content_editor, installs, deletions,
commits and publication outside this task. Missing optional grounding tools
are nonblocking. Do not run the full default suite or repeat unchanged proof.

Update the owning authoring/architecture contract and record changed files,
supported hosts, exact syntax, important receipts, commands, raw logs, source
hashes and limits in .artifacts/planning/vocabulary-reports/batch-031-build-validation.md.
Leave the Quest Board card with independent review as its exact next action.
Do not award VS entries, change accepted counts, or close broad V-017 yourself.
Ask the reviewer specifically whether one original occurrence is conserved at
the declared split stage and settles each recipient and parent cost once.
```

## Batch 032 — Absorb damage and produce bounded countereffects

```text
Luna, build and production-validate Batch 032: S-113, then S-114. Finish this
batch and leave it ready for independent review. Do not start Batch 033.

Work in C:\Users\brand\Documents\linux\Top Down Party Game. Follow AGENTS.md.
Read roadmap.md, docs/operations/current.md, docs/architecture/README.md,
ADRs 0018/0023, and docs/planning/vocabulary-prompt-workflow.md. Then read
S-113/S-114 in docs/planning/vocabulary-slices.md and V-018 in the checklist.
Verify accepted S-109/S-034 and inspect the current Batch 031 review/changes
because they share damage settlement. A passing builder report is not accepted
support. Use current source and preserve unrelated work; do not reset to aee56c0.
Run the Quest Board brief as Luna and claim or create this batch's card.

Scope:
- S-113: author an incoming-damage replacement, absorption or healing policy
  using an explicit qualifying type, stage and amount measure. Handle declared
  immunity interaction, including absorption that can qualify before immunity.
  Keep raw, prevented, absorbed, resolved and actual HP loss distinct.
- S-114: derive counter-damage or healing from the declared settled measure.
  Retain root occurrence, parent consequence, original cause and exact reacting
  source/recipient. Enforce the authored feedback/recursion limit so a response
  cannot trigger itself forever; unrelated legitimate responses must still work.
- Original attacks, riders, action budgets and source payments resolve once.
  A countereffect is a derived consequence, not a recast or reflection of the
  original spell. Original spell retargeting/reflection remains S-132/S-133.

Inspect the existing CombatAction, SpellDamageRolls, SharedStepExecutor and
source-owned lifecycle boundaries. Pin the selected SRD 5.2.1 clauses before
choosing policy order; a catalog description or native helper is not proof.
Use loaded neutral consumers and changed/renamed definitions. No per-ID native
handler, second damage engine, universal trigger scheduler or catalog rewrite.

Exercise actual weapon and flat/ordered shared-spell controls on the selected
hosts. Check immune/resistant targets, mixed types, partial prevention, wards,
Temporary HP with zero HP loss, a matching and a nonmatching source, healed
amount/cap, and follow-ups based on different declared measures. Verify two
reciprocal feedback sources terminate as authored while a later unrelated
occurrence still qualifies. Cover pending-choice refusal, source loss, stale
callbacks and ordered continuation without extra payment or repeated effects.
Keep exact source-specific receipts and actual HP changes as the evidence.

Run the existing Windows runner with affected logic groups and a registered
bounded batch scenario. Preserve accepted split/redirect behavior and the
checkpoint's kept-die/critical-history repairs. Reuse unchanged evidence.
New durable source rules/history need allowed-checkpoint and fresh-process
recovery with malformed-load refusal before party replacement. If only transient
causal state is added, keep it out of saves and explain that boundary.

Work solo. Do not edit tools/content_editor or shipped catalogs, install,
delete, commit or publish. No full default-suite run or speculative framework.

Update the owning authoring/architecture contract. Record changed files,
syntax, exact supported hosts, stage/measure receipts, production commands,
raw logs, source hashes and limits in
.artifacts/planning/vocabulary-reports/batch-032-build-validation.md.
Leave the Quest Board card with independent review as its exact next action.
Do not assign VS entries, update accepted totals or close broad V-018 yourself.
Ask the reviewer specifically whether every replacement/countereffect uses the
right settled measure and whether feedback limits preserve legitimate later work.
```

## Batch 033 — Replace zero-HP outcomes with owned attempt history

```text
Luna, build and production-validate Batch 033: S-117, then S-118. Finish this
batch and leave it ready for independent review. Do not start another batch.

Work in C:\Users\brand\Documents\linux\Top Down Party Game. Follow AGENTS.md.
Read roadmap.md, docs/operations/current.md, docs/architecture/README.md,
ADRs 0018/0019/0023, and docs/planning/vocabulary-prompt-workflow.md. Then read
S-117/S-118 and their V-020/V-088 parents. Verify accepted S-004, S-109 and
S-090 on their actual hosts; repeat-save DC history does not automatically
provide a zero-HP attempt host. Read relevant preceding damage-review repairs.
Use current source and preserve unrelated work; do not reset to aee56c0.
Run the Quest Board brief as Luna and claim or create this batch's card.

Scope:
- S-117: extend the existing shared zero_hp_replacement/replace_hp boundary
  with authored damage, critical and represented outright-death exclusions,
  qualifying source eligibility and a replacement-HP formula. Decide before
  unconsciousness/death consequences settle. Keep HP and Temporary HP distinct.
- S-118: resolve a declared save and DC formula/history at that same boundary.
  Increment at the authored attempted/accepted/result event and reset only on
  the declared real boundary. History belongs to the exact actor/source.
  Failure resumes the original proposed zero-HP outcome; success replaces once.
- Preserve original damage, concentration decisions, payments and ordered
  continuation. Declined, stale, invalid or ineligible options cannot acquire
  uses, change history or replay already settled work. Any permitted attempted
  payment follows its declared policy, including a failed save.

Inspect CombatAction, Character.take_damage, SharedStepExecutor's zero-HP rule
validation/execution, BarbarianRules, source pools and current history/rest
owners. Reuse the accepted typed Zombie/ordered execution route. Native
Relentless Rage is a regression reference, not proof of a generic new operation.
Pin the selected SRD 5.2.1 clauses and read only the relevant revised class view
if needed. No new feature-ID branch or alternate zero-HP interpreter.

Use loaded neutral and changed/renamed class/creature consumers through the
real incoming-damage controls. Cover eligible success/failure, excluded damage
type and critical, represented outright death, formula HP, no false activation
when Temporary HP prevents reaching zero, actual subsequent damage, and exact
once-only resource/history changes. Prove escalating attempts, the real declared
rest/reset event, source removal/reacquisition and independent sibling sources.
Exercise the player's pending choice/save route and the selected creature host,
including stale answers and ordered spell continuation. Preserve native Death
Ward, existing typed fortitude and Relentless Rage boundaries with focused checks.

Any source-owned history/uses that survive allowed checkpoints must recover
the original attempts, DC/reset state and identity in a fresh process without
reacquisition, rerolls or refunds. Validate both relevant save DTO paths and
malformed loads before replacing the live party. Keep pending requests transient.
General instant-death/destruction, revival and forms remain later slices.

Run the existing Windows runner, affected logic groups and a registered bounded
batch scenario. Work solo; do not edit tools/content_editor or shipped catalogs,
install, delete, commit or publish. Reuse unchanged proof and keep the task bounded.

Update the owning authoring/architecture contract. Record changed files,
syntax, exact hosts, exclusions, captured save/DC/attempt/payment receipts,
production commands, raw logs, source hashes and limits in
.artifacts/planning/vocabulary-reports/batch-033-build-validation.md.
Leave the Quest Board card with independent review as its exact next action.
Do not assign VS IDs, change accepted counts or close broad V-020/V-088 yourself.
Ask the reviewer whether replacement precedes zero-HP consequences and whether
attempt/reset/save recovery is source-owned and settles once across continuations.
```
