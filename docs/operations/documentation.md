# Documentation maintenance

[The documentation map](../README.md) assigns authority. Keep each fact in its
owner: roadmap for priority, Quest Board for handoff, ADR for durable reasons,
architecture for boundaries, mechanics for supported clauses, checkpoint for
latest accepted evidence. Code and production checks decide actual behavior.

When changing behavior:

1. Update the owning contract, distinguishing supported behavior, target
   direction and unimplemented detail. Mark approximations and unavailable
   clauses; never turn a registry row into a support claim.
2. Replace stale checkpoint sections rather than appending run diaries. Name
   the date, host, relevant checks/logs and limits. Put raw logs in ignored
   artifacts and transient resume details on the quest card.
3. When a decision changes, edit its ADR status and scope and add a reciprocal
   link to the replacement. Partially supersede the affected policy; preserve
   reasons and compatibility constraints still in force. Keep ADR numbers unique.
4. Remove obsolete duplicate plans when their useful requirements have an
   owner. Preserve dated evidence that explains a defect or acceptance boundary,
   with an explicit historical label under `docs/archive/`. Keep links working
   when moving documents. Avoid historical reports in onboarding; the current
   roadmap should link to accepted evidence rather than repeat batch diaries.
5. Check local links from active docs, ADR status/index agreement, and remaining
   references to removed documents. Read generated-report headers too: a
   regeneration must not resurrect an old plan or completion claim.

Documentation-only work needs link/consistency checks, not a gameplay rerun.
If authoring examples or schemas change, validate them against the actual
production loader. If runtime behavior changes, use [proportionate gameplay
validation](../testing.md). Source-coverage reports are dated inventories;
completion percentages and copied formulas are not rules evidence.

Rule-source tasks start in `reference/2024/`, which is generated from unchanged
mixed-edition originals. Keep copied source records exact, preserve their input
hashes/coordinates, and distinguish reference extraction from official rules
verification and runtime content. Use `python scripts/build_revised_class_reference.py --check`
after changing the view generator or original class inputs.
