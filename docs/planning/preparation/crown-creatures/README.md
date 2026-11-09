# Crown creature and actor candidates

**Current handoff:** the [cross-set engine mapping](../../crown-engine-mapping/README.md)
is complete as planning. Follow its [bounded queue](../../crown-engine-mapping/assignments.md),
starting with CXM-01/S-249 ammunition. The writing snapshot below and its unchanged
candidate rules/blockers remain inputs; no candidate is promoted or accepted.

**94 written candidates, outside production.** This continues the spell,
character/origin and item authoring passes. It enables no content, changes no
engine behavior and makes no gameplay acceptance claim.

Start with [the index](index.json), [selection links](selection-links.json) and
[dependency map](dependency-map.json). The latter classifies all 183 spell
candidates and all 79 character candidates plus their multiclass supplement,
and pins the current campaign/event occurrences and code consumers.

| Written records | Count |
|---|---:|
| Crown's ten direct encounter definitions | 10 |
| Aldric, Mira and Rowan | 3 |
| SRD stat blocks needed by legal forms and undead outputs | 59 |
| Additional SRD comparison blocks for overlapping encounter definitions | 5 |
| Low-CR swarm blocks held pending selection adjudication | 4 |
| Otherworldly Steed, Phantom Steed and Unseen Servant | 3 |
| Other spell-owned forces, lights, areas and images | 10 |
| **Total** | **94** |

Paths to candidates and other authoring files inside JSON are relative to this
folder unless explicitly recorded as a repository-root `path` with a hash.
Retained input payloads preserve their original fields and path conventions.
Candidate IDs distinguish `crown_<production-id>` from `srd_<form-id>`; matching
names are not permission to combine their stats or silently replace encounters.

## Legal selections and acquisition

[The complete animal inventory](animal-source-inventory.json) retains all 90
Beast/Swarm-of-Beasts source blocks from the SRD Animals section and their
eligibility decisions, plus five animal-shaped non-Beast exclusions. It uses
actual type, CR and Fly Speed, not the production curated menus or an `srd` flag.

- **Wild Shape:** 39 individual Beast options at Druid 2–3, expanding to 46 at
  Druid 4–5. Four/six known forms, one replacement after a Long Rest, CR limits
  1/4 then 1/2, no Fly Speed. Swimming is legal in band. Source-prescribed
  breathing, size, limbs, proficiency/mental/HP retention, Temporary HP,
  Concentration, equipment and ending rules still apply. GM-approved other-source
  forms require an explicit source decision; no supplemental catalog is approved
  by this pass.
- **Find Familiar/Wild Companion:** all 24 individual CR-0 SRD Beasts, including
  the eleven named spell forms. The normal spell imposes no invented Tiny/Small
  cap. Wild Companion uses the same forms with its Fey type, resource/Material
  exception and owner-Long-Rest ending. Source-specific acquisition and lifetime
  remain attached to the actual bond.
- **Pact of the Chain:** Imp, Pseudodragon, Quasit, Skeleton, Sphinx of Wonder,
  Sprite and Venomous Snake in addition to normal forms. One familiar attack
  using its Reaction is distinct from an Attack action and from Multiattack.
  Investment at Warlock 5 retains all Speed, DC, damage-type, command and
  owner-Reaction benefits. Imp/Quasit resemblance forms retain their own stats
  except printed Speeds; they do not require full animal-stat replacement.
- **Animate Dead:** SRD Skeleton/Zombie outputs, exact Small/Medium Humanoid
  remains, creation versus renewal counts, once-only remains use, commands,
  standing orders and 24-hour control. Expired control does not delete the body.
  The SRD Wight comparison also retains its separate delayed Zombie creation,
  cancellation causes and twelve-Zombie control cap.
- **Steeds:** Find Steed uses one Otherworldly Steed template with all three
  type variants. Horse/camel/dire-wolf/elk appearance is cosmetic. Spell levels
  2–3 fit this band; level-4 flight does not. Faithful Steed retains its actual
  Paladin-level acquisition/free-cast source. Phantom Steed uses Riding Horse
  stats with its own Speed/travel, rider, damage-ending, fading and temporary
  tack rules.

Four low-CR swarms are written as **held**, outside the individual legal-form
counts. A swarm is a collection rather than one animal; source/selection
adjudication remains explicit before any offering. Two also have a Fly Speed.
No silent swarm inclusion or quiet loss of their source bodies is needed.

Unseen Servant is a force with its stated AC/HP/Strength, not an invented monster.
Mage Hand, Spiritual Weapon, Conjure Animals, Dancing Lights, Flaming Sphere,
Spirit Guardians and four illusion/duplicate spells retain their complete spell
rules and proposed operations in actor/effect records. They do not acquire
arbitrary monster HP, turns, loot or creature targeting. Animal Messenger's
Tiny CR-0 targets are enumerated separately. Other existing-animal interactions,
body changes, borrowed Humanoid senses and corpse/restoration procedures keep
their existing candidate rules without inventing a spawn catalog.

## Source, reuse and blockers

Every SRD stat-block candidate contains the complete rule body, printed stats,
per-behavior plans, source-page/hash identity and unchanged matching production
donors with manifest declarations. [Source pages](source-pages.json) retain the
whole selected two-column context. Proposed operations and extracted numeric
parameters are authoring aids, not registered engine syntax or substitutes for
the complete rule. [Required mappings](required-extensions.json) group concrete
requirements under existing engine owners without claiming those whole slices
are missing. Existing form/actor contracts remain the integration starting point.

Campaign records preserve **all ten current definitions**, including custom
Goblin Chief and Lich King. The eight overlapping ordinary encounter definitions
retain explicit differences from the SRD. In particular, Crown's `ooze` has
different defenses from SRD Gray Ooze; the current Wolf lacks the SRD Bite rider;
the current Wight and Giant Spider use simplified actions. The full SRD blocks
are comparisons, not a covert campaign rebalance. No SRD Lich/Goblin Boss
substitution is made.

Material blockers include:

- Goblin Chief's Rally lacks range, action cost, recipients, duration and recovery
  parameters. Preserve it as custom policy requiring a concrete decision.
- Lich King keeps its CR 8, statistics, resistances, seven linked spell candidates
  and slot pool. Its Touch seed has a bare duration of `1`; the retained native
  observation records the turn-count interpretation, not a source ruling.
  Rejuvenation still lacks a represented phylactery and a policy reconciling
  revival with Crown's win condition. Neither a ten-day simulation nor an
  automatic finale reversal is claimed.
- Official Gray Ooze prints Initiative `-2 (13)`. Both values are retained with
  an explicit source-reconciliation blocker instead of silently correcting it.
- Source attacks/traits still need real shared action, save-only, multiattack,
  command, reaction, recharge, condition, movement, sensory and aftermath hosts.
  Giant Frog includes actual swallowing, internal damage and legal corpse escape;
  corrosion addresses actual item copies and Mending. An effect name or generic
  Restrained condition is not the complete rule.
- Companion seeds are campaign Characters, not SRD NPC blocks. Preserve fixed
  ability scores, identity, roster, gear and stable seats. Their 2024 backgrounds,
  lineage/options, subclass and later choices need explicit legal selection or
  campaign defaults before promotion. Do not double-apply ability increases or
  issue another equipment package on recruitment.
- Created undead Gear and actual corpse equipment require exact-copy
  reconciliation. Phantom Steed's saddle/bit/bridle are source-owned temporary
  equipment, with separation/ending rules; they are not permanent item rewards.

Loot uses the [reachable-item pass's findings and candidates](../crown-reachable-items/README.md),
plus [package equipment](../crown-equipment/README.md). Every encounter loot entry
links its existing item candidate. No generic post-combat loot settlement was
established by that trace; copied metadata does not prove a reward is paid.
Campaign boss/room rewards remain separate and must not be paid twice.

## Checks and boundary

Run `python docs/planning/preparation/crown-creatures/check_candidates.py` from
the repository root. It checks JSON/index coverage, complete source-behavior
partitioning, legal-set predicates, candidate links, pinned source hashes/pointers
and unchanged retained payloads, spell/character scan coverage and item reuse.
Documentation links and consistency were checked separately. Selected source
page rendering was inspected for the two-column/stat-table extraction.

No Godot run, gameplay test, engine fix, install, production enabling, save change
or promotion is part of this writing pass. World/event/object candidate authoring
and later cross-set engine mapping remain. Slice acceptance and runtime claims
are unchanged. See the [Crown scope](../../crown-content-scope.md) and
[roadmap](../../crown-roadmap.md).

This work includes material from the System Reference Document 5.2.1
(“SRD 5.2.1”) by Wizards of the Coast LLC, available at
[the official SRD page](https://www.dndbeyond.com/srd). The SRD 5.2.1 is licensed
under the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/legalcode).
The [official PDF](https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf)
SHA-256 is `8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87`.
Adaptations add normalized statistics, behavior plans, selection links and
mapping notes; custom Crown rules retain their separate campaign authority.
