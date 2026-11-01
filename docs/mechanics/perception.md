# Observer senses and concealment

`CombatPerception` owns combat sight and known creature locations. Target
selection, weapon/shared spell/projectile rolls, AI, Opportunity Attacks and
represented sensory requirements use the actual observer and live positions.
The [slice registry](../planning/vocabulary-slices.md#observer-senses-and-concealment)
owns the verified S-190/S-191 boundary.

Rules authority is [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf):
Vision and Light (p.11), Unseen Attackers and Targets (p.14), Devil's Sight
(p.72), Darkness (p.122), Blinded/Blindsight (p.177), Darkvision (p.179),
Hide (p.182), Invisible (p.184), Tremorsense/Truesight (p.190).
This does not implement the ordinary Hide/Search action procedure.

## Sight and obstruction

`can_see_target(observer, target, observer_position, target_position, grid)`
checks the existing hex LOS raster, the target's ambient/portable illumination,
the observer's actual sense ranges, Blinded, Invisible/Hidden and source-owned
obscuration. Distances use the existing five-foot hex model. Dim Light permits
sight; perception-check modifiers are a separate host.

Darkvision sees ordinary darkness within range. It does not pierce magical
Darkness. Blindsight works while Blinded and perceives Invisible creatures,
fog and darkness within range, while respecting wall LOS. Truesight pierces
ordinary/magical darkness and Invisible within range; it does not overcome
Blinded or fog. Native Darkvision, See Invisibility and True Seeing spell
sources remain in use and lose their benefits when their sources end.
The existing familiar-senses path remains intact; this is not a new remote
sensor control or origin implementation.

Ambient light and portable light radii still come from their existing owners.
The same wall LOS now prevents portable illumination passing through a wall.
Magical Darkness is queried separately from ordinary illumination, so placing
a mundane light in a magical Darkness area does not supply sight through it.

`HexGrid.obscurement_sources` records exact area sources with `kind`, `coords`
and `caster_id`. `CombatSpellZones` publishes the existing native Fog Cloud and
Darkness areas into it. Other represented area records may declare
`obscurement_kind: "fog"` or `"magical_darkness"`; no definition-ID registration
is needed. Intervening cells count even when both endpoints are outside an area.
Removing an area clears only its own entry/condition grants. Overlapping
obstruction and unrelated unsourced native conditions remain effective.
Light/Darkness cancellation thresholds and broader area-kind lifecycle work
remain S-274/S-276.

## Authored senses and darkness exceptions

Passive class features can declare `darkvision`, `blindsight`, `truesight` or
`tremorsense` effects with positive integer `range_feet` (up to 5280).
Selected feature-choice/invocation effects use the same live query. Native
Character creature/monster sense fields and monster `senses` remain supported.
Removing a selected feature removes its sense immediately; no stored sight
bonus survives the owning feature.

```json
{"type": "darkvision", "range_feet": 120, "magical": true}
```

`magical: true` extends that Darkvision to magical Darkness. It does not grant
Blindsight, invisible sight or immunity to Blinded. Devil's Sight now uses this
declaration. A darkness exception can additionally declare either or both:

- `obscurement_source_id`: only this exact area source is ignored.
- `own_source_only: true`: only areas whose `caster_id` is the observer qualify.

Every intersecting source must independently be pierced. An exception to one
source cannot erase another observer's obstruction or bypass an unrelated
overlapping source. Source-specific fields require magical Darkvision.

Tremorsense supplies location, never sight or cancellation of unseen attack
modifiers. Both actors must contact the same represented surface/liquid within
range. Tile `contact_surface_id` defaults to `ground`; distinct IDs separate
surfaces/liquids. Live player-participant and monster `altitude_feet` above the
tile's `elevation_feet` means no surface contact. Arbitrary walls/ceilings,
unrepresented contact and three-dimensional sense geometry are not inferred.

## Location is separate from sight

`can_locate_target` and `can_see_target` answer different questions. Ordinary
encounter occupants have known locations until Hidden, including Invisible
creatures. This is the combat roster's existing known-location convention,
not a sound-propagation or hearing simulation. A known unseen location permits
an ordinary attack or non-sight creature spell; it does not permit a spell or
reaction that requires sight. Physical targeting still checks obstruction.

Hidden creatures require observer-specific discovery, live special sight or
eligible Tremorsense. Successful detection by `can_locate_target` records a
receipt only for that observer. `reveal_location` is also available to trusted
disclosure hosts; it does not remove Hidden or grant sight. Losing a sense
removes sight but preserves a learned location until the target moves or hides
again. Receipts capture position and a transient concealment generation;
production movement events/new Hide invalidate old receipts, including movement
away and back. They are encounter-local and are not checkpoint/save data.

Attack target highlights/clicks, paused attack-choice validation, AI commands
and spell creature selection recheck the actual observer. The shared board uses
the active player observer and retains that observer during monster turns;
another player's discovery does not reveal a Hidden monster's token to them.
This does not claim that every initiative/log/detail surface hides all identity
metadata.

Attack visibility is evaluated in both directions. Attacking an unseen target
imposes Disadvantage; being unseen by the target grants Advantage. The ordinary
cancellation rule applies. Weapon and spell attacks reveal a Hidden attacker
after capturing the first roll; later projectiles re-evaluate sight.
Special sight can therefore make the result differ
for two observers against the same target. Spatial callers pass live grid and
positions through `spell_visibility`/`weapon_visibility`; monster projections
retain the actual monster as `observer`. Native direct calls without spatial
context retain bounded endpoint-condition/sense behavior, not guessed geometry.

Area/point selection evaluates the selected space independently of an unseen
occupant. An Invisible/Hidden creature in a legal area still receives its effects;
the area's point-sight requirement is not reapplied as creature sight.

`has_required_sense` recognizes `see`, `darkvision`, `blindsight`, `truesight`
and `tremorsense`. Unknown senses remain unavailable. Failed-save sensory
requirements measure from the recipient to the actual caster participant
(including a monster projection's live source),
not the effect/delivery origin, and revalidate when a paused source commits.

Cover, free-form illusion investigation, new remote-sensor controls, ordinary
Hide/Search and guessed-square targeting controls remain separate work. Native
consumers retain their existing ownership and spell lifetimes.
