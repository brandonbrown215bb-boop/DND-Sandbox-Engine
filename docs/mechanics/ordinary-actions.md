# Ordinary combat actions

The combat **Actions** button offers Ready, Dash, Disengage, Dodge, Hide, Help a
skill/tool check, Help an attack, Help to stabilize, and Search for hidden
creatures, plus Utilize for represented room objects. The existing Dodge button uses the same owner. `ordinary_action`
commands carry an action name and, for check Help, the selected proficiency;
`CombatState` assigns the Action cost. A caller cannot supply a cheaper cost.
Selecting a target costs nothing until a legal click; cancellation, a lost
Action, an unknown location, a dead target or an out-of-range click grants
nothing. Incapacitated actors cannot use these actions.

These rules follow the [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
pp. 18, 179, 181–183 and 186–187. The
[slice registry](../planning/vocabulary-slices.md#ordinary-action-continuation)
owns verification and remaining S-237 scope.

## Effects and feature reuse

- Dash adds current effective Speed to this turn's remaining movement. It does
  not refill spent movement or replace terrain/path costs. Repeated legal Dash
  actions can each add Speed, with their own Action or Bonus Action costs.
- Disengage uses the movement owner's existing Opportunity Attack exclusion
  for the remainder of this turn.
- Dodge lasts through the current turn and ends at the next owner turn's start,
  before start-of-turn effects. Attacks have Disadvantage only when the defender
  can see the attacker. The central Character and monster save owners grant
  Dexterity-save Advantage. Incapacitation or effective Speed 0 removes Dodge;
  curing the disabling condition or expiring its speed modifier does not restore
  it. Using all remaining movement does not reduce Speed to 0.
- Help an attack distracts an exact known enemy within 5 feet, with an unblocked
  ray. The next actual allied weapon/spell attack consumes the benefit once;
  the helper cannot consume its own Help. The unused benefit ends at the helper's
  next turn start. This reuses the familiar Help carrier; multiple helpers do
  not bank several advantaged attacks on the same enemy.
- Help to stabilize selects a dying, unstable adjacent ally and resolves an
  actual DC 10 Wisdom (Medicine) check. Success calls the existing stable-state
  owner; it does not heal or wake the ally.
- Help a skill/tool check selects one of the helper's actual proficiencies and
  an adjacent ally with an unblocked ray. Half proficiency does not qualify.
  `CheckHelpRules` grants Advantage on that ally's next matching actual
  `EventResolver` check before the helper's next turn starts. Tool matching uses
  the check's `tool_id` (or `check_context.required_tool_id`) and the loaded tool
  name/ID. An unrelated check preserves assistance; multiple matching helpers
  are consumed by the same check, without banking later rolls. The live check
  context must contain the grid and both participants; assistance requires
  the same proximity, an able helper and its still-owned proficiency then.
  Existing conditions compose with this Advantage. Teardown clears unused Help.
  This host represents physical assistance; verbal assistance and world checks
  without this live spatial context remain unsupported.

Check Help's command is:

```json
{"action":"help_check", "proficiency_kind":"skill", "proficiency":"Athletics"}
```

Use `proficiency_kind: "tool"` with the owned tool proficiency name for tools.
The HUD offers owned choices and the command boundary revalidates ownership.

Native Rogue and Monk movement/defense features call the same effects after
their declared cost/resource settlement. A loaded, renamed `cunning_action`
feature with `options: ["dash", "disengage", "hide"]` also gets the existing
movement picker; no feature-ID registration is needed. Its resource declaration
still supplies its available uses and cadence. The picker refuses a response
after the owning turn changes.

## Ready and held spells

`ReadyActionRules` owns encounter-local declarations, completed triggers and
Reaction delivery. The Actions chooser selects a trigger, its creature/side,
optional space/proximity, and response. The equivalent `ready_action` command
uses this shape:

```json
{
  "trigger":{"event":"movement", "side":"enemy", "within_hexes":1},
  "response":{"kind":"attack"}
}
```

Triggers support `movement`, `attack`, `cast`, `action` and `sound`; `side` is
`enemy`, `ally` or `any`. Optional `actor_id` identifies an exact creature,
`within_hexes` bounds distance from the Ready owner and `at_hex: [q, r]` selects
a board space. Movement publishes after each completed step, including forced
movement and teleport arrival. Attack and cast publish after their current
resolution. Completed-action producers also cover paid player consumables,
Shield controls, feature effects and targeted features, mode/item projection
controls, created-creature orders, paid child-parent completion (including
forfeiture), marker movement, tether/zone escape, rescue and shaking Sleep awake.
They publish after the operation's choices and effects settle; opening a picker,
an unpaid refusal or cancellation does not publish a completed action. A paid
failed check still does. Ordinary actions and monster turns retain their events.
Sound currently comes from Verbal casting and needs a clear ray
and a non-Deafened observer; broader noise and hearing through walls are open.
Visual triggers require the owner's actual sight. A componentless enemy cast
cannot trigger the cast response. A creature perceives its own movement/action
without needing to see itself.

Responses are `attack`, `move`, `ordinary` with `action`, or `spell` with the
normal permissioned `spell` payment selection (including slot-free cantrips).
Ordinary responses use the
supported actions above, excluding Ready itself; check Help also captures its
chosen proficiency. Ready pays the owner's Action now and expires before the
next owner turn starts. A perceivable completed trigger opens the owner's
Reaction prompt. Ignoring it or cancelling targeting preserves the held response
and Reaction. Acceptance revalidates the owner, exact targets, range, path and
resources after choices, then pays that owner's Reaction once. Attack releases
one strike with the captured exact weapon; Extra Attack does not apply. Movement
uses current Speed and the selected movement mode, ordinary terrain/fear/fall/
Opportunity Attack rules, and its own allowance. Neither response refills or
borrows the interrupted actor's Action, Bonus Action or movement.

`ReadySpellRules` casts an available Action-time spell immediately. It settles
the casting Action, slot/use, Metamagic, consumed component copy, Counterspell
and cast activity at that point. A restricted extra Action cannot supply the
spell's casting. Holding any spell requires temporary Concentration, replacing
the previous concentration. Losing it dissipates the spell without a refund.
The release uses the existing spell owners with fresh live targeting, including
point/object/area targets and multiple projectiles/recipients. Its private paid
context permits release after the last slot/component was spent. Cancelled
attempts cannot clear the retained paid spell; release does not repeat payment,
Counterspell, cast activity or cast-time Invisibility/Sanctuary cleanup. A
Concentration spell starts its normal effect concentration when released.

Readied Disengage ends with the triggering turn. Readied Dash adds movement
for that turn but grants no independent permission to move off turn; choose
Ready movement for that. All held responses, transient grants and chooser
state clear at encounter teardown. Nothing here is serialized or creates a
new save checkpoint.

## Utilize room objects

`{"action":"utilize"}` uses the ordinary Action command and highlights visible,
reachable objects in the encounter's captured local room. Clicking an object
offers its existing physical interactions: open/close, lock/unlock with a key,
pick a lock, pry/force open, bar/unbar, jam/unjam, extinguish and take/put an exact
item. Spell casting, weapon strikes and inspection use their existing owners;
they are not offered as Utilize interactions.

`CombatUtilizeRules` delivers those choices to `LocalRoomRules.interact`.
Opening a door updates actual movement/sight geometry; contents and inventory
change by exact instance identity. The actor's live combat position supplies
the room interaction origin. Skill/tool attempts receive the live encounter
check context, so matching adjacent Help is consumed by the real check.

The room, exact object, selected cell, actor/turn, sight, plane, horizontal and
vertical reach, available Action and selected item are checked again after
choices. Cancel, lost budgets, moved/replaced/removed objects and invalid tool
or inventory requests spend nothing. A legal attempt consumes one Action even
when its roll fails. Resolution and payment are synchronous after the last
guard. There is no campaign-time advance or new save checkpoint; changed room
objects use existing room persistence.

Ready can hold this ordinary response too. It selects an object and operation
at release, uses the same live guards, and pays only the Ready owner's Reaction
for an actual attempt. Objects sharing a creature's cell retain their own
identity. Cancelled or refused releases preserve both Ready and Reaction.
Encounters without a captured room have no object Utilize targets. Other tool
tasks and item-specific deployment effects still need their represented owners.

## Represented sound

An object can declare sound for an existing physical operation:

```json
"interaction_noise": {
  "force_open": {"volume": "loud", "range_feet": 60},
  "pry": {"volume": "loud", "range_feet": 60}
}
```

The operation must actually resolve through Utilize and pay its Action or
readied Reaction. A failed rolled attempt still produces its declared sound;
cancelled/stale choices, missing tools and other refusals do not. Invalid sound
declarations refuse before rolling, changing the object or paying. Volume is
`loud` (above a whisper) or `whisper`; range is an integral 1–5280 feet.
Only declared operations produce sound. Crown's Temple door and Offering chest
declare loud forcing/prying; existing saved room records are not rewritten.

`CombatNoiseRules` ends Hide on a loud sound even with no Ready declarations,
preserving independent Invisibility sources. Whisper sound retains Hide.
The existing **After a loud sound** Ready trigger accepts only loud sound.
Verbal casts publish a loud sound using the existing 60-foot encounter hearing
boundary. These ranges are represented encounter policy, not an SRD universal
hearing table. The SRD Hide ending is immediate after sound above a whisper
([SRD 5.2.1, p. 183](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=183)).

Hearing uses an inclusive authored range and a represented ray on the same
plane. Deafened listeners and silenced endpoints cannot hear it; Blinded,
fog, darkness and independent Invisibility do not prevent hearing. Room walls
(including glass) and closed doors block sound; opening/destroying them updates
the actual grid. Outside a bound room, `blocks_sound` controls a tile, falling
back to `blocks_sight` when absent. Hearing is captured per observer when sound
occurs: an earlier readied response cannot open a door to hear an old sound or
erase sound already heard by closing it. Response legality and Reaction costs
are still checked live. Sound and its listener receipts are encounter-local.

This is a flat-ray host. Sound around corners, attenuation, three-dimensional
hearing, arbitrary prose noise and other action/item/spell noise producers remain
unimplemented. A sound declaration does not implement a missing tool task or
deployment effect.

## Hide and creature discovery

Hide checks the live board before charging or rolling: a represented heavily
obscured space (darkness or fog) or existing sight-blocking Total Cover, and no
enemy that can see the actor. Enemy special senses still matter. Existing Hide's
own Invisible benefit cannot satisfy the legality gate for a new Hide attempt.
Three-Quarters Cover awaits the actual S-238 cover owner.

A DC 15 Dexterity (Stealth) check uses the shared check owner, including
proficiency, Expertise, conditions and Exhaustion. Success supplies a
source-owned Hidden marker with Invisible benefits and an encounter-only
discovery DC equal to the check total. It survives turn-end. An attack roll,
a committed Verbal spell (including an interrupted cast), or successful creature
discovery removes Hide. A non-Verbal spell that makes no attack roll retains it.
Independent spell/condition Invisibility is preserved when Hide ends. Faerie
Fire and Starry Wisp still suppress its Invisible benefits.

The creature Search action makes one Wisdom (Perception) hearing check against
the captured Hide totals. It uses the same represented sound rays within 60 feet;
Deafened automatically fails. Success ends the target's Hide and records the
discovered location. It does not pretend to see through fog or independent
Invisibility. Legacy arbitrary Hidden markers without a captured check total
are not assigned an invented discovery DC.

Ordinary Hide, Dodge, Disengage and captured Hide totals clear when the encounter
ends or its scene is torn down. They introduce no durable save state or new save
checkpoint. General sound propagation, hearing through walls, room/overworld
Hide, broader Search and the remaining ordinary actions are still separate work.

## Room Search and object discovery

The room **Search** button chooses one represented room space within 60 feet.
Click Search again to cancel. Switching characters cancels the choice; switching
between Search and an unpaid teleport, water, anchor or creature-placement
choice leaves only the newly requested operation active. Search adds no new save
checkpoint. It is a visual Wisdom (Perception) Search, following the concealed
object entry in [SRD 5.2.1, p. 187](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf#page=187).

A room object can declare:

```json
"discovery": {"dc": 15, "range_feet": 5}
```

Both fields are required: DC is an integral 1–1000 and vicinity is an integral
1–60 feet. The command's 60-foot selection limit and six-second exploration
Action are this room host's represented policy, not universal SRD search ranges
or investigation durations. Ordinary objects without `discovery` retain their
existing known status; old room/save records need no migration.

One live shared Perception check searches only the selected space. Success
discovers eligible objects whose authored vicinity includes the searcher, on
the same plane and outside containment. A failed roll or empty-space search
still advances the campaign clock by six seconds. Cancelled, stale, incapacitated,
out-of-map/out-of-range or unavailable-sight choices roll nothing and spend no
time. Dim light gives sight Perception Disadvantage; Darkvision treats dim light
as bright and darkness as dim. Actual Blindsight/borrowed familiar sight can
supply sight while the searcher's eyes are Blinded. The shared check rechecks
the actual spatial sight host instead of accepting a caller's success flag.
Ambient/carried light and active room fog/Darkness sources feed those queries.

Discovery appends the searcher's exact identity to that object's `discovered_by`
array, once. Another character must discover it independently. The object
becomes available through the existing object, spell, containment and remains
controls and their live identity guards; discovery itself grants no item or
spell effect. Taking a discovered cache uses the ordinary exact-copy transfer.
Unknown objects remain in physical/area queries and collision. Their marker,
name and direct-target offers are hidden from an observer who has not discovered
them, including encounter views. Untargeted area effects retain the real object.

Existing allowed checkpoints preserve those per-object observer receipts and
exact contents through both full-party and player-only recovery. Malformed,
duplicate or orphaned discovery records refuse before load. This does not
serialize a pending Search or add mid-room/mid-combat saving.

**Limits:** represented flat room spaces and visual concealed-object Search.
Hearing Search, passive discovery, sharing discoveries, overworld Search,
Insight/Medicine/Survival tasks, trap triggers/disarming, arbitrary knowledge,
full three-dimensional sensing and catalog conversion remain separate. The
[S-237 registry boundary](../planning/vocabulary-slices.md#ordinary-action-continuation)
owns verification and the remaining world Help, Study and Influence work.
