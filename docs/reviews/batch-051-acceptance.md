# Batch 051 acceptance (card Q-20261021-004820-aaf1, PR #21)

**Verdict: ACCEPT. No defects found.** Reviewer: runtime-reviewer, worktree /tmp/rev_wt051, builder head d8db668 (stacked on #20). Review commits are test and doc only.

Blunt caveat first: **players will not see this feature.** `data/core` has zero feats, and fixtures are not loaded at boot. `FeatRules.options` therefore returns nothing, the creation OriginFeatPicker and the sheet's LevelFeatRow never appear, and every ASI stays an ability improvement. The plumbing is correct, but it does nothing until SRD feat content lands (F1).

## SRD 5.2.1 citations (checked against the PDF text; page = printed footer)
- **p.83: correct.** "A background gives your character a specified Origin feat (described in 'Feats')."
- **p.87: correct.** "Parts of a Feat" covers Category ("If you're instructed to choose a feat and no category is specified, you can choose from any category"), Prerequisite, and Repeatable. Grappler, "General Feat (Prerequisite: Level 4+, Strength or Dexterity 13+)", is also on p.87, which matches the Grit fixture's shape.
- **p.29 (feat_rules.gd header): correct.** It is the Barbarian Level 4 Ability Score Improvement: "You gain the Ability Score Improvement feat ... or another feat of your choice for which you qualify."
- No off-by-one this time.

## Rules checked
- **Origin feat at creation:** only the Origin category is offered (T6 and the 051 scenario), and only once.
- **ASI or a feat:** a pending improvement can be spent on any qualifying feat. Origin feats are offered there too, which is correct per p.87 because no category is named.
  - The same applies at every entitled ASI level (4/8/12/16, plus Fighter 6/14); T3 covers a level-6 Fighter mixing +2 CON with a feat.
  - The level-19 Epic Boon feature is **not** wired to "or another feat" (F3).
- **Prerequisites:** level and any-of-abilities are enforced with permanent scores. An unsupported prerequisite key is refused at load.
- **Repeatable:** T2 takes a repeatable feat at creation and at two improvements, and the save validates. A non-repeatable duplicate is refused, both live and in a save.
- **Cap of 20:** STR 20 refuses +1 STR without spending the improvement, and a feat can still be taken (T4). No feat raises an ability yet (F4).
- **Refusal before cost:** unmet ability or level, duplicate, unknown, wrong category or no pending ASI all leave `feature_choices`, `asi_spent` and pending unchanged (builder's checks). A creation refusal returns to Equipment before `PartyManager.register_player_character`.
- **Saves:**
  - A legacy save without `origin_feat` loads.
  - A forged `feat:` value on every non-ASI choice id is refused by `saved_choices_error` (T1).
  - Under-level, non-origin, duplicate, unknown and unearned picks are refused.
  - The Fighter `asi_spent` count stays consistent through a round trip (T3).
- **049 integration:** chosen feats go through `OwnedFeatureSources.declared`, deduplicated against species feats. A feat's own `rule_upgrade` raises its pool to 3, and a short rest refills it to 3 (T5). The real save/load keeps modes and uses exactly once (scenario 051).
- **No per-ID branches.** Category, prerequisite and repeatable are all data. The one `class_id == "fighter"` line mirrors the existing `improve_scores` bookkeeping for `asi_spent`; it is not a feat branch.

## Evidence (Godot 4.7.2, one run at a time)
- Logic on d8db668: **5455/0**, which confirms the builder's +15 over #20's 5440. Gate: 46 scripts, 0 failed.
- Review head: **5462/0** (+7 R051). 0 SCRIPT ERROR. Wrapper exit 0.
- Scenarios 031-051 and shared_spell_flow all pass with 0 FAIL and 0 SCRIPT ERROR. ok counts: 031:25 032:33 033:70 034:10 035:9 036:7 037:11 038:7 039:10 040:12 041:10 042:10 043:11 044:12 045:16 046:16 047:10 048:8 049:9 050:8 051:6 shared:67. The 050 count is 8 here because this stack predates a495177; main has 12.

## Findings for Brandon (not fixed; owner decisions)
- **F1 Dormant feature.** No SRD feats ship, so no player can take a feat. A content card is needed: Origin feats (Alert, Magic Initiate, Savage Attacker, Skilled), the Ability Score Improvement feat, and General/Epic Boon feats. Most need mechanics beyond mode_choice.
- **F2 Background vs free pick.** SRD p.83 gives a *specified* Origin feat from the background. The game has no backgrounds, so 051 lets every character pick any Origin feat. That is the Human "Versatile" rule (p.86), applied to everyone. Accept it as a stand-in until backgrounds exist, or hold it.
- **F3 Missing prerequisite kinds:**
  - Fighting Style feats need "Fighting Style Feature";
  - class prerequisites ("at least 1 level in that class", p.87);
  - the level-19 Epic Boon feature's "or another feat".

  The `fighting_style` category loads today with no way to require the feature, so a Wizard could take one at an ASI once such content exists.
- **F4 No ability increases from feats.** SRD General feats include "+1 to one ability, max 20". The cap is not modelled for feats.
- **F5 Breaking for content.** Every feat now needs `category`, so uncategorised feats from mods or the content editor are refused at load.
- **F6** If a chosen feat's content is later removed (a mod is uninstalled), the whole save is refused ("Chosen feat ... is unknown"). This is consistent with other unknown content, but harsh.
- Minor: a creation refusal jumps back to Equipment with no message (unreachable today, because the picker offers only eligible feats). `surge.json` was reformatted with no trailing newline.

## Count updates
None proposed. This is player-path acquisition on top of the 049 vocabulary, not a new vocabulary slice. If Brandon counts F1 content later, that batch should carry it.

## Rook's final acceptance correction

The initial no-defects verdict missed saved ability prerequisites. Final acceptance
rejects unmet/malformed permanent ability scores before replacing the live session,
with a regression that failed before the fix. Current accepted limits belong in
the slice registry and source-carrier contract; the earlier findings remain history.
