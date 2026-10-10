# ADR-0013: Durable local rooms and individual item copies

> Migration scope (2026-10-09): [ADR-0018](0018-shared-data-driven-rules-runtime.md)
> governs new rule execution. Named modules below describe current owners,
> not permanent native handlers for content policy. Identity, ordering,
> cost and compatibility guarantees remain constraints. Dated implementation
> and validation statements describe this ADR's original snapshot.

Status: Accepted, 2026-10-06

Spell targets need concrete objects, and two copies of one catalog item can
have different charges, attunement, damage or enchantments. Regenerating a
dungeon on every visit would erase those changes and repeat rewards.

Keep the room-to-room dungeon map. An authored room stores five-foot hex
cells, walls, exits, individually positioned characters and ordinary objects.
Exploration and combat bind the same geometry and stable object identities.
Combat captures character positions before returning. The existing campaign
ledger stores every visited dungeon snapshot, including generated Room DTOs
and plain local state. Leaving a dungeon retains its snapshot; entering uses
the snapshot before considering generation.

Inventory keeps its catalog-ID `backpack` and `equipped` projections so current
weapon/armor queries continue to work. `InventoryCopies` stores stable copy
IDs, definitions and per-copy state. Copy-based operations are transactional:
validate the destination before removing a source. Ordinary buy creates a
copy; sell/consume removes the selected copy. Copy allocation does not consume
the gameplay dice stream.

Schema-2 saves without copy data reconstruct one instance for each saved
occurrence. They do not call starting-equipment grants, merge duplicates or
change gold. Schema-2 saves with copy data validate projections, identity,
ownership and world records before mutating the session. Party character DTOs
are authoritative; repeated player-seat DTOs and the active dungeon's repeated
ledger snapshot represent the same owners, not additional item grants.

Save only plain data. Scene nodes, grids and cast contexts stay live-only.
Legacy rules/save namespaces remain untouched. Checkpoint saving is allowed
at the dungeon entrance or existing safe overworld states; local exploration
and combat remain unsaveable. Durable changes enter the next permitted save.

The initial foundation established ordinary objects and storage. Magic locks,
object damage, lighting, attunement and time ownership were separate follow-ups;
some now have bounded implementations in the
[foundation contracts](../mechanics/spell-foundations.md). Read their current
limits before declaring a capability absent or complete. No universal world
engine or combat extraction is required by this room/storage decision.

Acceptance uses Godot production inventory/object rules and the
`local_room_object_flow` scene scenario for key, door, chest, encounter return,
checkpoint disk save and revisit. Structural inventory/dependency checks do
not certify spell clauses. The configured independent-review contracts were
unavailable during this implementation; review and checks were performed solo.

## Wave 3 extension — 2026-10-08

Continue using the same room/object ledger. A `barrier` object's HP is the
authority for whether its authored wall cell remains solid; do not delete the
authored geometry on destruction. Material and height determine sight while
damage defenses and thresholds remain authored object rules. Legacy rooms
without barrier objects retain their existing walls.

Durable areas carry caster/source identity and campaign-clock expiry.
Concentration areas also retain a serializable character effect marker, so
encounter return and checkpoint reload preserve their owner. Cleanup visits
already saved active/unloaded room states; it never generates another dungeon.
Surface heat is authored separately from surface traversal and includes a
bounded vertical reach. There is no general physics or environment service.
