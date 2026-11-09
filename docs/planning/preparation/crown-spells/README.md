# Crown spell candidates

**Current handoff:** the [cross-set engine mapping](../../crown-engine-mapping/README.md)
is complete as planning. Follow its [bounded queue](../../crown-engine-mapping/assignments.md),
starting with CXM-01/S-249 ammunition. The writing snapshot below and its unchanged
candidate rules/blockers remain inputs; no candidate is promoted or accepted.

**183 written drafts. Not loaded, enabled or gameplay-verified.** This is the
owner-selected data-first authoring pass, prepared from SRD 5.2.1 on 2026-11-08
against source revision `2a19eb1d`. It does not change production definitions,
the conversion queue's delivery labels or engine-slice acceptance.

Start with [the spell index](index.json). It lists every ID, filename, level,
source pages, draft form and required-extension groups. Filenames replace `/`
with `-`; the actual spell IDs remain unchanged. All files live in this tracked
folder, outside DataLoader's `data/core` and `data/mods` roots.

| Level | Candidates |
|---|---:|
| Cantrips | 27 |
| 1 | 57 |
| 2 | 57 |
| 3 | 42 |
| Total | 183 |

## What each candidate contains

- `casting`: the source casting time, trigger text, range, components/material,
  duration, Concentration and spell lists. Timed casting is retained rather than
  silently shortened to an Action.
- `rules`: the complete normalized SRD body, divided into individually referenced
  requirements. Examples and embedded stat blocks stay with their spell. These
  1,103 text units are reference requirements, not a completion denominator.
- `authored_operations`: structured effect intentions with targets, choices,
  quantities, triggers and endings, or a reference to the shared definition.
  Proposed operation names **are not registered engine opcodes or new accepted
  syntax**. They specify the data still needing a runtime mapping. Do not build
  a separate spell executor for each declaration: group its parts by reusable
  operations and the existing owners.
- `runtime_draft`: an existing-contract definition or supported fragments where
  those can be written now. A fragment is only the named portion: a damage
  fragment does not supply a trigger, casting-ability bonus, area lifecycle or
  granted-action controller. The complete `rules` and operation plan still apply.
- `required_extensions`: explicit mapping/host requirements, named reuse points,
  slice references and retained partial-conversion limits. A requirement can
  need wiring to an existing owner; it does not prove that owner is absent.
- `source` and `audit`: official page/hash identity and the older audit/production
  record used as a starting point. Current production data is not the authority.

The current-contract material comprises **41 retained shared definitions, 10 new
shared drafts and 26 fragment sets**. The other **106 candidates have proposed
operation declarations with their complete rules**, without a current-contract
payload. None of those categories means “ready to enable.”

For example, [Hold Person](hold_person.json) has a new shared condition/repeat-save
draft; [Water Walk](water_walk.json) declares actual surface-crossing rules; and
[Find Steed](find_steed.json) retains its full embedded Otherworldly Steed stat block.
The latter two do not pretend that source text alone supplies their world hosts.

## Broad handoff

The subsequent [creature/actor candidates](../crown-creatures/README.md) now
resolve complete in-band form sets, undead outputs, steed templates and other
spell-owned actors/effects. Their dependency map classifies all 183 spells and
reuses these full rules/drafts. It does not implement their remaining hosts or
enable any spell. World/event/object authoring remains separate.

[Required extensions](required-extensions.json) groups the spell-specific
requirements so related spells can be mapped and implemented together. These
are authoring handoff groups, not new S-IDs, accepted slices or diagnosed runtime
failures. Read each referenced candidate's full rules before choosing work.

No gameplay tests, engine fixes, pack installation or production enabling were
part of this pass. JSON/ID/reference checks only establish that the written set
is present and internally readable. Later work must reconcile the source rules
against current generic operations and verify actual controls/hosts before
deliberate promotion. Keep native behavior until its replacement covers it.
Retained higher-slot and cantrip-upgrade rules do not grant Crown characters
additional slots or expand the campaign's level band.

## Source and attribution

These candidates include material from the *System Reference Document 5.2.1*
by Wizards of the Coast LLC, available at
[the official SRD PDF](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
licensed under [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/).
This adaptation normalizes extracted text, structures rules as data and adds
authoring/runtime-mapping notes. Per-spell pages and the PDF SHA-256 are retained.
The column-ordered extraction includes bottom-of-column continuations and
embedded stat blocks; the older abbreviated imported descriptions are not copied
as complete source rules.
