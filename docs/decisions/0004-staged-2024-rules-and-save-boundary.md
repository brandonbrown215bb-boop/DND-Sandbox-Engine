# ADR-0004: Stage the 2024 core classes and preserve legacy saves

Date: 2026-10-03
Status: Accepted; original rollout order superseded by the current roadmap

> [ADR-0018](0018-shared-data-driven-rules-runtime.md) governs the target rules
> runtime. Monk-first delivery and narrow native resource methods below
> describe the initial rollout, not the continuing architecture or priority.
> The save/rules isolation and evidence boundaries remain binding.
> [ADR-0023](0023-vocabulary-first-delivery-and-bounded-world-judgment.md)
> records the owner's statement that no player campaigns currently need
> preservation. Migration/compatibility planning is not a delivery gate;
> save isolation and non-destructive file handling remain.

The owner chose broader level 1-5 mechanics, the 2024 rules, Monk first,
and project-local workflow simplification. SRD 5.2.1 is the default rules
authority: https://www.dndbeyond.com/srd.

## Decision

- Build the 12 core classes in small production-path slices. Artificer and
  Mystic remain stored as reference content but are not new-character choices.
- Separate legacy features from 2024 support; hide unsupported mechanics and
  state remaining creation, subclass, feat, and progression gaps explicitly.
- Keep existing command, character, resolver, HUD, and save boundaries. Add
  narrow resource methods rather than a new rules service or plugin.
- New campaigns save to `user://saves/dnd2024/`, using schema 2 and
  `ruleset_id: dnd-2024-srd-5.2.1`. Old `user://saves/` files are untouched,
  reported as incompatible, and never automatically migrated or overwritten.
- The ruleset ID identifies the intended rules source, not complete support.
  Existing partial mechanics must not be advertised as a complete 2024 game.
- Focus is shared across Monk abilities, begins at level 2, has a maximum equal
  to Monk level, and recovers on short/long rests. Remaining Focus persists.

The proposed Wolf-only ADR-0002 does not authorize a 2024 Wild Shape
implementation. It is now withdrawn; use source-verified 2024 semantics for future form work.

## Delivery and Evidence

Use one owner and optional focused independent review. Source and executable
Godot checks establish gameplay behavior; inventory and structural Python
checks do not. A large combat refactor, old audit repair, publishing,
controllers, and UI shell completion do not block this mechanics milestone.

This work includes material from the System Reference Document 5.2.1
("SRD 5.2.1") by Wizards of the Coast LLC, available at
https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative
Commons Attribution 4.0 International License, available at
https://creativecommons.org/licenses/by/4.0/legalcode.
