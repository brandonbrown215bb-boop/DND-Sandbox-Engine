# Batch 044 build: S-210 / S-203

Stacks on Batch 043 (PR #11, `batch-043-s196-s202` @ 512945a).

## Selection
Of the slices named as fair game, only two are ready:

| Slice | Deps | Ready? |
|---|---|---|
| S-210 | S-161, S-196 (both built) | yes |
| S-203 | S-202 (built), S-074 (Verified), S-060 (built) | yes |
| S-197 | S-064 (Planned, unbuilt) | no |
| S-198 | S-067 (Planned, unbuilt) | no |
| S-170 | S-168 (Planned, unbuilt) | no |

- **S-210, attached parts and required sets.** It unblocks S-211 and S-213.
- **S-203, magic-property suppression, restoration and destruction.** It finishes the S-202 curse/magic line.

Neither touches the excluded areas:
- BondRules: bonded copies can't be attached, and no bond trigger was added.
- The wand charge path: no charge state is read or changed.
- Item projection, S-120, F1, Druid, the content editor.

**No real thresholds.** All values are neutral fixtures, so there's nothing to cite. No catalog item gets attachments or a suppression spell.

## Design
- **`AttachmentRules` (S-210)**
  - A host item declares `attachments {sockets:[{id, accepts?|item_types?}], sets:[{id, requires, benefits}]}`, and DataLoader validates it.
  - `attach` moves the exact carried copy into `host.state.attached[socket]`, keeping its identity and state. It refuses before anything moves when:
    - the socket is filled, undeclared or doesn't accept that part
    - the part is the host itself
    - the part is equipped, attuned or cursed
    - the part is bonded
    - the part is a container or another host
  - `detach` returns the same record once.
  - A set grants its source benefits only while the host is **worn** and every required socket is filled. This goes through `SourceBenefitRules.query`, kind `item_set`. Removing one part disables only the sets that require that socket.
  - Giving the host carries its parts. A host with parts can't be stowed in a container.
  - HUD: local-room **Attach** (`attach_any`) and **Detach** (`detach_last`).
  - Saves: `AttachmentRules.saved_error`, run in both SaveManager paths, refuses: duplicated or re-carried identities, undeclared or wrong sockets, non-hosts, nested parts and future serials. `InventoryCopies.ownership_error` also counts attached ids across characters.
- **`MagicPropertyRules` (S-203)**
  - New shared spell effect `suppress_item_magic {properties, mode: suppress|destroy}`. The properties it can name are `source_benefits`, `spell_permissions`, `incoming_negation_rule` and `attachment_sets`.
  - It's a flat self-cast carrier, like the other source carriers. It affects only the caster's **worn** exact copies that really have each listed property.
  - **Suppress:**
    - It's owned by the spell record (`magic_suppression`).
    - `MagicPropertyRules.active` is checked in: SourceBenefitRules (item benefits and sets), both SpellPermissionRules item paths, and the CastInterruptionRules item negation.
    - When the source ends (concentration or expiry), the still-worn copy works again without re-equipping or re-attuning.
    - Unlisted properties and mundane fields are untouched, and other wearers' copies are unaffected.
  - **Destroy:** writes `state.destroyed_magic[property] = {cause, source_id}` on the exact copy. It's permanent, re-equipping doesn't restore it, and other copies keep theirs.
  - Saves: `spell_effect_persistence` accepts `magic_suppression` records. `MagicPropertyRules.saved_error` refuses suppressions that are widened, retyped or empty, and destroyed entries with no cause or for a property the item lacks.

## Validation
- Logic: **5252 passed / 0 failed**, against a fresh baseline at 512945a of 5223/0. That is **+29**, equal to the 29 checks in `batch_044_checks.gd`.
- Scenarios (0 FAIL each): 031 25, 032 33, 033 70, 034 10, 035 9, 036 7, 037 11, 038 7, 039 10, 040 13, 041 11, 042 9, 043 11, **044 12**, shared_spell_flow 67. There was no SCRIPT ERROR or Parse Error in any log.
- `batch_044_parts_magic_flow` covers:
  - HUD attach of two exact gems, completing the worn host's set.
  - A real HUD cast of the suppress spell: AC drops by the ring benefit plus the set, and the spell permission stays.
  - A real monster attack that reads the suppressed AC.
  - Concentration end, which restores everything.
  - A real HUD cast of the destroy spell, which removes only the ring's spell permission.
  - A real detach, which disables only the gem set.
  - A recast, then a real `SaveManager` save/load with the parts, the live suppression and the destroyed magic, with no state clearing. After reload, concentration end restores only the suppressed properties.
- Coverage grep: every new public function has a production caller.

## Limits
- Suppression and destruction are a self-cast carrier on the caster's own worn copies. There's no targeted, area or antimagic host, and no Dispel Magic interaction.
- The saving bonus from `has_equipped_attuned_item` (Ring of Protection) isn't one of the suppressible properties.
- Sets grant only SourceBenefit AC/speed. Parts have no charges of their own (that's S-211, and the charge path is excluded).
- A host's parts can be detached through the HUD only while the host is carried, not worn.
- The fixtures use type `tool` and `ring` (F3).
