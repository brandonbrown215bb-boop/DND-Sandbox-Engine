# Crown campaign band

Source: `data/core/campaigns/the_lost_crown.json`.

| Contract | Current inventory |
|---|---|
| Campaign | The Lost Crown (`the_lost_crown`) |
| Starting level | 1 |
| Intended final level | 5 (`max_level`) |
| Player count encoded in data | 2–4 |
| Map | 43 hex tiles; Elderwick is the start tile |
| Required dungeons | Ruins of Ashvale (5 rooms), Caverns of Gloom (6 rooms), Tower of the Lich (7 rooms) |
| Milestones | `enter_dungeon_1`, `clear_dungeon_1`, `clear_dungeon_2`, `enter_dungeon_3` |
| Final encounter | `lich_king` in Tower of the Lich |
| Victory condition | Collect 3 `crown_fragment` items and defeat `lich_king` |
| Minimum companion roster | Not encoded or reachable in the current repository; pending Gate 4 party/companion inventory |

The planning band remains levels 1–5. The data defines the band and the dungeon graph, but does not yet prove a complete companion roster, idempotent milestone progression, or a player-facing terminal flow.
