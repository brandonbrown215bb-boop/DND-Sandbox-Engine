# Wave 3 review and completion

> Historical snapshot, not current priority or acceptance. See the
> [documentation map](../README.md) for current authority. Findings, counts,
> gate decisions and execution orders below apply to the dated snapshot;
> reproduce relevant behavior before reopening a defect or reusing a claim.

Reviewed and corrected on 2026-10-08 against Luna's working tree, using Windows
Godot 4.7.stable.official.5b4e0cb0f. Unrelated changes were preserved. The
configured team contracts were unavailable, so this review was performed solo.

Wave 3's **supported first versions** are delivered. This accepts W3-F1 through
W3-F3 at the boundary in the foundation roadmap; it does not certify every
spell clause or every environment. Named spell follow-ups remain partial.

## Findings — Fix now, resolved

1. **Wall of Fire could not use its real endpoint picker.** The production
   record lacked the line selection effect, while the old logic fixture supplied
   that effect itself. Ordinary casts could fail to create the zone. The record
   now declares two endpoints, both are range-checked, and the live test uses
   that record. Ongoing damage also incorrectly allowed another Dexterity save,
   damaged creatures entering the hot-side strip, and shared entry/end-turn
   suppression. Only appearance damage now permits a save; entry into the wall
   and ending a turn in its danger footprint have separate full-damage triggers.
   The deferred live test's endpoint Array now has the correct Godot type.
2. **Transferred concentration areas could lose their saved owner.** Older
   encounter handlers had no serializable effect marker. All ten supported
   transfer spells now keep ownership through character/room reload. Ending
   Concentration removes only that source from active and unloaded saved rooms;
   campaign time expires unloaded records as well. This prevents orphaned
   hazards or areas disappearing unexpectedly at a checkpoint.
3. **Flight could enter below raised ground; pushes skipped intermediate
   hazards.** Fly and Levitate now check floor and ceiling at each destination.
   Weapon pushes, Brutal Strike, Repelling Blast and spell pushes share the
   actual traversed cells, occupancy/wall checks, Antilife Shell crossing,
   falling and area damage. A push through the wall and two Spike Growth cells
   now causes all three intended damage events, rather than just relocating
   the creature.
4. **The test setup obscured gameplay evidence.** Logs and disposable Windows
   save profiles now default to the writable project `.artifacts/tests/` tree.
   Requested scenarios can run as one batch with one bootstrap/parse/boot gate.
   No gate or safe-save rule was disabled. Sleet Storm and the lifetime fixture
   now own component pouches; extinguishing uses a reachable actor. Stale
   Warlock/lifetime expectations no longer treat an unavailable spell as
   castable or Invisibility as unavailable. They verify refusal without spending
   resources, supported Arcanum choices, and persistence of the pending choice.
5. **Bless's priced component could never match an owned item.** Its record
   required a five-GP Holy Symbol but omitted the catalog identity used by the
   priced-component check. A pouch could not substitute, and even owning the
   correct symbol failed. The record now names `holy_symbol`; the lifetime
   scenario owns that copy and verifies the real multi-target cast and costs.

## Foundation work completed

- Ashvale has ordinary timber and masonry barrier objects. Their material,
  Armor Class, health, height, damage defenses and threshold are plain saved
  data. Inspect, Fire Bolt and Strike barrier expose normal player paths;
  nonflammable stone rejects Fire, insufficient hits do not damage the masonry,
  and destroyed timber opens passage and sight through checkpoint reload.
  Glass can remain solid while allowing sight.
- An authored lava fissure has separate heat damage and vertical reach. Water
  Walk grants surface traversal while heat still damages the walker. Entering
  hot cells and ending a turn there resolve Fire damage in room exploration and
  combat, respecting defenses and altitude. The author's `1d4` and five-foot
  reach are encounter choices, not a universal SRD lava damage formula.
  A knockout stops room movement in the damaging cell and charges only the
  traversed route; falls also resolve at their actual step.
- The established environment, nourishment, exhaustion, movement modes,
  altitude, ceiling, teleport and mount paths remain covered by the room checks.

## Verification

Bootstrap, the 155-script parse gate and production boot passed. The accepted
complete logic run passed **2,330 checks, zero failures**, with the final room
and foundation scenarios in `.artifacts/wave3-review/acceptance.log`.
Ten affected live
scenarios passed in `.artifacts/wave3-review/final.log`: the new foundation
scenario, room object loop, Wall of Fire, Sleet Storm, Black Tentacles, Moonbeam,
Freedom of Movement, Antilife Shell, Barbarian actions and area object ignition.
Spike Growth passed in `legacy-fixtures-accepted.log`; the final corrected
lifetime scenario and 585 spell logic checks passed in
`bless-lifetime-accepted.log`. These accepted runs cover twelve live scenarios
in total, all without unexpected engine/script errors. The runtime inventory,
spell register and feature matrix were regenerated without promoting full
rules completeness.

The initial broad run exposed three obsolete Warlock assertions, a Spike
Growth component fixture failure and ten lifetime failures. Missing equipment,
an obsolete disabled-spell expectation and the real Bless component defect
caused those lifetime failures; those results remain in the logs. They are not
reported as successful runs. Expected rejection warnings test malformed saves
and unavailable content; the runner still rejects unexpected engine errors.

The foundation scenario includes an actual permitted entrance disk save/load,
not only a JSON round-trip. Area ownership checks cover all ten supported zone
types through character and room JSON. Generated logs and runtime exports remain
ignored artifacts. Manual visual acceptance and a complete SRD clause audit
were not performed.

## Remaining work

See the roadmap's explicit Wave 3 deferrals: other zone transfers, indefinite
Black Tentacles, Antilife Shell room transfer, exact spell volumes/obscuration,
Wall of Fire's ring and chosen side, NPC Alarm delivery and other spell modes.
These are named integrations rather than prerequisites for the delivered
first versions. The next foundation card is W4-F1, owned creatures.

Rules reference: [SRD 5.2.1, Wall of Fire, Water Walk and Objects](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf).
