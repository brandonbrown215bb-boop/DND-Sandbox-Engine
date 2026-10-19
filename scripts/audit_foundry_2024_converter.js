#!/usr/bin/env node
/**
 * Foundry VTT v14 / dnd5e v6.0.6 (2024 PHB, MM, SRD, Ravenloft) -> Top Down Party Game
 * Prototype Converter & Gap Audit Script
 *
 * Reads the LevelDB packs from the Foundry Portable installation and sibling 2024 modules,
 * translates records into Top Down Party Game's JSON schemas, validates them against our
 * DataLoader / SharedSpell / CombatAction contracts, and outputs a JSON + console gap report.
 */

const path = require("path");
const fs = require("fs");

const FOUNDRY_ROOT = "C:/Users/brand/Documents/TTRPG/00_INBOX/00_Downloads_Unsorted/FoundryVTT-WindowsPortable-14.369";
const CLASSIC_LEVEL_PATH = path.join(
  FOUNDRY_ROOT,
  "FoundryVTT-WindowsPortable-14.369/App/resources/app/node_modules/classic-level"
);
const { ClassicLevel } = require(CLASSIC_LEVEL_PATH);

const REPO_ROOT = path.resolve(__dirname, "..");

// ─── 1. LevelDB Pack Reader with Embedded Document Joining ──────────────────

async function readPack(packPath) {
  if (!fs.existsSync(path.join(packPath, "CURRENT"))) return [];
  const db = new ClassicLevel(packPath, { valueEncoding: "json" });
  const docs = new Map();
  const actorItems = new Map();
  const actorItemEffects = new Map();
  const docEffects = new Map();
  const sceneRegions = new Map();
  const sceneBehaviors = new Map();

  for await (const [k, v] of db.iterator()) {
    const parts = k.split("!");
    const kind = parts[1];
    const id = parts[2];
    if (["actors", "items", "scenes", "tables", "adventures", "journal"].includes(kind)) {
      docs.set(id, v);
    } else if (kind === "actors.items") {
      const [actorId] = id.split(".");
      if (!actorItems.has(actorId)) actorItems.set(actorId, []);
      actorItems.get(actorId).push(v);
    } else if (kind === "actors.items.effects") {
      const [actorId, itemId] = id.split(".");
      const key = `${actorId}.${itemId}`;
      if (!actorItemEffects.has(key)) actorItemEffects.set(key, []);
      actorItemEffects.get(key).push(v);
    } else if (kind === "items.effects" || kind === "actors.effects") {
      const [parentId] = id.split(".");
      if (!docEffects.has(parentId)) docEffects.set(parentId, []);
      docEffects.get(parentId).push(v);
    } else if (kind === "scenes.regions") {
      const [sceneId] = id.split(".");
      if (!sceneRegions.has(sceneId)) sceneRegions.set(sceneId, []);
      sceneRegions.get(sceneId).push(v);
    } else if (kind === "scenes.regions.behaviors") {
      const [sceneId] = id.split(".");
      if (!sceneBehaviors.has(sceneId)) sceneBehaviors.set(sceneId, []);
      sceneBehaviors.get(sceneId).push(v);
    }
  }
  await db.close();

  for (const [id, doc] of docs.entries()) {
    doc._embeddedEffects = docEffects.get(id) || [];
    const embItems = actorItems.get(id) || [];
    for (const it of embItems) {
      it._embeddedEffects = actorItemEffects.get(`${id}.${it._id}`) || [];
    }
    doc._embeddedItems = embItems;
    if (sceneRegions.has(id)) doc._regions = sceneRegions.get(id);
    if (sceneBehaviors.has(id)) doc._behaviors = sceneBehaviors.get(id);
  }
  return Array.from(docs.values());
}

// ─── 2. Helper Utilities ────────────────────────────────────────────────────

function asArray(val) {
  if (!val) return [];
  if (Array.isArray(val)) return val;
  if (val instanceof Set) return Array.from(val);
  if (typeof val === "string") return [val];
  if (typeof val === "object") return Object.values(val);
  return [];
}

function slugify(name) {
  return String(name || "")
    .toLowerCase()
    .replace(/['’]/g, "")
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function stripHtml(html) {
  return String(html || "")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

function abilityMod(score) {
  return Math.floor(((Number(score) || 10) - 10) / 2);
}

function crToProf(cr) {
  const n = Number(cr) || 0;
  if (n < 5) return 2;
  if (n < 9) return 3;
  if (n < 13) return 4;
  if (n < 17) return 5;
  if (n < 21) return 6;
  if (n < 25) return 7;
  if (n < 29) return 8;
  return 9;
}

function crToXp(cr) {
  const table = {
    0: 10, 0.125: 25, 0.25: 50, 0.5: 100,
    1: 200, 2: 450, 3: 700, 4: 1100, 5: 1800, 6: 2300, 7: 2900, 8: 3900,
    9: 5000, 10: 5900, 11: 7200, 12: 8400, 13: 10000, 14: 11500, 15: 13000,
    16: 15000, 17: 18000, 18: 20000, 19: 22000, 20: 25000, 21: 33000,
    22: 41000, 23: 50000, 24: 62000, 25: 75000, 26: 90000, 27: 105000,
    28: 120000, 29: 135000, 30: 155000
  };
  return table[Number(cr)] ?? 0;
}

function formatDamagePart(part, modValue = null, includeDefaultMod = false) {
  if (!part) return null;
  const types = asArray(part.types);
  if (part.custom?.enabled && part.custom?.formula) {
    let customF = String(part.custom.formula);
    if (modValue !== null) customF = customF.replace(/@mod/g, String(modValue));
    return {
      formula: customF,
      type: types[0] || "untyped",
      types
    };
  }
  const num = Number(part.number) || 0;
  const denom = Number(part.denomination) || 0;
  let bonusStr = String(part.bonus || "").trim();
  if (modValue !== null) {
    if ((bonusStr === "" && includeDefaultMod) || bonusStr === "@mod") {
      bonusStr = modValue !== 0 ? String(modValue) : "";
    } else if (bonusStr.includes("@mod")) {
      try {
        const expr = bonusStr.replace(/@mod/g, String(modValue));
        if (/^[0-9+\-*\s()]+$/.test(expr)) {
          bonusStr = String(Function(`"use strict"; return (${expr});`)());
        }
      } catch (_) {}
    }
  } else if (bonusStr === "@mod") {
    bonusStr = "";
  }
  let formula = "";
  if (num > 0 && denom > 0) {
    formula = `${num}d${denom}`;
    if (bonusStr) {
      const bNum = Number(bonusStr);
      if (!Number.isNaN(bNum) && bNum !== 0) {
        formula += bNum > 0 ? ` + ${bNum}` : ` - ${Math.abs(bNum)}`;
      }
    }
  } else if (bonusStr) {
    formula = bonusStr;
  }
  return {
    formula: formula || "0",
    type: types[0] || "untyped",
    types,
    scaling: part.scaling || null
  };
}

function durationToSeconds(dur) {
  if (!dur || !dur.units) return 0;
  const val = Number(dur.value) || 1;
  switch (dur.units) {
    case "round": return val * 6;
    case "minute": return val * 60;
    case "hour": return val * 3600;
    case "day": return val * 86400;
    case "turn": return 6;
    default: return 0;
  }
}

function rangeToHexes(range) {
  if (!range) return 1;
  const units = range.units || "ft";
  const val = Number(range.value) || 0;
  if (units === "self") return 0;
  if (units === "touch") return 1;
  if (units === "ft") return Math.max(1, Math.round(val / 5));
  if (units === "mi") return Math.min(1000, Math.round((val * 5280) / 5));
  return 1;
}

// ─── 3. Prototype Spell Converter & Validator ───────────────────────────────

const SHARED_SPELL_CONDITIONS = new Set([
  "blinded", "deafened", "frightened", "poisoned", "prone",
  "restrained", "stunned", "paralyzed", "incapacitated",
  "blessed", "baned", "shield_of_faith"
]);

const EXTENDED_5E_CONDITIONS = new Set([
  "charmed", "invisible", "grappled", "petrified", "exhaustion", "unconscious"
]);

function translateAndAuditSpell(fSpell) {
  const sys = fSpell.system || {};
  const activities = Object.values(sys.activities || {});
  const embEffects = fSpell._embeddedEffects || [];
  const gaps = [];
  const adapterNotes = [];

  const hasRegionBehaviors = embEffects.some(e => e.type === "all" || (e.system?.behaviors && e.system.behaviors.length > 0))
    || JSON.stringify(fSpell).includes("RegionBehavior");
  if (hasRegionBehaviors) {
    gaps.push("region_behavior_zone");
  }

  if (activities.length === 0) {
    gaps.push("no_activities_narrative_or_passive");
  } else if (activities.length > 1) {
    const slotActivities = activities.filter(a => a.consumption?.spellSlot !== false);
    const nonSlotActivities = activities.filter(a => a.consumption?.spellSlot === false);
    if (slotActivities.length >= 1 && nonSlotActivities.length >= 1) {
      gaps.push("multi_activity_followup");
    } else {
      gaps.push("multi_activity_choice_or_compound");
    }
  }

  const act = activities[0] || {};
  const actType = act.type || "none";
  if (actType === "enchant") gaps.push("enchant_activity");
  if (actType === "summon") gaps.push("summon_activity");
  if (actType === "transform") gaps.push("transform_activity");
  if (actType === "teleport") gaps.push("teleport_activity");
  if (actType === "check") gaps.push("check_activity");
  if (actType === "cast") gaps.push("cast_delegation_activity");
  if (actType === "forward") gaps.push("forward_activity");

  const actTimeType = sys.activation?.type || "action";
  let castingTime = "action";
  if (actTimeType === "bonus") castingTime = "bonus_action";
  else if (actTimeType === "reaction") {
    castingTime = "reaction";
    adapterNotes.push("reaction_casting_time");
  } else if (actTimeType !== "action") {
    adapterNotes.push(`non_combat_casting_time:${actTimeType}`);
  }

  const tpl = act.target?.template?.type ? act.target.template : (sys.target?.template || {});
  const aoeType = tpl.type || "";
  let targetSelector = "single";
  let areaRadius = undefined;
  let coneSize = undefined;
  if (sys.range?.units === "self" && !aoeType) {
    targetSelector = "self";
  } else if (aoeType === "sphere" || aoeType === "radius" || aoeType === "cylinder") {
    targetSelector = "area";
    areaRadius = Math.max(1, Math.round((Number(tpl.size) || 10) / 5));
    if (aoeType === "cylinder") adapterNotes.push("cylinder_mapped_to_sphere");
  } else if (aoeType === "cone") {
    targetSelector = "cone";
    coneSize = Math.max(1, Math.round((Number(tpl.size) || 15) / 5));
  } else if (aoeType === "cube" || aoeType === "line" || aoeType === "wall") {
    targetSelector = "area";
    areaRadius = Math.max(1, Math.round((Number(tpl.size) || 10) / 5));
    adapterNotes.push(`aoe_shape_${aoeType}`);
  } else if (Number(sys.target?.affects?.count) > 1) {
    targetSelector = "multi";
  }

  const translated = {
    id: slugify(fSpell.name),
    name: fSpell.name,
    description: stripHtml(sys.description?.value).slice(0, 300),
    execution: "shared",
    level: Number(sys.level) || 0,
    casting_time: castingTime === "bonus_action" ? "bonus_action" : "action",
    range: rangeToHexes(sys.range),
    target: targetSelector,
    concentration: asArray(sys.properties).includes("concentration"),
    ritual: asArray(sys.properties).includes("ritual"),
    school: sys.school || "evo",
    rules_source: "dnd-2024-foundry-pack",
    rules_status: "2024-translated-prototype"
  };
  if (areaRadius) translated.area_radius = areaRadius;
  if (coneSize) translated.cone_size = coneSize;

  const durSec = durationToSeconds(sys.duration);
  if (durSec > 0) translated.duration_seconds = durSec;

  if (actType === "attack") {
    const atkType = act.attack?.type?.value || "ranged";
    translated.attack_type = atkType === "melee" ? "melee_spell" : "ranged_spell";
  } else if (actType === "save") {
    const saveAbils = asArray(act.save?.ability);
    const saveAbil = (saveAbils[0] || "dex").toUpperCase();
    translated.save = saveAbil;
    translated.half_on_save = act.damage?.onSave === "half";
  } else {
    translated.attack_type = "none";
  }

  const dmgParts = (act.damage?.parts || []).map(p => formatDamagePart(p, null)).filter(p => p && p.formula !== "0");
  if (dmgParts.length === 1) {
    translated.damage = dmgParts[0].formula;
    translated.damage_type = dmgParts[0].type;
    if (dmgParts[0].types.length > 1) {
      adapterNotes.push("player_chosen_damage_type_set");
    }
  } else if (dmgParts.length > 1) {
    adapterNotes.push("multi_component_damage");
    translated.damage = dmgParts[0].formula;
    translated.damage_type = dmgParts[0].type;
  }

  const effectsOut = [];
  if (actType === "heal" && act.healing) {
    const h = formatDamagePart(act.healing, null);
    const isTemp = asArray(act.healing.types).includes("temphp");
    if (h && h.formula && h.formula !== "0") {
      effectsOut.push({
        type: isTemp ? "temporary_hp" : "heal",
        value: h.formula,
        ...(act.healing.bonus === "@mod" ? { ability_bonus_from_caster: true } : {})
      });
    }
  }

  // Embedded ActiveEffects
  let hasUnmappedEffectChanges = false;
  for (const eff of embEffects) {
    if (eff.type === "enchantment") continue;
    const statuses = asArray(eff.statuses);
    for (const st of statuses) {
      if (SHARED_SPELL_CONDITIONS.has(st)) {
        const effObj = { type: "grant_condition", condition: st };
        if (actType === "save") effObj.on_failed_save = true;
        if (actType === "attack") effObj.on_spell_hit = true;
        effectsOut.push(effObj);
      } else if (EXTENDED_5E_CONDITIONS.has(st)) {
        adapterNotes.push(`condition_not_in_shared_spell_allowlist:${st}`);
      }
    }
    // Check if changes map to SourceBenefitRules (ac / speed)
    const changes = eff.changes || [];
    const benefits = [];
    for (const ch of changes) {
      if (ch.key === "system.attributes.ac.bonus" && !Number.isNaN(Number(ch.value))) {
        benefits.push({ type: "armor_class_bonus", value: Number(ch.value) });
      } else if (ch.key === "system.attributes.movement.walk" && !Number.isNaN(Number(ch.value))) {
        benefits.push({ type: "speed_bonus_feet", value: Number(ch.value) });
      } else if (statuses.length === 0) {
        hasUnmappedEffectChanges = true;
      }
    }
    if (benefits.length > 0 && targetSelector === "self" && !translated.damage && !translated.save && translated.attack_type === "none") {
      effectsOut.push({ type: "grant_source_benefits", benefits });
    }
  }
  if (hasUnmappedEffectChanges) {
    adapterNotes.push("active_effect_property_changes");
  }
  if (effectsOut.length > 0) {
    translated.effects = effectsOut;
    if (effectsOut.some(e => e.type === "grant_condition") && !translated.duration_seconds) {
      translated.duration_seconds = 6;
    }
  }

  if (actType === "utility" && !translated.damage && effectsOut.length === 0) {
    gaps.push("utility_or_narrative_spell_without_direct_damage_or_condition");
  }

  let tier = "tier1_ready_now";
  if (gaps.length > 0) {
    tier = "tier3_needs_engine_capability";
  } else if (adapterNotes.length > 0) {
    tier = "tier2_needs_minor_converter_or_allowlist_expansion";
  }

  return {
    id: translated.id,
    name: fSpell.name,
    level: translated.level,
    tier,
    gaps,
    adapterNotes,
    translated
  };
}

// ─── 4. Prototype Monster Converter & Validator ─────────────────────────────

function translateAndAuditMonster(fActor) {
  const sys = fActor.system || {};
  const cr = Number(sys.details?.cr) || 0;
  const prof = crToProf(cr);
  const abilities = {
    STR: Number(sys.abilities?.str?.value) || 10,
    DEX: Number(sys.abilities?.dex?.value) || 10,
    CON: Number(sys.abilities?.con?.value) || 10,
    INT: Number(sys.abilities?.int?.value) || 10,
    WIS: Number(sys.abilities?.wis?.value) || 10,
    CHA: Number(sys.abilities?.cha?.value) || 10
  };

  const savingThrowBonuses = {};
  for (const [k, up] of [["str", "STR"], ["dex", "DEX"], ["con", "CON"], ["int", "INT"], ["wis", "WIS"], ["cha", "CHA"]]) {
    const p = Number(sys.abilities?.[k]?.proficient) || 0;
    if (p > 0) {
      savingThrowBonuses[up] = abilityMod(abilities[up]) + Math.floor(p * prof);
    }
  }

  const initBonusRaw = String(sys.attributes?.init?.bonus || "").trim();
  let initBonus = abilityMod(abilities.DEX);
  if (initBonusRaw === "@prof") initBonus += prof;
  else if (initBonusRaw === "@prof * 2" || initBonusRaw === "2 * @prof") initBonus += prof * 2;
  else if (!Number.isNaN(Number(initBonusRaw)) && initBonusRaw !== "") initBonus += Number(initBonusRaw);

  const senses = {};
  for (const sKey of ["darkvision", "blindsight", "tremorsense", "truesight"]) {
    const val = Number(sys.attributes?.senses?.[sKey] ?? sys.attributes?.senses?.ranges?.[sKey]) || 0;
    if (val > 0) senses[sKey] = Math.round(val / 5);
  }

  const attacks = [];
  const specialAbilities = [];
  let multiattackCount = 1;
  const gaps = new Set();
  const adapterNotes = new Set();
  const activityBreakdown = {
    total: 0,
    attackTranslated: 0,
    attackWithUnmappedConditionRider: 0,
    multiattackOrLegendaryResHandled: 0,
    singleTargetSaveAction: 0,
    aoeSaveAction: 0,
    castSpellDelegation: 0,
    summonAction: 0,
    otherUtilityOrCheckOrHeal: 0
  };

  for (const item of fActor._embeddedItems || []) {
    // Skip embedded spell copies (they are referenced by Spellcasting CastActivities)
    if (item.type === "spell") continue;

    const iSys = item.system || {};
    const acts = Object.values(iSys.activities || {});
    const itemEffects = item._embeddedEffects || [];
    const nameLower = item.name.toLowerCase();

    if (nameLower.startsWith("multiattack")) {
      const desc = stripHtml(iSys.description?.value);
      const wordToNum = { two: 2, three: 3, four: 4, five: 5, six: 6, "2": 2, "3": 3, "4": 4 };
      const m = desc.match(/makes\s+(two|three|four|five|six|\d+)\s+/i);
      if (m) {
        multiattackCount = wordToNum[m[1].toLowerCase()] || 2;
      } else {
        multiattackCount = 2;
        adapterNotes.add("complex_multiattack_prose");
      }
      activityBreakdown.total += acts.length;
      activityBreakdown.multiattackOrLegendaryResHandled += acts.length;
      specialAbilities.push({ id: "multiattack", name: item.name, description: desc });
      continue;
    }

    if (nameLower.startsWith("legendary resistance")) {
      activityBreakdown.total += acts.length;
      activityBreakdown.multiattackOrLegendaryResHandled += acts.length;
      gaps.add("legendary_resistance_budget");
      specialAbilities.push({ id: "legendary_resistance", name: item.name, description: stripHtml(iSys.description?.value) });
      continue;
    }

    if (acts.length === 0) {
      specialAbilities.push({
        id: slugify(item.name),
        name: item.name,
        description: stripHtml(iSys.description?.value)
      });
      continue;
    }

    for (const act of acts) {
      activityBreakdown.total++;
      const actType = act.type;
      const activationType = act.activation?.type || iSys.activation?.type || "action";

      if (activationType === "legendary" || activationType === "lair") {
        gaps.add(`activation_${activationType}`);
      }
      if (iSys.uses?.recovery?.some(r => r.period === "recharge")) {
        gaps.add("recharge_recovery");
      }

      if (actType === "attack") {
        const atkType = act.attack?.type?.value || iSys.type?.value || "melee";
        const isRanged = atkType.includes("R") || atkType === "ranged";
        const abilChoice = act.attack?.ability || (isRanged ? "dex" : "str");
        const abilKey = abilChoice === "spellcasting"
          ? (sys.attributes?.spellcasting || "int").toUpperCase()
          : abilChoice.toUpperCase();
        const mod = abilityMod(abilities[abilKey] ?? Math.max(abilities.STR, abilities.DEX));

        const allParts = [];
        if (iSys.damage?.base && (iSys.damage.base.number || iSys.damage.base.custom?.enabled)) {
          allParts.push(formatDamagePart(iSys.damage.base, mod, true));
        }
        for (const p of act.damage?.parts || []) {
          allParts.push(formatDamagePart(p, mod, false));
        }
        const validParts = allParts.filter(p => p && p.formula !== "0");
        const primary = validParts[0] || { formula: `1d4 + ${mod}`, type: "bludgeoning" };
        const extraEffects = [];

        for (let i = 1; i < validParts.length; i++) {
          extraEffects.push({
            type: "bonus_damage",
            damage: validParts[i].formula,
            damage_type: validParts[i].type
          });
        }

        let riderGap = false;
        for (const eff of itemEffects) {
          for (const st of asArray(eff.statuses)) {
            if (st === "restrained" || st === "grappled") {
              extraEffects.push({ type: "restrain", save: "STR", dc: 8 + prof + mod, duration: 1 });
              if (st === "grappled") adapterNotes.add("grappled_mapped_to_restrain_or_needs_grapple_rider");
            } else if (st === "poisoned") {
              extraEffects.push({ type: "poison_save", save: "CON", dc: 8 + prof + mod, duration: 1, damage: "0" });
            } else if (st === "paralyzed") {
              extraEffects.push({ type: "paralyze_save", save: "CON", dc: 8 + prof + mod, duration: 1 });
            } else {
              riderGap = true;
              adapterNotes.add(`on_hit_condition_rider:${st}`);
            }
          }
        }

        const reachFt = Number(iSys.range?.reach || iSys.range?.value) || (isRanged ? 60 : 5);
        attacks.push({
          name: item.name + (act.name && act.name !== "Attack" && acts.length > 1 ? ` (${act.name})` : ""),
          ability: ["STR", "DEX", "CON", "INT", "WIS", "CHA"].includes(abilKey) ? abilKey : "STR",
          damage: primary.formula,
          damage_type: primary.type,
          range: Math.max(1, Math.round(reachFt / 5)),
          ...(extraEffects.length > 0 ? { extra_effects: extraEffects } : {})
        });

        if (riderGap) activityBreakdown.attackWithUnmappedConditionRider++;
        else activityBreakdown.attackTranslated++;
      } else if (actType === "save") {
        const tplType = act.target?.template?.type || iSys.target?.template?.type || "";
        if (tplType) {
          gaps.add(`monster_aoe_save:${tplType}`);
          activityBreakdown.aoeSaveAction++;
        } else {
          adapterNotes.add("monster_single_target_save_action");
          activityBreakdown.singleTargetSaveAction++;
        }
      } else if (actType === "cast") {
        gaps.add("monster_cast_activity");
        activityBreakdown.castSpellDelegation++;
      } else if (actType === "summon") {
        gaps.add("monster_summon_activity");
        activityBreakdown.summonAction++;
      } else {
        if (actType !== "utility") gaps.add(`monster_${actType}_activity`);
        activityBreakdown.otherUtilityOrCheckOrHeal++;
      }
    }
  }

  if (attacks.length === 0) {
    const strMod = abilityMod(abilities.STR);
    attacks.push({
      name: "Unarmed Strike",
      ability: "STR",
      damage: `1d4 + ${strMod}`,
      damage_type: "bludgeoning",
      range: 1
    });
    adapterNotes.add("synthesized_fallback_attack_for_save_or_caster_monster");
  }

  const translated = {
    id: slugify(fActor.name),
    name: fActor.name,
    size: (sys.traits?.size || "med") === "med" ? "medium" : (sys.traits?.size || "medium"),
    creature_type: sys.details?.type?.value || "monster",
    challenge_rating: cr,
    xp: crToXp(cr),
    hit_points: sys.attributes?.hp?.formula || String(sys.attributes?.hp?.max || 10),
    armor_class: Number(sys.attributes?.ac?.value ?? sys.attributes?.ac?.flat) || 10,
    speed: Math.max(1, Math.round((Number(sys.attributes?.movement?.walk) || 30) / 5)),
    initiative_bonus: initBonus,
    senses,
    ability_scores: abilities,
    saving_throw_bonuses: savingThrowBonuses,
    damage_resistances: asArray(sys.traits?.dr?.value),
    damage_immunities: asArray(sys.traits?.di?.value),
    damage_vulnerabilities: asArray(sys.traits?.dv?.value),
    condition_immunities: asArray(sys.traits?.ci?.value),
    attacks,
    ...(multiattackCount > 1 ? { multiattack: multiattackCount } : {}),
    ai_behavior: "aggressive",
    special_abilities: specialAbilities,
    rules_source: "dnd-2024-foundry-pack"
  };

  return {
    id: translated.id,
    name: fActor.name,
    cr,
    gaps: Array.from(gaps),
    adapterNotes: Array.from(adapterNotes),
    activityBreakdown,
    translated
  };
}

// ─── 5. Main Audit Execution ────────────────────────────────────────────────

(async () => {
  const srdDir = path.join(FOUNDRY_ROOT, "FoundryVTT-WindowsPortable-14.369/Data/systems/dnd5e/packs");
  const phbDir = path.join(FOUNDRY_ROOT, "dnd-players-handbook v2.2.0_FVTT13-14/dnd-players-handbook/packs");
  const mmDir = path.join(FOUNDRY_ROOT, "dnd-monster-manual v1.4.0_FVTT13-14/dnd-monster-manual/packs");
  const rhwDir = path.join(FOUNDRY_ROOT, "dnd-ravenloft-horrors-within_V1.0.1_FVTT13-14_CLEAN/dnd-ravenloft-horrors-within/packs");

  // 1. Audit PHB 2024 Spells (391 spells) + RHW Spells
  const phbSpells = (await readPack(path.join(phbDir, "spells"))).filter(d => d.type === "spell");
  const rhwSpells = (await readPack(path.join(rhwDir, "options"))).filter(d => d.type === "spell");
  const allSpells = [...phbSpells, ...rhwSpells];

  const spellResults = allSpells.map(translateAndAuditSpell);
  const spellTiers = { tier1_ready_now: 0, tier2_needs_minor_converter_or_allowlist_expansion: 0, tier3_needs_engine_capability: 0 };
  const spellGapCounts = {};
  const spellNoteCounts = {};
  for (const r of spellResults) {
    spellTiers[r.tier]++;
    for (const g of r.gaps) spellGapCounts[g] = (spellGapCounts[g] || 0) + 1;
    for (const n of r.adapterNotes) spellNoteCounts[n] = (spellNoteCounts[n] || 0) + 1;
  }

  const ourSpellsDir = path.join(REPO_ROOT, "data/core/spells");
  const ourSpellIds = new Set();
  for (const f of fs.readdirSync(ourSpellsDir)) {
    if (!f.endsWith(".json")) continue;
    const arr = JSON.parse(fs.readFileSync(path.join(ourSpellsDir, f), "utf8"));
    for (const s of arr) if (s.id) ourSpellIds.add(s.id);
  }
  const newSpellsAvailable = spellResults.filter(s => !ourSpellIds.has(s.id));

  // 2. Audit MM 2024 Monsters (504) + Ravenloft Monsters (69 + 54) + PHB Companion/Summon NPCs (127)
  const mmMonsters = (await readPack(path.join(mmDir, "actors"))).filter(d => d.type === "npc");
  const rhwMonsters = (await readPack(path.join(rhwDir, "actors"))).filter(d => d.type === "npc");
  const phbSummonNpcs = (await readPack(path.join(phbDir, "actors"))).filter(d => d.type === "npc");

  const mmResults = mmMonsters.map(translateAndAuditMonster);
  const rhwResults = rhwMonsters.map(translateAndAuditMonster);

  const mmGapCounts = {};
  const mmNoteCounts = {};
  const mmActTotals = {
    total: 0,
    attackTranslated: 0,
    attackWithUnmappedConditionRider: 0,
    multiattackOrLegendaryResHandled: 0,
    singleTargetSaveAction: 0,
    aoeSaveAction: 0,
    castSpellDelegation: 0,
    summonAction: 0,
    otherUtilityOrCheckOrHeal: 0
  };
  let mmPureAttackMonsters = 0;

  for (const m of mmResults) {
    if (m.gaps.length === 0) mmPureAttackMonsters++;
    for (const g of m.gaps) mmGapCounts[g] = (mmGapCounts[g] || 0) + 1;
    for (const n of m.adapterNotes) mmNoteCounts[n] = (mmNoteCounts[n] || 0) + 1;
    for (const k of Object.keys(mmActTotals)) {
      mmActTotals[k] += m.activityBreakdown[k] || 0;
    }
  }

  const ourMonstersDir = path.join(REPO_ROOT, "data/core/monsters");
  const ourMonsters = new Map();
  for (const f of fs.readdirSync(ourMonstersDir)) {
    if (!f.endsWith(".json")) continue;
    const arr = JSON.parse(fs.readFileSync(path.join(ourMonstersDir, f), "utf8"));
    for (const m of arr) if (m.id) ourMonsters.set(m.id, m);
  }

  let matchedMonsters = 0;
  let repairedCreatureType = 0;
  let repairedSenses = 0;
  let repairedInitBonus = 0;
  let repairedSaveBonuses = 0;
  let acOrHpDiffs = 0;

  for (const m of mmResults) {
    const ours = ourMonsters.get(m.id);
    if (!ours) continue;
    matchedMonsters++;
    if (!ours.creature_type && m.translated.creature_type) repairedCreatureType++;
    if (!ours.senses && Object.keys(m.translated.senses).length > 0) repairedSenses++;
    if (ours.initiative_bonus === undefined) repairedInitBonus++;
    if (!ours.saving_throw_bonuses && Object.keys(m.translated.saving_throw_bonuses).length > 0) repairedSaveBonuses++;
    if (Number(ours.armor_class) !== m.translated.armor_class) acOrHpDiffs++;
  }

  // 3. Audit Equipment
  const srdEquip = await readPack(path.join(srdDir, "equipment24"));
  const rhwItems = await readPack(path.join(rhwDir, "items"));
  const equipBreakdown = {
    totalSrd24: srdEquip.length,
    weaponsWithMastery: 0,
    mundaneArmorShields: 0,
    toolsAndGear: 0,
    magicItemsWithActivities: 0,
    magicItemsWithEffects: 0,
    magicActTypes: {}
  };
  for (const it of srdEquip) {
    const acts = Object.values(it.system?.activities || {});
    if (it.type === "weapon" && it.system?.mastery) equipBreakdown.weaponsWithMastery++;
    if (it.type === "equipment" && ["light", "medium", "heavy", "shield"].includes(it.system?.type?.value)) {
      equipBreakdown.mundaneArmorShields++;
    }
    if (it.type === "tool" || it.type === "loot" || it.type === "container") equipBreakdown.toolsAndGear++;
    if (acts.length > 0) {
      equipBreakdown.magicItemsWithActivities++;
      for (const a of acts) equipBreakdown.magicActTypes[a.type] = (equipBreakdown.magicActTypes[a.type] || 0) + 1;
    }
    if ((it._embeddedEffects || []).length > 0) equipBreakdown.magicItemsWithEffects++;
  }

  // 4. Audit Subclasses & Feats across PHB 2024 + Ravenloft
  const phbClassesPack = await readPack(path.join(phbDir, "classes"));
  const rhwOptionsPack = await readPack(path.join(rhwDir, "options"));
  const phbFeatsPack = await readPack(path.join(phbDir, "feats"));

  const ourSubclassesDir = path.join(REPO_ROOT, "data/core/subclasses");
  const ourSubclassIds = new Set(
    fs.readdirSync(ourSubclassesDir).filter(f => f.endsWith(".json")).map(f => f.replace(".json", ""))
  );

  const summary = {
    generatedAt: new Date().toISOString(),
    modulesReviewed: {
      "dnd-players-handbook (v2.2.0)": {
        classes: 12,
        subclasses: phbClassesPack.filter(d => d.type === "subclass").length,
        classFeatures: phbClassesPack.filter(d => d.type === "feat").length,
        feats: phbFeatsPack.length,
        spells: phbSpells.length,
        summonAndCompanionNpcs: phbSummonNpcs.length
      },
      "dnd-monster-manual (v1.4.0)": {
        monsters: mmMonsters.length,
        embeddedActivities: mmActTotals.total
      },
      "dnd-ravenloft-horrors-within (v1.0.1)": {
        bestiaryMonsters: rhwMonsters.length,
        dreadlords: rhwMonsters.filter(a => a.flags?.["dnd-ravenloft-horrors-within"]?.dreadlord).length,
        subclasses: rhwOptionsPack.filter(d => d.type === "subclass").length,
        darkGiftsAndFeats: rhwOptionsPack.filter(d => d.type === "feat" && d.system?.type?.value === "feat").length,
        lineages: rhwOptionsPack.filter(d => d.type === "race").length,
        bastionFacilities: 8,
        mistTalismans: rhwItems.filter(d => d.system?.type?.value === "mistTalisman").length
      }
    },
    spellTranslationAudit: {
      totalAudited: spellResults.length,
      alreadyInOurCatalog: spellResults.length - newSpellsAvailable.length,
      netNew2024Spells: newSpellsAvailable.length,
      tiers: spellTiers,
      tier1And2CombinedPct: Math.round(((spellTiers.tier1_ready_now + spellTiers.tier2_needs_minor_converter_or_allowlist_expansion) / spellResults.length) * 100),
      engineBlockers: spellGapCounts,
      converterNormalizations: spellNoteCounts,
      sampleConvertedSpells: spellResults.filter(s => s.tier === "tier1_ready_now").slice(0, 3).map(s => s.translated)
    },
    monsterTranslationAudit: {
      totalMM2024Monsters: mmResults.length,
      pureAttackAndTraitMonstersReadyNow: mmPureAttackMonsters,
      pureAttackMonstersPct: Math.round((mmPureAttackMonsters / mmResults.length) * 100),
      activityBreakdown: mmActTotals,
      matchedInOurCatalog: matchedMonsters,
      netNewMM2024Monsters: mmResults.length - matchedMonsters,
      repairsAvailableForOurExistingMonsters: {
        repairedCreatureType,
        repairedSenses,
        repairedInitBonus,
        repairedSaveBonuses,
        acDiffs2014vs2024: acOrHpDiffs
      },
      engineBlockersByMonsterCount: mmGapCounts,
      converterNormalizations: mmNoteCounts,
      sampleConvertedMonster: mmResults.find(m => m.id === "adult_red_dragon")?.translated || mmResults[0]?.translated
    },
    equipmentTranslationAudit: equipBreakdown,
    subclassCoverageGap: {
      ourCurrentSubclasses: Array.from(ourSubclassIds),
      phb2024SubclassesAvailable: phbClassesPack.filter(d => d.type === "subclass").length,
      ravenloftSubclassesAvailable: rhwOptionsPack.filter(d => d.type === "subclass").length
    }
  };

  const outPath = path.join(REPO_ROOT, ".artifacts/planning/foundry-2024-translation-audit.json");
  fs.writeFileSync(outPath, JSON.stringify(summary, null, 2), "utf8");
  console.log(JSON.stringify(summary, null, 2));
})();
