# Quest Board

This is an optional notice board for concurrent work. Solo work, planning and
routine reviews need no card. Keep only live coordination here; completed
committed cards can leave the working tree because Git preserves their history.
Cards under `quests/` contain structured state and a readable handoff.

Run `python .questboard/quest.py --help` for commands. Useful examples:

```powershell
python .questboard/quest.py brief --actor "Rook"
python .questboard/quest.py add "Coordinate pack integration" --next "Validate the editor's pinned candidate" --actor "Rook"
python .questboard/quest.py claim Q-... --actor "Rook"
python .questboard/quest.py handoff Q-... --actor "Rook" --next "Repair the reported export field"
python .questboard/quest.py finish Q-... --actor "Rook" --note "Integration checked"
```

## Ground rules

- One quest should have one concrete next action.
- When coordinating here, claim before changing that shared scope.
- Do not take an unexpired claim without an explicit `--force` decision.
- A handoff without a next action is just a diary entry. The CLI refuses it.
- Keep durable design facts in technical references; don't duplicate build reports here.
- If cards conflict in Git, resolve the overlap deliberately; two agents probably touched the same ground.

Set `QUESTBOARD_ACTOR` to avoid repeating `--actor`. Otherwise the CLI falls back to
the repository Git user, then the operating-system username.
