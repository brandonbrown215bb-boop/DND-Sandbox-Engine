<!-- AGENT_GROUND_START -->
## Repository Ground

- Read `docs/operations/current.md`, `docs/architecture/README.md`, and relevant ADRs before substantial changes. Historical `.agents/` role logs are not current instructions or live agent state.
- Attempt Agent Ground status once when available. Missing tooling is nonblocking; inspect current source and tests instead.
- If `.codegraph/` exists, try CodeGraph first. Check language coverage: an index without GDScript cannot locate game behavior. Fall back to `rg` and source; do not install or rebuild tools merely to start work.
- Keep boundaries cohesive and testable. Split by responsibility, not ceremony.
- Preserve unrelated work and generated/source boundaries.
- Update documentation when shipped behavior changes. State limitations plainly.
- Record durable project decisions in ADRs. Keep transient task state out of durable documentation.
- Use `docs/README.md` for documentation authority. ADR-0018 governs the shared data-driven runtime direction; named native class/spell/monster helpers are migration code, not the default for new rules.
- Dated gates/reviews and old wave sequences do not choose priorities or block current work. Proposed engine syntax is not executable; verify capability and support claims against source and production Godot checks.
- Replace stale checkpoint sections instead of appending diaries. Supersede ADR policy explicitly while preserving still-binding identity, cost, source-ownership and save guarantees.
<!-- AGENT_GROUND_END -->

<!-- QUEST_BOARD_START -->
## Shared Quest Board

This repository uses `.questboard/` as its shared coordination surface.

Before substantial work:

1. Run `python .questboard/quest.py brief --repo "<absolute repository path>" --actor "<your name/tool>"`.
2. Claim the quest before editing its scope. If none exists, add one.
3. Treat an unexpired claim by someone else as occupied ground.

Before pausing or handing work to another person or agent:

1. Record what changed and the exact next action.
2. Use `handoff`, `move ... blocked/review`, or `finish` so the status is honest.
3. Include `.questboard/quests/` changes when the associated code is committed. Do not create a commit merely to update coordination.

The quest board is volatile coordination, not architecture documentation. Source, tests,
ADRs, and project documentation remain authoritative for durable technical facts.
<!-- QUEST_BOARD_END -->

## Small Product Working Model

- One owner and one obvious ready card. Split work by observable behavior, not by arbitrary time limits.
- Work solo by default. Use one independent reviewer for shared combat rules or persistence, with a specific question and reproducible checks. If team contracts are unavailable, continue solo and state the review limitation.
- Do not use overlapping reviewers, mandatory victory ceremonies, or repeated green runs without new evidence to investigate.
- Keep `roadmap.md` as priority authority, the Quest Board as ownership/next-action authority, and ADRs/architecture as durable design authority.
- SRD 5.2.1 is the rules authority for the staged core-12 milestone. Artificer and Mystic are outside this milestone. Supported means production behavior is verified, not that a description or dictionary entry exists.
- Python checks validate inventory and JSON structure. Godot checks own gameplay and save behavior. Do not interpret copied Python formulas as production proof.
- Change combat boundaries only when the current feature needs it. A wholesale CombatState extraction is not a prerequisite for mechanics work.
- Preserve legacy saves. New campaigns use the 2024 save namespace; no automatic migration or legacy rules engine.
