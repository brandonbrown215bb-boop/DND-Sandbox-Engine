# Architecture decisions

Accepted ADRs explain durable decisions. [ADR-0018](0018-shared-data-driven-rules-runtime.md)
owns the shared data-driven runtime direction; it does not claim implementation.
Read [current architecture](../architecture/README.md) for existing owners,
[roadmap](../../roadmap.md) for priority and
[slice registry](../planning/vocabulary-slices.md) for verified boundaries. Old implementation restrictions do not override later decisions.

| ADR | Status and scope |
|---|---|
| [0000 — Windows validation host](0000-windows-validation-host.md) | Accepted; renumbered from duplicate 0001, policy retained |
| [0001 — Shared-keyboard local seats](0001-shared-keyboard-hot-seat.md) | Accepted |
| [0002 — Wolf-only Crown Wild Shape](0002-wild-shape-crown-band.md) | Withdrawn; unaccepted old rules proposal |
| [0003 — VTT shell and activity history](0003-player-vtt-shell-and-activity-history.md) | Accepted; grimoire refinement included |
| [0004 — Staged rules and save isolation](0004-staged-2024-rules-and-save-boundary.md) | Accepted; initial delivery order superseded by roadmap/0018 |
| [0005 — Fighter through level 20](0005-fighter-level-20-progression.md) | Accepted scope/current implementation; native policy transitional under 0018 |
| [0006 — Bounded class features](0006-composable-class-features.md) | Partially superseded by 0018; current executor and compatibility retained |
| [0007 — Campaign time and messages](0007-campaign-time-and-messenger-delivery.md) | Accepted clock/ledger; named policy transitional under 0018 |
| [0008 — Combat light markers](0008-combat-spell-light-markers.md) | Amended; modeled visibility now uses markers |
| [0009 — Source-owned spell effects](0009-source-owned-spell-conditions.md) | Amended by 0017; source/lifetime guarantees retained |
| [0010 — Spell area modules](0010-combat-spell-area-modules.md) | Accepted current organization; native policy transitional under 0018 |
| [0011 — Initial player cast split](0011-player-spell-cast-stages.md) | Superseded by 0012; ordering guarantees retained |
| [0012 — Spell resolution/lifecycle modules](0012-focused-spell-resolution-and-lifecycle.md) | Accepted current organization; extension policy superseded by 0017/0018 |
| [0013 — Local rooms and item copies](0013-local-rooms-and-item-copies.md) | Accepted identity/transaction boundary |
| [0014 — Owned creatures and projections](0014-owned-creature-lifecycle.md) | Accepted identity/lifetime boundary |
| [0015 — Party corpses and recovery](0015-party-corpses-and-recovery.md) | Accepted life-state/compatibility boundary |
| [0016 — Undead existence and control](0016-created-undead-existence-and-control.md) | Accepted identity/control boundary |
| [0017 — Shared JSON spells](0017-shared-json-spell-execution.md) | Accepted; handler exception superseded by 0018; mixed checks implemented in 0019 |
| [0018 — Shared data-driven rules runtime](0018-shared-data-driven-rules-runtime.md) | Accepted direction; implementation staged |
| [0019 — Shared ordered execution & zero-HP replacement](0019-shared-ordered-execution-and-zero-hp-replacement.md) | Accepted; Corrections A3, B1, B1R1, B1R2, B2A, and B2B verified |
| [0020 — Roll tokens and pre-roll replacement](0020-roll-tokens-and-pre-roll-replacement.md) | Accepted; Slice 2 shared `roll_token_pool` runtime, Diviner Portent/Greater Portent, and save preflight |
| [0021 — Damage interception and wards](0021-damage-interception-and-wards.md) | Accepted; Slice 3 shared `damage_ward_pool` / `damage_ward_projection`, 5-step damage order, Abjurer Arcane/Projected Ward, and save preflight |
| [0022 — Rest completion and slot recovery](0022-rest-completion-and-slot-recovery.md) | Accepted; Slice 4A/4B bounded Short/Long Rest completion, `rest_slot_recovery` window, Wizard Arcane Recovery, and single-owner execution |
| [0023 — Vocabulary-first delivery and bounded world judgment](0023-vocabulary-first-delivery-and-bounded-world-judgment.md) | Accepted direction; separate discovery/build/check/translation, stage-based resolution, current save priorities, observer-specific illusions and executable campaign Wish outcomes |
| [0024 - Explicit represented class-level formula inputs](0024-explicit-class-level-formula-inputs.md) | Accepted bounded implementation (VS-44, independent Batch F review) |
| [0025 — Source-owned rider occurrence locks](0025-source-owned-rider-occurrence-locks.md) | Accepted bounded implementation (VS-54/55/56); actual roll completion, durable active-grant option locks and bounded numeric payment waiver |

| [0026 - Derived source benefit carriers](0026-derived-source-benefit-carriers.md) | Accepted bounded direction and behavior (VS-59/60); exact existing carriers and derived AC/speed additions |

| [0027 - Captured source-pool dice](0027-captured-source-pool-dice.md) | Accepted bounded implementation (VS-61); on-acquire capture and new-dice-only progression |

| [0028 - Captured recipient grants](0028-captured-recipient-grants.md) | Accepted bounded direction and S-082 (VS-63); S-083 extension accepted in ADR-0029 (VS-64) |

| [0029 - Party roll contributions and allocations](0029-party-roll-contributions-and-allocations.md) | Accepted bounded implementation (VS-64/65/66/67); shared attack gift, fixed helper modifier and HP/Temporary HP allocations |

| [0030 - Ordered permanent acquisition receipts](0030-permanent-acquisition-receipts.md) | Accepted bounded direction; Batch 018 independently accepted as VS-68/69 |

| [0031 - Derived casting permissions and preparation receipts](0031-derived-casting-permissions-and-repertoire-receipts.md) | Accepted bounded implementation (Batch 021, VS-76–78) |

| [0032 - Recipient Temporary HP and aura entry receipts](0032-recipient-temporary-hp-and-aura-entry-receipts.md) | Accepted bounded direction and implementation (VS-84/85/86) |

| [0033 - Parent action child continuations](0033-parent-action-child-continuations.md) | Encounter-local paid parents, local child action waivers and source-owned continuation |

| [0034 - Source-owned zero-HP attempts](0034-source-owned-zero-hp-attempts.md) | Accepted bounded direction and implementation (VS-111/112); exact source history and completed-rest resets |

New ADRs must state the decision, reason, compatibility constraints, acceptance
boundary and affected earlier decisions. Keep implementation diaries and latest
assertion counts out of ADRs. Superseded means a decision no longer governs its
stated scope; it does not erase still-relevant invariants or authorize save changes.
