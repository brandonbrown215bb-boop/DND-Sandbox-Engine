# ADR-0030: Ordered permanent acquisition receipts

Date: 2026-10-17
Status: Accepted bounded direction; Batch 018 independently accepted as VS-68/69

## Decision and reason

Opt-in classes declare distinct starting/multiclass grants and permanent gains
at class or character-level thresholds. Character retains ordered class history,
pending milestone levels and source-specific acquisition receipts. Granting and
restoring have separate paths: acquisition applies deltas once, while restoration
reads saved totals and checks receipts without executing them. This supplies
permanent source ownership without inferring equipment ownership from whether
the actor still carries a granted item.

Existing milestone delivery awards an unspent level to these actors. The shared
Class Progression panel chooses its class and consumes the entitlement with
stale-answer and whole-grant inventory checks. Reuse ClassProgression's permanent
score/CON handling and the existing exact inventory copies. Fixed authored base
level HP avoids introducing another roll/choice workflow in this bounded host.

## Compatibility and boundary

Classes without the opt-in contract keep their existing native behavior. This
extends ADR-0024's represented allocations with an authored update route only for
these classes; its native multiclass/spell limitations still apply elsewhere.
Primary passive weapon/armor/skill proficiency choices reuse existing
acquisition/replacement; other choice fields refuse validation.
Secondary native features and casting remain unsupported. No catalog conversion,
temporary/reversible stat ledger, save migration or new save permission is added.

Validate ordered history, class totals and exact authored receipts on both DTO
paths before session replacement. Restore pending levels, equipment identities
and already-applied totals without replay. Existing legacy/save namespace and
allowed-checkpoint guarantees remain under ADR-0004, ADR-0018 and ADR-0023.

Independent acceptance requires neutral/renamed loaded consumers, real creation,
milestone and level-choice controls, once-only class/character deltas, atomic
refusal, separate-process recovery and malformed full-save refusal. The current
checkpoint and batch evidence own test results; this ADR does not accept slices.
