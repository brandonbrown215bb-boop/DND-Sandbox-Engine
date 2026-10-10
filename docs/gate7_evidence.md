# Gate 7 campaign evidence

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

## Automated result

| Check | Result |
|---|---|
| Player-facing objective | Pass - Crown objective text is rendered from campaign and party state |
| Companion and party composition | Pass - fixed-seed smoke recruits two companions and carries the four-member party into the finale |
| CROWN-09 composition rows | Pass - named `crown_composition_solo_two` and `crown_composition_three_four` cover all four solo/two/three/four-player party rows through production Camp Roster/party setup, safe save/load, objective visibility, combat ownership, and formation; normal shared-keyboard acceptance remains manual |
| CROWN-10 safe-point relaunch | Pass - `scripts/validate_crown_fresh_relaunch.ps1` terminates a prepare process and recovers in a separate process, restoring Crown campaign, four-member ownership, objective, cleared dungeon, reward ledger, and overworld state |
| Two-player midgame relaunch | Pass - `scripts/validate_crown_two_player_relaunch.ps1` recovers a separate two-seat process with owners `[0,1,0,1]`, transferred leadership, two cleared dungeons, two rewards, two fragments, and the Tower objective |
| Dungeon lifecycle | Pass - entry, generated rooms, boss chamber, pending combat, clear ledger, idempotent re-entry, and reward boundary are exercised; named `dungeon_reentry_round_trip` also inspects the plain Room DTO checkpoint and supported reload |
| Event flow | Pass - production event dialog is presented during the Crown smoke; named `crown_event_fairy_ring` covers the Fairy Ring chain, three legal choices, DEX success/failure, reward, condition, healing, teleport, and explicit absence of companion/ledger mutations |
| Final encounter | Pass - production Lich King encounter resolves through the live CombatState loop |
| Defeat flow | Pass - `combat_defeat` exercises the party-wipe boundary and visible defeat screen; named `final_encounter_round_trip` covers the production Lich King loss, safe reload, victory, idempotent reward claim, and completion screen |
| Completion flow | Pass - victory records the campaign win condition and presents the provisional completion screen |
| Normal dungeon victory return | Pass - production `dungeon.tscn`/`combat.tscn` flow with `test_mode=false` restores the pending room, clears it, resets pending combat, preserves party position, and re-enables dungeon input |
| Fixed-seed campaign smoke | Pass - `crown_smoke` completes the bounded production path with no skipped required stage |

## Open Gate 7 work

CROWN-03 now has one named production event outcome proof, and CROWN-04 has
an automated cleared-dungeon reload/re-entry proof. CROWN-05 through CROWN-07
also have a named production loss/reload/victory proof. The broader required-event
and campaign-ledger matrix remains open. Automated CROWN-09 composition rows
and two named CROWN-10 fresh-process relaunch proofs now exist; broader
fresh-process coverage at every supported save point remains. Normal GUI and
two-player campaign sampling are optional and nonblocking for this casual
project. Gate 7 stays `in_progress` behind the unfinished Gate 5 and Gate 6
contracts and its own agent-owned acceptance audit.
