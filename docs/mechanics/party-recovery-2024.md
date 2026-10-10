# Party recovery: bounded SRD 5.2.1 integration

Rules authority: [SRD 5.2.1](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf),
Revivify (printed page 159), Gentle Repose (135), Dead (180), and the
damage/death/stabilization rules (17–18). Production support is a bounded party
slice, **not complete spell certification**.

## Revivify clause checklist

| Clause | Production behavior and evidence |
| --- | --- |
| Level 3, Action, Touch | Normal level-5 Cleric preparation and clicked combat spell path; room control requires the same prepared spell. One Magic action and one eligible slot in combat; no slot/action loss on refusal. |
| V/S/M; consumed diamond worth at least 300 GP | Shared hand/component preflight; shop supplies a named 300-GP diamond copy. Normal cast consumes exactly one copy. Pouches/foci do not replace it. |
| Creature died within the last minute | Actual deaths capture campaign time; effective unprotected age up to 60 seconds is accepted, 61 seconds refused. Unknown old death times remain ineligible. |
| Return with 1 HP | Revives the original Character and party slot with 1 HP; clears death-save/corpse state and retains inventory and class identity. |
| Spirit can refuse | Saved owner policy on sheet/recovery panel; unwilling target refuses before resources are committed. |
| Old age cannot be revived | Explicit recorded restriction refuses. |
| Missing parts are not restored | Non-vital recorded missing parts survive revival; missing vital parts, unavailable souls and transformed-undead bodies are explicit recovery restrictions. |
| General Dead rule | Ordinary healing/rest/level-ups cannot revive the dead; death ends Concentration and attunement, revival lowers Exhaustion by one. Other effects retain their existing supported lifetimes. |

## Gentle Repose clause checklist

| Clause | Production behavior and evidence |
| --- | --- |
| Level 2, Action or Ritual, Touch | Prepared spell on the room panel and existing combat Action path. Live room ritual control takes 606 seconds, consumes the component and spends no spell slot. Interruption simulation remains open. |
| V/S/M; consumes two Copper Pieces | Shared component preflight consumes one dedicated two-coin packet. Crown's integer-GP shop sells the prepared packet for 1 GP; loose copper currency is not implemented. |
| Corpse or other remains | Party corpse target, including partial/bone/dust remains; absent/destroyed remains and living/downed targets refuse. Arbitrary world corpses are not supported. |
| Ten days, protected from decay and undeath | Saved ten-day interval exposes the protection check. No automatic decay system exists; subsequent created-undead integrations must honor this shared check before changing the remains. |
| Preserved time does not count against revival limit | Effective age subtracts protected seconds. Recasts extend protection without resetting old age, expiry resumes the clock, and saving/loading preserves the same interval. |

## Verification and remaining boundaries

`CorpseChecks` exercises production damage, actual death, ordinary healing/rest,
attunement cleanup, willingness, exact revival boundary, restrictions, partial
remains, preservation recast/expiry, body DTO rejection, old schema-2 death,
stable recovery, death saves and level-up refusal. `party_recovery_flow` uses
class preparation, merchant purchases, equipment controls, recovery buttons,
safe entrance disk save/load, ordinary Cure Wounds on an unconscious ally, and
clicked combat Revivify with refusal before cost, and a normal Gentle Repose ritual after reload. `downed_area_damage_flow` verifies actual unconscious-ally damage and death through Fireball and a moved Cloud of Daggers; `cloud_of_daggers_spell_flow` verifies normal Wizard preparation, initial damage and the persistent zone turn cap. Accepted logs are recorded in
the current operations checkpoint.

These are same-process disk round trips on Windows Godot 4.7; no manual visual
acceptance or fresh-process relaunch is claimed. Party recovery is implemented;
arbitrary monster/NPC bodies, world-body transport, full body-part consequences,
other resurrection spells, and all higher forms remain open. Regenerate's limb
recovery, Speak with Dead's authored knowledge, and created-undead body
consumption/protection integration remain separate Wave 4 requirements. Damage
rider combinations and the complete general death-rule audit are not certified
by this slice.

This work includes material from the System Reference Document 5.2.1 by Wizards
of the Coast LLC, available at https://www.dndbeyond.com/srd, licensed under
[Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/legalcode).
