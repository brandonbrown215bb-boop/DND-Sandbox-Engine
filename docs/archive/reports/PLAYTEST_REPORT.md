# Godot GUI Playtest Report

> **Archived material.** This preserves a past snapshot, not current instructions.
> Read the [current checkpoint](../../operations/current.md) and [roadmap](../../../roadmap.md) before acting.


Date: 2026-10-08, America/Chicago. Tester: Codex using the installed Windows computer-use skill and its documented `@oai/sky` workflow.

## Executive Summary

**Verdict: launches and supports substantial live gameplay, but saved campaigns cannot be resumed.** Three distinct passes exercised exploration, room interactions, solo and party combat, healing, victory, defeat, and a fresh restart. The save/recovery failure makes longer adventures unsafe to rely on. Divine Smite is inaccessible after a valid hit, and the tested Paladin's longsword damage omits Strength.

Active confirmed findings: **2 P1, 3 P2, no active P0**. Crowded labels, hidden instructions, and incomplete character setup guidance also create significant friction. No new script/engine errors appeared in the playable session logs. This does not establish that all mechanics are complete or correct.

The earlier P0 startup parser failure, PT-001, was repaired under the separate user instruction to fix playtest blockers. That repair is already verified. **No production source or assets were changed during these resumed playtest passes.** The archived [earlier report](../../../playtest-evidence/startup-report-before-playable-passes.md) preserves pre-repair observations; its obsolete verdict is superseded here.

Major gaps: full Crown-fragment collection and final Lich King victory, higher-level/class coverage, successful merchant transactions, equipment swapping, attunement, revival, and hazard damage. These were not established by GUI play. Save recovery blocked continuation of both saved adventures; defeat ended the exploratory campaign. The tested low-level slice cannot validate the whole SRD milestone. Audio cannot be judged from the screenshot/input surface.

## Environment and Method

- Normal production launch: `.artifacts/tools/godot/Godot_v4.7-stable_win64.exe --path "C:\Users\brand\Documents\linux\Top Down Party Game"`.
- Godot 4.7 stable, official build `5b4e0cb0f`; Compatibility renderer, ANGLE/D3D11, NVIDIA GeForce RTX 5060 Ti.
- Entry inspected: `project.godot` → `scenes/main.tscn` → `src/main.gd` → title menu. Default client size approximately 1280 × 720; also maximized and restored.
- Genre/loop: turn-based party RPG for local players. Create characters, travel a hex overworld, resolve events, explore dungeons, fight, loot/heal/rest, and recover three Crown fragments before defeating the Lich King.
- Each gameplay action used real mouse/keyboard input in the focused game window and a refreshed screenshot. Turns and movement animations were allowed to resolve before interpreting their results. No programmatic gameplay, debug teleporting, direct scene jumping, or save editing supplied GUI outcomes.
- Focused source reads and a separate headless **read-only save diagnostic** clarified observed defects. The diagnostic scene only reads JSON and validates it; it does not load a campaign or manipulate the live game.
- Repository instructions/current operations/architecture were read; Quest Board ownership was maintained. CodeGraph was attempted but unavailable; no Agent Ground status tool was callable. Existing unrelated changes were preserved.

## Three Playtesting Passes

| Pass | Actual path and actions | Outcome |
|---|---|---|
| A — Normal player | Randomized Gimble Oakshield, Half-Elf Paladin. Overworld movement and Mysterious Shrine; help, character sheet, spell preparation, safe save. Ruins of Ashvale: key pickup, locked door, guardian battle, melee targeting, Lay on Hands, victory. Entered another encounter with Wight/Skeleton/Zombie, moved in difficult terrain, dodged, and took damage. Settings, quit to menu, quit application, fresh normal launch, attempted Continue/Load. | Guardian defeated; live loop playable. Resume failed. Smite and weapon-damage defects reproduced. |
| B — Exploratory player | Manually created Elf Wizard Hero 1 using point buy. Recruited Aldric (Cleric), Mira (Ranger), Rowan (Rogue), reaching 4/4. Wandering Merchant event and Elderwick shop. Entered Ashvale; Fire Bolt against timber, burning spread/extinguish attempt, key and chest, potion loot. Companion initiative and mace attack; Wizard Ray of Frost and Fire Bolt; second guardian victory. Transferred potion at valid distance, consumed it, rested, exited and revisited dungeon/town. | Party, object interaction, cantrips, healing, rest, and transitions observed working. Transactions remained unverified. |
| C — Stress/recovery | Repeated Dodge after spending Action, clicked outside room and stone/lava hexes, tried simultaneous W+D and wheel input, retested Escape picker cancellation. Dismissed companions, saved Wizard campaign, re-entered cleared room, tested movement limits, fought Wight alone, reached lethal damage and defeat. Tried safe-save recovery, read final Chronicle, returned to title, created a fresh two-player campaign, tested turn handoff and window sizing. Recorded/prepared Wizard spells and cast three Magic Missile darts in another guardian encounter. | Invalid repeated actions refused; defeat and fresh restart work. Safe-save recovery failed again. Magic Missile consumed a slot and reported 14 force damage. |

Visited: title/setup/creation, overworld/Elderwick, Shrine and Wandering Merchant events, Ashvale entrance/coarse room map/authored antechamber, guardian arena, forest encounters, victory/defeat/terminal Chronicle, settings, roster, character sheets. No full campaign completion is claimed.

## Test Coverage

PASS applies only to the specific actions in its row.

| Feature/mechanic | Actions attempted | Expected behavior | Observed behavior | Result |
|---|---|---|---|---|
| Startup and title | Fresh normal visible launches after repair | Usable menu | Menu appeared; New Campaign worked | PASS |
| Character creation | Randomize All; manual Elf Wizard; point-buy increments; attempt extra increment at zero points | Valid party creation without overspending | Created characters; zero-point increment did not overspend | PASS |
| Two local players | Create two characters; End Turn | Active seat changes | P1/P2 markers and active character switched | PASS |
| Overworld movement/events | Click hexes; Shrine choice; Merchant Close | Travel cost and event completion | Coordinates/cost logged; events closed into world | PASS |
| Camera/window | Wheel zoom in/out; maximize/restore; brief W+D chord | View responds without losing UI | Zoom and sizing worked; chord had no visible change | PARTIAL |
| Help and sheets | Open, scroll, Escape | Readable information and dismissal | Help/sheets usable; basic guidance incomplete | PASS |
| Wizard setup | Record six starter spells; prepare four | Spellbook/prepared selection updates | 0 recorded → 6; 0/4 → 4/4 prepared | PASS |
| Dungeon transitions | Enter, room map, entrance, leave, re-enter | Correct room/location state | Worked; cleared room/door state persisted in session | PASS |
| Key and locked door | Take beyond reach then adjacent; Unlock/Open | Reject distance; permit keyed passage | Refusal then pickup/unlock/open and passage | PASS |
| Chest/inventory | Select, open, take potion | Loot enters inventory | Take logged; potion selectable | PASS |
| Object fire | Fire Bolt miss/hit; distant/adjacent extinguish | Hit/burning, proximity rules | Damage/burning/spread logged; distant extinguish refused; neighbor reignited fire | PASS |
| Potion transfer/use | Give remotely then adjacent; companion Use | Reach check and healing | Transfer refused then succeeded; Aldric 2/14 → 11/14 | PASS |
| Rest | Attempt inside local room; rest on coarse map | Rest in allowed state restores resources | Local button inactive; map rest restored Aldric to 14/14 | PASS |
| Shop/tavern | Enter, inspect items/shopper/sale controls at 0 gold | Clear unaffordable state | Insufficient Gold and unavailable paid rest shown | PARTIAL |
| Purchase/sale | No completed paid transaction | Correct gold/items accounting | No transaction established | NOT TESTED |
| Combat turn order | Solo and four-member party End Turn | Player/enemy initiative advances | Correct observed handoffs and round changes | PASS |
| Melee targeting | Out-of-range longsword; adjacent attacks; dagger attempt | Range refusal; attack resolution | Refused range; hits/misses and Action cost observed | PASS |
| Weapon damage | Compare Paladin STR +1 with two hit detail panels | Add Strength to ordinary longsword damage | d8 results 1 and 2 applied as 1 and 2 | FAIL |
| Divine Smite | After two nonlethal melee hits, Bonus available; inspect spell/feature choices | Offer usable after-hit Smite | Always disabled; no usable after-hit prompt | FAIL |
| Cantrips | Fire Bolt on object/enemy; Ray of Frost enemy | Spell hit/damage/effect | Fire damage; cold damage and movement penalty logged | PASS |
| Limited-slot spell | Prepare Magic Missile; target same creature for three darts | Resolve darts, spend Action/slot | Logged 14 force damage and one level-one slot spent | PASS |
| Components | Heroism with longsword + shield | Refuse missing free hand without Action cost | Explicit free-hand refusal; Action retained | PASS |
| Healing feature | Lay on Hands on wounded Paladin | Heal and spend Bonus/resource | 16/22 → 22/22; Bonus spent, Action retained | PASS |
| Dodge/repeated controls | Dodge; repeat three times | First consumes Action; repeats refused | Dodge status then three no-Action messages | PASS |
| Boundaries/movement budget | Void, stone, lava, long route; forest movement | No illegal movement/budget overrun | No movement on refused clicks; long-route refusal; forest costs observed | PARTIAL |
| Hazard damage | Try lava from two positions | Observe damage if entry possible | Entry refused; no lava damage observed | NOT TESTED |
| Druid Wild Shape | Select listed feature with 2/2 uses | Eligible form flow/transform | Picker closed, no observed transform; known forms not configured/verified | PARTIAL |
| Combat Escape | Press Escape in Paladin and Wizard spell picker; compare mouse Cancel | Close picker as banner promises | Escape failed; mouse Cancel worked | FAIL |
| Damage and victory | Enemy attacks; defeat guardian in A/B | HP changes, terminal victory, return | HP loss, victory modal, Continue returned to room | PASS |
| Defeat/terminal flow | Wight lethal hit; Continue; final Chronicle; title | Defeat and recovery choices | Defeat/Chronicle/title worked; safe reload disabled | PARTIAL |
| Safe save/resume | Save Paladin and Wizard; fresh-process title; post-defeat safe load | Resume saved campaign | Save success/file exists; Continue/Load/Safe Save disabled | FAIL |
| Settings/quit | Volume slider visual change; combat settings; Quit to Menu; title Quit | Controls and transitions work | Slider moved; unsafe Save disabled; menu/application closed | PASS |
| Audio | No listening-capable test surface | Evaluate sound/mix | Cannot establish audio outcome | NOT TESTED |
| Equipment/attunement/revival | Controls visible, no completed actions | Correct gear/recovery effects | Not exercised | NOT TESTED |
| Final objectives/high levels | No complete fragment/final-boss run | Full campaign win/progression | Low-level slice only | NOT TESTED |

## Confirmed Bugs

### PT-002 — P1 — Saved campaigns cannot be resumed

**What happens / why it matters:** Save reports success, but title Continue/Load and post-defeat Load Safe Save are disabled. The owner's progress becomes inaccessible after quitting or defeat. Files remain present; deletion or corrupt file contents were not observed.

**Reproduction:**

1. Start The Lost Crown, create one character, enter overworld and move at least once.
2. Open Menu → Save. Observe the success entry.
3. Quit to menu, quit the application, launch normally again.
4. Attempt Continue and Load: both are disabled.
5. In a second campaign, save on the overworld, enter a dungeon and lose a solo fight.
6. Choose Continue on Defeat, then attempt Load Safe Save: disabled again.

**Expected:** Resume the valid safe checkpoint. **Actual:** No resumable campaign is offered.

**Frequency:** Both GUI-saved campaigns rejected; demonstrated on fresh launch and after defeat.

**Evidence:** [fresh title](../../../playtest-evidence/23-fresh-relaunch-load-unresponsive.jpg), [defeat recovery](../../../playtest-evidence/32-defeat-safe-save-disabled.jpg), [settings showing quicksave](../../../playtest-evidence/37-settings-quicksave-exists.jpg), [first save/log](../../../playtest-evidence/pass-a-quicksave.json), [second save](../../../playtest-evidence/pass-b-quicksave.json), [runtime log](../../../playtest-evidence/godot-runtime.log), [read-only diagnostic](../../../playtest-evidence/save-readonly-diagnostic-b.log).

**Supported cause:** `src/autoload/save_manager.gd:393` requires visited coordinates to have integer types. Godot JSON decoding produces `[0.0, 0.0]` with type 3 (float), while TYPE_INT is 2. Production validation then returns `visited overworld location is invalid`. Title eligibility consequently rejects the save.

**Suggested correction — Fix now:** Accept finite, integral JSON numeric coordinates and normalize them safely; continue rejecting fractional/malformed coordinates. Add a production save → disk JSON → fresh reload check, including post-defeat recovery. Preserve existing files.

### PT-003 — P1 — Divine Smite has no usable after-hit path

**What happens / why it matters:** A core Paladin mechanic appears available but cannot be activated after an eligible hit, materially reducing the class's gameplay.

**Reproduction:**

1. Use Gimble's level-two Paladin with a longsword, available level-one slots/free cast, and unused Bonus Action.
2. Hit the Ashvale guardian in melee without killing it.
3. Observe that no Smite prompt appears. Open Spell.
4. Click Divine Smite, displayed as `[Cast after a melee hit] [Free cast available]`.
5. Check Features; only Lay on Hands is offered. Repeat after another eligible hit on a later round.

**Expected:** An after-hit Smite choice using the available Bonus Action/free cast or slot. **Actual:** Spell row remains disabled and no usable choice appears.

**Frequency:** Two eligible nonlethal hits on separate rounds.

**Evidence:** [first hit/picker](../../../playtest-evidence/15-smite-picker-after-hit.jpg), [repeat](../../../playtest-evidence/20-smite-disabled-reproduced.jpg).

**Supported cause:** `src/combat/combat_hud.gd:422` unconditionally disables after-hit trigger spells. `CombatAction.resolve_divine_smite` exists at line 1392, but its callers found in current source are tests, with no production after-hit invocation found.

**Suggested correction — Fix now:** Connect a successful eligible melee hit to a cancellable Smite choice; consume costs only when accepted and prevent use outside the qualifying window.

### PT-004 — P2 — Paladin longsword damage omits Strength

**What happens / why it matters:** Successful attacks deal less damage than their character statistics imply, prolonging fights and misrepresenting ordinary weapon rules.

**Reproduction:**

1. Use Gimble, whose sheet shows STR 12 (+1), with longsword and shield.
2. Attack the guardian in adjacent melee range.
3. Expand Roll Details on a successful ordinary hit.
4. Compare the d8 roll with total/applied damage; repeat with another hit.

**Expected:** The observed d8 rolls 1 and 2 should yield 2 and 3 damage before any separately displayed target adjustment. **Actual:** Details show totals/applied damage of 1 and 2, omitting +1. No displayed resistance adjustment explains this.

**Frequency:** Two detail panels establish the omission.

**Evidence:** [roll 1](../../../playtest-evidence/18-damage-missing-strength.jpg), [roll 2](../../../playtest-evidence/19-damage-omission-reproduced.jpg), [character resources](../../../playtest-evidence/12-character-resources.jpg).

**Supported cause:** Catalog longsword damage is `1d8`. In `src/combat/combat_action.gd:956`, ordinary weapon ability damage is appended in a Fighter-only branch; the tested Paladin does not receive that adjustment. Passing a modifier dictionary does not add a term absent from the dice formula.

**Suggested correction — Fix now:** Apply ordinary weapon ability damage for all applicable classes, preserving explicit exceptions and avoiding double additions. Verify through the production attack path using a non-Fighter.

### PT-005 — P2 — Escape does not close combat spell picker

**What happens / why it matters:** The banner promises Esc/Cancel, but only mouse Cancel closes the list. Keyboard cancellation is unreliable and feels stuck.

**Reproduction:**

1. On a controllable combat turn, click Spell.
2. Press Escape while the list is open; press again.
3. Observe that the picker remains open.
4. Click its Cancel button: it closes.
5. Repeat using the Wizard rather than Paladin.

**Expected:** Escape closes the picker and cancels targeting. **Actual:** No visible dismissal, despite focused game window.

**Frequency:** Repeated Paladin presses and independent Wizard reproduction. Escape successfully closed sheets, help, roster, final Chronicle, and attack targeting in their tested states.

**Evidence:** [Paladin](../../../playtest-evidence/16-spell-picker-escape-fails.jpg), [Wizard](../../../playtest-evidence/28-wizard-escape-failure.jpg).

**Suspected cause:** HUD cancellation runs in `_unhandled_input` (`combat_hud.gd:165`); focused GUI controls may consume Escape first. Exact consuming control is not established.

**Suggested correction — Fix now:** Route Escape consistently to the visible combat picker, using the same cancel operation as its button. Verify with keyboard focus inside the list.

### PT-006 — P2 — Room object markers hide actors standing on their hex

**What happens / why it matters:** A character can occupy the offering chest's space, but its yellow square covers the character token. Tactical position becomes ambiguous during combat.

**Reproduction:**

1. Enter Ashvale guardian combat with a melee character.
2. Move onto the offering chest hex, immediately beside the guardian.
3. Observe the movement budget/Chronicle update and successful adjacent attack.
4. Inspect that hex: the square covers the actor portrait. Repeat with a companion party.

**Expected:** Actors remain distinguishable above passable objects. **Actual:** Object marker hides the token; left portrait and logs are needed to infer position.

**Frequency:** Observed in the Paladin pass and again with Aldric in the party pass.

**Evidence:** [Paladin on object](../../../playtest-evidence/17-lay-on-hands-heal.jpg), [party combat](../../../playtest-evidence/27-ray-of-frost-hit-slow.jpg). Nearby object-label overlap is also visible in [room layout](../../../playtest-evidence/13-local-room-layout.jpg).

**Suspected cause:** Rendering order/overlapping markers; no specific renderer fix was proven.

**Suggested correction — Fix now:** Draw actor tokens above object markers, or use an offset/combined marker for shared cells. Show full labels on selection/hover to reduce crowding.

## Gameplay and Usability Feedback

**Controls/responsiveness:** Hex clicking and turn advancement are understandable once discovered, and range/action refusals avoid wasting resources in the tested cases. Movement has visible animation; instantaneous snapshots sometimes preceded its completion. Wheel zoom and window sizing work. Sustained keyboard/right-or-middle-drag camera behavior remains unverified because the input workflow used brief key chords and left-button actions.

**Objectives/navigation:** The Crown goal is clear in campaign setup. At default width, the overworld objective truncates before its next-step text. Help explains portraits/camera/Chronicle but misses the basic click-to-move/attack loop. The authored-room Chronicle finally supplies movement instructions. Wizard spellbook/preparation and Druid known-form setup deserve an explicit onboarding step; an empty/unconfigured class can otherwise appear broken.

**Pacing:** The solo Paladin guardian fight took six rounds; melee misses and understated damage made it slow. A party and cantrips provided more tactical options. No broader balance conclusion is justified from these encounters. Skeleton/Wight ranged attacks, difficult terrain, resource limits, and healing were visibly consequential.

**Feedback/friction:** The Chronicle provides useful rolls, costs, and refusal reasons. Its preserved scroll position means new instructions may remain offscreen behind the New button. Magic Missile dart assignment was explained only there while the top banner said SELECT. Keep current action instructions visible outside the scrolling history. Fire/burning mostly changes log entries; object appearance gives little state feedback. Labels collide heavily at default room scale. Revisited town layout also shifted left under the portrait rail ([evidence](../../../playtest-evidence/30-town-offset-layout.jpg)); viewport-centered/clamped dialogs would help.

**Unfinished/uncertain features:** Runtime warns that 25 effectless feature records remain unavailable; dictionary/content counts are not evidence of gameplay support. Animate Objects remains documented unfinished, outside this tested slice. Wild Shape selection did not transform the new Druid; focused inspection shows the form picker returns empty if no known eligible forms, so successful form setup/transformation remains a coverage gap rather than a confirmed rules failure.

## Recommended Priorities

1. **Fix now:** Restore saved-campaign and post-defeat recovery. Retest on an existing preserved save and a fresh GUI save before relying on longer campaigns.
2. **Fix now:** Connect Divine Smite to eligible hits and restore normal weapon ability damage. These affect ordinary low-level play.
3. **Fix now:** Keep actors visible on object cells and make combat Escape match its advertised behavior.
4. **Fix when touched:** Lead players through spellbook/prepared-spell/known-form setup. Keep target/dart instructions visible, improve room labels, and center dialogs within the viewport.
5. **Next QA pass after fixes:** Resume a saved campaign through a Crown fragment and final boss; complete buy/sell/equip/consumable accounting, revival, Druid transformation, and broader class checks. Do not substitute inventory metadata or copied formulas for production gameplay.

## Evidence and Limits

Original screenshots are JPEGs saved directly from computer-use capture data in `playtest-evidence/`; none were fabricated or edited. `.gdignore` keeps them out of resource imports. The two UI-created saves were copied as evidence before later play. The final new campaign was not saved over them. The game was closed normally after testing and its window disappearance verified.

Playable-session logs: [Pass A](../../../playtest-evidence/pass-a-runtime.log), [Passes B/C](../../../playtest-evidence/godot-runtime.log). Both contain the known unsupported-feature warning and no matched `ERROR`/`SCRIPT ERROR`. Save diagnostics are supplementary only; sandbox slot enumeration is not relied on as the defect's cause. Absolute-file JSON decoding and the production validator output establish the numeric-type rejection.

The earlier startup repair's automated parse/boot/world/crown-smoke checks remain in `.artifacts/tests/7f118fa669e146f6828fbd20878175f8/`. They validate that repair, not the outcomes or untested mechanics in this GUI report. No additional gameplay automation was used for these passes.
