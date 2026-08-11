# Crown balance fixture: Ruins of Ashvale

This is the seeded baseline for the first Crown dungeon boss. It uses the
production `the_lost_crown` campaign record, dungeon scene, Wight monster
record, safe-save guard, and live combat loop.

| Dimension | Fixture contract |
| --- | --- |
| Party | Four active Crown characters: the two test players plus Aldric and Mira |
| Entry | Entering `ruins_of_ashvale` applies `enter_dungeon_1`, raising the party to level 2 |
| Encounter | One production `wight` boss, generated from the dungeon boss record |
| Rest/save | Safe-save is available at the entrance checkpoint; it is blocked after the party leaves that checkpoint |
| Reward | One `crown_fragment` and `gold_100`, granted by the dungeon record after a successful clear |
| Seed | `20260810` |
| Budget | The live Wight encounter must resolve with at least one party member standing within 12 rounds |

The automated fixture prints the observed round count, party HP attrition, and
remaining Wight HP. Human review remains required for whether the fight reads
as fair, whether the twelve-round cap is appropriate, and whether the reward
feels proportionate to the risk.
