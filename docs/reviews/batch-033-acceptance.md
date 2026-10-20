# Batch 033 acceptance: zero-HP replacement and owned attempts

Accepted 2026-10-19 at the owner's explicit request, after independent review
and repair re-review closed R1 and R2 without remaining findings.

| Slice | Accepted subset | Boundary |
|---|---|---|
| S-117 | VS-111 | Authored eligibility and replacement HP at the existing pre-defeat damage boundary |
| S-118 | VS-112 | Exact actor/source save DC, attempt, payment and completed-rest/reset history |

The registry is **112/226 accepted; 114 remain**. P4 is **13/25**. Accepted
prerequisites remain S-004/VS-04, S-109/VS-52 and S-090/VS-96 on their existing
hosts. Broad V-020/V-088 remain partial; this does not certify catalog consumers.

## Accepted behavior and limits

Character and Dictionary damage use the existing SharedStepExecutor event
adapter before unconsciousness/death settlement. Damage/critical/represented
massive-death exclusions, required condition and replacement HP/DC formulas
preflight before replacement save RNG or payment. Temporary HP remains separate;
native Death Ward precedes the shared boundary and Relentless Rage retains its
existing fallback.

Optional primary-target authorization captures the exact live source and policy.
Weapon authorization precedes the attack; player flat/ordered spell authorization
precedes settlement. Primary weapon poison riders share the authorization and
its consumed flag. Source loss, changed policy, reacquisition and stale callbacks
cannot reuse old authorization or replay settled parent work.

Attempted/accepted and success/failure policies retain exact source-owned counts
and numeric-pool payments. Completed RestRules events reset only declared
histories, including detached sources. Character history, lifetime totals,
latest receipt/reset generation and paid pool state recover without acquisition,
rerolls or refunds. Both full-save DTO routes validate before replacing live
state; pending choices remain transient and save boundaries are unchanged.

Hosts are loaded primary class features on Characters, incoming monster weapons
including their primary poison riders, player flat/ordered shared spells, and
automatic typed rules on live Dictionary creatures. Dictionary history remains
encounter-local. Linked/counter recipients have no new optional picker. Other
controllers, post-roll rescue choices, general instant death/destruction, forms,
revival and catalog conversion remain unverified.

## Independent findings closed

- R1: primary poison damage previously lost accepted authorization. The repair
  shares the original authorization object. Actual controls prove a small base
  hit leaves it available for poison, while a base replacement consumes it once.
- R2: inconsistent positive saved counts previously lowered the recovered DC.
  Receipts now capture reset_count; both DTO validators check the declared
  increment and current/before/after/lifetime/reset consistency. Real reset and
  post-reset recovery remain valid; contradictory loads preserve live state.

## Production evidence

Final source was matched to the repair manifest during independent re-review.
No runtime changes followed that evidence; acceptance changes documentation and
coordination only. Retained Godot 4.7 evidence:

- Bootstrap, **255-script parse** and production boot passed.
- **1965/0** combat/spell/Barbarian/persistence assertions and **70/0** actual
  controls passed, including both poison cases and original regressions.
- **32 malformed full-save refusals** across both DTO routes preserved actor
  identity, history and paid quantities.
- Parent/child **1608/1824** recovered exact state with zero recovery RNG, then
  a new CON107/DC10 occurrence replaced to HP6 and spent existing pool4 to 3.
- Unchanged prior-batch controls retain **25/0** and **33/0** passing evidence
  from the sixth run; its Batch 033 failure is excluded.

Reproduction command:

```powershell
.\run_tests.ps1 -Suite all -LogicGroup combat,spells,barbarian,persistence -Scenario batch_033_zero_hp_flow
```

Detailed local evidence remains under ignored `.artifacts/`: reports
`planning/vocabulary-reports/batch-033-independent-review.md`,
`batch-033-repair-validation.md`, `batch-033-repair-review.md`, and
`batch-033-repair-source-manifest.json`; final logs are in
`tests/batch-033-repairs-v2/`. The original startup probe supports the suspected
menu/scheduling mechanism; the exact historical seventh-run cause remains
inference, with no unseeded stress claim.

Acceptance selects no further batch. The roadmap and owner choose later work.
