# Temporary HP decisions and aura entry protections

Independent [Batch 027 review](../../.artifacts/planning/vocabulary-reports/batch-027-review.md)
accepts S-078/S-079/S-081 as VS-84/85/86 within the limits below.
These contracts extend Character combat features. They do not convert existing
spell, captured-gift or allocation Temporary HP consumers to recipient prompts.

## Temporary HP grants

An active `class_feature` uses its exact numeric `resource_pool`, an `action`,
`bonus_action` or `free` action cost, empty `effects`, and this property:

```json
"temporary_hp_grant": {
  "amount": 8,
  "duration_seconds": 60,
  "beneficiary": "recipient",
  "benefits": { "ac_bonus": 2, "save_bonus": 1 }
}
```

The feature menu asks for one willing living party Character, including self.
When that recipient already has Temporary HP, the popup displays the actual
current amount and offers Keep or Replace, including replacement with fewer HP.
Keep and Cancel spend nothing and preserve the original supplier, remaining
amount and deadline. Replace spends one exact pool quantity and the supplier's
action once. No existing Temporary HP is consumed as payment.

The recipient retains one grant with exact supplier, recipient, source, serial,
original payload and campaign deadline. Partial damage preserves that grant;
depletion, replacement, source-pool removal and expiry end its linked benefit.
`beneficiary` may be `recipient` or `supplier`. Linked bonuses use the strongest
qualifying Temporary HP grant per beneficiary, rather than stacking gifts from
several recipients. AC and saving-throw bonuses are each integers from 0 to 10.
Amounts are 1–100000; duration is 1–86400 campaign seconds. Other benefit types,
rolled amounts, several recipients and monster recipients are unsupported.

The pending offer retains the recipient's HP/source snapshot, supplier's exact
pool object/quantity, feature definition, turn and clock. Changed answers refuse
before payment; replay cannot create a second grant. The host requires the
supplier to remain the active Character on the same combat turn and budget.
The supplier directs the recipient popup in the shared-keyboard host; this is
not a separate network player prompt.

## Chosen aura protections

A passive feature declares one `protection_aura` effect:

```json
{
  "type": "protection_aura",
  "group": "entry_guard",
  "radius_feet": 10,
  "duration_seconds": 30,
  "entry_policy": "once_per_source",
  "benefits": { "ac_bonus": 2, "save_bonus": 1 }
}
```

Actual combat position refresh acquires a timed entry benefit once per exact
bearer/feature/recipient. Being inside at the first refresh counts as entry.
The deadline starts at entry, continues inside and outside, and is never
restarted by exit/reentry, another refresh, saving or reloading. The receipt
remains after expiry to enforce that declared policy. Incapacitated/dead bearers
cannot grant new entries; an already captured timed benefit keeps its deadline.

For protection that requires continued membership, use `entry_policy` of
`membership` and `duration_seconds` of `0`. It ends immediately outside radius,
on bearer incapacitation/death or feature loss, and returns on eligible reentry.
Live membership is cleared when combat closes and is not restored at an
exploration checkpoint. Timed lingering benefits remain queryable there.

Overlapping sources in a `group` do not stack. The first eligible source is the
default; Choose aura protection in the actual feature menu selects another exact
source. Different groups add. A changed/expired offer refuses a stale answer.
Radius is in 5-foot steps from 5 to 150. Benefits have the same bounds as above.
One feature supplies one protection aura; use distinct feature identities for
different protections. A recipient keeps at most 100 entry receipts; further
new sources are unavailable rather than discarding old anti-replay history.

The owner is also the bearer. Distinct transferred bearers, monster/exploration
entry detection, next-turn deadlines, resettable aura-use cadences, Speed and
damage-resistance payloads remain open. Fixed campaign-time deadlines are the
supported lingering policy; this does not certify those broader consumers.

## Checkpoints

Only settled HP grants, supply serials, aura entry receipts and aura selections
persist. Existing safe checkpoint and legacy namespace boundaries remain.
SaveManager validates both player and party DTOs, exact participants, loaded
payloads, amounts, deadlines, supplier pool ownership and duplicate DTO agreement
before replacing the session. A pending combat decision is not a save point.
See the [independent review](../../.artifacts/planning/vocabulary-reports/batch-027-review.md)
for final repair/checks and the builder report for retained recovery evidence.
