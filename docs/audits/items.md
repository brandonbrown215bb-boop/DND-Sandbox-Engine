# Items & Equipment audit (priority 2) — batches 1–2

Status: **partial**. Batch 2 (below, after batch 1) adds the 46 refused consumables effect by effect, every SRD adventuring-gear entry, and a code/data trace of how the magic-item shells are exposed. Batch 1 is an inventory reconciliation for every SRD item, plus a clause-level breakdown of *ordinary weapons and armor* and of the *general* magic-item rules. Individual magic-item entries are **not** broken down clause by clause yet (see Coverage). This is a docs/audit file only. It changes no runtime code, content or availability.

## Provenance

| | |
|---|---|
| Base commit | `ede0a3cdfa66f21b0b3415f498c2e186e56a0db4` (origin/main, 2026-10-26 07:40 CDT) |
| Runner | **Linux headless Godot 4.7.2.stable.official.ed1daf0bf** (`Godot_v4.7.2-stable_linux.x86_64 --headless`). The Windows runner was unreachable, so this is not a Windows result. |
| Inventory source | Initialized production `DataLoader` autoload (`get_all_items()`), with no fixtures |
| Registry | 289 unique items, 362 spells, 481 monsters, 0 validation failures (the existing warning about 25 effectless feature records was rejected) |
| `registry_hash_sha256` | `70a83cc74e530743e90f8fadc992bd0651f56b51cb84b06cd73fcaf22187845e` (sha256 of `DataLoader.get_registry_hash()`) |
| SRD text | SRD 5.2.1 PDF. Equipment pp.89–106, Magic Items pp.209–253. Every statement below comes from that text, not from memory. |

To rerun (artifacts are git-ignored under `.artifacts/items-audit/`):

```
godot --headless --path . res://tools/item_audit/item_inventory_export.tscn      # writes runtime.json
pdftotext -layout -f 89 -l 106 SRD_CC_v5.2.1.pdf .artifacts/items-audit/eq.txt
pdftohtml -xml -i -f 89 -l 106 SRD_CC_v5.2.1.pdf .artifacts/items-audit/eq
pdftohtml -xml -i -f 209 -l 253 SRD_CC_v5.2.1.pdf .artifacts/items-audit/mi
python3 tools/item_audit/reconcile_item_inventory.py                          # writes reconciliation.json
```

`tools/item_audit/export_item_inventory.gd` reports how each item can be used by copying the production `Inventory.consume()` gate: the item must be a consumable, it must have effects, and every effect must pass `EventResolver.is_effect_supported`. Light sources have their own path. The script adds no rules of its own.

## Totals

| SRD category | SRD entries | Loaded | Missing |
|---|---|---|---|
| Weapons (Weapons table) | 38 | 38 | 0 |
| Armor + Shield (Armor table) | 13 | 13 | 0 |
| Other equipment entries (gear, tools, packs, focuses) | 104 | 59 | 45 |
| Magic items | 258 | 66 entries (94 loaded records, counting variants) | 192 |

Loaded items that match no SRD entry: 67. These are supplement and future content (firearms, laser weapons, Blackrazor, Moonblade, Sword of Kas, Sword of Answering ×10, enspelled staffs, Whelm, Wave, Efreeti Chain, and others), campaign items (ashvale_brass_key, crown_fragment, dark_shard_amulet), and components or currency (gemstones, powders, gold, antidote, spellbook). They are outside this audit. Full list: `reconciliation.json → loaded_not_srd_matched`.

How the 289 loaded items can be used: 232 are not consumables; 46 consumables are **refused** ("no implemented effect"); 9 consumables are supported; 2 are light sources.

**Missing equipment (45):** Gaming Set; Ammunition; Barrel; Basket; Block and Tackle; Book; Bottle, Glass; Bucket; Burglar's / Diplomat's / Dungeoneer's / Scholar's Pack; Candle; Case, Crossbow Bolt; Case, Map or Scroll; Chain; Chest; Clothes, Fine / Traveler's; Flask; Grappling Hook; Hunting Trap; Ink; Ink Pen; Jug; Ladder; Lock; Magnifying Glass; Manacles; Map; Paper; Parchment; Perfume; Pole; Pot, Iron; Pouch; Quiver; Ram, Portable; Sack; Shovel; Signal Whistle; Spikes, Iron; String; Tent; Vial.

**Missing magic items (192):** listed in `reconciliation.json → srd_missing`. They include whole families the engine has none of: every ring except Protection, every rod, every Wand except Magic Missiles, Spell Scroll, Bag of Holding / Handy Haversack / Portable Hole, Armor/Weapon/Shield/Ammunition +1/+2/+3, Belt of Giant Strength, Ioun Stone, Figurine of Wondrous Power, Deck/Mysterious Deck, Ring of Three Wishes, Sphere of Annihilation, Sending Stones.

Name-matching caveats: matching uses normalized names plus a small family map. Spell Scroll and Gaming Set were spot-checked and really are absent; they are not naming misses. Sword of Vengeance is loaded but SRD 5.2.1 has no entry with that name.

## Finding F-1: most loaded SRD magic items have no rules

Of the 94 loaded records that match SRD magic items, **84 carry no rule-bearing field**. The fields checked are magical, effects, attunement, curse, charges, recovery, activation, aftermath, source_benefits, bonuses, container and links. The 84 split two ways:

- **Consumable stubs (35):** the potions and oils, apart from 4 healing potions and Potion of Poison / Poison Resistance. `consume()` refuses them, so this is **safe**. *(Batch 2 correction: batch 1 said 46 here and 38 below. 46 is the total of all refused consumables, including gear and non-SRD potions. The correct split of the 84 is 35 consumable + 49 equippable/held.)*
- **Weapon / armor / shield / held-item stubs (49, including Hat of Many Spells as a `tool`):** for example Oathbow (`ability: STR`, 1d8, range 30, no magic), Sun Blade, Mace of Disruption, Dwarven Thrower, Javelin of Lightning, every Dragon Scale Mail, Armor of Invulnerability, Animated Shield, and all staffs except Power and Striking. These pass the normal `can_equip` and attack paths as **plain mundane gear**. That is a fidelity problem, not a crash: the engine shows an item that does not do what its SRD text says. `identify_rules.gd` recognizes `imported_magic_*` sources, but nothing stops them from being equipped. Batch 2 traced whether shop, loot or creation flows hand these out: **none do** (see B2-3).
- Records that do carry rules: Wand of Magic Missiles (charges, dawn recovery, activation spell), Staff of Power and Staff of Striking (attunement, charges, recovery, last-charge aftermath, bonus), Ring of Protection (attunement, AC/save bonus, one-ring limit), the healing potions, and Potion of Poison / Poison Resistance.

Classification: content conversion against existing hosts. Most of these need no new vocabulary, only conversion, which is out of scope here. Whether to gate the 49 equippable stubs is an availability decision for the owner. This audit makes no change.

## Ordinary weapons (reviewed at clause level)

Field comparison of all 38 SRD weapons against the loaded records (`reconciliation.json → weapon_field_diffs`): damage, damage type and the finesse, heavy, light, loading, reach, thrown, two-handed and versatile flags **match for all 38**.

The diffs are:
- The **Ammunition** property is missing on all 9 ammunition weapons. The loader uses a `ranged` tag instead.
- **Long range** is not represented on any of the 16 ranged or thrown weapons. Only normal range is stored, in 5-ft cells.
- Musket and Pistol have no mastery in either the item record or the FighterRules table.

| Clause (SRD p.89–90) | Behavior | Classification | Owner / evidence |
|---|---|---|---|
| Category, proficiency | Simple/Martial; proficiency adds PB | existing supported (not re-tested) | `weapon_type` field; class proficiencies |
| Finesse | choose STR or DEX, same for attack and damage | existing supported | combat_action.gd, rogue/fighter rules |
| Light | extra Bonus Action attack with a different Light weapon, no positive modifier | existing supported | off-hand slot requires Light (`can_equip`) |
| Two-Handed | needs two hands | existing supported | `can_equip` blocks shield/off-hand |
| Versatile | larger die when wielded two-handed | existing supported | combat_action.gd:1169; `versatile_damage` on all 7 SRD versatile weapons |
| Loading | one shot per action/BA/reaction | existing supported (attack-action path only) | combat_state.gd:3853. BA/reaction firing not verified |
| Reach | +5 ft reach, including opportunity attacks | existing supported (not re-tested for OAs) | `"reach" in properties` in combat_state.gd / fighter_rules.gd |
| Ammunition | needs and expends 1 piece; free hand to load; recover half after a fight | **genuine gap → S-249 (items-1)** | no ammo items, no property, no consumption |
| Range (normal/long) | Disadvantage beyond normal range; no attack beyond long range | **genuine gap → S-250 (items-2)** | long range not stored; no range-band roll mode found |
| Heavy | Disadvantage if melee and STR < 13, or ranged and DEX < 13 | **genuine gap → S-250 (items-2)** | `heavy` is read only for class features (GWM etc.), not as an attack predicate |
| Thrown | draw as part of the attack; melee weapon keeps its melee ability | existing supported (partly) | `thrown_range` exists; draw/ability parity not verified; long range is under S-250 (items-2) |
| Mastery: Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex | per the SRD text | existing supported | fighter_rules.gd:300–340, combat_state.gd:5358–5360; mastery choice and expansion is **already planned under S-127** |
| Mastery source | each weapon's mastery property | existing supported, with a conversion note | FighterRules reads a **hardcoded table keyed by weapon id**, not `item.mastery`, so a magic weapon built on a base weapon gets no mastery. Fixing that belongs with S-255 (items-7) |
| Improvised weapons | Rules Glossary | **not reviewed** | — |
| Selling at half cost | economy | **not reviewed** (shop.gd) | — |

## Armor and shields (reviewed at clause level)

AC values for all 13 entries match the SRD. The stealth-disadvantage flag matches. Medium armor's Dex cap is handled in AC code, though I did not re-test it. Weight is missing on the 10 records imported from `imported_base_items` (also noted in docs/mechanics/srd-item-weights.md).

| Clause (SRD p.92–93) | Behavior | Classification | Owner |
|---|---|---|---|
| AC formula and Dex cap | base AC, + Dex, max 2 for medium | existing supported | character AC code |
| Shield +2, one shield | | existing supported | shield slot |
| Strength column | Speed −10 ft unless STR ≥ requirement (Chain Mail 13, Splint and Plate 15) | **genuine gap → S-251 (items-3)** | no requirement field, no code |
| Stealth column | Disadvantage on Dexterity (Stealth) checks while worn | **missing consumer → S-251 (items-3)** | the field exists but only `ui/shop.gd` reads it |
| Armor training | without training: Disadvantage on STR/DEX D20 Tests, no spellcasting | **genuine gap → S-251 (items-3)** (pending verification) | `armor_proficiencies` list exists; grep found no penalty consumer |
| Don/Doff times | Light 1/1 min, Medium 5/1, Heavy 10/5; Shield is a Utilize action | **genuine gap → S-252 (items-4)** | equipping is instant; no action/time cost |

## Tools, containers, supplies (reviewed at family level only)

| Family | Classification | Owner |
|---|---|---|
| Tool proficiency and purpose-aware checks | existing supported | S-028 (VS-24) |
| Tool crafting | already planned | S-198 / S-199 |
| Gaming Set (absent), tool weights | content conversion | srd-item-weights.md follow-up |
| Packs: expanding into contents | existing supported (`expand_pack_instance`) | 4 of 7 SRD packs are missing (conversion only) |
| Containers: exact non-nested contents | existing supported | S-196 (VS-131). Volume capacity is enforced only when a compartment declares `max_volume` (container_rules.gd:87; corrected in batch 5) |
| Liquids, oil and fuel quantities | already planned | S-197 |
| Light sources (lamp/lantern/torch) | existing supported | S-064 (VS-135) |
| Rations and food | already planned | S-200 / S-201 |
| Thrown or applied supplies (Acid, Alchemist's Fire, Holy Water, Basic Poison, Caltrops, Ball Bearings, Healer's Kit, Antitoxin): 46 refused consumables include these | **not reviewed clause by clause.** Likely reuses for attack-with-object, weapon-coating riders (S-076 planned) and area hazards | batch 2 |
| Mounts, vehicles, trade goods, lifestyle, services | **not reviewed** | — |

## General magic-item rules (reviewed at clause level, SRD pp.209–212)

| Clause | Classification | Owner |
|---|---|---|
| Attunement: 1 hour, max 3 items, one copy at a time | existing supported | inventory.gd `attune_instance`; S-202 (VS-132) |
| Attunement prerequisites ("by a Wizard", "by a Spellcaster", and others) | **genuine gap → S-253 (items-5)** | no prerequisite field or check |
| Curses: attunement can't be ended, removed by Remove Curse | existing supported | S-202 (VS-132), `break_cursed_item_attunements` |
| Charges, dawn/dusk recovery | existing supported | S-063 (VS-93) |
| Last-charge aftermath / destroyed item | existing supported | S-060 (VS-118) |
| Child-copy charges (spent charges carried to split copies) | already planned | S-211 |
| Activation: Magic action, casting from an item | existing supported | S-134 (VS-76), S-139 |
| Stored spells, then release (Ring of Spell Storing, etc.) | already planned | S-150 / S-151 |
| Linked copies (Sending Stones, etc.) | existing supported | S-162 (VS-129) |
| Attached parts | existing supported | S-210 (VS-133) |
| Repair and mending | already planned | S-212 |
| Random-table items (Bag of Tricks, Deck of Illusions, Wand of Wonder, …) | already planned | S-214 / S-215 |
| Wish-class items (Ring of Three Wishes) | already planned | S-220–S-222 |
| Magic-item saving bonus (Ring/Cloak of Protection) | existing supported | `magic_item_saving_bonus` |
| Spell Scroll: cast if the spell is on your list; ability check for a higher-level spell; scroll is consumed; scroll as a ready-made spell slot | **genuine gap → S-254 (items-6)** | item missing; S-134 gives casting permission but not the list/check gate or one-use consumption |
| "Armor / Weapon / Ammunition (Any …)" templates over a chosen base item | **genuine gap → S-255 (items-7)** | no base-item template; at least 17 SRD entries have "(Any …)" in their category line (a lower bound, since only the first category line is parsed) |
| Item durability (AC/HP of objects), resilience | existing supported | object destruction rules, S-072 (not re-verified for items) |
| Sentient items, artifacts | **not reviewed** (source sections not decomposed) | — |
| Wearing/wielding limits (two boots, one cloak, etc.) | existing supported (worn_slot) | not re-verified for all slots |

## Proposed slices (placeholders at audit time; wave 2 assigned the S-IDs shown)

**S-249 (items-1) — Ammunition consumption and recovery.**
- Source: SRD p.90 "Ammunition".
- Affects: 9 ammunition weapons, the Ammunition entry, Quiver and the Crossbow Bolt Case, and Ammunition +1/+2/+3, Ammunition of Slaying and Efficient Quiver.
- Reuses: S-196 exact contents (quiver), S-197 counted quantities, the S-060 copy destruction pattern.
- Depends on: an `ammunition` property and an `ammunition_type` on the weapon, plus counted ammo items.
- **Done when:** a headless check shows a Longbow attack is refused with "no ammunition" when the wielder holds 0 arrows. With 3 arrows, two attacks leave 1. After combat ends, spending 1 minute restores floor(2/2) = 1 arrow, and the other is lost. A save/load round trip keeps the count.

**S-250 (items-2) — Weapon range bands and the Heavy predicate.**
- Source: SRD p.90 "Range", "Heavy", "Thrown".
- Affects: 16 ranged or thrown weapons (long range), 9 Heavy weapons.
- Reuses: the existing attack roll-mode advantage/disadvantage aggregation.
- Depends on: storing `long_range` per weapon (a data field; the conversion happens in this slice).
- **Done when:** a check shows a Longbow attack at 160 ft rolls with Disadvantage and is refused at 610 ft. A STR 12 creature attacking with a Greatsword rolls with Disadvantage and a STR 13 one does not. A DEX 12 creature firing a Heavy Crossbow rolls with Disadvantage. A thrown Dagger uses the same ability the wielder would use in melee.

**S-251 (items-3) — Worn-armor predicates.**
- Source: SRD p.92 Armor table "Strength" and "Stealth" columns, and Armor Training.
- Affects: all 12 armors plus Shield (training only).
- Reuses: S-028 purpose-aware checks for Stealth; the existing speed-modifier and spellcasting-permission hosts.
- Depends on: a `strength_requirement` data field on Chain Mail, Splint and Plate.
- **Done when:** a check shows a STR 14 wearer of Plate has Speed −10 ft and a STR 15 wearer does not. A Scale Mail wearer has Disadvantage on a Dexterity (Stealth) check. A wearer without Heavy armor training has Disadvantage on STR/DEX D20 Tests and is refused when casting a spell. All three effects go away when the armor is unequipped.

**S-252 (items-4) — Don/Doff timing.**
- Source: SRD p.92 table group headers and the Shield row.
- Affects: all armor and shields.
- Reuses: the campaign time-cost host (ADR-0007) and the Utilize action cost.
- Depends on: nothing beyond the existing action costs.
- **Done when:** a check shows that equipping Plate outside combat advances campaign time by 10 minutes and removing it by 5. In combat, Medium or Heavy armor cannot be donned, and donning a Shield spends the Utilize action. The result reports the time spent.

**S-253 (items-5) — Attunement prerequisites.**
- Source: SRD p.210 "Attunement" (prerequisite clause) and each entry's "Requires Attunement by …".
- Affects: SRD entries with class, spellcaster or other attunement qualifiers (at least 11 entries have "by a …" in their first category line; the full count is batch 2; for example Staff of Power and Robe of the Archmagi).
- Reuses: `attune_instance`; class and spellcasting predicates (QRY-06 owned predicates).
- **Done when:** a check shows a Fighter is refused attunement to a "by a Sorcerer, Warlock, or Wizard" item with that reason, a Wizard succeeds, and a loaded item that requires attunement but has no qualifier is unaffected.

**S-254 (items-6) — Spell Scroll use.** *(Wave 2: items-6, items-10 and items-14 are one slice, S-254.)*
- Source: SRD Spell Scroll entry (Magic Items, "Scroll, Rarity Varies").
- Affects: Spell Scroll for every spell level. Also usable by future scroll-like consumables.
- Reuses: S-134 item casting permission, the shared spell runtime (ADR-0017), S-060 destruction.
- **Done when:** a check shows a Wizard casts *Magic Missile* from a level-1 scroll and the scroll is gone. A Fighter is refused because the spell is not on their list. A caster reading a scroll above their highest slot level makes the ability check at DC 10 + spell level: on a failure the scroll is lost and nothing is cast, and on a success the spell resolves. The scroll's save DC and attack bonus come from the scroll's level table, not the caster.

**S-255 (items-7) — Magic templates over a base item.**
- Source: SRD entries written as "Weapon (Any Simple or Martial)", "Armor (Any Medium or Heavy …)", Weapon/Armor/Shield/Ammunition +1/+2/+3, Flame Tongue, Vorpal Sword, Adamantine/Mithral Armor, and others.
- Affects: at least 17 SRD entries with "(Any …)" (lower bound).
- Reuses: the existing item copies (ADR-0013) and `weapon_bonus` / `armor_bonus`.
- Depends on: S-250 (items-2) for range data inheritance; mastery being read from the item rather than the FighterRules id table.
- **Done when:** a check creates a "+1 Weapon" copy over a Longsword. The copy reports 1d8 slashing, Versatile 1d10, mastery Sap and +1 to attack and damage. A Fighter with Weapon Mastery applies Sap with it. A "Mithral Armor" copy over Half Plate has no Stealth disadvantage and no Strength requirement. Both survive save/load.

## Batch 2 (2026-10-26): consumables, adventuring gear, shell exposure

Same base commit, registry hash and Linux headless export as batch 1. origin/main had not moved, so no rebase was needed. Extra artifact: `.artifacts/items-audit/srd_gear_text.json`, holding 88 gear and tool descriptions split from `pdftotext -f 94 -l 100`, plus `m2.txt` (`pdftotext -f 209 -l 253`). Each SRD clause below was read from those files.

### B2-1: the 46 refused consumables, effect by effect

46 = 7 SRD gear + 35 SRD magic potions/oils + 4 non-SRD potions (Comprehension, Fire Breath, Greater Invisibility, Pugilism; out of scope). Every one has `effects: []`, so `consume()` refuses it and the shop's `_is_buyable_item` hides it. None of them is exposed with wrong behavior.

| Item(s) | SRD clause (summary) | Reusable operation | Classification | Owner |
|---|---|---|---|---|
| Acid, Alchemist's Fire, Holy Water | replace one attack: throw at a target within 20 ft; DEX save, DC 8 + Dex + PB; 2d6 Acid / 1d4 Fire + Burning / 2d8 Radiant only vs Fiend or Undead; item used up | thrown-object attack replacement with a save | **genuine gap → S-256 (items-8)** | S-126 DC profile (verified); Burning exists in combat_object_rules.gd |
| Oil (douse creature/object) | same throw; on a failed save the target is covered; next Fire damage within 1 min +5 Fire | S-256 (items-8) plus a timed next-damage rider | gap (8) + already planned | S-076 next result grant (planned) |
| Oil (pour on a space), Caltrops | Utilize: cover a 5-ft square; entry triggers (Oil once lit / Caltrops DC 15 DEX: 1 Piercing, Speed 0); 10 min to recover Caltrops | item-deployed hazard area | **genuine gap → S-258 (items-11)** | entry scopes S-184 (planned); zone host combat_spell_zones.gd |
| Oil (fuel) | fuel for Lamp/Lantern | existing supported | — | S-064 (`fuel_item_id` on hooded lantern) |
| Antitoxin | Bonus Action; Advantage on saves to avoid or end Poisoned for 1 hour | timed, condition-scoped save advantage | **genuine gap → S-257 (items-9)** | `roll_modifier` exists but no condition-scoped timed route was verified |
| Basic Poison | Bonus Action; coat 1 weapon or 3 ammo; next Piercing/Slashing damage +1d4 Poison; lasts 1 min or until dealt | weapon-coating next-damage grant | already planned | S-076 (+ S-013 P2); ammo half needs S-249 (items-1) |
| Potion of Resistance ×10, Potion of Invulnerability | Resistance to one type for 1 h / all damage for 1 min | timed self-resistance from an item | **gap → S-257 (items-9)** | — |
| Potion of Giant Strength ×6 | STR *becomes* 21/23/23/25/27/29 for 1 h; no effect if STR is already ≥ that score | timed score setting | **host exists, no consumable route → S-257 (items-9)** | S-039 score setting (verified, VS-46) |
| Potion of Climbing, Potion of Flying | Climb Speed = Speed + Advantage on climb checks / Fly Speed + hover, 1 h; fall when it ends | timed movement mode | **gap → S-257 (items-9)**; fall on expiry already planned | S-179 modes (verified); S-181 (planned) |
| Potion of Water Breathing | breathe underwater for 24 h | timed breathing adaptation | already planned | S-205 |
| Potion of Heroism | 10 Temp HP for 1 h + Bless with no Concentration | Temp HP (supported) + item spell effect | conversion + **S-254 (items-10)** | S-015 / `temporary_hp` |
| Clairvoyance, Diminution, Growth, Gaseous Form, Speed, Mind Reading (DC 13), Oil of Etherealness, Oil of Slipperiness (Freedom of Movement 8 h, or Grease over a 10-ft square) | "gain the effect of spell X", usually with no Concentration, a fixed duration or DC, and sometimes an end clause removed (Speed: no lethargy) | item-delivered spell effect with source overrides | **genuine gap → S-254 (items-10)** | S-134 covers *casting* from items, not "gain the effect" without casting; spells run on the shared runtime |
| Potion of Animal Friendship | "you can cast" the level-3 version, save DC 13 | casting from an item at a fixed level and DC | existing host, conversion only | S-134, S-139 |
| Potion of Invisibility | Invisible for 1 h; ends early on an attack roll, dealing damage, or casting a spell | condition with action-triggered early end | **gap → S-257 (items-9)** (end triggers) | `grant_condition` supported; observer side is S-191 (planned) |
| Philter of Love | charmed by the next creature you see within 10 min, for 1 h | observer-dependent deferred trigger | already planned (observer) + ADR-0023 judgment for "see" | S-190 |
| Elixir of Health | cures magical contagions; ends Blinded, Deafened, Paralyzed, Poisoned | `remove_condition` ×4 | conversion only (supported type); "contagions" is a source gap (no disease model) | — |
| Potion of Vitality | removes all Exhaustion, ends Poisoned; for 24 h Hit Point Dice heal their maximum | remove (supported) + timed HD-max modifier | conversion + **gap → S-257 (items-9)** | — |
| Potion of Longevity | physical age −(1d6+6), minimum 13; 10% cumulative backfire | no age model | **source gap / ADR-0023 deferred** | — |
| Oil of Sharpness | coat a nonmagical Slashing/Piercing melee weapon or 20 ammo → +3 | magic template over a base item | gap → S-255 (items-7) | — |

### B2-2: adventuring gear and tools, entry by entry

I read the SRD text for every entry in the Tools and Adventuring Gear sections. "Conv" means the existing host covers it and only the data needs converting (out of scope here).

**Tools (25 entries, 24 loaded):** every tool's Utilize DC belongs to the verified **S-028** purpose-aware tool checks, and every Craft list to **S-198/S-199** (planned). Two notes:
- The 23 records imported from `imported_magic_tools.json` carry `effects: []`, so their Utilize benefits aren't converted (conv).
- Only Thieves' Tools has an authored effect (`enable_check: lockpick`), and I found no production consumer of `enable_check`. Lock picking does work through local-room rules, but I didn't verify that path.
- Gaming Set is missing (conv).

**Focuses:** Arcane Focus ×5, Druidic Focus ×4, Holy Symbol and Component Pouch are existing supported through `Inventory.has_spellcasting_focus`. The Druidic Focus records have `effects: []`; I didn't verify whether the compatibility check is id-based.

**Gear entries:**

| Entry | Loaded | SRD rule (summary) | Classification |
|---|---|---|---|
| Acid, Alchemist's Fire, Antitoxin, Basic Poison, Caltrops, Holy Water, Oil | yes | see B2-1 | B2-1 |
| Ball Bearings | yes (`tool`, no effects) | Utilize: 10-ft square; DC 10 DEX or Prone on entry; 10 min to recover | **S-258 (items-11)** |
| Hunting Trap | no | Utilize to set; DEX save on stepping on the plate; restrained by the trap | **S-258 (items-11)** + S-168/S-169 escape |
| Net | **yes, as a weapon: 1d4 bludgeoning, STR, value 1, sold in the shop** | replace an attack; DEX save or Restrained, auto-success vs Huge+; DC 10 Athletics escape; Net AC 10, 5 HP | **data divergence that is exposed** (it deals damage it shouldn't and doesn't restrain); behavior is S-256 (items-8) + continuation of S-168/S-169 |
| Manacles, Chain, Rope (bind) | Rope yes; Manacles, Chain no | Utilize vs a Grappled/Incapacitated/Restrained target; DC 13 check; bound = Restrained; escape/burst DCs | continuation of verified **S-168 / S-169** (restraint relation, escape); conv |
| Rope (knot), String | Rope yes | Utilize knot, DC 10 Sleight of Hand; burst DC 20 | S-028 conv. **Divergence:** loaded Rope grants +2 Athletics (climbing), which the SRD text doesn't say |
| Climber's Kit | yes | Utilize anchor: can't fall more than 25 ft, or move more than 25 ft until undone (BA) | **divergence:** loaded as +2 Athletics (climbing), not in the SRD; anchor is a tether, continuation of S-168 |
| Crowbar | yes | Advantage on Strength checks where leverage applies | **divergence:** loaded as +2 Athletics (prying); local_room_rules.gd requires a Crowbar to pry, which is supported. Advantage belongs to the S-028 roll-mode host |
| Costume, Magnifying Glass, Perfume, Pole (vault) | Costume yes; others no | Advantage on a scoped ability check (Perfume: 1 h, Indifferent Humanoid within 5 ft) | existing host S-028 (purpose-aware), conv; Perfume's audience scope is an ADR-0023 judgment |
| Book, Map | no | +5 to scoped Int/Wis checks when consulting an accurate one | S-028 conv; "accurate" is an ADR-0023 judgment |
| Portable Ram | no | +4 to the Strength check to break doors; a helper gives Advantage | S-028 / local-room door rules, conv |
| Healer's Kit | yes (no effects) | 10 uses; Utilize to stabilize at 0 HP with no Medicine check | **missing host continuation:** stabilize exists (zero_hp_aftermath_rules.gd, character.gd) but no item route; uses are covered by the S-063 charge vocabulary |
| Lamp | yes (**no `light_source`**) | burns Oil; Bright 15 ft + Dim 30 ft | S-064 conv (the light-source host exists) |
| Lantern, Hooded | yes (light_source) | Bright 30 + Dim 30; hood down as a BA | existing supported (S-064). Hood toggle is not represented (conv) |
| Lantern, Bullseye | yes, **as a consumable with `vision_bonus` for 10, no fuel** | 60-ft Cone Bright + 60 Dim, burns Oil | **data divergence.** Its use path is supported, but it doesn't match the SRD; cone light → S-190 (planned) |
| Torch | yes (light_source 20/40, 1 h) | as above; can attack as a Simple Melee weapon for 1 Fire | light existing supported (S-064); torch-as-weapon not represented (conv) |
| Candle | no | 1 h, Bright 5 + Dim 5 | S-064 conv |
| Tinderbox | yes (no effects) | lights a fuel source as a BA, other fires in 1 min | the lighting action cost isn't modeled; S-064 conv |
| Backpack | yes (container 30 lb) | 30 lb within 1 cu ft | existing supported (S-196). Volume not declared in data (corrected in batch 5: `max_volume` *is* enforced when the data declares it, container_rules.gd:87; this record declares none) |
| Barrel, Basket, Bottle, Bucket, Case ×2, Chest, Flask, Jug, Pot, Pouch, Quiver, Sack, Vial | no | capacity in lb, cu ft, gallons, pints or ounces, or a count (Quiver 20 Arrows) | S-196 conv; liquid capacity S-197 (planned); ammo-count capacity S-249 (items-1) |
| Entertainer's, Explorer's, Priest's Pack | yes | expands into its contents | existing supported (`expand_pack_instance`) |
| Burglar's, Diplomat's, Dungeoneer's, Scholar's Pack | no | expands into its contents | conv |
| Rations, Waterskin | yes | malnutrition/dehydration via the Rules Glossary | `nourish` supported; exposure S-200/S-201 (planned) |
| Bedroll, Blanket, Tent | Bedroll, Blanket yes; Tent no | auto-succeed / Advantage on extreme-cold saves; sleeps 1–2 | S-201 (planned) |
| Block and Tackle | no | hoist 4× lift capacity | **not classified**: carrying-capacity host not located (batch 3) |
| Grappling Hook | no | Utilize throw within 50 ft, DC 13 Acrobatics to catch; climb if roped | S-028 + S-179 climb, conv |
| Ladder, Pole (reach), Shovel (1 h dig), Iron Spikes, Bell, Signal Whistle, Mirror, Spyglass, Ink, Ink Pen, Paper, Parchment, Clothes ×2, Robe | mixed (Bell, Mirror, Robe loaded) | descriptive, narrative or world-interaction | **ADR-0023 bounded judgment / deferred.** No discrete mechanic beyond flavor, local-room use or time cost |
| Spell Scroll (gear table) | no | see S-254 (items-6) | S-254 (items-6) |

Reconciler note: the batch-1 gear header parser missed **Spyglass** (1,000 GP, not loaded), so the corrected missing-equipment count is **46**, not 45. Iron Spikes, Chest and Portable Ram text was split by the PDF's two-column layout; I read those entries by hand where the text was recoverable (Ram) and left the rest unchecked (Spikes, Chest).

### B2-3: are the 49 equippable magic-item shells handed out?

I traced code and data paths only.
- **Shop (`src/ui/shop.gd`):** `_is_buyable_item` requires `value > 0`, and all 49 shells have `value: 0`. **Not sold.** Selling isn't relevant, because a player never receives one.
- **Loot:**
  - The dungeon generator hard-codes `gold_100` and `potion_healing`.
  - Dungeon `loot` lists, monster `loot_table`s and event `give_item`/`success_loot` all use explicit ids.
  - A full-text search of every non-item JSON under the repo found **no reference** to any of the 49 ids, apart from `data/content_manifest.json` (approved overrides) and `docs/reviews/dnd-runtime-source-ownership.json`. **Not dropped.**
- **Character creation:** it uses class `starting_equipment` (explicit ids), and none are shells. **Not granted.**
- The only other `get_all_items()` caller in production code is the shop.

Conclusion: in the current production content, the shells can't be reached through normal play. They are still reachable through authored content, mods, saves and test harnesses, because the DataLoader validates the ids as real items. The **Net** (B2-2) is the one SRD item that really is exposed with wrong behavior, since it's buyable.

### Batch 2 proposed slices

**S-256 (items-8) — Thrown-object attack replacement.**
- Source: SRD gear entries Acid, Alchemist's Fire, Holy Water, Oil (douse) and Net: "When you take the Attack action, you can replace one of your attacks with throwing…".
- Affects: those 5 entries; Bottle/Flask improvised throws are out of scope.
- Reuses: the Attack-action swing count (combat_state.gd), the S-126 save-DC profile (DC 8 + Dex + PB), the Burning hazard, S-168 restraint for Net, and item-copy destruction.
- Depends on: S-076 (planned) for Oil's next-Fire rider only.
- **Done when:** a check shows a level-5 Fighter can spend one of 2 Attack-action swings throwing Acid at a target 20 ft away (and is refused at 25 ft). The target makes a DEX save against DC 8 + Dex + PB, takes 2d6 Acid on a failure, and the vial is removed while the second swing stays available. Holy Water deals no damage to a non-Fiend, non-Undead target. Alchemist's Fire applies Burning on a failure. A Net restrains a Medium target, automatically fails against a Huge one, and the target escapes with DC 10 Athletics.

**S-257 (items-9) — Timed self-modifiers from consumables.**
- Source: Antitoxin, Potion of Resistance, Invulnerability, Giant Strength, Climbing, Flying, Invisibility (end triggers) and Vitality (HD maximum).
- Affects: 22 loaded consumables.
- Reuses: S-039 score setting, S-179 movement modes, condition grants, S-015 source-owned expiry, and campaign/combat time (S-064).
- Depends on: S-181 (planned) for falling when flight expires.
- **Done when:** a check shows that after drinking Potion of Hill Giant Strength, a STR 10 character's attack and Athletics use STR 21 for exactly 1 hour, then revert to 10; a STR 22 drinker is unchanged. Fire Resistance halves Fire damage only, and only for 1 hour. Antitoxin gives Advantage on a save against Poisoned but not on another CON save. Invisibility ends when the drinker makes an attack roll. Flying grants a Fly Speed equal to Speed. Every effect survives save/load with its remaining time.

**S-254 (items-10) — Item-delivered spell effects with source overrides.**
- Source: the potions and oils that say "you gain the effect of the X spell" (Clairvoyance, Diminution, Growth, Gaseous Form, Speed, Mind Reading, Heroism/Bless, Etherealness, Slipperiness).
- Affects: 9 loaded consumables, plus future wondrous items worded the same way.
- Reuses: the shared spell runtime (ADR-0017) and the S-134 permission model.
- Depends on: whichever of these spells the spell audit marks as supported.
- **Done when:** a check shows Potion of Speed applies the Haste effect for 10 rounds, the drinker is not concentrating, and the effect produces no lethargy turn when it ends. Potion of Mind Reading uses save DC 13 regardless of the drinker. Diminution's duration is rolled once (1d4 hours). The effect is not cast: it uses no slot, no components, and doesn't trigger "when a creature casts a spell" reactions. A spell the runtime does not support makes the potion refuse with that reason, instead of being consumed with no effect.

**S-258 (items-11) — Item-deployed hazard areas.**
- Source: Caltrops, Ball Bearings, Oil (pour + ignite), Hunting Trap, and Oil of Slipperiness (Grease mode).
- Affects: 5 entries (3 loaded).
- Reuses: the spell-zone hosts (combat_spell_zones.gd, spell_zone_terrain.gd), the Utilize action, and S-122 placement.
- Depends on: S-184 entry scopes (planned).
- **Done when:** a check shows Caltrops deployed with a Utilize action on a 5-ft square within 5 ft. The first creature to enter it that turn makes a DC 15 DEX save; on a failure it takes 1 Piercing and has Speed 0 until the start of its next turn, and a second entry in the same turn doesn't trigger it again. Recovering the Caltrops takes 10 minutes and returns the item. Ball Bearings cause Prone on a failed DC 10 save across a 10-ft square. Poured Oil burns only after it is lit.

### Batch 2 data divergences (conversion corrections; no proposal; not changed here)

| Item | Divergence |
|---|---|
| Net | modeled as a damaging weapon (1d4 bludgeoning) and sold in the shop |
| Lantern, Bullseye | consumable `vision_bonus`; no cone, no fuel |
| Lamp | no `light_source` |
| Crowbar | +2 Athletics instead of Advantage |
| Rope, Climber's Kit | +2 Athletics (climbing), not in the SRD |
| Healer's Kit | no stabilize route |
| Thieves' Tools | `enable_check` with no consumer found |
| Imported tools | no Utilize data |


## Batch 3 (2026-10-26): reconciler fix + missing magic items (rings, wands, boots, cloaks)

Same base commit `ede0a3c`, since origin/main had not moved. The registry hash is unchanged (`70a83cc7…845e`).

### B3-0: Reconciler fix

- **Spyglass fix:** `gear()` now accepts thousands separators in costs (`[\d,]+`), so Spyglass (1,000 GP) is parsed.
- **SRD entry counts:** now 105 gear/tool, 258 magic, 38 weapon and 13 armor. Missing: **46 equipment** and **192 magic**. Loaded-but-unmatched stays at 67.
- **Unchanged sections:** I compared the weapon diffs, magic rule fields, loaded list and hash in `reconciliation.json` against the batch-2 file (with `srd_entries`/`srd_missing` removed), and they are identical.
- **Magic item text export:** the reconciler now also writes `.artifacts/items-audit/srd_magic_text.json`, the full SRD body text for each magic item, sliced from `mi.xml` between consecutive item headings. The batch-2 `m2.txt` split truncated some entries, such as Boots of Speed and Ring of Animal Influence. Every clause below comes from this export.
- **Known limitation:** the text follows the PDF's reading order. Page numbers and the occasional table line run into the body text, and the tables were read by hand.

### B3-1: Host facts used for classification (read from code this batch)

- **Equipped-item benefits (S-049, verified VS-59):** `SourceBenefitRules.benefits_error` accepts **only `AC` and `speed` (walking) additions**, from 1 to 10, gated on attunement and S-203 suppression. No passive resistance, save bonus, roll mode, non-walking speed or condition immunity can ride an equipped copy.
- **Item-carried features:** `OwnedFeatureSources.item_features` gives an equipped, attuned copy its `features` with copy-scoped ids. Item activations therefore reuse:
  - the class-feature vocabulary (`COMMON_SELF_EFFECTS`);
  - exact-source pools (S-006), dawn and random recovery (S-063) and last-charge aftermath (S-060);
  - item casting permissions (S-134 and S-139).
  The precedent is the loaded Wand of Magic Missiles.
- **Resistance:** `Character.resist_damage` hard-codes each source (Rage, features, Protection from Energy, and so on), plus a `feature_uses["damage_resistances"]` list that no production code writes. There's no item route.
- **Divergence in loaded data (new):** `ring_of_protection` carries `armor_class_bonus` and `saving_throw_bonus` effects that **no production code consumes**. Its AC should come through `source_benefits` and its save bonus needs S-259 (items-12). It isn't exposed, because its value is 0 (B2-3).
- **Spells:** whether each named spell works is the spell audit's domain. Below, "S-134 conversion" means the item side (permission, DC, charges, recovery) has a verified host. It doesn't mean the spell itself is supported.

### B3-2: Entry-by-entry classification (47 entries: 21 rings, 12 wands, 14 boots/cloaks/slippers)

"Conv" means an existing host covers it and only data needs converting. Charge pools are always S-006 and dawn recovery S-063. A last-charge 1d20 crumble roll is S-060. All of these are verified, and I don't repeat them per row unless they're the only rule.

| Item | Clause → classification |
|---|---|
| Boots of Elvenkind | silent steps → ADR-0023 narrative; Advantage on Stealth → **S-259 (items-12)** (passive roll mode; S-091 host has no item carrier) |
| Boots of Levitation | cast Levitate on self at will → S-134 conv; self-only target restriction not confirmed in S-134 (**check**) |
| Boots of Speed | BA toggle doubles Speed; OA against you at Disadvantage; 10 min total, then until Long Rest → toggle/cumulative time S-064 conv; doubling Speed and OA Disadvantage → **S-259 (items-12)** |
| Boots of Striding and Springing | Speed floor 30; no encumbrance or Heavy Armor speed reduction → **S-259 (items-12)**; jump 30 ft for 10 ft of movement → S-239 (items-18 folded, wave 2); originally **jump host not located** (unreviewed) |
| Boots of the Winterlands | Cold Resistance → **S-259 (items-12)**; cold tolerance → S-201 (planned); ignore ice/snow Difficult Terrain → S-179 terrain costs conv |
| Winged Boots | 4 charges; Magic action: Fly 30 for 1 h → timed self-grant S-012 + S-179 conv (non-walking speed needs S-259 (items-12) payload); 30 ft/round descent on expiry → S-181 (planned) |
| Slippers of Spider Climbing | Climb Speed = Speed, hands free → **S-259 (items-12)** + S-179; not on slippery surfaces → S-179 surface rules conv |
| Cloak of Arachnida | Poison Resistance → **12**; spider climb → **12** + S-179; immune to webs, webs are Difficult Terrain → **12** (source-specific exemption); Web DC 13, double area, 1/dawn → S-134/S-126 conv + area change S-141 (planned) |
| Cloak of Displacement | attackers have Disadvantage → **12**; stops on damage until your next turn starts, suppressed at Speed 0 → S-203 suppression + S-072 termination conv |
| Cloak of Elvenkind | Disadvantage on Perception to perceive you; Advantage on Stealth → **12** (observer-side half: S-188/S-190, planned) |
| Cloak of Invisibility | 3 charges; Magic action: Invisible 1 h; ends on hood down or doffing → `grant_condition` + S-072 equipment termination conv; observer effects S-191 (planned) |
| Cloak of Protection | +1 AC → S-049 conv; +1 saves → **12** |
| Cloak of the Bat | Advantage on Stealth → **12**; Fly 40 only in Dim Light or Darkness → **12** + light predicate S-190 (planned); Polymorph into a Bat keeping Int/Wis/Cha, 1/dawn → S-134 + S-163 retained-stat projection conv |
| Cloak of the Manta Ray | breathe underwater → S-205 (planned); Swim 60 → **12** |
| Ring of Animal Influence | 3 charges; Animal Friendship, Fear (Beasts only), Speak with Animals at DC 13 → S-134/S-139/S-126 conv; Beast-only target filter → S-025 binding (verified) conv |
| Ring of Djinni Summoning | summon a Friendly obedient djinni within 120 ft, Concentration up to 1 h → S-154/S-155/S-156/S-158 conv; 24 h cooldown → S-014 conv; nonmagical if the djinni dies → S-203 destruction conv |
| Ring of Elemental Command | **Bane:** Advantage vs Elementals, they have Disadvantage vs you → **12**. **Compulsion:** DC 18 Wis, Charmed and you control its move/action → S-173 (planned). **Focus:** languages → S-218 (planned); resistance/immunity, fly + hover, swim → **12** + S-179; earth passage and shunt → S-180/S-181 (planned); breathing → S-205 (planned). **Spells:** 5 charges, DC 18, per-spell charge costs (Feather Fall 0) → S-134/S-139 conv |
| Ring of Evasion | 3 charges; Reaction after a failed DEX save → succeed instead → S-092 explicit success conv (Reaction budget S-160 is planned for off-turn types; **check**) |
| Ring of Feather Falling | descend 60 ft/round, no falling damage → S-181 (planned) |
| Ring of Free Action | Difficult Terrain costs nothing extra → S-179 conv; magic can't reduce Speeds or cause Paralyzed/Restrained → **12** (source-scoped condition and speed immunity) |
| Ring of Invisibility | Magic action: Invisible until removed, or a BA to end → `grant_condition` + S-072 conv; observer side S-191 (planned) |
| Ring of Jumping | Jump, self only → S-134 conv (self-only: **check**) |
| Ring of Mind Shielding | immune to thought, lie, alignment and type detection → S-195 (planned); telepathy only by permission → S-218 (planned); imperceptible toggle → ADR-0023 narrative; soul enters the ring on death → S-175 (planned) + **unreviewed** (no soul-in-item host) |
| Ring of Regeneration | regain 1d6 HP every 10 min while at ≥1 HP → **S-260 (items-13)**; regrow parts over 1d6+1 days → S-206/S-207 (planned) |
| Ring of Resistance | Resistance to one gem-determined type (1d10 table) → **12**; gem variant → S-255 (items-7) template |
| Ring of Shooting Stars | Dancing Lights and Light at will; Faerie Fire for 1 charge → S-134 conv. **Lightning Spheres** (2 charges, Concentration, moving spheres discharging on first approach, DC 15, damage by sphere count) → S-154 created actor + S-184 first approach (planned) + S-016 table lookup; **unreviewed** whether a moving discharge host exists. **Shooting Stars** (1–3 charges, one 15-ft cube per charge, DC 15, 5d4 Radiant) → **unreviewed** (item area-save activation host not located) |
| Ring of Spell Storing | stores up to 5 levels with the original caster's DC, attack and slot → S-150/S-151 (planned) |
| Ring of Spell Turning | Advantage on saves vs spells → **12**; a successful save vs a spell of level ≤7 negates it → S-116 conv; reflect a single-target spell as a Reaction, using the caster's own DC → S-133 (planned) |
| Ring of Swimming | Swim 40 → **12** |
| Ring of Telekinesis | cast Telekinesis → S-134 conv |
| Ring of the Ram | 1–3 charges: ranged spell attack +7, 2d10 Force per charge and a 5-ft push per charge → fixed-attack profile S-126 conv; **forced push host not located (unreviewed)**; break an object, Str +5 per charge → S-028 + S-032 conv |
| Ring of Three Wishes | 3 charges cast Wish → S-221 (planned); nonmagical after the last charge → S-060 conv |
| Ring of Warmth | Cold damage −2d8 → S-109 component reduction (verified) via a **12** item carrier; unharmed at ≤0 °F → S-201 (planned) |
| Ring of Water Walking | Water Walk on self → S-134 conv |
| Ring of X-ray Vision | Magic action: 30-ft X-ray for 1 min, material limits → S-195 (planned); reuse before a Long Rest needs DC 15 Con or Exhaustion → S-090 history with Long Rest reset conv |
| Wand of Binding | 7 charges; Hold Monster (5) or Hold Person (2) at DC 17 → S-134/S-139/S-126 conv |
| Wand of Enemy Detection | 1 charge: direction (not distance) of the nearest Hostile within 60 ft for 1 min, including Invisible or hidden ones; ends if you let go → S-194 (planned) + S-072 conv |
| Wand of Fear | Command (flee or grovel only, 1 charge) or Fear (60-ft Cone, 3) at DC 15 → S-134 conv; restricted Command options → S-085 conv (**check**) |
| Wand of Fireballs / Lightning Bolts | ≤3 charges; level 3 plus 1 per extra charge, DC 15 → S-134/S-139 conv (charge-scaled level: **check** against S-139 upcast rules) |
| Wand of Magic Detection | 3 charges, Detect Magic → S-134 conv |
| Wand of Paralysis | 1 charge: DC 15 Con or Paralyzed 1 min, repeat the save each turn → S-068 conv (activation as an item feature) |
| Wand of Polymorph / Web | Polymorph DC 15 / Web DC 13 → S-134 conv |
| Wand of Secrets | 1 charge: points to the nearest secret door or trap within 60 ft → S-194 (planned) |
| Wand of the War Mage +1/+2/+3 | bonus to spell attacks → S-022 flat bonus via a **12** carrier; ignore Half Cover → **cover host not located (unreviewed)**; wave 2 folds this into S-238's source cover exemption; +N variants → S-255 (items-7) |
| Wand of Wonder | 1d100 effect table, DC 15, 120-ft range floor → S-214/S-215 (planned) + S-223 partial support (planned); the child spells are the spell audit's |

**Batch 3 proposed slices**

**S-259 (items-12) — Passive equipped-item modifiers beyond AC and walking speed.**
- **Source:** the "while you wear/hold" clauses above.
- **Affects:** 19 of the 47 entries, plus loaded Ring of Protection.
  - Typed Resistance and Immunity.
  - Flat saving-throw bonus.
  - Scoped ability-check Advantage, and Disadvantage for observers.
  - Attack modes against or for the wearer, and Opportunity Attack Disadvantage.
  - Speed floor, doubling and immunity to encumbrance.
  - Climb, swim and fly speeds and hover.
  - Source-scoped condition and speed-reduction immunity.
  - Spell-attack bonus.
  - Damage reduction by dice.
- **Reuses:**
  - S-049/VS-59 carrier identity, attunement gating and S-203 suppression (extending `benefits_error`'s stat allowlist rather than adding a new channel).
  - S-091 roll modes, S-109 reduction, S-022 attack bonus and S-179 modes.
- **Depends on:** nothing planned. Observer-side clauses (Elvenkind) keep S-188/S-190 as their owners.
- **Done when:** a check shows:
  - An attuned, equipped Ring of Resistance (fire) halves a 10-Fire hit to 5 and leaves 10 Cold at 10.
  - Unequipping it, or ending the attunement, restores 10 Fire.
  - Cloak of Protection adds +1 to a DEX save and +1 AC, and two Cloaks of Protection on different characters don't affect each other.
  - Boots of Elvenkind give Advantage on Stealth only, not Acrobatics.
  - Ring of Swimming grants Swim 40 without changing walking Speed.
  - Ring of Free Action prevents Hold Person's Paralyzed but not a non-magical grapple's Restrained.
  - A save/load keeps all of this without turning it into permanent stats.
  - Ring of Protection's loaded AC and save bonuses take effect through this route.

**S-260 (items-13) — Periodic elapsed-time effects from a worn item.**
- **Source:** Ring of Regeneration, "regain 1d6 Hit Points every 10 minutes if you have at least 1 Hit Point".
- **Affects:** Ring of Regeneration. Unreviewed wondrous items are likely candidates, to be confirmed in batch 4.
- **Reuses:** S-064 cumulative active time (verified), S-049 carrier identity, `heal`, and the campaign clock.
- **Depends on:** none.
- **Done when:** a check shows that a wearer at 5/30 HP heals 1d6 after exactly 10 minutes of campaign time.
  - It heals 3×1d6 after 30 minutes, with each roll recorded once.
  - It doesn't heal at 0 HP, or while the ring is unequipped.
  - A save/load at minute 7 heals at minute 10, not minute 17.
  - Combat rounds count toward the 10 minutes, at 6 s per round.

### B3-3: Unreviewed magic items (145; family-level only from batch 1)

- **Armor (5):** Adamantine Armor; Armor, +1, +2, or +3; Armor of Resistance; Mithral Armor; Shield, +1, +2, or +3
- **Weapon (20):** Ammunition, +1, +2, or +3; Ammunition of Slaying; Berserker Axe; Dancing Sword; Defender; Dragon Slayer; Energy Bow; Flame Tongue; Frost Brand; Giant Slayer; Holy Avenger; Luck Blade; Nine Lives Stealer; Sword of Life Stealing; Sword of Sharpness; Sword of Wounding; Vicious Weapon; Vorpal Sword; Weapon, +1, +2, or +3; Weapon of Warning
- **Wondrous Item (112):** Amulet of Health; Amulet of Proof against Detection and Location; Amulet of the Planes; Apparatus of the Crab; Bag of Beans; Bag of Devouring; Bag of Holding; Bag of Tricks; Bead of Force; Bead of Nourishment; Belt of Dwarvenkind; Belt of Giant Strength; Bowl of Commanding Water Elementals; Bracers of Archery; Bracers of Defense; Brazier of Commanding Fire Elementals; Brooch of Shielding; Broom of Flying; Candle of Invocation; Cape of the Mountebank; Carpet of Flying; Censer of Controlling Air Elementals; Chime of Opening; Circlet of Blasting; Crystal Ball; Crystal Ball of Mind Reading; Crystal Ball of Telepathy; Crystal Ball of True Seeing; Cube of Force; Cubic Gate; Decanter of Endless Water; Deck of Illusions; Dimensional Shackles; Dragon Orb; Dust of Disappearance; Dust of Dryness; Dust of Sneezing and Choking; Efficient Quiver; Efreeti Bottle; Elemental Gem; Eversmoking Bottle; Eyes of Charming; Eyes of Minute Seeing; Eyes of the Eagle; Feather Token; Figurine of Wondrous Power; Folding Boat; Gauntlets of Ogre Power; Gem of Brightness; Gem of Seeing; Gloves of Missile Snaring; Gloves of Swimming and Climbing; Gloves of Thievery; Goggles of Night; Handy Haversack; Hat of Disguise; Headband of Intellect; Helm of Brilliance; Helm of Comprehending Languages; Helm of Telepathy; Helm of Teleportation; Horn of Blasting; Horn of Valhalla; Horseshoes of a Zephyr; Horseshoes of Speed; Instant Fortress; Ioun Stone; Iron Bands; Iron Flask; Lantern of Revealing; Mantle of Spell Resistance; Manual of Bodily Health; Manual of Gainful Exercise; Manual of Golems; Manual of Quickness of Action; Marvelous Pigments; Medallion of Thoughts; Mirror of Life Trapping; Mysterious Deck; Necklace of Adaptation; Necklace of Fireballs; Necklace of Prayer Beads; Pearl of Power; Periapt of Health; Periapt of Proof against Poison; Periapt of Wound Closure; Pipes of Haunting; Pipes of the Sewers; Portable Hole; Robe of Eyes; Robe of Scintillating Colors; Robe of Stars; Robe of the Archmagi; Robe of Useful Items; Rope of Climbing; Rope of Entanglement; Scarab of Protection; Sending Stones; Sovereign Glue; Sphere of Annihilation; Stone of Controlling Earth Elementals; Stone of Good Luck (Luckstone); Talisman of Pure Good; Talisman of the Sphere; Talisman of Ultimate Evil; Tome of Clear Thought; Tome of Leadership and Influence; Tome of Understanding; Universal Solvent; Well of Many Worlds; Wind Fan; Wings of Flying
- **Rod (7):** Immovable Rod; Rod of Absorption; Rod of Alertness; Rod of Lordly Might; Rod of Resurrection; Rod of Rulership; Rod of Security
- **Scroll (1):** Spell Scroll

> **Batch 4 correction:** B4-0 supersedes the B3-2 rows marked "S-134 conv" for fixed-DC, self-only, charge-scaled and option-restricted items. B3-3 below is the pre-batch-4 list, kept for history. See B4-3 for what is still unreviewed.

## Batch 4 — sub-item resolution and the remaining 145 magic items

Source text: srd_magic_text.json (the 145 entries in B3-3). The registry hash is unchanged (70a83cc7…845e). origin/main is ede0a3c and is already an ancestor of audit/items, so no rebase was needed. Only production `src/` was read; probes and checks were not counted as hosts.

### B4-0: The 11 open B3 sub-items, resolved against code

| # | Sub-item | Finding (file:line) | Resolution |
|---|---|---|---|
| 1 | Self-only item casting | S-134 `spell_permissions` (spell_permission_rules.gd:6–30) has ability, spells, charges, slot_payment_allowed, maximum_spell_level, allowed_components and spell_lists. There is no target restriction field. | **Gap → S-254 (items-14).** Batch 3's "S-134 conv" is wrong for Boots of Levitation, Ring of Water Walking, Mind Shielding (self) and similar items. |
| 2 | Reaction budget | `reaction_available` and the "reaction" cost exist (combat_turn_budget.gd). ReactionTriggers.EVENTS = on_attacked, on_hit_by_attack, on_damaged_by_creature, on_hit_with_attack (reaction_triggers.gd:18). There is no event for "you fail a save". | The budget is hosted. Attack-event reactions are conv (Gloves of Missile Snaring). The failed-save reaction (Ring of Evasion, Scarab-like) → **S-263 (items-17)**. S-160 isn't needed, because these spend the ordinary Reaction. |
| 3 | Command option restriction | The options are hard-coded in combat_hud.gd:1878 `["approach","drop","flee","grovel","halt"]` and chosen through spell_cast_choices.gd:203. There is no data field to restrict them. S-085 does not apply. | **Gap → S-254 (items-14)** (allowed-option subset). Affects Wand of Fear. |
| 4 | Charge-scaled upcast | The only charge→level route is hard-coded to `wand_of_magic_missiles` (combat_command.gd:35–52; spell_cast_resources.gd:124–135; it sets `_selected_spell_slot_level = charges`). S-134's `charges` is a fixed cost per policy, not tied to level. | **Gap → S-254 (items-14).** The Wand of Magic Missiles route is the model to generalize. Affects Wand of Fireballs, Lightning Bolts, Necklace of Fireballs and Robe of Stars. |
| 5 | Jump | The only host is the Jump spell's `jumping` condition: combat_state.gd:2404 `_can_use_spell_jump`, once per turn, needs remaining_speed ≥ 2, and sets `jump_spell_used_this_turn`. There are no general jump-distance rules. | Ring of Jumping = conv (S-134 casts Jump on self, but self-only → items-14). Boots of Striding and Springing's fixed jump → **S-239 (items-18 folded)**. |
| 6 | Forced push | The spell effect `{"type":"push","distance","on_failed_save"}` (spell_effect_application.gd:174–180) uses `push_combat_target`. | **Hosted** for spell-shaped payloads. Ring of the Ram and Horn of Blasting push → items-10 inline payload (see the items-10 amendment). |
| 7 | Cover | There is no cover computation anywhere in `src/`. `ignore_cover_on_save` is declared in shared_spell.gd but nothing reads it. | **Unhosted, out of the items domain** (a combat-rules gap). "Ignore Half Cover" on Wand of the War Mage has nothing to apply to until cover exists. It is not counted against items. |
| 8 | Ring of Shooting Stars spheres | There is no host for a moving, discharging light sphere. | **Gap → items-10 inline payload** for the lightning burst, plus S-154 (planned) for the controllable sphere actor. |
| 9 | Item area-save activations (non-spell) | Route (a) is Magic Missile only. Route (b) casts named spells. There is no host for an item-authored save effect with no named spell. | **Gap → items-10 amendment** (inline spell-shaped payload, not cast). |
| 10 | Soul-in-item | Only corpse_rules has the "soul_unavailable" restriction. Nothing stores a soul or creature inside an item. | **Unhosted.** Mirror of Life Trapping and Iron Flask capture are narrative, or wait on S-156/S-157 (planned). |
| 11 | Fixed item save DC / attack bonus | Spell DC = the caster's `save_dc`, replaceable only by an S-126 `attack_profile` spell scope (attack_profile_rules.gd:15–16, 234–246, scope `permission_sources`). Item features reach actor features through OwnedFeatureSources.item_features (owned_feature_sources.gd:49–58), but that function rewrites only `id` and `rule`, not `scope.permission_sources`. So an item can't name its own copy as the source. SPELL_ADD_KEYS has no spell attack key. | **Partial.** An actor-wide +N DC is conv (Robe of the Archmagi). A fixed DC scoped to the item's own spells, and any spell attack bonus, → **S-254 (items-14)** (self-copy scope) and items-12 (spell attack +N). |

**Corrections to the B3-2 rows:**
- Boots of Levitation, Ring of Mind Shielding (self part), Ring of Water Walking, Ring of Jumping: S-134 conv → **S-134 + items-14 (self-only)**.
- Wand of Fear: S-134 conv → **S-134 + items-14 (Command subset, fixed DC 15)**.
- Wand of Fireballs and Lightning Bolts: S-134 conv → **S-134 + items-14 (charge→level, fixed DC 15)**.
- Wand of Paralysis: S-134 conv → **items-10 inline payload + items-14 fixed DC 15** (Paralysis is not a named spell).
- Ring of Evasion: check → **S-092 + S-263 (items-17)**.
- Ring of the Ram: check → **items-10 inline payload (push) + items-14 (charge-scaled dice)**.
- Ring of Shooting Stars: check → per #8.
- Boots of Striding and Springing: check → **S-049 speed floor (items-12) + S-239 (items-18 folded)**.
- Wand of the War Mage: check → **items-12 spell attack +N**. The cover clause is unhosted (#7).

### B4-1: Host facts (new this batch)

- **`weapon_bonus`** (magic_property_rules.gd:37–50): an integer `{attack, damage}` 0..3 on magic weapons. It is consumed for the exact equipped copy at combat_action.gd:1141 and gated by active(). This is the verified host for every +N weapon clause. MagicPropertyRules.PROPERTIES = source_benefits, spell_permissions, incoming_negation_rule, attachment_sets, item_effects, features, weapon_bonus.
- **S-126 weapon profile** (attack_profile_rules.gd:12–13): replace ability, damage_die, damage_type(+choices), attack_bonus, save_dc, range; add attack_bonus, damage_bonus, save_dc, range. A hit-window damage-type choice exists (S-127). There is **no extra-dice-on-hit field, no creature-type condition, and no natural-20 trigger**.
- **SourceBenefitRules** (S-049) carries only AC and walking speed. Score setting (S-039, VS-46) exists, but no item carries it, so it goes under items-12.
- **`evasion`** exists only as a feature effect for spell DEX half-on-save (spell_save_resolver.gd:208).
- **Not found:** a critical-hit-to-normal rule, a generic on-hit extra damage rider, vehicles, item-stored creatures, cover, and general jump.

### B4-2: Clause classification

Key:
- **conv** = the host exists; data only.
- **items-N** = an items-N proposal (now an S-ID; see the wave 2 map in vocabulary-slices.md).
- **S-xxx (planned)** = a shared slice not yet built.
- **narr** = narrative or out of the combat sandbox; not engine work.
- Every row was reviewed clause by clause against the srd_magic_text.json text unless it is marked *partial-review*.

#### Wondrous items (112)

| # | Item | Clauses → host |
|---|---|---|
| 1 | Amulet of Health | CON = 19 → items-12 (S-039 score setting) + items-5 attunement |
| 2 | Amulet of Proof against Detection | hidden from divination → S-187–S-195 (planned) |
| 3 | Amulet of the Planes | Plane Shift + DC 15 Int check + random plane → S-221/S-177 (planned); narr |
| 4 | Apparatus of the Crab | vehicle, levers, claws → narr / vehicle unhosted |
| 5 | Bag of Beans | dump → items-10 inline (fire 5d4, DC 15 DEX); planted-bean table → S-016 + narr |
| 6 | Bag of Devouring | creature-in-bag devour → unhosted (#10); container → S-196 |
| 7 | Bag of Holding | compartment 500 lb/64 ft³ → S-196 (volume enforced when declared, container_rules.gd:87; corrected in batch 5); rupture/planar gate → S-177 (planned) |
| 8 | Bag of Tricks | 3/dawn creature table → S-154–S-158 (planned) + S-016 + S-014 |
| 9 | Bead of Force | 10-ft sphere 5d4 Force, DEX DC 15, globe trap → items-10 inline + items-11 |
| 10 | Bead of Nourishment | replaces a day of food → S-200 (planned) |
| 11 | Belt of Dwarvenkind | CON +2 max 20, darkvision, Poison resistance, poison-save Advantage, Dwarvish → items-12 |
| 12 | Belt of Giant Strength | STR = 21/23/25/27/29 → items-12 (S-039) |
| 13 | Bowl of Commanding Water Elementals | summon 1/day → S-154–S-158 + S-014 |
| 14 | Bracers of Archery | bow proficiency + damage +2 for bows → items-12 (proficiency) + S-126 add damage_bonus (conv, scope properties) |
| 15 | Bracers of Defense | +2 AC if no armor or shield → S-049 + items-3 predicate |
| 16 | Brazier of Commanding Fire Elementals | as 13 |
| 17 | Brooch of Shielding | Force resistance; Magic Missile immunity → items-12 + S-116 (conv, incoming_negation_rule) |
| 18 | Broom of Flying | Fly 50 (30 if over 200 lb), command word → S-179 + items-12 |
| 19 | Candle of Invocation | alignment-scoped Advantage, Gate → items-12 + narr |
| 20 | Cape of the Mountebank | Dimension Door 1/day + smoke → S-134 + items-14 self-only + S-187 (planned) |
| 21 | Carpet of Flying | as 18 (vehicle-like capacity) |
| 22 | Censer of Controlling Air Elementals | as 13 |
| 23 | Chime of Opening | open lock, 10 charges → narr (no lock model) |
| 24 | Circlet of Blasting | Scorching Ray +5 attack 1/dawn → S-134 + items-14 fixed attack |
| 25 | Crystal Ball | Scrying DC 17 → S-134 + items-14 fixed DC; narr |
| 26 | Crystal Ball of Mind Reading | + Detect Thoughts DC 17 → as 25 |
| 27 | Crystal Ball of Telepathy | + Suggestion DC 17 → as 25 |
| 28 | Crystal Ball of True Seeing | + truesight 120 → as 25 + items-12 sense |
| 29 | Cube of Force | 36 charges, face table → items-11 barrier + items-14 charge cost; *partial-review*: face-specific blocking is unhosted |
| 30 | Cubic Gate | Plane Shift / Gate → narr / S-221 |
| 31 | Decanter of Endless Water | geyser 30 ft, STR DC 13 or Prone → items-10 inline |
| 32 | Deck of Illusions | illusion card → S-187 (planned) |
| 33 | Dimensional Shackles | Restrained + teleport block, escape DC 30 → S-168 + narr |
| 34 | Dragon Orb | spells at DC 18, dragon call → items-14 + narr |
| 35 | Dust of Disappearance | invisible 2d4 min, area → grant_condition + items-10 |
| 36 | Dust of Dryness | absorb water / water elemental 10d6 CON DC 13 → items-10 inline |
| 37 | Dust of Sneezing and Choking | 30-ft CON DC 15 incapacitated, repeat saves → items-10 inline |
| 38 | Efficient Quiver | three compartments → S-196 (conv-check) |
| 39 | Efreeti Bottle | d100 table, efreeti ally → S-016 + S-154 |
| 40 | Elemental Gem | summon elemental → S-154 |
| 41 | Eversmoking Bottle | heavily obscured cloud → items-11 + S-187 |
| 42 | Eyes of Charming | Charm Person DC 13, 3 charges → S-134 + items-14 fixed DC |
| 43 | Eyes of Minute Seeing | Investigation Advantage close → items-12 |
| 44 | Eyes of the Eagle | Perception Advantage (sight) → items-12 |
| 45 | Feather Token | anchor/bird/fan/swan/tree/whip variants → per-variant: S-154 (bird, swan, whip), narr |
| 46 | Figurine of Wondrous Power | creature form per figurine, N-day cooldown → S-154 + S-014 (day cooldown check) |
| 47 | Folding Boat | vehicle → narr |
| 48 | Gauntlets of Ogre Power | STR = 19 → items-12 |
| 49 | Gem of Brightness | 50 charges: light / blind ray CON DC 15 / cone → items-10 inline + items-14 charges |
| 50 | Gem of Seeing | truesight 120 ft 10 min, 3 charges → S-012 timed + items-12 sense |
| 51 | Gloves of Missile Snaring | Reaction on hit, reduce 1d10 + Dex → ReactionTriggers on_hit_by_attack (conv) + S-109 reduction |
| 52 | Gloves of Swimming and Climbing | climb/swim speed = speed, +5 Athletics → items-12 + S-179 |
| 53 | Gloves of Thievery | +5 Sleight of Hand, lock picking → items-12 |
| 54 | Goggles of Night | darkvision 60 → items-12 |
| 55 | Handy Haversack | compartments → S-196 (volume limits enforced when declared; corrected in batch 5) |
| 56 | Hat of Disguise | Disguise Self → S-134 + items-14 self-only |
| 57 | Headband of Intellect | INT = 19 → items-12 |
| 58 | Helm of Brilliance | gems cast spells DC 18; Fire aura +1d6; Fire resistance; undead aura → items-14 + items-12 + items-13 |
| 59 | Helm of Comprehending Languages | Comprehend Languages at will → S-134 |
| 60 | Helm of Telepathy | Detect Thoughts / Suggestion DC 13 → S-134 + items-14 |
| 61 | Helm of Teleportation | Teleport, 3 charges → S-134 (conv, charges) |
| 62 | Horn of Blasting | 30-ft cone 5d6 Thunder, CON DC 15, deafened, 20% explode → items-10 inline + S-016 |
| 63 | Horn of Valhalla | spirit warriors 7-day cooldown → S-154 + S-014 |
| 64 | Horseshoes of a Zephyr | no ground trace, travel → narr |
| 65 | Horseshoes of Speed | +30 walking speed (mount) → S-049 (conv on mount) |
| 66 | Instant Fortress | structure → narr |
| 67 | Ioun Stone | per type: stat +2 max 20, AC +1, saves +1, PB +1, regeneration → items-12/items-13; Absorption → S-116 + S-006 budget; Sustenance → S-200 |
| 68 | Iron Bands | ranged attack, Restrained, DC 20 escape → items-10 inline + S-168 |
| 69 | Iron Flask | trap creature → unhosted (#10) |
| 70 | Lantern of Revealing | reveal invisible 30 ft → S-187 (planned) |
| 71 | Mantle of Spell Resistance | Advantage on saves vs spells → items-12 |
| 72 | Manual of Bodily Health | CON +2 max 30 after 48 h over 6 days → **S-262 (items-16)** |
| 73 | Manual of Gainful Exercise | STR → items-16 |
| 74 | Manual of Golems | golem crafting → S-198 (planned) / narr |
| 75 | Manual of Quickness of Action | DEX → items-16 |
| 76 | Marvelous Pigments | create objects → narr |
| 77 | Medallion of Thoughts | Detect Thoughts DC 13 → as 60 |
| 78 | Mirror of Life Trapping | trap → unhosted (#10) |
| 79 | Mysterious Deck | card table, Wish-level effects → S-016 + narr |
| 80 | Necklace of Adaptation | breathe anywhere, gas/inhaled save Advantage → S-205 + items-12 |
| 81 | Necklace of Fireballs | bead = Fireball, + per extra bead 1d6, DC 15 → items-14 (count-scaled) |
| 82 | Necklace of Prayer Beads | bead spells, Bonus Action, own DC → S-134 + S-140 casting_time (conv) |
| 83 | Pearl of Power | regain a slot ≤3, 1/dawn → restore_resource (conv-check) |
| 84 | Periapt of Health | heal 2d4+2 1/dawn → self heal effect (conv) |
| 85 | Periapt of Proof against Poison | Poison immunity → items-12 |
| 86 | Periapt of Wound Closure | stabilize at start of turn; double HD healing → items-12 (death-save hook check) |
| 87 | Pipes of Haunting | 30-ft WIS DC 15 Frightened → items-10 inline + items-14 charges |
| 88 | Pipes of the Sewers | rat swarms → S-154 |
| 89 | Portable Hole | compartment, suffocation, planar → S-196 + S-177 (volume enforced when declared; corrected in batch 5) |
| 90 | Robe of Eyes | darkvision 120, see invisible/ethereal, Perception Advantage → items-12 |
| 91 | Robe of Scintillating Colors | 20 ft WIS DC 15 Stunned, attack Disadvantage → items-10 inline + items-14 charges |
| 92 | Robe of Stars | saves +1; Magic Missile at level 5 (stars) → items-12 + items-14 fixed level |
| 93 | Robe of the Archmagi | AC 15+Dex, spell-save Advantage, DC/attack +2 → items-12 (S-039 base AC) + S-126 add save_dc (conv) + items-12 spell attack |
| 94 | Robe of Useful Items | patch → object table → narr / S-016 |
| 95 | Rope of Climbing | animated rope → narr |
| 96 | Rope of Entanglement | Restrained, escape DC 15 → items-10 inline + S-168 |
| 97 | Scarab of Protection | spell-save Advantage; turn death-effect save success, 12 charges → items-12 + items-17 (S-092) |
| 98 | Sending Stones | Sending → S-134 (conv) |
| 99 | Sovereign Glue | object adhesion → narr |
| 100 | Sphere of Annihilation | move sphere, 4d10 Force / destroy → unhosted; narr |
| 101 | Stone of Controlling Earth Elementals | as 13 |
| 102 | Luckstone | +1 ability checks and saves → items-12 |
| 103 | Talisman of Pure Good | fissure DEX DC 20; touch damage; +2 spell attack → items-10 inline + items-13 + items-12 |
| 104 | Talisman of the Sphere | double Arcana check to control Sphere → items-12; sphere unhosted |
| 105 | Talisman of Ultimate Evil | as 103 |
| 106 | Tome of Clear Thought | INT → items-16 |
| 107 | Tome of Leadership and Influence | CHA → items-16 |
| 108 | Tome of Understanding | WIS → items-16 |
| 109 | Universal Solvent | dissolve glue → narr |
| 110 | Well of Many Worlds | portal → narr |
| 111 | Wind Fan | Gust of Wind DC 13, failure chance → S-134 + items-14 + S-016 |
| 112 | Wings of Flying | Fly 60 for 1 h, 1d12 h recharge → S-179 + S-012 + S-014 |

#### Rods (7)

| # | Item | Clauses → host |
|---|---|---|
| 113 | Immovable Rod | fixed in place, 8000 lb → narr |
| 114 | Rod of Absorption | Reaction absorb a targeting spell; levels pool → S-116 + S-006 + ReactionTriggers spell event (missing → items-17 extension) |
| 115 | Rod of Alertness | initiative Advantage; truesight timed; Bless-like aura; spells → items-12 + S-134 |
| 116 | Rod of Lordly Might | +3 mace (weapon_bonus conv) + form switching (S-164) + on-hit paralyze/drain/terrify → items-15 |
| 117 | Rod of Resurrection | Heal / Resurrection charges → S-134 (conv) |
| 118 | Rod of Rulership | 120-ft WIS DC 15 charm → items-10 inline |
| 119 | Rod of Security | demiplane → S-177 / narr |

#### Weapons (20)

| # | Item | Clauses → host |
|---|---|---|
| 120 | Ammunition, +1/+2/+3 | weapon_bonus on ammunition → items-1 + items-7 |
| 121 | Ammunition of Slaying | creature-type CON DC 17, 6d10 → items-15 + items-1 |
| 122 | Berserker Axe | weapon_bonus (conv) + HP max +1/level (items-12) + curse (S-202 planned) |
| 123 | Dancing Sword | hovers and attacks → S-154 (partial) |
| 124 | Defender | weapon_bonus +3, shift to AC per turn → items-15 |
| 125 | Dragon Slayer | +1 (conv); +3d6 vs Dragons → items-15 |
| 126 | Energy Bow | +1 (conv); energy arrow damage type → S-127 choice (conv); ladder/shot extras → narr |
| 127 | Flame Tongue | toggle +2d6 Fire, light → items-15 |
| 128 | Frost Brand | +1d6 Cold, Fire resistance, extinguish → items-15 + items-12 |
| 129 | Giant Slayer | +1 (conv); +2d6 vs Giants and prone STR DC 15 → items-15 |
| 130 | Holy Avenger | +3 (conv); +2d10 Radiant vs Fiend/Undead; aura save Advantage → items-15 + items-12 |
| 131 | Luck Blade | +1 (conv); saves +1 → items-12; luck reroll → S-226 (planned); Wish → narr |
| 132 | Nine Lives Stealer | +2 (conv); nat-20 kill ≤100 HP CON DC 15, charges → items-15 |
| 133 | Sword of Life Stealing | nat-20 +10 Necrotic + temp HP → items-15 |
| 134 | Sword of Sharpness | max damage vs objects; nat-20 +14 Slashing / limb → items-15 |
| 135 | Sword of Wounding | 1d4 Necrotic per hit stacking, no regain, repeat save → items-15 + items-13 |
| 136 | Vicious Weapon | nat-20 +2d6 → items-15 |
| 137 | Vorpal Sword | +3 (conv), ignore Slashing resistance (S-110 conv-check), nat-20 decapitate → items-15 |
| 138 | Weapon, +1/+2/+3 | weapon_bonus (conv) + items-7 template |
| 139 | Weapon of Warning | initiative Advantage aura, wake allies → items-12 |

#### Armor (5)

| # | Item | Clauses → host |
|---|---|---|
| 140 | Adamantine Armor | critical → normal hit → items-12 (incoming crit negation) + items-7 |
| 141 | Armor, +1/+2/+3 | S-049 AC + items-7 (conv) |
| 142 | Armor of Resistance | one damage resistance → items-12 + items-7 |
| 143 | Mithral Armor | no Stealth Disadvantage / STR requirement → items-3 + items-7 |
| 144 | Shield, +1/+2/+3 | S-049 AC (conv) |

#### Scroll (1)

| # | Item | Clauses → host |
|---|---|---|
| 145 | Spell Scroll | S-254 (items-6) (already proposed; fixed DC table → also items-14) |

### B4-3: Amendments to existing proposals

- **items-10 amendment (inline payload):** besides named-spell effects, items-10 accepts an inline spell-shaped payload authored on the item (area, save ability, fixed DC, damage, conditions, push). It is resolved through the shared spell runtime as "not cast". **Additional done-when:** a check shows Horn of Blasting makes a 30-ft cone with a CON DC 15 save. A creature that fails takes 5d6 Thunder and is Deafened; one that succeeds takes half and is not Deafened. No slot is spent, no Counterspell is offered, and Ring of the Ram pushes a failed target 5 ft per charge using the existing push effect.
- **items-12 scope additions:** ability-score setting (S-039), capped increases (max 20), save, check and spell-save Advantage, senses, resistances and immunities, skill and initiative modifiers, spell attack +N, incoming crit → normal, HP max per level, and weapon proficiency. **Additional done-when:** a check shows Gauntlets of Ogre Power set STR 8 → 19 but leave STR 20 unchanged. Adamantine Armor turns a critical hit into a normal hit. Both stop applying when the item is unequipped.

### B4-4: New proposed slices

**S-254 (items-14) — Generic item-activated spell casting with item overrides.**
- **Source:** Wands of Fireballs, Lightning Bolts and Fear; Necklace of Fireballs; Circlet of Blasting; Crystal Balls; Eyes of Charming; Helm of Telepathy; Medallion; Dragon Orb; Robe of Stars; Wind Fan; Hat of Disguise; Cape of the Mountebank; Boots of Levitation; Ring of Water Walking and Jumping.
- **Affects:** about 25 items.
- **Reuses:** the wand_of_magic_missiles charge→level route (combat_command.gd:35–52; spell_cast_resources.gd:124–135), generalized from its hard-coded ID. Also S-134 permissions, S-126 save_dc replace (with a self-copy `permission_sources` rewrite in OwnedFeatureSources.item_features), S-139, S-006 charges and S-060.
- **Adds:** per-permission `target: self`, `charges_to_level` / per-extra-charge dice, fixed `save_dc` / `spell_attack`, and `allowed_options` (Command).
- **Depends on:** none.
- **Done when:** a check shows Wand of Fireballs spending 3 charges casts Fireball at level 5 with DC 15 regardless of the wielder's own DC, and refuses 4 charges when only 3 remain. Wand of Fear's Command offers only flee and grovel. Boots of Levitation refuse any target but the wearer. Circlet of Blasting's Scorching Ray uses +5 to hit. Wand of Magic Missiles still behaves exactly as before.

**S-261 (items-15) — Weapon-copy hit and crit riders.**
- **Source:** Flame Tongue, Frost Brand, Dragon Slayer, Giant Slayer, Holy Avenger, Vicious, Life Stealing, Sharpness, Vorpal, Nine Lives Stealer, Sword of Wounding, Defender, Ammunition of Slaying and Rod of Lordly Might.
- **Affects:** 14 entries.
- **Reuses:** weapon_bonus (combat_action.gd:1141), the S-126 profile (scope/kind), S-127 hit window, S-068 creature types, S-016 and S-006 charges.
- **Adds:** extra dice on hit, creature-type conditions, natural-20 triggers, an on-hit save rider, and a Defender bonus transfer to AC per turn.
- **Depends on:** items-7.
- **Done when:** a check shows a +1 Dragon Slayer hit on a Dragon adds +1 and 3d6 of the weapon's type, while the same hit on a Humanoid adds +1 only. A Vicious Weapon adds 2d6 only on a natural 20. Defender with 2 bonus moved to AC gives +1/+1 attack and damage and +2 AC until the start of the next turn. Flame Tongue adds 2d6 Fire only while it is ignited. Everything is tied to the exact copy and stops when the copy is unequipped.

**S-262 (items-16) — Study items with permanent score increases.**
- **Source:** Manuals of Bodily Health, Gainful Exercise and Quickness of Action; Tomes of Clear Thought, Leadership and Influence, and Understanding.
- **Affects:** 6 entries.
- **Reuses:** S-039 score caps (raised to a maximum of 30), campaign time (S-064), and S-014 (the item loses its magic for 100 years).
- **Depends on:** S-198/S-199 downtime (planned) for the 48-hours-over-6-days activity.
- **Done when:** a check shows that completing 48 hours of study within 6 days with the Manual of Gainful Exercise raises STR 18 → 20 and the cap to 30. Interrupted study grants nothing. Afterwards the manual grants nothing to a second reader. The increase survives save/load, and unequipping or dropping the manual doesn't remove it.

**S-263 (items-17) — Item reactions on the wielder's own save.**
- **Source:** Ring of Evasion, Scarab of Protection and Rod of Absorption.
- **Affects:** 3 entries.
- **Reuses:** reaction_available, ReactionTriggers (reaction_triggers.gd:18), S-092 outcome forcing, S-116 negation and S-006 charges.
- **Adds:** an `on_failed_save` event (with ability filter) and an `on_targeted_by_spell` event.
- **Depends on:** none.
- **Done when:** a check shows a wearer who fails a DEX save against Fireball can spend the Reaction and 1 charge to succeed instead, taking half damage. A second failed save in the same round is not offered (no Reaction). A CON save is not offered. With 0 charges, nothing is offered.

**S-239 (items-18 folded) — Item-granted fixed jumps.** *(Wave 2: folded into S-239's jumping finish line as an item-granted fixed jump.)*
- **Source:** Boots of Striding and Springing.
- **Affects:** 1 entry; general jump rules are out of the items domain.
- **Reuses:** the `jumping` movement path (combat_state.gd:2404–2409).
- **Depends on:** none.
- **Done when:** a check shows the wearer jumps up to 30 ft for 10 ft of movement, is refused with less than 10 ft remaining, and loses the ability when the boots are removed.

**Planned vs new:** the batch 3 plan named items-14 (item casting), 15 (non-spell area activations) and 16 (weapon riders), and possibly 17 (crit negation and Missile Snaring).
- Non-spell area activations folded into the **items-10 amendment** instead of a new 15.
- Weapon riders became **items-15**.
- Crit negation folded into **items-12**.
- Missile Snaring turned out to be conv (on_hit_by_attack + S-109).
- New, unplanned: **items-16** (study), **items-17** (own-save reactions) and **items-18** (jumps).

### B4-5: Still unreviewed or partial inside these 145

- *partial-review:* Cube of Force face blocking (29), and Dancing Sword actor behaviour (123).
- *conv-check* (host named, data not tried): Efficient Quiver S-196, Figurine day-scale S-014, Pearl of Power restore_resource, Vorpal S-110 bypass, Periapt of Wound Closure death-save hook, and Robe of the Archmagi S-126 add save_dc through an item feature.
- **narr** entries (about 20) were classified but get no engine work.

## Batch 5 — loaded SRD magic records, the 49 shells, the data spike, gear leftovers

origin/main is still ede0a3c, which is an ancestor of audit/items, so no rebase was needed. The registry hash is unchanged. Only production `src/` was read. "Spike" here means a read-only check of the code and validators. No content was edited, and nothing was run in-engine (no Godot binary on the box).

### B5-1: The 94 loaded SRD magic records

| Group | Count | Status |
|---|---|---|
| Records with rule fields | 10 | Clause by clause; see B5-2 |
| Equippable shells (stub: weapon 23, armor 19, shield 6, tool 1) | 49 | Clause by clause; see B5-3 |
| Stub consumables | 35 | Already covered by the B2 refused-consumable pass. `Inventory.consume` refuses an empty `effects` (inventory.gd:308–325). |

### B5-2: The 10 records with rule fields, checked against their hosts

| Record | Data | SRD 5.2.1 | Verdict |
|---|---|---|---|
| potion_healing / greater / superior / supreme | heal 2d4+2 / 4d4+4 / 8d4+8 / 10d4+20; `action_cost: action` | the same dice. A Bonus Action to drink, or to administer to a creature within 5 ft. | **Dice OK. D-3:** the action cost is wrong (Action vs Bonus Action), and the administer-to-another clause is missing. |
| potion_of_poison | apply_condition poisoned, duration 10 | 4d6 Poison, a CON DC 13 save, Poisoned for 1 hour | **D-2:** the damage and save are missing, and the duration is wrong (10 vs 1 hour). |
| potion_of_poison_resistance | apply_condition **poisoned**, 10 | Potion of Resistance (Poison): Resistance for 1 hour | **D-1: the effect is inverted.** It poisons the drinker. Fix → items-9. |
| (all 6 above) | two records share each ID in imported_magic_consumables.json (2014 and 2024 text) | — | **D-4:** duplicate IDs. Which copy wins depends on load order; confirm in DataLoader. |
| ring_of_protection | `effects: armor_class_bonus 1, saving_throw_bonus 1` | +1 AC and saves | **Values OK, but the host is branched on the item ID** (inventory.gd:538 `magic_item_saving_bonus`, inventory_copies.gd:145, container_rules.gd:292). Nothing in production reads those `effects` types. **D-5** → generalize under items-12. |
| staff_of_power | +2/+2 weapon_bonus, AC +2 source_benefits, 20 charges, recovery 6–20, last-charge degrade keeping weapon_bonus | also +2 saves and +2 spell attack; a 9-spell charge table; recovery **2d8+4**; on a 20 it regains 1d8+2; Retributive Strike | **weapon_bonus, AC and degrade: conv, match.** **D-6:** the saves bonus (items-12), the spell attack bonus (items-12), `spell_permissions` (S-134 conv, levelled versions → items-14) and Retributive Strike (items-10 inline) are missing. The recovery distribution is wrong → items-20. |
| staff_of_striking | +3/+3, 10 charges, recovery 5–10, last-charge nonmagical | the same, plus spend up to 3 charges on a hit for +1d6 Force each | **Match** for the fields present. 1d6+4 equals uniform 5–10. **D-7:** the on-hit charge rider is missing → items-15. |
| wand_of_magic_missiles | 7 charges, recovery 2–7, activation 1–3 charges | the same; crumbles on a 1 after the last charge | **The activation matches the hard-coded host.** 1d6+1 equals uniform 2–7. **D-8:** `last_charge_aftermath` (destroy on 1) is missing, although LastChargeRules hosts it (data_loader.gd:614) → conv. |

Charge-recovery host: inventory.gd:557–564 rolls a **uniform** value from minimum to maximum. That is exact for one die plus a constant (1d6+1, 1d6+4, 1d3) and wrong for multi-die expressions (2d8+4). → S-265 (items-20).

### B5-3: The 49 equippable shells, clause by clause

All 49 have no rule fields, so in the engine today every one behaves as its base item. Hosts for the clauses:

| Shell | Clauses → host |
|---|---|
| Animated Shield | Bonus Action hover for 1 min, hands free → S-154 (planned) / S-012; ends on Incapacitated → partial |
| Armor of Invulnerability | B/P/S resistance → items-12; 10-min immunity 1/dawn → S-012 + mode_choice uses_per dawn (conv) |
| Armor of Vulnerability ×3 | resistance → items-12; curse + vulnerability → S-202 (planned) + items-12 |
| Arrow-Catching Shield | +2 AC vs ranged → items-12 (conditional AC); Reaction to become the target → items-17 extension (`on_attacked` exists; target swap is new) |
| Dagger of Venom | +1 (weapon_bonus conv); 1/dawn coat, next hit CON DC 15 2d10 + Poisoned → items-15 + S-076 (planned) |
| Demon Armor | +1 AC (S-049 conv); unarmed 1d8 Slashing +1 → S-126 scope kind unarmed (check); curse → S-202; Disadvantage vs demons → items-12 |
| Dragon Scale Mail ×10 | +1 AC conv; breath-save Advantage + one resistance → items-12; dragon sense → narr |
| Dwarven Plate | +2 AC conv; Reaction to cut forced movement by 10 ft → items-17 extension (no forced-movement event) |
| Dwarven Thrower | +3 conv; Thrown 20/60 → items-2 + items-7; +1d8 (2d8 vs Giant) on a ranged hit → items-15; returns → items-1 |
| Elven Chain | +1 AC conv; counts as trained → items-3 |
| Glamoured Studded Leather | +1 AC conv; appearance → narr |
| Hammer of Thunderbolts | +1 conv; 5 charges thrown, 30-ft CON DC 17 Stun → items-15 + items-10 inline; returns → items-1 |
| Hat of Many Spells | focus → items-12; unknown-spell attempt + d100 → S-016 + narr-heavy; *partial-review* (text truncated past 700 chars) |
| Javelin of Lightning | damage type → S-127 conv; Line 4d6 DEX DC 13 1/dawn → items-10 inline |
| Mace of Disruption | +2d6 vs Fiend/Undead, destroy at ≤25 HP WIS DC 15 → items-15; light → S-187 (planned) |
| Mace of Smiting | +1 (+3 vs Construct) → weapon_bonus + items-15 conditional; nat-20 +7/14 → items-15 |
| Mace of Terror | 3 charges, 30-ft WIS DC 15 Frightened with flee behaviour → items-10 inline + items-14 charges; flee AI → narr/unhosted |
| Oathbow | sworn enemy for 7 days: Advantage, no cover, +3d6 → items-15 + **items-19** (7-day cooldown); cover → unhosted (B4-0 #7) |
| Plate Armor of Etherealness | Etherealness 1/dawn, ends on removal → S-134 + items-14 (self, end-on-unequip) |
| Quarterstaff of the Acrobat | +2 conv; form switching → S-164; light → S-187; *partial-review* (text truncated) |
| Scimitar of Speed | +2 conv; one Bonus Action attack per turn → unhosted for item copies (no item-granted bonus-action attack); listed under items-15 |
| Sentinel Shield | Initiative + Perception Advantage → items-12 |
| Shield of Missile Attraction | ranged resistance → items-12; curse redirect → S-202 + items-17 extension |
| Shield of the Cavalier | +2 AC conv; Forceful Bash swing → items-8-like attack replacement + push (spell push host) ; *partial-review* (text truncated) |
| Spellguard Shield | spell-save Advantage + spell attacks against you at Disadvantage → items-12 |
| Staff of Charming | spells 1 charge → S-134 conv; reflect/resist enchantment → items-17 |
| Staff of Fire / Frost | resistance → items-12; spell table → S-134 conv; destroy on a 1 → LastChargeRules conv |
| Staff of Healing | Cure Wounds charges by level → items-14 (charge→level); others S-134 conv; vanish → conv |
| Staff of Swarming Insects | 30-ft obscuring cloud → items-11 + S-187; spells → S-134 |
| Staff of the Magi | +2 conv; spell attack +2 → items-12; spell-save Advantage → items-12; absorption → items-17 (`on_targeted_by_spell`) + S-006; Retributive Strike → items-10; *partial-review* (text truncated) |
| Staff of the Python | becomes a snake → S-154 / S-164 |
| Staff of the Woodlands | +2 conv; spell attack +2 → items-12; spells → S-134; Tree Form → narr |
| Staff of Thunder and Lightning | +2 conv; five 1/dawn powers (2d6 Lightning, Stun DC 17, Lightning Bolt, Thunderclap, Thunder and Lightning) → items-15 + items-10 inline + S-134 |
| Staff of Withering | 3 charges, +2d10 Necrotic + CON DC 15 Disadvantage for 1 h → items-15 |
| Sun Blade | Bonus Action blade, Finesse, proficiency mapping, Radiant +2, +1d8 vs Undead, sunlight → S-164 + S-126 type replace (conv) + items-15 + S-187 |
| Thunderous Greatclub | STR 20 floor → items-12 (S-039); +1d8 Thunder → items-15; Clap cone STR DC 15 Prone → items-10 inline |
| Trident of Fish Command | Dominate Beast DC 15, 3 charges, Beast with a Swim Speed only → S-134 + items-14 (fixed DC, target predicate) |

### B5-4: Data spike on the host-named-but-untried items from B4-5 (read-only)

| Item | Host checked | Result |
|---|---|---|
| Efficient Quiver | S-196 ContainerRules: compartments with KEYS id, item_types, max_count, max_weight, **max_volume** (container_rules.gd:8–24, 87) | **conv.** Three compartments with count limits fit. **Correction to B4:** volume *is* validated (line 87), so "volume not enforced" in B4-2 rows 7/55/89 is wrong; it is enforced when data declares it. |
| Figurine of Wondrous Power | item power `uses_per` is accepted only as "dawn" for item powers (feature_mode_rules.gd:64; owned_feature_sources.gd:227, 285) | **Not hosted:** N-day cooldowns are missing → **S-264 (items-19)**. |
| Pearl of Power | `restore_resource` is a ClassFeature effect (class_feature.gd:12, 376) | **Partial:** the effect type exists only on class features; no item carrier was verified. Stays *check*. |
| Vorpal Sword (ignore resistance) | `resolve_damage(..., bypass_resistance, bypass_layers)` (combat_action.gd:571, 607–613) | **Host exists.** It needs an item rider to pass the flag → items-15. |
| Periapt of Wound Closure | ZeroHpAftermathRules.pending_death_save_rule / automatic death save (character.gd:3030–3033); `stabilize()` at 3079 | **Partial host.** The automatic-outcome route exists. The item carrier and "double HD healing" need items-12. |
| Robe of the Archmagi (+2 DC) | `attack_profile` features are validated on item data (data_loader.gd:818) and merged through OwnedFeatureSources.item_features | **conv** for the actor-wide +2 save_dc. |

### B5-5: Iron Spikes, Chest, Block and Tackle, carrying capacity

- **Text recovered** from SRD_CC_v5.2.1.pdf (pdftotext).
  - **Chest (5 GP)** (p.96): "A Chest holds up to 12 cubic feet of contents." → S-196 compartment with `max_volume: 12` (conv).
  - **Spikes, Iron (1 GP)** (p.99): "bundles of ten. As a Utilize action, you can use a blunt object, such as a Light Hammer, to hammer a spike into wood, earth, or a similar material… to jam a door shut or to then tie a Rope or Chain to the Spike." → narr (there is no door or lock model; see Chime of Opening).
  - **Block and Tackle**: "hoist up to four times the weight you can normally lift."
- **Carrying capacity:** the SRD table (p.~186) gives Tiny Str×7.5 / ×15, Small/Medium Str×15 / ×30, Large ×30 / ×60, Huge ×60 / ×120. Above carry weight, while dragging, lifting or pushing, Speed is at most 5 ft. **No host in production `src/`:** no Str×15 or drag/lift computation, and no encumbrance speed cap. Only container compartment `max_weight` exists. → **S-266 (items-21)**. Block and Tackle is classified there (lift ×4).
- **Loaded status:** none of Iron Spikes, Chest or Block and Tackle has a loaded record under any ID or name in data/core/items.

### B5-6: Mounts, vehicles, ammunition (SRD pp.~99–101)

- **Ammunition table:** Arrows 20 per Quiver 1 lb 1 GP; Bolts 20 per Case 1½ lb; Firearm Bullets 10 per Pouch 2 lb; Sling Bullets 20 per Pouch 1½ lb; Needles 50 per Pouch 1 lb. **No loaded ammunition records** (no arrows, bolts, bullets or needles in data/core/items) → items-1 (already proposed). The storage containers map to S-196 conv.
- **Mounts and other animals:** carrying capacity for Camel 450, Elephant 1,320, Draft Horse 540, Riding Horse 480, Mastiff 195, Mule 420, Pony 225 and Warhorse 540 lb. **Tack and drawn vehicles:** Carriage, Cart, Chariot, Saddles, Sled, Wagon, feed and stabling. **Large vehicles:** a ship table with speed, crew, cargo, AC, HP, damage threshold and cost. **No loaded records and no mount or vehicle rules in production `src/`.** Carry capacities → items-21. Mounted combat and vehicle HP/threshold are outside the items domain and are **unhosted / not proposed here**; recommend that the combat or travel owner claim them.

### B5-7: New proposed slices

**S-264 (items-19) — Multi-day and long cooldowns on item powers.**
- **Source:** Figurine of Wondrous Power (2–7 days, per figurine), Horn of Valhalla (7 days), Oathbow (sworn enemy until dawn 7 days later), and Manuals and Tomes (100 years).
- **Affects:** at least 4 entries.
- **Reuses:** item `mode_choice` powers (feature_mode_rules.gd), campaign time (S-064) and S-014 cooldowns.
- **Adds:** `uses_per: "days"` with a `days` count, measured from the use time on the item copy.
- **Depends on:** none.
- **Done when:** a check shows a Bronze Griffon figurine used on day 1 is refused on days 2–5 and offered again on day 6 (5-day cooldown). A save/load on day 3 keeps the refusal. A second figurine copy has its own clock. Dawn-based item powers are unchanged.

**S-265 (items-20) — Dice-expression charge recovery and recharge branches.**
- **Source:** Staff of Power (2d8+4, and on a 20 it regains 1d8+2), plus every item whose recovery is more than one die (Wand of Fear 1d6+1 and similar are already exact).
- **Affects:** at least 1 loaded item (staff_of_power) and future staffs.
- **Reuses:** inventory.gd:557–564 recovery and LastChargeRules `roll.trigger_on`.
- **Adds:** a `charge_recovery.dice` expression, plus an optional last-charge `on_roll` regain outcome.
- **Depends on:** none.
- **Done when:** a check shows that 1,000 seeded dawns on an empty Staff of Power give regained values from 6 to 20 with the 2d8+4 distribution (13 is the most common, and 6 and 20 are each about 1/64). Expending the last charge and rolling 20 regains 1d8+2 instead of degrading. Staff of Striking's 1d6+4 results are unchanged.

**S-266 (items-21) — Carrying capacity, drag/lift/push and lift multipliers.**
- **Source:** SRD Carrying Capacity (Str × 15 / × 30 by size), Block and Tackle (×4 lift), and mount carrying capacities.
- **Affects:** every character and mount; Block and Tackle; 8 mount entries.
- **Reuses:** item `weight` fields, the inventory, S-196 max_weight, the size field, and the speed modifiers in S-049.
- **Adds:** a carry limit and a drag/lift/push limit derived from STR and size. Speed is capped at 5 ft while moving more than the carry limit, and an item can multiply the lift limit.
- **Depends on:** none (mount riding stays out of scope).
- **Done when:** a check shows a Medium STR 10 character carrying 150 lb moves normally. At 151 lb dragged, Speed is at most 5 ft. With a Block and Tackle, they can hoist up to 1,200 lb (4 × 300 lb lift) but not 1,201 lb. A Small STR 10 character uses the same limits as Medium. Removing items restores normal Speed.

**Extension noted (no new number):** items-17 also covers attack-target swap reactions (Arrow-Catching Shield; the Shield of Missile Attraction curse), the forced-movement reduction (Dwarven Plate) and Staff of the Magi absorption. Its done-when is unchanged; these are listed as additional affects.

**Corrections recorded:**
- B4-2 rows 7, 55 and 89 ("volume not enforced") → volume *is* enforced when declared (container_rules.gd:87).
- B4-5 conv-check items are resolved by B5-4.

## Final reconciled summary (after batch 5)

### Totals

| Set | Count | Reviewed at clause level | Notes |
|---|---|---|---|
| SRD entries in the reconciler | 414 | — | srd_entries |
| Loaded unique items | 289 | — | runtime registry 70a83cc7…845e |
| Loaded SRD magic records | 94 | **94** (10 with rules B5-2, 49 shells B5-3, 35 consumables B2) | |
| SRD magic items missing from data | 192 | **192** (47 B3, 145 B4) | some *partial-review* clauses, see below |
| Ordinary weapons / armor / general magic rules | — | yes (B1) | |
| SRD gear and tools | 88 text entries | yes (B2), plus Iron Spikes, Chest and Block and Tackle now (B5-5) | |
| Ammunition, mounts and vehicles tables | — | yes (B5-6) | no loaded records |
| Non-SRD loaded items | 67 | **no** | |

### Data defects found (content not changed; reported only)

1. **D-1** potion_of_poison_resistance applies Poisoned (inverted).
2. **D-2** potion_of_poison is missing 4d6 damage and the DC 13 save, and its duration is wrong.
3. **D-3** healing potions cost an Action, not a Bonus Action; the administer clause is missing.
4. **D-4** duplicate consumable IDs (2014 and 2024) in imported_magic_consumables.json.
5. **D-5** Ring of Protection is ID-branched in code; its `effects` are unread.
6. **D-6** Staff of Power is missing saves, spell attack, spells, Retributive Strike and the recovery distribution.
7. **D-7** Staff of Striking is missing its on-hit charge rider.
8. **D-8** Wand of Magic Missiles is missing its destroy-on-1 aftermath.

### Coverage: still unreviewed or partial

- **Unreviewed:** the 67 non-SRD items; the selling, lifestyle and trade-goods sections; sentient items and artifacts; and whether each named spell works in the runtime (spell audit domain).
- **Partial-review (text truncated or host unverified):**
  - Hat of Many Spells, Quarterstaff of the Acrobat, Shield of the Cavalier and Staff of the Magi tail clauses;
  - Cube of Force faces and Dancing Sword actor;
  - Pearl of Power item carrier;
  - Demon Armor unarmed scope;
  - D-4 load-order winner.
- **Out of domain, unhosted:** cover (now planned under S-238 after wave 2); mounted combat and vehicle HP; doors and locks; soul or creature storage; planar travel; Wish.

### Proposals (wave 2 assigned S-IDs; no new V-IDs)

| ID | Title | Main already-planned dependencies |
|---|---|---|
| items-1 → S-249 | Ammunition consumption and recovery | — |
| items-2 → S-250 | Weapon range bands and the Heavy predicate | — |
| items-3 → S-251 | Worn-armor predicates | — |
| items-4 → S-252 | Don/Doff timing | S-064 |
| items-5 → S-253 | Attunement prerequisites | — |
| items-6 → S-254 | Spell Scroll use | S-134, S-060 |
| items-7 → S-255 | Magic templates over a base item | items-2 |
| items-8 → S-256 | Thrown-object attack replacement | S-076 |
| items-9 → S-257 | Timed self-modifiers from consumables | S-181 |
| items-10 → S-254 | Item-delivered spell effects (+ inline payload amendment) | spell audit |
| items-11 → S-258 | Item-deployed hazard areas | S-184 |
| items-12 → S-259 | Passive equipped-item modifiers (+ B4 scope additions) | — |
| items-13 → S-260 | Periodic elapsed-time effects | — |
| items-14 → S-254 | Generic item-activated spell casting with overrides | — |
| items-15 → S-261 | Weapon-copy hit and crit riders | items-7 |
| items-16 → S-262 | Study items with permanent score increases | S-198/S-199 |
| items-17 → S-263 | Item reactions on own save / targeting (+ B5 extension) | — |
| items-18 → S-239 (fold) | Item-granted fixed jumps | — |
| items-19 → S-264 | Multi-day item cooldowns | — |
| items-20 → S-265 | Dice-expression charge recovery | — |
| items-21 → S-266 | Carrying capacity and lift multipliers | — |

### Mapping to already-planned shared slices (not proposed here)

- **Created actors:** S-154 to S-158 (Bag of Tricks, elemental bowls and others, Figurines, Horn of Valhalla, Animated Shield, Dancing Sword, Staff of the Python).
- **Illusion and detection:** S-187 to S-195 (amulets, lanterns, obscurement, light).
- **Travel and planes:** S-177/S-178 and S-221.
- **Curses:** S-202.
- **Downtime and crafting:** S-198/S-199.
- **Breathing and food:** S-200 and S-205.
- **Other planned dependencies:** S-076 (next-hit coatings), S-181 (falling), S-184 (entry scopes) and S-226 (luck rerolls).
- **Verified slices reused as conv:** S-006, S-012, S-014, S-016, S-039, S-049, S-060, S-064, S-068, S-092, S-109, S-110, S-116, S-126, S-127, S-134, S-139, S-140, S-164, S-168, S-179 and S-196.

### Recommended next queue

1. **Hand the data defects D-1 to D-8 to the content owner.** D-1 and D-2 are player-visible wrong results.
2. **Prioritize items-12, items-14 and items-15.** They cover most of the clause volume. items-12 also removes the Ring of Protection ID branch (D-5).
3. **Small, independent slices:** items-20 and items-19, then items-21.
4. **The 67 non-SRD items,** clause by clause.
5. **The partial-review tails** listed above. Read the full untruncated text first.
6. **Ask the combat and travel owners** to claim cover, mounted combat and vehicles.

## Batch 090: item data defect status (stacked on Batch 089)

| Item | Status | Detail |
|---|---|---|
| D-1 potion_of_poison_resistance | FIXED (inverted effect removed); resistance BLOCKED | The Poisoned effect is removed. The potion is now a refused stub, like the other Potions of Resistance (acid, cold and so on have `effects: []`). Granting Poison Resistance for 1 hour needs a resistance-grant consumable effect (items-9, an engine change). The only existing host, the `protection_from_poison` condition, also grants Advantage on saves against Poisoned, so it would over-grant. |
| D-2 potion_of_poison | FIXED, partial | Added 4d6 Poison damage. The existing 10-turn Poisoned approximation is retained. The proposed 600-turn extension is deferred: the shared combat host incorrectly deals 1d4 damage every Poisoned turn, and a bare condition does not expire with campaign time. Correct Poisoned consequences (S-235), a one-hour elapsed-time lifetime (S-257) and the DC 13 Constitution save remain BLOCKED; consumable `apply_condition` has no save field. Poisoned is still applied without a save, as before. |
| D-3 healing potions | FIXED, partial | `action_cost` is now `bonus_action` on the winning records: consumables.json potion_healing and potion_greater_healing (manifest winners), and imported potion_superior_healing #79 and potion_supreme_healing #81. Administering a potion to another creature within 5 ft is BLOCKED: consume() only targets the user (new operation). |
| D-4 duplicate consumable IDs | AUDIT CORRECTION, no change | content_manifest.json resolves all 42 duplicate IDs. In every pair the 2024/SRD copy wins (the second record), and healing/greater healing are won by consumables.json. Load order does not decide the winner. |
| D-5 ring_of_protection | BLOCKED | The ID-branched host (inventory.gd:538, inventory_copies.gd:145, container_rules.gd:292) needs engine work (PROPOSED-items-12). The data values (+1 AC and +1 saves) are already correct. |
| D-6 staff_of_power | BLOCKED | The +2 to saves and spell attacks needs items-12. The spell table needs "your spell save DC": item spell_permissions require a fixed `ability`, and no production item uses them yet. Level-5 Fireball/Lightning Bolt need items-14. Retributive Strike needs items-10. The 2d8+4 recovery and regaining 1d8+2 on a 20 need items-20, because recovery is uniform min..max; 6–20 is kept as the closest range. |
| D-7 staff_of_striking | BLOCKED | No data vocabulary exists for spending charges on a hit for damage (items-15). |
| D-8 wand_of_magic_missiles | NOT CHANGED (behavior already present; data addition unsafe) | spell_cast_resources.gd:136–143 already rolls d20 and destroys the wand on a 1 when the last charge is spent. The spend goes through spend_instance_charges, which also settles any `last_charge_aftermath`, so adding the data would roll twice. Removing the native branch first is engine work, so this is BLOCKED until then. |

Note (merge with #70): `PROPOSED-items-N` and `items-N` placeholders above map to the wave-2 S-IDs in the table "Proposed slices".
