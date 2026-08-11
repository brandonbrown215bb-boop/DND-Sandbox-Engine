# Gate 5 evidence

## Representative rules cohort

The loader now supplies executable effects for a narrow cohort supported by the
existing action and event resolvers:

- Fighter: Second Wind, Action Surge, and level-5 Extra Attack.
- Barbarian, Monk, Paladin, and Ranger: level-5 Extra Attack.
- Rogue: level-5 Uncanny Dodge reaction availability.
- Rogue: Sneak Attack damage dice.
- Rogue: level-2 Cunning Action with Dash, Disengage, and Hide choices.
- Wizard: Arcane Recovery.
- Cleric: Harness Divine Power's spell-slot recovery path.

Unsupported active records remain rejected rather than becoming inert buttons.

## Automated result

| Check | Result |
|---|---|
| Project-context parse | Pass - 62 scripts loaded |
| Logic suite | Pass - 666 assertions, 0 failures |
| Command boundary | Pass - CombatCommand and PlayerCommand reject unknown/incomplete requests before state mutation |
| Feature resource boundary | Pass - unknown features cannot consume a resource; rest cadence restores Second Wind |
| Action economy | Pass - action and bonus-action budgets are independent; Action Surge can restore the spent action |
| Effect vocabulary | Pass - temporary HP, named resource spend/restore, concentration links, and timed monster movement cleanup have typed/deterministic coverage |
| Area selection | Pass - production Burning Hands, Sleep, Thunderwave, Fireball, and Bless records carry a validated transient sphere/cone selection contract; invalid geometry is rejected before spell resources are spent |
| Martial level progression | Pass - curated Extra Attack reaches levels 5 for Fighter, Barbarian, Monk, Paladin, and Ranger |
| Rogue reaction behavior | Pass - Uncanny Dodge is retained as a mechanics-backed level-5 feature; explicit accept/decline decisions are tested and only acceptance on a hit consumes the defender reaction |
| Reaction ownership slice | Pass - monster attacks and opportunity attacks collect owner-labelled in-shell prompts; test mode declines immediately, while timeout/cancel also decline without consuming a reaction |
| Counterspell observers | Pass - eligible player observers are prompted once per player spell cast, and explicit observer accept/decline decisions are covered against monster targets |
| Rest cadence | Pass - short rests restore only short-rest feature uses; long rests restore long/rest features, HP, spell slots, and clear transient modifiers |
| Rogue feature availability | Pass - Sneak Attack and Cunning Action are executable data; Cunning Action is a per-turn bonus-action feature with in-shell choice handling |
| Crown monster riders | Pass - poison, restraint, paralysis, armor corrosion, and maximum-HP riders cross the shared monster attack boundary |
| Existing combat and integration suites | Pass - logic 666/0; full isolated integration manifest passed every named scenario, including `action_resource_round_trip` and `character_sheet_contexts` |
| Mixed-mechanics encounter | Pass - named `mixed_mechanics_encounter` uses production Fighter, Rogue, Wizard, and Cleric entities to exercise martial attack, bonus action, Shield reaction, concentration, Cure Wounds, Fireball DEX save, and sphere area selection |
| Action/resource persistence | Pass - named `action_resource_round_trip` spends a production Fighter feature and Wizard spell slot, saves at the overworld safe point, reloads through the real DTO boundary, and boots the next combat with the remaining resources |

## Decision

`in_progress`. This is a first rules cohort, not the full Gate 5 contract.
Monster decisions now cross a validated `AICommand` boundary before movement
or attacks execute. The effect vocabulary now includes timed AC/stat, roll, and
movement modifiers with character serialization and turn expiry. Player-owned
reaction paths are covered for monster attacks, opportunity attacks, Shield,
Uncanny Dodge, and Counterspell observer selection; broader reaction ownership
and class coverage remain open. The mixed encounter and action/resource
round-trip fixtures close their automated slices. The confirmed Rogue
starting-equipment and Ranger mark/action-flow defects plus the remaining
`CombatState` separation criterion keep the gate in progress. Normal GUI
sampling is optional and nonblocking.
