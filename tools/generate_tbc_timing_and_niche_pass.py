import csv
from collections import defaultdict
from pathlib import Path


ROOT = Path("ClassResearchTBC")
DB2 = ROOT / "DB2"


CLASSES = ["Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior", "Pet"]


def read_csv(path):
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def index_one(rows, key):
    out = {}
    for row in rows:
        out.setdefault(row.get(key, ""), row)
    return out


def index_many(rows, key):
    out = defaultdict(list)
    for row in rows:
        out[row.get(key, "")].append(row)
    return out


def ms_to_sec(value):
    if value in (None, ""):
        return ""
    try:
        value = float(value)
    except ValueError:
        return ""
    if value == 0:
        return "0"
    return f"{value / 1000:.3f}".rstrip("0").rstrip(".")


def fmt(value):
    return str(value or "").replace("|", "\\|").replace("\n", " ").strip()


def usage_tag(spell_name, skill_line):
    text = f"{spell_name} {skill_line}".lower()
    if any(w in text for w in ["heal", "renew", "rejuvenation", "regrowth", "lifebloom", "chain heal", "holy light", "flash of light", "earth shield", "prayer"]):
        return "healing"
    if any(w in text for w in ["taunt", "growl", "righteous fury", "holy shield", "shield block", "shield slam", "revenge", "lacerate", "maul", "swipe", "devastate", "sunder"]):
        return "tanking"
    if any(w in text for w in ["fear", "polymorph", "cyclone", "sap", "blind", "kidney", "counterspell", "purge", "mana burn", "viper", "trap", "hamstring", "stun", "silence"]):
        return "pvp-control"
    if any(w in text for w in ["bolt", "shot", "strike", "blast", "fireball", "frostbolt", "wrath", "starfire", "mind flay", "mangle", "shred", "sinister", "bloodthirst", "whirlwind", "execute", "incinerate", "corruption", "curse", "judgement", "seal"]):
        return "damage"
    if any(w in text for w in ["improved", "specialization", "mastery", "precision", "focus", "subtlety", "instinct", "power", "guidance", "knowledge"]):
        return "passive/talent"
    return "utility/rank"


def load_data():
    return {
        "abilities": read_csv(DB2 / "wago_anniversary_class_skillline_abilities.csv"),
        "misc": index_one(read_csv(DB2 / "wago_anniversary_spellmisc.csv"), "SpellID"),
        "cast": index_one(read_csv(DB2 / "wago_anniversary_spellcasttimes.csv"), "ID"),
        "duration": index_one(read_csv(DB2 / "wago_anniversary_spellduration.csv"), "ID"),
        "range": index_one(read_csv(DB2 / "wago_anniversary_spellrange.csv"), "ID"),
        "cooldowns": index_one(read_csv(DB2 / "wago_anniversary_class_spell_cooldowns.csv"), "SpellID"),
        "power": index_many(read_csv(DB2 / "wago_anniversary_class_spell_power.csv"), "SpellID"),
        "shapeshift": index_one(read_csv(DB2 / "wago_anniversary_spellshapeshift.csv"), "SpellID"),
        "totems": index_one(read_csv(DB2 / "wago_anniversary_spelltotems.csv"), "SpellID"),
        "reagents": index_one(read_csv(DB2 / "wago_anniversary_spellreagents.csv"), "SpellID"),
        "equipped": index_one(read_csv(DB2 / "wago_anniversary_spellequippeditems.csv"), "SpellID"),
        "effects": index_many(read_csv(DB2 / "wago_anniversary_class_spell_effects.csv"), "SpellID"),
    }


def timing_for(data, spell_id):
    misc = data["misc"].get(spell_id, {})
    cast = data["cast"].get(misc.get("CastingTimeIndex", ""), {})
    duration = data["duration"].get(misc.get("DurationIndex", ""), {})
    range_row = data["range"].get(misc.get("RangeIndex", ""), {})
    cooldown = data["cooldowns"].get(spell_id, {})
    powers = data["power"].get(spell_id, [])
    shapeshift = data["shapeshift"].get(spell_id, {})
    totems = data["totems"].get(spell_id, {})
    reagents = data["reagents"].get(spell_id, {})
    equipped = data["equipped"].get(spell_id, {})
    effects = data["effects"].get(spell_id, [])
    power_costs = []
    for power in powers:
        mana = power.get("ManaCost", "")
        pct = power.get("PowerCostPct", "")
        ptype = power.get("PowerType", "")
        if mana and mana != "0":
            power_costs.append(f"type{ptype}:{mana}")
        elif pct and pct != "0":
            power_costs.append(f"type{ptype}:{pct}%")
    req_totems = ";".join(v for k, v in totems.items() if k.startswith("Totem_") and v not in ("", "0"))
    req_reagents = ";".join(v for k, v in reagents.items() if k.startswith("Reagent_") and v not in ("", "0"))
    effect_summary = ";".join(
        f"E{e.get('EffectIndex')}:effect={e.get('Effect')},aura={e.get('EffectAura')},base={e.get('EffectBasePoints')},trigger={e.get('EffectTriggerSpell')}"
        for e in effects[:3]
    )
    return {
        "CastTimeSec": ms_to_sec(cast.get("Base")),
        "CastMinimumSec": ms_to_sec(cast.get("Minimum")),
        "DurationSec": ms_to_sec(duration.get("Duration")),
        "MaxDurationSec": ms_to_sec(duration.get("MaxDuration")),
        "RangeMinYd": range_row.get("RangeMin_0", ""),
        "RangeMaxYd": range_row.get("RangeMax_0", ""),
        "GCDSec": ms_to_sec(cooldown.get("StartRecoveryTime")),
        "CooldownSec": ms_to_sec(cooldown.get("RecoveryTime")),
        "CategoryCooldownSec": ms_to_sec(cooldown.get("CategoryRecoveryTime")),
        "PowerCost": ";".join(power_costs),
        "ShapeshiftMask": shapeshift.get("ShapeshiftMask_0", "") or shapeshift.get("ShapeshiftMask", ""),
        "ShapeshiftExclude": shapeshift.get("ShapeshiftExclude_0", ""),
        "RequiredTotems": req_totems,
        "RequiredReagents": req_reagents,
        "EquippedItemClass": equipped.get("EquippedItemClass", ""),
        "EquippedItemSubclass": equipped.get("EquippedItemSubclass", ""),
        "EffectSummary": effect_summary,
    }


def generate_spell_timing_index(data):
    fields = [
        "Class", "SkillLine", "SpellID", "SpellName", "UsageTag",
        "CastTimeSec", "CastMinimumSec", "GCDSec", "CooldownSec", "CategoryCooldownSec",
        "DurationSec", "MaxDurationSec", "RangeMinYd", "RangeMaxYd", "PowerCost",
        "ShapeshiftMask", "ShapeshiftExclude", "RequiredTotems", "RequiredReagents",
        "EquippedItemClass", "EquippedItemSubclass", "EffectSummary",
    ]
    rows = []
    for ability in data["abilities"]:
        class_name = ability.get("InferredClass", "")
        if class_name not in CLASSES:
            continue
        spell_id = ability.get("SpellID", "")
        spell_name = ability.get("SpellName", "")
        timing = timing_for(data, spell_id)
        row = {
            "Class": class_name,
            "SkillLine": ability.get("SkillLine", ""),
            "SpellID": spell_id,
            "SpellName": spell_name,
            "UsageTag": usage_tag(spell_name, ability.get("SkillLine", "")),
        }
        row.update(timing)
        rows.append(row)

    out = ROOT / "All-Spells-Timing-Index.csv"
    with out.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)

    by_class = defaultdict(int)
    casted = defaultdict(int)
    gcd = defaultdict(int)
    cooldowns = defaultdict(int)
    durations = defaultdict(int)
    for row in rows:
        c = row["Class"]
        by_class[c] += 1
        if row["CastTimeSec"] not in ("", "0"):
            casted[c] += 1
        if row["GCDSec"] not in ("", "0"):
            gcd[c] += 1
        if row["CooldownSec"] not in ("", "0"):
            cooldowns[c] += 1
        if row["DurationSec"] not in ("", "0"):
            durations[c] += 1

    lines = [
        "# All Spells Timing Index",
        "",
        "This is the down-to-seconds pass for all DB2 class and pet skill-line spell rows. Values are generated from Wago Tools `wow_anniversary` DB2 exports.",
        "",
        "Blank means no joined DB2 row was present in the pulled timing table. `0` means the DB2 timing row reports zero milliseconds.",
        "",
        "## Generated File",
        "",
        "- `All-Spells-Timing-Index.csv`",
        "",
        "## Timing Coverage By Class",
        "",
        "| Class | Spell rows | Cast-time rows | GCD rows | Cooldown rows | Duration rows |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for class_name in sorted(by_class):
        lines.append(f"| {class_name} | {by_class[class_name]} | {casted[class_name]} | {gcd[class_name]} | {cooldowns[class_name]} | {durations[class_name]} |")
    lines.extend([
        "",
        "## Timing Columns",
        "",
        "- `CastTimeSec`: spell cast time in seconds from `SpellMisc.CastingTimeIndex -> SpellCastTimes.Base`.",
        "- `GCDSec`: start recovery/GCD in seconds from `SpellCooldowns.StartRecoveryTime`.",
        "- `CooldownSec`: spell recovery/cooldown in seconds from `SpellCooldowns.RecoveryTime`.",
        "- `CategoryCooldownSec`: category cooldown in seconds from `SpellCooldowns.CategoryRecoveryTime`.",
        "- `DurationSec`: aura/effect duration in seconds from `SpellMisc.DurationIndex -> SpellDuration.Duration`.",
        "- `RangeMinYd` and `RangeMaxYd`: range row from `SpellMisc.RangeIndex -> SpellRange`.",
        "- `PowerCost`, `RequiredTotems`, `RequiredReagents`, and equipped-item columns expose spell constraints useful for automation.",
    ])
    write(ROOT / "All-Spells-Timing-Index.md", "\n".join(lines))

    for class_name in sorted(by_class):
        class_rows = [r for r in rows if r["Class"] == class_name]
        if class_name == "Pet":
            path = ROOT / "Pet-Spells-Timing.md"
            title = "Pet Spell Timing"
        else:
            path = ROOT / class_name / "Spell-Timing-Index.md"
            title = f"{class_name} Spell Timing Index"
        lines = [
            f"# {title}",
            "",
            "Generated from `All-Spells-Timing-Index.csv`. This class view includes every DB2 class skill-line spell row, including ranks/passives/utility, with timings in seconds where DB2 exposes them.",
            "",
            "| Skill line | Spell ID | Spell name | Use | Cast | GCD | CD | Cat CD | Duration | Range | Cost | Constraints |",
            "|---|---:|---|---|---:|---:|---:|---:|---:|---|---|---|",
        ]
        for r in sorted(class_rows, key=lambda x: (x["SkillLine"], x["SpellName"], int(x["SpellID"] or 0))):
            constraints = []
            if r["ShapeshiftMask"]:
                constraints.append(f"shape={r['ShapeshiftMask']}")
            if r["RequiredTotems"]:
                constraints.append(f"totem={r['RequiredTotems']}")
            if r["RequiredReagents"]:
                constraints.append(f"reagent={r['RequiredReagents']}")
            if r["EquippedItemClass"]:
                constraints.append(f"equip={r['EquippedItemClass']}:{r['EquippedItemSubclass']}")
            lines.append(
                f"| {fmt(r['SkillLine'])} | {r['SpellID']} | {fmt(r['SpellName'])} | {r['UsageTag']} | {r['CastTimeSec']} | {r['GCDSec']} | {r['CooldownSec']} | {r['CategoryCooldownSec']} | {r['DurationSec']} | {r['RangeMinYd']}-{r['RangeMaxYd']} | {fmt(r['PowerCost'])} | {fmt('; '.join(constraints))} |"
            )
        write(path, "\n".join(lines))


def generate_niche_docs():
    write(ROOT / "Shared" / "Niche-Mechanics-Timing-Deep-Dive.md", """# Niche Mechanics Timing Deep Dive

This file collects the mechanics that most often break TBC rotation code when they are treated as ordinary priority buttons. The class files linked below contain exact state machines and timing rules.

## Index

| Mechanic | File | Core timing |
|---|---|---|
| Feral powershifting | `../Druid/Powershifting-Timing.md` | Energy ticks every 2.0s; Cat GCD 1.0s; shifting into form uses 1.5s GCD; Furor + Wolfshead = 60 energy on entering Cat |
| Paladin seal twisting | `../Paladin/Seal-Twisting-Timing.md` | Cast twist seal inside the final 0.4s before the white swing lands |
| Shaman totem twisting | `../Shaman/Totem-Twisting-Timing.md` | Windfury weapon buff persists about 10.0s after Windfury Totem is replaced |
| Enhancement weapon sync | `../Shaman/Totem-Twisting-Timing.md` | Avoid off-hand/main-hand collision when Flurry/Windfury timing matters |
| Hunter shot timing | `../Hunter/Shot-Timing.md` | Do not start Steady Shot before Auto Shot fires; rotation depends on effective ranged speed |
| Warrior Slam timing | `../Warrior/Slam-Timing.md` | Slam immediately after white swing; never before the swing lands |
| Rogue energy and poison timing | `../Rogue/Energy-Poison-Timing.md` | Energy ticks in 20 energy / 2.0s chunks; pool before finishers |
| Warlock imp machine gun | `../Warlock/Imp-Machine-Gun-Timing.md` | Imp Firebolt 2.0s base, 1.5s with 2/2 Improved Firebolt, 1.0s pet GCD |
| Healing downrank timing | `Healing-Downrank-Timing.md` | Downrank only when the lower rank lands before the next lethal event |

## Automation Rule

If a mechanic depends on a swing timer, energy tick, aura pulse, pet cast, seal state, totem state, or downrank table, do not implement it as a flat priority action. It needs explicit state and timing checks.
""")

    write(ROOT / "Druid" / "Powershifting-Timing.md", """# Druid Powershifting Timing

Sources: Warcraft Tavern Feral powershifting guide, Wowhead Feral DPS rotation guide, Wowhead TBC powershifting energy update, local Sonah/Flux swing and powershift references.

## Exact TBC Timing Facts

| Fact | Value |
|---|---:|
| Cat energy tick | 20 energy every 2.0s |
| Cat-form ability GCD | 1.0s |
| Shifting into Cat Form GCD | 1.5s |
| Leaving Cat Form | Does not start a GCD |
| Furor energy on Cat entry | 40 energy at 5/5 |
| Wolfshead Helm energy on Cat entry | 20 energy |
| Furor + Wolfshead Cat entry | 60 energy |

## 4-Second Cycle State Machine

1. Start near the end of a Cat cycle with energy low enough that waiting is worse than shifting.
2. Leave Cat Form. This does not start a GCD.
3. Re-enter Cat Form immediately. This starts the 1.5s form GCD and grants 60 energy with Furor + Wolfshead.
4. If the shift was timed roughly 1.0s into the 2.0s energy tick cycle, the next tick occurs during the form GCD and raises energy to about 80.
5. Cast Mangle/Shred/Rake/Rip action as soon as the 1.5s form GCD ends.
6. Wait for the next 2.0s energy tick if needed.
7. Cast the second Cat action after the energy tick.
8. As soon as that 1.0s Cat GCD ends and no mandatory finisher/refresh is pending, powershift again.

## Rotation Conditions

| Condition | Action |
|---|---|
| Mangle missing and target will live | Do not spend shift cycle on low-value filler; refresh Mangle |
| 4-5 combo points and Rip missing/expiring | Save energy/GCD for Rip |
| Energy below next useful action and mana safe | Powershift |
| Energy tick is less than 0.5s away and GCD free | Wait for tick rather than shifting if it enables immediate action |
| Mana below emergency threshold | Stop powershifting; preserve mana for forms/utility |
| Omen of Clarity active | Spend clearcast before shifting if a valid action is available |

## Automation Inputs

- `energy`
- `mana`
- `energy_tick_time_remaining`
- `gcd_remaining`
- `cat_form_active`
- `mangle_remains`
- `rip_remains`
- `combo_points`
- `clearcasting_active`
- `powershift_enabled`
- `wolfshead_equipped_or_configured`

## Guardrails

- Do not add Savage Roar, Berserk, Cat Swipe, or later-expansion energy logic.
- Do not powershift during GCD if the API cannot queue form entry safely.
- Do not powershift if the next global must be emergency Bear, decurse, battle rez, or survival.
""")

    write(ROOT / "Paladin" / "Seal-Twisting-Timing.md", """# Paladin Seal Twisting Timing

Sources: Wowhead/Wowhead comments for Seal of Blood, TBC Paladin theorycraft discussions, local Flux/Sonah seal twist state references, Warcraft Tavern Paladin seal/judgement overview.

## Exact Timing Facts

| Fact | Value |
|---|---:|
| Twist window | Final 0.4s before white swing impact |
| Required twist participant | Seal of Command must be one of the two seals |
| Judgement behavior | Consumes the active seal; coordinate with swing and Crusader Strike |
| Crusader Strike | Does not replace swing-timed twisting; it is its own cooldown action |
| Failure mode | Seal cast too early replaces the old seal; too late misses the swing |

## Basic Twist Sequence

1. Maintain the primary damage seal for the current ruleset, usually Seal of Blood / Seal of the Martyr where available.
2. Track main-hand swing timer to impact.
3. When swing remaining is `<= 0.4s` and `> latency safety floor`, cast the twist seal, commonly Seal of Command if Blood/Martyr is active.
4. Let the white swing land with both seal effects eligible.
5. After swing resolution, restore the primary seal before the next swing cycle if mana and GCD allow.
6. Use Judgement only when it will not consume the needed seal at the wrong point in the swing cycle.

## Automation Conditions

| Condition | Action |
|---|---|
| `swing_remaining > 0.4s` | Do not twist yet |
| `swing_remaining <= latency_floor` | Too late; skip twist to avoid wasting mana/GCD |
| `mana below twist floor` | Drop twisting; run simple seal/Judgement/Crusader Strike |
| `forbearance risk and Avenging Wrath planned` | Confirm no emergency bubble plan is needed |
| `movement or boss mechanic imminent` | Skip twist if swing contact is unlikely |
| `active seal will be judged` | Re-seal plan must be available before next swing |

## Suggested State Fields

- `active_seal_id`
- `primary_seal_id`
- `twist_seal_id`
- `swing_remaining`
- `latency_ms`
- `mana`
- `judgement_cd`
- `crusader_strike_cd`
- `gcd_remaining`
- `target_in_melee`
- `threat_safe`

## Guardrails

- Do not add Divine Storm, Seal of Vengeance assumptions for every faction/ruleset, Holy Power, or modern Hand spell names.
- Treat faction seal availability as data/config, not as a universal constant.
- If swing timer is unavailable, disable twisting and fall back to simple seal priority.
""")

    write(ROOT / "Shaman" / "Totem-Twisting-Timing.md", """# Shaman Totem Twisting, Imbues, and Weapon Timing

Sources: Wowhead Enhancement rotation guide, Icy Veins Enhancement guide, Warcraft Tavern Shaman totems and Enhancement guides, CurseForge TotemTwistTimer description, local Sonah/Flux totem references.

## Exact Totem-Twist Timing Facts

| Fact | Value |
|---|---:|
| Windfury Totem weapon buff persistence | About 10.0s after Windfury Totem is replaced |
| Totem cast cadence | One totem per GCD |
| Standard twist pair | Windfury Totem -> Grace of Air Totem |
| Safe refresh habit | Re-drop Windfury before 10.0s expires, commonly around 8.0-9.0s |
| Cost | High mana and attention cost |

## Basic Twist Sequence

1. Drop Windfury Totem to apply the temporary weapon buff to the melee party.
2. Immediately after the GCD allows, drop Grace of Air Totem or the assigned second Air totem.
3. Track the Windfury weapon-buff timer on party members, not just the active totem object.
4. Before the Windfury buff expires, re-drop Windfury Totem.
5. Again replace with Grace of Air after the Windfury buff is applied.
6. Stop twisting if mana, movement, interrupts, grounding/tremor duty, or survival makes twisting lower value.

## Twist State Machine

| State | Condition | Action |
|---|---|---|
| `no_wf_buff` | melee group lacks Windfury buff | Drop Windfury Totem |
| `wf_buff_applied` | Windfury buff active and GCD free | Drop Grace of Air or assigned Air totem |
| `wf_buff_refresh_soon` | Windfury buff <= 2.0s remaining | Drop Windfury Totem |
| `mana_low` | mana below configured floor | Stop twisting; keep most important single totem |
| `utility_air_needed` | Grounding/Tremor-style emergency equivalent by element/assignment | Utility totem overrides twist |

## Enhancement Weapon Timing

- Keep weapon imbues active; do not overwrite them with stones/oils unless explicitly configured.
- Watch main-hand/off-hand swing timers. Weapon sync or stagger decisions affect Windfury and Flurry behavior.
- Warcraft Tavern notes the importance of swing display and avoiding badly timed simultaneous swings when Flurry/internal timing matters.
- Stormstrike and shocks should not starve the mana needed for totem twisting if twisting is assigned.

## Automation Inputs

- `active_air_totem`
- `party_windfury_buff_remains`
- `gcd_remaining`
- `mana`
- `twist_enabled`
- `melee_group_has_warrior_or_rogue`
- `grace_of_air_assignment`
- `grounding_or_utility_override`
- `mainhand_swing_remaining`
- `offhand_swing_remaining`

## Guardrails

- Do not add Wind Shear, Lava Burst, Riptide, Hex, Feral Spirit, Maelstrom Weapon, Lava Lash, or modern Fire Nova.
- Wrath of Air does not twist like Windfury/Grace; do not assume every totem aura persists after replacement.
""")

    write(ROOT / "Warlock" / "Imp-Machine-Gun-Timing.md", """# Warlock Imp Machine Gun Timing

Sources: DB2 `SpellMisc`, `SpellCastTimes`, `SpellCooldowns`, `SpellEffect`, Warcraft Wiki Firebolt page, classic/TBC community discussions, local Warlock research.

## DB2 Timing Facts

| Spell | Spell IDs | DB2 timing |
|---|---|---|
| Imp Firebolt | 3110, 7799, 7800, 7801, 7802, 11762, 11763, 27267 | 2.0s base cast, 1.0s pet GCD, no recovery cooldown |
| Improved Firebolt rank 1 | 18126 | DB2 effect base around -251 ms; practical reduction is about 0.25s |
| Improved Firebolt rank 2 | 18127 | DB2 effect base around -501 ms; practical reduction is about 0.5s |
| Improved Imp ranks | 18694, 18695, 18696 | Increases Imp Firebolt/Fire Shield/Blood Pact effect by 10/20/30%, not cast speed |

## What "Machine Gun Imp" Means In TBC Terms

It is not a hidden 1.0s Firebolt loop from Improved Imp. The DB2-backed model is:

1. Imp Firebolt has a 2.0s cast time.
2. 2/2 Improved Firebolt reduces Firebolt by about 0.5s.
3. The resulting practical Firebolt cast is about 1.5s.
4. The pet GCD is 1.0s, so the Imp is cast-time limited at 1.5s, not GCD-limited.
5. Improved Imp increases effect/damage/Blood Pact style value, not the firing cadence.

## Automation Conditions

| Condition | Action |
|---|---|
| Imp active, target valid, Firebolt autocast enabled | Let Imp chain-cast Firebolt |
| Pet out of range or line of sight | Move/reposition pet or accept downtime |
| Target reflect/immunity/fire resistance issue | Consider pet passive/hold if Firebolt is harmful or useless |
| Threat-sensitive pull | Delay pet attack until tank threat exists |
| Raid needs Blood Pact | Keep Imp alive and in range; do not sacrifice/swap pet casually |

## Implementation Fields

- `pet_active`
- `pet_type_imp`
- `pet_casting_firebolt`
- `pet_firebolt_cast_remaining`
- `pet_gcd_remaining`
- `improved_firebolt_rank`
- `improved_imp_rank`
- `pet_target_valid`
- `pet_los_or_range_ok`

## Guardrails

- Do not import Wrath/Cata Empowered Imp, Demonic Empowerment, or modern pet scaling behavior.
- Do not call the 2/2 Improved Firebolt cadence 1.0s unless a branch-specific runtime test proves DB2 is wrong.
""")

    write(ROOT / "Hunter" / "Shot-Timing.md", """# Hunter Shot Timing

Sources: Wowhead Hunter DPS rotation guide, TBC hunter rotation theorycraft tools, Hunter PvP guide examples, local Sonah swing timer references.

## Core Timing Rules

| Rule | Timing meaning |
|---|---|
| Auto Shot must not be clipped | Wait until Auto Shot actually fires before beginning Steady Shot |
| Steady Shot weave | Cast Steady Shot in the gap after Auto Shot |
| Kill Command | Off-GCD style reaction after crit/proc; use immediately when available |
| Multi-Shot | Higher-value than Steady in many cases, but can clip Auto or break CC |
| Effective weapon speed | Determines 1:1, 1:2, 1:3, 5:5:1:1/French-style rotations |

## Automation Conditions

- If `auto_shot_about_to_fire`, do not cast Steady/Multi/Aimed.
- If `auto_shot_fired` and `steady_fits_before_next_auto`, cast Steady Shot.
- If `multi_shot_ready` and `cc_safe` and it fits before next Auto, use Multi-Shot.
- If haste pushes effective speed too low, prefer Auto preservation over extra Steady casts.
- Pet Kill Command should not disrupt the shot timer.
""")

    write(ROOT / "Warrior" / "Slam-Timing.md", """# Warrior Slam and Swing Timing

Sources: Icy Veins/Wowhead Warrior rotation guides, TBC community swing-timer discussion, local Warrior swing manager references.

## Slam Timing

| Rule | Meaning |
|---|---|
| Slam after white swing | Use Slam immediately after the auto attack lands |
| Slam before swing | Bad: delays or clips the white swing |
| Swing timer required | Arms Slam logic should be disabled or simplified without it |
| Haste threshold | Very fast swing speeds can make MS/WW priority stronger than trying to force Slam |

## Automation Conditions

- If `mainhand_swing_remaining <= safety_window`, wait for the swing instead of starting Slam.
- If `swing_just_landed` and rage is available, Slam can be used as filler.
- Mortal Strike and Whirlwind cooldowns still matter; do not Slam if it causes a major cooldown miss.
- During movement, skip Slam and use instant actions.
""")

    write(ROOT / "Rogue" / "Energy-Poison-Timing.md", """# Rogue Energy, Finishers, and Poison Timing

Sources: Icy Veins Rogue DPS rotation guide, Warcraft Tavern Rogue rotation guides, local Rogue energy tick references.

## Core Timing

| Fact | Value |
|---|---:|
| Energy tick | 20 energy every 2.0s |
| Energy cap | 100 |
| Practical pooling warning | Avoid sitting near cap before an incoming tick |
| Combo point cap | 5 |

## Finisher State Machine

1. Keep Slice and Dice active unless the target dies before it pays off.
2. Use Rupture when the target can bleed and will live long enough.
3. Use Eviscerate when Rupture will not tick enough or target is bleed immune.
4. Use Expose Armor only if assigned and raid value beats personal finisher loss.
5. Pool energy before Kidney Shot, rupture refresh, or cooldown windows.

## Poison Rules

- Do not overwrite Rogue poisons with sharpening stones/oils.
- Poison immune targets require fallback builder/finisher logic, especially for Mutilate/Envenom style decisions.
- PvP poisons are matchup tools: Wound, Crippling, Mind-numbing, and Deadly/Instant choices must be configurable.
""")

    write(ROOT / "Shared" / "Healing-Downrank-Timing.md", """# Healing Downrank Timing

Sources: Warcraft Tavern advanced Shaman coefficient/downranking guide, Icy Veins/Wowhead healer guides, local healer helper references.

## Universal Rule

Downranking is a timing and mana decision, not a blanket instruction. Use a lower rank only when it lands before the next lethal damage event and provides enough healing for the expected deficit.

## Decision Table

| Situation | Timing rule |
|---|---|
| Tank will die to next swing | Use fastest/emergency correct-rank heal or cooldown, not an efficient downrank |
| Predictable steady damage | Downrank if the lower rank lands before the next damage event and avoids overheal |
| Raid pulse in 1-2 GCDs | Pre-cast/pre-HoT or group heal; cancel if pulse does not happen |
| Mana critical | Use lower ranks, cancel-cast, potion/rune/Mana Tide/Innervate planning |
| Dispel lethal | Dispel before downranked filler heal |

## Spec Notes

- Restoration Druid: Lifebloom/Rejuvenation/Regrowth timing usually matters more than Healing Touch downrank spam.
- Holy Paladin: Flash of Light and Holy Light ranks are the core timing choices; Holy Shock is movement/emergency.
- Priest: Greater Heal/Flash Heal/Renew/Prayer choices depend on group damage and cast landing time.
- Restoration Shaman: Chain Heal rank choice depends on bounce count and damage pattern; Healing Wave downrank can be useful but TBC downranking penalties reduce old Classic-style extremes.
""")

    write(ROOT / "Shared" / "All-Niche-Mechanics-Index.md", """# All Niche Mechanics Index

This index is the answer to the "all niches" pass. It links every advanced timing/mechanic file created for the research set.

| Class/area | File |
|---|---|
| All spells down to seconds | `../All-Spells-Timing-Index.csv` and `../All-Spells-Timing-Index.md` |
| Druid powershifting | `../Druid/Powershifting-Timing.md` |
| Paladin seal twisting | `../Paladin/Seal-Twisting-Timing.md` |
| Shaman totem twisting/imbues | `../Shaman/Totem-Twisting-Timing.md` |
| Hunter shot timing | `../Hunter/Shot-Timing.md` |
| Warrior Slam timing | `../Warrior/Slam-Timing.md` |
| Rogue energy/poisons | `../Rogue/Energy-Poison-Timing.md` |
| Warlock imp machine gun | `../Warlock/Imp-Machine-Gun-Timing.md` |
| Healing downrank timing | `Healing-Downrank-Timing.md` |
| Shared deep-dive overview | `Niche-Mechanics-Timing-Deep-Dive.md` |
""")


def update_readme_sources():
    readme = ROOT / "README.md"
    text = readme.read_text(encoding="utf-8")
    block = """

## Timing and Niche Mechanics Pass

The third expansion pass adds:

- `All-Spells-Timing-Index.csv` and `All-Spells-Timing-Index.md`.
- Per-class `Spell-Timing-Index.md` files.
- `Pet-Spells-Timing.md`.
- Deep niche mechanics docs for powershifting, seal twisting, totem twisting, Hunter shot timing, Warrior Slam timing, Rogue energy/poisons, Warlock imp machine gun, and healing downrank timing.
- `Shared/All-Niche-Mechanics-Index.md`.
"""
    if "## Timing and Niche Mechanics Pass" not in text:
        readme.write_text(text.rstrip() + block + "\n", encoding="utf-8")

    sources = ROOT / "Sources.md"
    source_text = sources.read_text(encoding="utf-8")
    source_block = """

## Timing and Niche Mechanics Sources

- Warcraft Tavern Feral powershifting guide: https://www.warcrafttavern.com/tbc/guides/feral-dps-powershifting-rotation-guide/
- Wowhead Feral DPS rotation guide: https://www.wowhead.com/tbc/guide/classes/druid/feral/dps-rotation-cooldowns-abilities-pve
- Wowhead TBC powershifting energy update: https://www.wowhead.com/tbc/news/upcoming-change-to-feral-druid-energy-and-powershifting-in-tbc-classic-323041
- Wowhead Seal of Blood spell/comments: https://www.wowhead.com/tbc/spell=31892/seal-of-blood
- Wowhead Enhancement Shaman rotation guide: https://www.wowhead.com/tbc/guide/classes/shaman/enhancement/dps-rotation-cooldowns-abilities-pve
- Icy Veins Enhancement Shaman rotation guide: https://www.icy-veins.com/tbc-classic/enhancement-shaman-dps-pve-rotation-cooldowns-abilities
- Warcraft Tavern Shaman totems guide: https://www.warcrafttavern.com/tbc/guides/shaman-totems/
- Warcraft Tavern Enhancement Shaman rotation guide: https://www.warcrafttavern.com/tbc/guides/pve-enhancement-shaman-rotation-abilities/
- Warcraft Wiki Firebolt page: https://warcraft.wiki.gg/wiki/Firebolt
- Wowhead Hunter DPS rotation guide: https://www.wowhead.com/tbc/guide/classes/hunter/dps-rotation-cooldowns-abilities-pve
- Icy Veins Rogue DPS rotation guide: https://www.icy-veins.com/tbc-classic/rogue-dps-pve-rotation-cooldowns-abilities
- Warcraft Tavern Advanced Shaman guide: https://www.warcrafttavern.com/tbc/guides/advanced-shaman-guide-part-1/
"""
    if "## Timing and Niche Mechanics Sources" not in source_text:
        sources.write_text(source_text.rstrip() + source_block + "\n", encoding="utf-8")


def main():
    data = load_data()
    generate_spell_timing_index(data)
    generate_niche_docs()
    update_readme_sources()


if __name__ == "__main__":
    main()
