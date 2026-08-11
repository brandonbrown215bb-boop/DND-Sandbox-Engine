# Content pipeline

Gate 2 content is loaded from two runtime roots in this order:

1. `data/core/` contains imported source records and curated mechanics.
2. `data/mods/` contains future internal content packs and explicit overrides.

The loader sorts every directory listing and registers records by stable ID. A
duplicate is a load failure unless `data/content_manifest.json` names the
winner and every replaced record. The manifest is the authority for the
current imported/core collisions; a future mod override must add its own
entry rather than relying on filesystem order.

The manifest also declares internal pack metadata. `core` and `crown` each
have an identity, semantic version, dependency list, and ruleset compatibility
label; runtime layers reference those pack IDs. This is an engine boundary,
not a user-facing mod manager.

When a curated record wins an approved collision, fields missing from it are
filled from the replaced descriptive record. Existing curated fields such as
spell effects, action economy, targets, saves, concentration, and class access
are never overwritten by imported data.

The loader validates required record fields before registration. Active class
features with neither executable `effects` nor a named `resolver` are rejected
from the player-facing class record and reported as unavailable. They are not
treated as implemented because a description exists.

Semantic validation also checks supported spell casting times, targets, schools,
damage types, abilities, non-negative ranges/resource parameters, dice
expressions, and stable campaign/event/content references. Development builds
print a compact registry diagnostic with active layers, pack IDs, approved
override count, and validation-failure count.

`DataLoader.get_registry_hash()` provides a deterministic snapshot for repeated
load checks. `Character.initialize()` consumes the curated production spell
access table and initializes slots, so a caster's first usable spell is proven
through the normal creation path. The same loader boundary curates executable
effects for the representative Fighter, Rogue, Wizard, and Cleric cohort; the
remaining unsupported effectless records stay unavailable until their mechanics are
implemented.

The shared effect vocabulary now also supports timed AC/stat modifiers,
attack/save roll modifiers, and movement modifiers. Character queries apply
these modifiers to effective AC, attack/save rolls, and movement speed; the
same timed entries are serialized with the character and expire with turn
ticks. The first owner-labelled reaction prompt is now wired for monster
attacks, while triggered reaction ownership and the broader spell/item effect surface
remain open.

## Importer boundary

`src/convert_all_5etools.py` requires an explicit external 5eTools source
directory, accepts explicit raw and output roots, and defaults generated content
to `data/imported/`. The importer refuses an output or report path inside
`data/core/`, so a rerun cannot overwrite curated records. Directory discovery
is sorted before conversion.

Each run writes `import_report.json` beside the staged output unless `--report`
supplies another non-curated path. The report records source and exported
counts, skipped records, duplicate IDs within the source/import, and IDs that
collide with existing `data/core/` records. Staged output is review material;
promotion into curated content remains a deliberate manifest-backed change.
