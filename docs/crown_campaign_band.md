# Crown campaign band

The bounded `crown_smoke` integration scenario exercises the production
overworld, party movement, first dungeon generation, entry milestone and
idempotent clear ledger, event dialog, Lich King encounter composition,
objective completion, and provisional completion screen in one process.

Source: `data/core/campaigns/the_lost_crown.json`.

| Contract | Current inventory |
|---|---|
| Campaign | The Lost Crown (`the_lost_crown`) |
| Starting level | 1 |
| Intended final level | 5 (`max_level`) |
| Player count encoded in data | 1–4 |
| Map | 43 hex tiles; Elderwick is the start tile |
| Required dungeons | Ruins of Ashvale (5 rooms), Caverns of Gloom (6 rooms), Tower of the Lich (7 rooms) |
| Milestones | `enter_dungeon_1`, `clear_dungeon_1`, `clear_dungeon_2`, `enter_dungeon_3` |
| Final encounter | `lich_king` in Tower of the Lich |
| Victory condition | Collect 3 `crown_fragment` items and defeat `lich_king` |
| Companion roster | Aldric, Mira, and Rowan are encoded as available campaign companions |

The planning band remains levels 1–5. The data defines the band, dungeon graph, and companion roster. Logic evidence now covers idempotent milestones, safe save checkpoints, party serialization, and defeat/completion destinations; host review remains open.
