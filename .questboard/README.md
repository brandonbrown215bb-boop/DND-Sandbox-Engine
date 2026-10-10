# Quest Board

This directory is the project's shared notice board for humans and coding agents.
Quest cards under `quests/` are tracked Markdown. Each card contains a structured state
block plus a readable summary and handoff log.

## Current roadmap execution

The remaining work in `roadmap.md` is decomposed into small cards.

- Only the current card is `ready`; downstream cards stay `parked`.
- Split by one observable mechanic, fixture, bounded data batch or host check,
  rather than an arbitrary time limit.
- The current roadmap chooses priorities and accepted ADRs own durable rules.
  Historical gate chains and old predecessor cards do not reinstate blockers.
- When a direction changes, update the one next-action card; do not unpark an
  obsolete successor chain automatically. The board records ownership/motion,
  not a competing implementation plan.

## Lean review policy

- `review` is only for a bounded human decision that can be made now. It is not
  a waiting room for green automation or optional playtesting.
- Finish implementation cards when their own production-path and automated
  acceptance criteria pass. Do not copy the same manual check onto every card.
- Human play is consolidated under the optional Crown sampler. It is for feel,
  readability, and surprising wiring gaps; it never requires a full playthrough
  and does not block this casual project.
- Publication, friend-run, cleanup, and controller work stays `parked` until it
  is actually wanted.
- Keep one obvious `ready` card whenever practical.

Record a playtest finding through the CLI so the next card rewrite preserves it:

```powershell
python .questboard/quest.py note Q-... --actor "Pigeon" --note "human_reviewed: What happened"
```

The obvious next action is always shown by:

```powershell
python .questboard/quest.py brief --actor "<your name/tool>"
```

## The short ritual

```text
arrive -> brief -> claim -> work -> handoff/review/block/finish
```

Run `python .questboard/quest.py --help` for commands. Useful examples:

```powershell
python .questboard/quest.py brief --actor "Pigeon/Codex"
python .questboard/quest.py add "Repair unit progress refresh" --next "Reproduce the stale scan path" --actor "Esmund/Cursor"
python .questboard/quest.py claim Q-... --actor "Esmund/Cursor"
python .questboard/quest.py handoff Q-... --actor "Esmund/Cursor" --next "Verify the progress tracker upload" --note "Refresh logic patched"
python .questboard/quest.py move Q-... review --actor "Pigeon/Codex" --next "Run Inventor smoke test"
python .questboard/quest.py finish Q-... --actor "Pigeon/Codex" --note "Smoke test passed"
```

## Ground rules

- One quest should have one concrete next action.
- Claim before changing code in its scope.
- Do not take an unexpired claim without an explicit `--force` decision.
- A handoff without a next action is just a diary entry. The CLI refuses it.
- Keep durable design facts elsewhere. This board records motion.
- If cards conflict in Git, resolve the overlap deliberately; two agents probably touched the same ground.

Set `QUESTBOARD_ACTOR` to avoid repeating `--actor`. Otherwise the CLI falls back to
the repository Git user, then the operating-system username.
