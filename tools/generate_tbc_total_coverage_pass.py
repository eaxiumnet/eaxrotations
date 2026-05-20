import csv
import re
from collections import defaultdict
from pathlib import Path


ROOT = Path("ClassResearchTBC")
DB2 = ROOT / "DB2"


CLASSES = ["Druid", "Hunter", "Mage", "Paladin", "Priest", "Rogue", "Shaman", "Warlock", "Warrior"]


SPECS = [
    ("Druid", "Balance", "DPS", "Caster support DPS", "Starfire/Wrath, Moonfire/Insect Swarm when efficient, Improved Faerie Fire assignment", "Hurricane only when tank control and CC safety allow", "Cyclone/roots/forms, off-heal, decurse, mobility"),
    ("Druid", "Feral-DPS", "DPS", "Cat melee DPS", "Mangle, Shred, Rip, powershift energy planning", "No Cat Swipe in TBC; target-swap and single-target priority", "Stealth opener, Cyclone/roots/forms, Bear emergency"),
    ("Druid", "Bear-Tank", "Tank", "High-armor tank", "Mangle, Lacerate, Maul, Faerie Fire, Demo Roar", "Swipe and tab-threat with rage floor", "Flag/body defense, charge/bash, anti-melee control"),
    ("Druid", "Restoration", "Healer", "HoT healer", "Lifebloom stacks, Rejuvenation, Regrowth, Swiftmend/NS saves", "Raid pre-HoT and Tranquility only when safe", "Pre-HoT, Cyclone, roots, travel form, LoS"),
    ("Hunter", "Beast-Mastery", "DPS", "Pet burst DPS", "Auto/Steady timing, Kill Command, Bestial Wrath, pet uptime", "Multi-Shot/Volley only when CC safe and tank threat stable", "Bestial Wrath kill window, traps, Viper Sting, pet pressure"),
    ("Hunter", "Marksmanship", "DPS", "Shot and utility DPS", "Auto/Steady timing, Multi-Shot if no clip/CC issue, Trueshot support", "Multi-Shot/Volley with strict CC safety", "Drain/control games with Viper Sting, traps, Scatter/Silencing style utility"),
    ("Hunter", "Survival", "DPS", "Expose Weakness support DPS", "Auto/Steady timing, crit/Expose Weakness uptime, trap control", "Multi-Shot/Volley only if no CC break", "Trap/utility, Wyvern-style control where talented, drain support"),
    ("Mage", "Arcane", "DPS", "Mana-burn caster", "Arcane Blast burn/conserve cycles, Evocation timing", "Blizzard/Arcane Explosion only when safe", "Polymorph, Counterspell, Spellsteal, burst setup"),
    ("Mage", "Fire", "DPS", "Crit/ignite caster", "Scorch assignment, Fireball, Combustion timing", "Flamestrike/Blast Wave/Dragon's Breath with CC safety", "Control into burst, Counterspell, Dragon's Breath if talented"),
    ("Mage", "Frost", "DPS", "Control caster", "Frostbolt, Water Elemental, Cold Snap planning", "Blizzard/Nova/Cone control with threat awareness", "Strong control, Ice Block, kiting, Counterspell"),
    ("Paladin", "Holy", "Healer", "Single-target healer", "Flash of Light, Holy Light ranks, Holy Shock/Divine Favor saves", "Spot heal only; no Beacon in TBC", "Cleanse, bubble, BoP/Freedom/Sacrifice, stun"),
    ("Paladin", "Protection", "Tank", "AoE Holy-threat tank", "Righteous Fury, Holy Shield, Consecration, Judgement/seal", "Consecration/Avenger's Shield with CC pathing checks", "Durable objective tank, dispels, stuns, blessings"),
    ("Paladin", "Retribution", "DPS", "Melee support DPS", "Seal/Judgement, Crusader Strike, seal twisting if supported", "Consecration if mana/threat/CC allow", "Burst with stun/wings, Cleanse/Freedom/BoP utility"),
    ("Priest", "Discipline", "Healer", "Mitigation/utility healer", "Shield rules, Flash/Greater Heal, Pain Suppression/PI", "Prayer tools only when group damage aligns", "Dispel, Mana Burn, Pain Suppression, fear"),
    ("Priest", "Holy", "Healer", "Flexible raid/tank healer", "Greater Heal ranks, Flash Heal, Renew, CoH/PoH where talented", "Circle/Prayer by injured group count", "Dispel, fear, emergency heals, no Guardian Spirit in TBC"),
    ("Priest", "Shadow", "DPS", "Mana-support DoT DPS", "VT, SW:P, Mind Blast, Mind Flay, SW:D safely", "Multidot only; no Mind Sear in TBC", "DoT pressure, Silence, fear, Mana Burn/dispels"),
    ("Priest", "Smite", "DPS", "Holy damage utility", "Holy Fire, Smite, PI/Inner Focus, utility override", "Holy Nova only if stacked/safe", "Unexpected burst, dispels, emergency heals"),
    ("Rogue", "Assassination", "DPS", "Poison/dagger DPS", "Mutilate, SnD, Rupture/Envenom/Eviscerate by target", "No real AoE; control/kill priority mobs", "Openers, poisons, stuns, blind, resets"),
    ("Rogue", "Combat", "DPS", "Primary PvE Rogue", "SnD, Sinister Strike, Rupture/Eviscerate, AR/BF", "Blade Flurry on 2 targets; no broad AoE", "Cooldown burst, Kick, stuns, control"),
    ("Rogue", "Subtlety", "DPS", "PvP/control Rogue", "Hemorrhage, opener control, finishers", "Control first, damage second", "Sap/Blind/Kidney/Vanish/Preparation control chains"),
    ("Shaman", "Elemental", "DPS", "Caster support DPS", "Lightning Bolt, Chain Lightning, shocks, Totem of Wrath", "Chain Lightning/Fire totems only if CC safe", "Purge, Grounding, Tremor, Earth Shock interrupt"),
    ("Shaman", "Enhancement", "DPS", "Melee support DPS", "Stormstrike, shocks, imbues, totems, twisting if assigned", "Magma/Fire Nova totems only if safe", "Purge, shocks, Grounding/Tremor, burst melee"),
    ("Shaman", "Restoration", "Healer", "Chain Heal raid healer", "Earth Shield, Chain Heal, Healing Wave/LHW, NS save", "Chain Heal bounce planning", "Purge, Grounding/Tremor, Earth Shield, LHW triage"),
    ("Warlock", "Affliction", "DPS", "DoT/support DPS", "Assigned curse, UA/Corruption/Siphon Life, Shadow Bolt filler", "Multidot or Seed only when threat/CC safe", "Fear/DoT/drain pressure, pet/curse utility"),
    ("Warlock", "Demonology", "DPS", "Pet-centric DPS", "Felguard/pet uptime, curse, Shadow Bolt, Life Tap", "Pet cleave/Seed with CC and threat checks", "Soul Link/Felguard control, fear, drains"),
    ("Warlock", "Destruction", "DPS", "Direct-damage caster", "Curse, Shadow Bolt or fire variant, Life Tap", "Seed on clumped controlled packs", "Burst, Shadowfury if talented, fear/curse pressure"),
    ("Warrior", "Arms", "DPS", "Two-hand support DPS", "Mortal Strike, Slam timing, Whirlwind, Execute", "Sweeping Strikes/Whirlwind/Cleave if CC safe", "MS pressure, Hamstring, Intercept, Pummel"),
    ("Warrior", "Fury", "DPS", "Dual-wield DPS", "Bloodthirst, Whirlwind, HS rage dump, Execute", "Whirlwind/Cleave when threat safe", "Uptime pressure, Intercept/Pummel, Berserker Rage"),
    ("Warrior", "Protection", "Tank", "Shield tank", "Shield Slam, Revenge, Devastate/Sunder, Shield Block", "Thunder Clap/tab target/Cleave with rage and CC checks", "Flag/objective tank, interrupts, Disarm, stuns"),
]


DUNGEONS = [
    ("Hellfire Ramparts", "60-62", "Hellfire Citadel, Hellfire Peninsula", ["Watchkeeper Gargolmar", "Omor the Unscarred", "Vazruden the Herald / Nazan"], "Early Outland melee/caster packs, patrol awareness, basic heroic spike damage."),
    ("The Blood Furnace", "61-63", "Hellfire Citadel, Hellfire Peninsula", ["The Maker", "Broggok", "Keli'dan the Breaker"], "Dense fel-orc packs, caster control, poison/slime-style pressure, boss add/control checks."),
    ("The Shattered Halls", "69-70", "Hellfire Citadel, Hellfire Peninsula", ["Grand Warlock Nethekurse", "Blood Guard Porung", "Warbringer O'mrogg", "Warchief Kargath Bladefist"], "Large melee packs, gauntlet pressure, stun/cleave risk, AoE threat stress test."),
    ("The Slave Pens", "62-64", "Coilfang Reservoir, Zangarmarsh", ["Mennu the Betrayer", "Rokmar the Crackler", "Quagmirran"], "Naga/broken packs, poison/nature pressure, healer attention to tank spikes."),
    ("The Underbog", "63-65", "Coilfang Reservoir, Zangarmarsh", ["Hungarfen", "Ghaz'an", "Swamplord Musel'ek", "The Black Stalker"], "Nature/poison themes, pet/add control, ground effects and caster positioning."),
    ("The Steamvault", "68-70", "Coilfang Reservoir, Zangarmarsh", ["Hydromancer Thespia", "Mekgineer Steamrigger", "Warlord Kalithresh"], "Caster interrupts, add control, purge/cleanse value, boss empowerment awareness."),
    ("Mana-Tombs", "64-66", "Auchindoun, Terokkar Forest", ["Pandemonius", "Tavarok", "Nexus-Prince Shaffar", "Yor"], "Ethereal caster packs, mana pressure, reflect/shield-style boss checks, add portals."),
    ("Auchenai Crypts", "65-67", "Auchindoun, Terokkar Forest", ["Shirrak the Dead Watcher", "Exarch Maladaar"], "Undead utility, caster disruption, healing pushback/positioning, summoned add control."),
    ("Sethekk Halls", "67-69", "Auchindoun, Terokkar Forest", ["Darkweaver Syth", "Talon King Ikiss", "Anzu"], "Caster packs, polymorph/fear/control risk, LoS pulls, bird/add control."),
    ("Shadow Labyrinth", "69-70", "Auchindoun, Terokkar Forest", ["Ambassador Hellmaw", "Blackheart the Inciter", "Grandmaster Vorpil", "Murmur"], "Fear/charm/caster-heavy dungeon, strong interrupt/dispels, movement and sonic burst awareness."),
    ("Old Hillsbrad Foothills", "66-68", "Caverns of Time, Tanaris", ["Lieutenant Drake", "Captain Skarloc", "Epoch Hunter"], "Escort pacing, add waves, mounted/chase sections, objective protection."),
    ("The Black Morass", "70", "Caverns of Time, Tanaris", ["Chrono Lord Deja", "Temporus", "Aeonus"], "Portal waves, add pickup, boss timers, mana pacing across continuous combat."),
    ("The Mechanar", "70", "Tempest Keep, Netherstorm", ["Gatewatcher Gyro-Kill", "Gatewatcher Iron-Hand", "Mechano-Lord Capacitus", "Nethermancer Sepethrea", "Pathaleon the Calculator"], "Mechanic/caster packs, polarity/bomb-style movement, add control."),
    ("The Botanica", "70", "Tempest Keep, Netherstorm", ["Commander Sarannis", "High Botanist Freywinn", "Thorngrin the Tender", "Laj", "Warp Splinter"], "Botanical/nature packs, add waves, interrupts, poison/nature resistance checks."),
    ("The Arcatraz", "70", "Tempest Keep, Netherstorm", ["Zereketh the Unbound", "Dalliah the Doomsayer", "Wrath-Scryer Soccothrates", "Harbinger Skyriss"], "Dangerous caster/demon packs, stuns/interrupts, heavy heroic tank damage, multi-phase final boss."),
    ("Magisters' Terrace", "70", "Isle of Quel'Danas", ["Selin Fireheart", "Vexallus", "Priestess Delrissa", "Kael'thas Sunstrider"], "High-density caster/control dungeon, PvP-like Delrissa fight, purge/interrupt/CC priority."),
]


RAIDS = [
    ("Karazhan", "10-player", "Deadwind Pass", ["Servant Quarters", "Attumen the Huntsman", "Moroes", "Maiden of Virtue", "Opera Event", "The Curator", "Terestian Illhoof", "Shade of Aran", "Netherspite", "Chess Event", "Prince Malchezaar", "Nightbane"], "Mixed undead/demon/caster utility, CC, interrupts, add control, tank spikes, movement, beam/phase handling."),
    ("Gruul's Lair", "25-player", "Blade's Edge Mountains", ["High King Maulgar", "Gruul the Dragonkiller"], "Council control/tanking assignments, shatter movement, growth-based tank pressure, threat discipline."),
    ("Magtheridon's Lair", "25-player", "Hellfire Peninsula", ["Magtheridon"], "Channeler add control, interrupt rotations, cube/click assignments, tank cooldowns and raid burst windows."),
    ("Serpentshrine Cavern", "25-player", "Zangarmarsh", ["Hydross the Unstable", "The Lurker Below", "Leotheras the Blind", "Fathom-Lord Karathress", "Morogrim Tidewalker", "Lady Vashj"], "Resistance/tank swaps, add waves, water/movement, demon phase control, multi-add tanking, final phase objective handling."),
    ("The Eye / Tempest Keep", "25-player", "Netherstorm", ["Al'ar", "Void Reaver", "High Astromancer Solarian", "Kael'thas Sunstrider"], "Air/ground movement, threat resets, arcane/caster pressure, legendary weapon/add phase handling, interrupts."),
    ("Hyjal Summit", "25-player", "Caverns of Time", ["Rage Winterchill", "Anetheron", "Kaz'rogal", "Azgalor", "Archimonde"], "Wave-based trash, AoE threat, decurse/fear/doom mechanics, boss transitions, anti-fear and survival checks."),
    ("Black Temple", "25-player", "Shadowmoon Valley", ["High Warlord Naj'entus", "Supremus", "Shade of Akama", "Teron Gorefiend", "Gurtogg Bloodboil", "Reliquary of Souls", "Mother Shahraz", "Illidari Council", "Illidan Stormrage"], "Tank spikes, target swaps, ghost/vehicle-style duty, council interrupts, shadow resistance planning, demon phase control."),
    ("Zul'Aman", "10-player", "Ghostlands", ["Akil'zon", "Nalorakk", "Jan'alai", "Halazzi", "Hex Lord Malacrass", "Zul'jin"], "Timed-run routing, animal boss mechanics, add waves, interrupts/dispels, multi-mob council-style control. Guardrail: original TBC final boss is Zul'jin; verify any source naming Daakara before use."),
    ("Sunwell Plateau", "25-player", "Isle of Quel'Danas", ["Kalecgos", "Brutallus", "Felmyst", "Eredar Twins", "M'uru", "Kil'jaeden"], "High raid damage, strict dispels, tank busters, portal/split-realm style duty, add burn, survival cooldown chains."),
    ("Doom Lord Kazzak", "Outdoor raid boss", "Hellfire Peninsula", ["Doom Lord Kazzak"], "World-boss threat, shadow damage, anti-heal/drain checks, tight kill discipline."),
    ("Doomwalker", "Outdoor raid boss", "Shadowmoon Valley", ["Doomwalker"], "World-boss threat, earthquake/chain lightning-style raid spread, tank positioning."),
]


PVP_CLASSES = {
    "Druid": "Respect Cyclone, roots, HoTs, travel form, and stealth. Purge/dispels pressure Restoration; slows/stuns punish Feral; interrupts hurt Balance casts.",
    "Hunter": "Control pet and range, remove Viper Sting where possible, avoid trap chains, close gaps carefully after dead-zone removal.",
    "Mage": "Stop Polymorph chains, force Ice Block, dispel Spellsteal value, avoid Shatter setups, pressure during Counterspell downtime.",
    "Paladin": "Bait bubble/BoP/Freedom, purge/dispels where possible, watch Hammer of Justice and Cleanse; do not tunnel into immunities.",
    "Priest": "Protect buffs from dispel, stop Mana Burn, punish fear cooldown, pressure Shadow before DoTs stabilize.",
    "Rogue": "Deny opener where possible, survive Cheap/Kidney chain, remove poisons, keep DoTs/bleeds to prevent easy resets.",
    "Shaman": "Kill/deny key totems, fake or bait Grounding, expect Earth Shock interrupts and Purge; Tremor changes fear plans.",
    "Warlock": "Break Fear chains, dispel/cleanse carefully around UA, control pet, line-of-sight DoTs/drains when possible.",
    "Warrior": "Control uptime with roots/slows/disarms, watch Intercept/Pummel, do not feed rage with weak damage unless kiting is secured.",
}


HEALERS = [
    ("Restoration Druid", "HoT/rolling tank and mobile raid support", "Lifebloom stack, Rejuvenation, Regrowth, Swiftmend/NS", "Pre-HoT before damage; avoid blooming unless burst healing is needed", "Remove Curse, Abolish Poison"),
    ("Holy Paladin", "Efficient single-target/tank healer", "Flash of Light, Holy Light ranks, Holy Shock, Divine Favor", "Maintain Light's Grace for heavy periods; Cleanse can outrank filler", "Cleanse magic/poison/disease"),
    ("Discipline Priest", "Mitigation/utility healer", "PW:S with rage caveat, Flash/Greater Heal, Pain Suppression, Power Infusion", "Shield only when Weakened Soul and rage concerns allow", "Dispel Magic, Abolish Disease"),
    ("Holy Priest", "Flexible tank/raid healer", "Greater Heal, Flash Heal, Renew, Prayer of Healing, Circle of Healing if talented", "Downrank and cancel-cast; use group heals by injured-count", "Dispel Magic, Abolish Disease"),
    ("Restoration Shaman", "Chain Heal raid healer", "Earth Shield, Chain Heal, Healing Wave, Lesser Healing Wave, Nature's Swiftness", "Bounce planning and Mana Tide timing are core", "Poison/Disease cleansing totems and direct cures"),
]


TANKS = [
    ("Bear Druid", "Armor/health tank with strong sustained threat", "Mangle, Lacerate, Maul, Swipe", "Swipe/tab-target on packs; rage floor for taunt/recovery", "Frenzied Regeneration, Barkskin, trinkets"),
    ("Protection Paladin", "AoE Holy-threat tank", "Righteous Fury, Consecration, Holy Shield, Judgement/seal", "Consecration and Holy Shield maintain pack threat; mana depends on damage/heals", "Ardent Defender, bubble/cancelaura, trinkets, potions"),
    ("Protection Warrior", "Shield control/snap tank", "Shield Slam, Revenge, Devastate/Sunder, Shield Block", "Tab threat plus Thunder Clap/Cleave where safe; rage floor for Shield Block", "Shield Wall, Last Stand, trinkets, stance tools"),
]


def read_csv(path):
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text.rstrip() + "\n", encoding="utf-8")


def esc(value):
    return str(value or "").replace("|", "\\|").replace("\n", " ").strip()


def usage_tag(class_name, spell_name):
    name = spell_name.lower()
    passive_words = ["improved", "specialization", "mastery", "precision", "focus", "subtlety", "instinct", "fury", "power", "guidance", "knowledge"]
    heal_words = ["heal", "renew", "rejuvenation", "regrowth", "lifebloom", "chain heal", "holy light", "flash of light", "earth shield", "prayer", "shield"]
    tank_words = ["taunt", "growl", "righteous fury", "holy shield", "shield block", "shield slam", "revenge", "lacerate", "maul", "swipe", "devastate", "sunder"]
    pvp_words = ["fear", "polymorph", "cyclone", "sap", "blind", "kidney", "counterspell", "purge", "mana burn", "viper", "trap", "hamstring", "stun", "silence"]
    dps_words = ["bolt", "shot", "strike", "blast", "fireball", "frostbolt", "wrath", "starfire", "shadow word", "mind", "mangle", "shred", "sinister", "bloodthirst", "whirlwind", "execute", "incinerate", "corruption", "curse", "judgement", "seal"]
    if any(w in name for w in heal_words):
        return "healing"
    if any(w in name for w in tank_words):
        return "tanking"
    if any(w in name for w in pvp_words):
        return "pvp-control"
    if any(w in name for w in dps_words):
        return "damage"
    if any(w in name for w in passive_words):
        return "talent-passive"
    return "utility-or-rank"


def playstyle_tags(class_name, spell_name, skill_line):
    combined = f"{spell_name} {skill_line}".lower()
    tags = []
    if usage_tag(class_name, spell_name) == "damage":
        tags.append("single-target")
    if any(w in combined for w in ["multi-shot", "cleave", "whirlwind", "hurricane", "blizzard", "rain of fire", "seed", "consecration", "chain lightning", "chain heal", "sweeping", "volley", "arcane explosion", "holy nova", "magma"]):
        tags.append("multi-target")
    if usage_tag(class_name, spell_name) == "healing":
        tags.append("healing")
    if usage_tag(class_name, spell_name) == "tanking":
        tags.append("tanking")
    if usage_tag(class_name, spell_name) == "pvp-control":
        tags.append("pvp")
    if any(w in combined for w in ["poison", "curse", "disease", "dispel", "cleanse", "remove", "purge"]):
        tags.append("dispel-cleanse")
    if any(w in combined for w in ["totem", "seal", "stance", "form", "aspect", "poison", "imbue"]):
        tags.append("state-maintenance")
    return ";".join(tags) if tags else "utility"


def generate_all_spell_and_talent_indexes():
    abilities = read_csv(DB2 / "wago_anniversary_class_skillline_abilities.csv")
    talents = read_csv(DB2 / "wago_anniversary_talents_by_tree.csv")

    spell_out = ROOT / "All-Spells-Usage-Index.csv"
    with spell_out.open("w", newline="", encoding="utf-8") as handle:
        fields = ["Class", "SkillLineID", "SkillLine", "SpellID", "SpellName", "UsageTag", "PlaystyleTags", "AcquireMethod", "ClassMask", "RaceMask"]
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in abilities:
            class_name = row.get("InferredClass", "")
            if class_name not in CLASSES and class_name != "Pet":
                continue
            spell_name = row.get("SpellName", "")
            writer.writerow({
                "Class": class_name,
                "SkillLineID": row.get("SkillLineID", ""),
                "SkillLine": row.get("SkillLine", ""),
                "SpellID": row.get("SpellID", ""),
                "SpellName": spell_name,
                "UsageTag": usage_tag(class_name, spell_name),
                "PlaystyleTags": playstyle_tags(class_name, spell_name, row.get("SkillLine", "")),
                "AcquireMethod": row.get("AcquireMethod", ""),
                "ClassMask": row.get("ClassMask", ""),
                "RaceMask": row.get("RaceMask", ""),
            })

    talent_out = ROOT / "All-Talents-Usage-Index.csv"
    with talent_out.open("w", newline="", encoding="utf-8") as handle:
        fields = ["Class", "Tree", "TierID", "ColumnIndex", "TalentID", "RankSpellIDs", "RankSpellNames", "UsageTag", "PlaystyleTags", "PrereqTalent0", "RequiredSpellID"]
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in talents:
            class_name = row.get("Class", "")
            names = row.get("RankSpellNames", "") or row.get("SpellName", "")
            writer.writerow({
                "Class": class_name,
                "Tree": row.get("Tree", ""),
                "TierID": row.get("TierID", ""),
                "ColumnIndex": row.get("ColumnIndex", ""),
                "TalentID": row.get("TalentID", ""),
                "RankSpellIDs": row.get("RankSpellIDs", ""),
                "RankSpellNames": names,
                "UsageTag": usage_tag(class_name, names),
                "PlaystyleTags": playstyle_tags(class_name, names, row.get("Tree", "")),
                "PrereqTalent0": row.get("PrereqTalent0", ""),
                "RequiredSpellID": row.get("RequiredSpellID", ""),
            })

    counts = defaultdict(lambda: defaultdict(int))
    for row in read_csv(spell_out):
        counts[row["Class"]][row["UsageTag"]] += 1
    lines = [
        "# All Spells and Talents Usage Index",
        "",
        "This pass adds usage tags on top of the DB2 class spell/talent extracts. The CSVs are intentionally broad: they include rank rows, passives, utility, PvP/control, healing, tanking, and damage entries so no class spellbook area is invisible.",
        "",
        "## Files",
        "",
        "- `All-Spells-Usage-Index.csv` - every DB2 class/pet skill-line ability row with usage and playstyle tags.",
        "- `All-Talents-Usage-Index.csv` - every DB2 talent row with usage and playstyle tags.",
        "",
        "## Spell Usage Counts by Class",
        "",
        "| Class | Damage | Healing | Tanking | PvP/control | Talent/passive | Utility/rank |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for class_name in sorted(counts):
        c = counts[class_name]
        lines.append(f"| {class_name} | {c['damage']} | {c['healing']} | {c['tanking']} | {c['pvp-control']} | {c['talent-passive']} | {c['utility-or-rank']} |")
    lines.extend([
        "",
        "## Usage",
        "",
        "- Use `UsageTag` to decide whether a spell belongs in a DPS, healing, tanking, PvP, passive, or utility review.",
        "- Use `PlaystyleTags` for automation buckets such as `single-target`, `multi-target`, `healing`, `tanking`, `pvp`, `dispel-cleanse`, and `state-maintenance`.",
        "- The tags are research labels, not runtime authority. DB2 spell IDs remain the authoritative identifiers.",
    ])
    write(ROOT / "All-Spells-and-Talents-Usage.md", "\n".join(lines))


def generate_dungeon_docs():
    lines = [
        "# All TBC Dungeons Deep Matrix",
        "",
        "Second-pass total coverage for all Burning Crusade dungeons. Source hubs: Wowhead TBC dungeon overview and dungeon guide index, Icy Veins TBC dungeon guide hub, Warcraft Tavern dungeons/raids hub.",
        "",
        "## All Dungeons",
        "",
        "| Dungeon | Normal level | Location | Bosses | Total-coverage rotation modifiers |",
        "|---|---|---|---|---|",
    ]
    for dungeon, level, location, bosses, focus in DUNGEONS:
        lines.append(f"| {dungeon} | {level} | {location} | {', '.join(bosses)} | {focus} |")
    lines.extend([
        "",
        "## Role Rules For Every Dungeon",
        "",
        "| Role | Universal dungeon rule | Failure case this prevents |",
        "|---|---|---|",
        "| Tank | Mark or establish priority before DPS starts; LoS caster packs; face cleaves away | DPS deaths, healer threat, accidental extra pulls |",
        "| Healer | Track tank spike windows, dispel lethal debuffs, drink/mana-plan between pulls | OOM on heroics, deaths during chained pulls |",
        "| Melee DPS | Interrupt healers/casters, avoid frontals, disable cleave around CC | Broken CC and cleave deaths |",
        "| Ranged DPS | Kill priority adds, protect CC, kite runners/adds, decurse/dispel if class can | Pulling extra packs and failed mechanics |",
        "| Pet classes | Move pet behind mobs and disable pet cleave near CC | Pet deaths and broken CC |",
        "",
        "## Automation Checks",
        "",
        "- `cc_safe` before any AoE/cleave.",
        "- `tank_has_pack_control` before sustained AoE.",
        "- `dangerous_cast` before damage filler.",
        "- `runner_low_hp` before continuing normal target priority.",
        "- `healer_mob_active` before normal boss/pack DPS.",
        "- `heroic_mode` should lower defensive thresholds and raise CC/interrupt priority.",
    ])
    write(ROOT / "Encounters" / "All-Dungeons-Deep-Matrix.md", "\n".join(lines))


def generate_raid_docs():
    lines = [
        "# All TBC Raids Deep Matrix",
        "",
        "Second-pass total coverage for Burning Crusade raid and outdoor raid-boss content. Source hubs: Wowhead TBC raid overview, Icy Veins raid/dungeon hubs, and existing class guide sources.",
        "",
        "## All Raids and Raid Bosses",
        "",
        "| Raid | Size | Location | Bosses | Total-coverage rotation modifiers |",
        "|---|---|---|---|---|",
    ]
    for raid, size, location, bosses, focus in RAIDS:
        lines.append(f"| {raid} | {size} | {location} | {', '.join(bosses)} | {focus} |")
    lines.extend([
        "",
        "## Raid Role Rules",
        "",
        "| Role | Rule | Implementation note |",
        "|---|---|---|",
        "| Main tank | Preserve mitigation resource for tank busters and taunt swaps | Defensive threshold should be encounter-aware, not only HP-based |",
        "| Off tank | Watch add timers and taunt/snap-threat windows | Add wave logic overrides boss filler |",
        "| Healer | Pre-cast/pre-HoT for scripted damage; dispel by danger | Healing target selection needs debuff danger weighting |",
        "| Melee DPS | Obey frontals/cleaves, threat walls, and target swaps | Movement and target-lock logic must beat pure priority |",
        "| Ranged DPS | Handle spread/stack, interrupts, add burns, and school swaps | Resist/immunity checks must alter spell priority |",
        "| Hybrid DPS | Utility assignments can outrank damage | Decurse, cleanse, off-heal, innervate, purge, grounding/tremor |",
        "",
        "## Boss Mechanic Buckets",
        "",
        "| Bucket | Examples | Affected automation |",
        "|---|---|---|",
        "| Add waves | Hyjal waves, Vashj, M'uru, Magtheridon channelers | Target priority, AoE, snap threat, interrupts |",
        "| Tank busters | Brutallus, Gruul growth, Illidan phases | Defensive manager and healer pre-cast |",
        "| Resistance/immunity | Hydross, Mother Shahraz, school-heavy bosses | Spell school fallback and gear set selection |",
        "| Movement | Shatter, flame patches, beams, air phases | Instant-cast and movement-priority rules |",
        "| Council/control | Maulgar, Illidari Council, Delrissa-like fights | Interrupt/CC target rotation |",
        "| Assignment mechanics | Cubes, beams, ghosts, portals, click duties | Rotation pause/utility override state |",
    ])
    write(ROOT / "Encounters" / "All-Raids-Deep-Matrix.md", "\n".join(lines))


def generate_pvp_docs():
    lines = [
        "# Total PvP Coverage Matrix",
        "",
        "Second-pass PvP coverage for arena, battlegrounds, world PvP, class matchups, and spec playstyles. Sources include TBCPVP arena guide hub, Wowhead TBC PvP class guides, Icy Veins PvP hubs, and local Sonah PvP references.",
        "",
        "## Brackets and Modes",
        "",
        "| Mode | What matters | Rotation consequence |",
        "|---|---|---|",
        "| 2v2 arena | Mana, resets, LoS, dampened kill windows | Defensive/resource logic often outranks damage filler |",
        "| 3v3 arena | Cross-CC, burst setup, healer swaps | Track enemy healer CC/interrupt state before burst |",
        "| 5v5 arena | Fast target calls, burst, interrupts, purge/dispel volume | Prefer quick-response utility and survival thresholds |",
        "| Battlegrounds | Objectives, group fights, flag/base defense | Target objectives and control before PvE-style damage |",
        "| World PvP | Opener advantage, escape tools, consumables, uneven numbers | Defensive and mobility rules need earlier trigger points |",
        "",
        "## Enemy Class Response Matrix",
        "",
        "| Enemy class | Response rules |",
        "|---|---|",
    ]
    for class_name, text in PVP_CLASSES.items():
        lines.append(f"| {class_name} | {text} |")
    lines.extend([
        "",
        "## Spec PvP Playstyle Index",
        "",
        "| Class | Spec | PvP role | Primary PvP checks |",
        "|---|---|---|---|",
    ])
    for class_name, spec, role, identity, single, multi, pvp in SPECS:
        lines.append(f"| {class_name} | {spec} | {identity} | {pvp} |")
    lines.extend([
        "",
        "## PvP Automation Rules",
        "",
        "- Never run pure PvE rotation while the player or healer is under lethal pressure.",
        "- Enemy cast danger, healer CC, burst cooldowns, trinket state, and LoS state are higher-order decisions.",
        "- Track diminishing returns where local API/support code allows it.",
        "- Do not break friendly CC with cleave, DoTs, pet cleave, Consecration, Chain Lightning, Seed, or Blizzard unless kill-confirmed.",
        "- PvP consumable/item usage must obey arena/battleground restrictions.",
    ])
    write(ROOT / "Shared" / "PvP-Total-Coverage-Matrix.md", "\n".join(lines))


def generate_role_playbooks():
    heal_lines = [
        "# Total Healing Playbook",
        "",
        "All TBC healing playstyles in one implementation-oriented matrix.",
        "",
        "| Spec | Healing identity | Single-target plan | Multi-target plan | Dispel/utility |",
        "|---|---|---|---|---|",
    ]
    for spec, identity, single, multi, dispel in HEALERS:
        heal_lines.append(f"| {spec} | {identity} | {single} | {multi} | {dispel} |")
    heal_lines.extend([
        "",
        "## Healing Priority Ladder",
        "",
        "1. Prevent immediate lethal damage on assigned tank or objective carrier.",
        "2. Remove lethal debuff if dispel is faster than healing through it.",
        "3. Use emergency cooldown if the next boss swing/global would kill.",
        "4. Use efficient planned heal/rank for predictable damage.",
        "5. Use group/raid heal only when enough targets benefit.",
        "6. Conserve, drink, or mana restore before the next scripted spike.",
        "",
        "## Downrank/Overheal Rules",
        "",
        "- Downrank when the target is not in lethal range and the lower rank lands before the next damage event.",
        "- Cancel-cast if incoming damage does not happen and no other target needs that heal.",
        "- Do not downrank emergency saves.",
        "- Add incoming-damage prediction when local API support is reliable.",
    ])
    write(ROOT / "Shared" / "Healing-Total-Playbook.md", "\n".join(heal_lines))

    tank_lines = [
        "# Total Tanking Playbook",
        "",
        "All TBC tanking playstyles in one implementation-oriented matrix.",
        "",
        "| Spec | Tank identity | Single-target threat | Multi-target threat | Defensive plan |",
        "|---|---|---|---|---|",
    ]
    for spec, identity, single, multi, defensive in TANKS:
        tank_lines.append(f"| {spec} | {identity} | {single} | {multi} | {defensive} |")
    tank_lines.extend([
        "",
        "## Tank Priority Ladder",
        "",
        "1. Position mobs and face cleaves/frontal attacks away.",
        "2. Use required active mitigation before the swing/spell window.",
        "3. Establish snap threat on skull or add.",
        "4. Maintain debuffs and sustained threat.",
        "5. Spend excess resource only after defensive and recovery floors are safe.",
        "6. Taunt/snap recover loose mobs before returning to normal cycle.",
        "",
        "## Dungeon vs Raid Tanking",
        "",
        "- Dungeons emphasize CC safety, LoS pulls, and pack control.",
        "- Raids emphasize boss timers, tank swaps, mitigation windows, and threat ceilings.",
        "- Heroics raise the defensive floor and lower tolerance for DPS pre-pulls.",
    ])
    write(ROOT / "Shared" / "Tanking-Total-Playbook.md", "\n".join(tank_lines))

    dps_lines = [
        "# Total DPS Playstyle Matrix",
        "",
        "All 29 spec playstyles in one table for single-target, multi-target, and PvP review.",
        "",
        "| Class | Spec | Role | Identity | Single-target | Multi-target | PvP/utility |",
        "|---|---|---|---|---|---|---|",
    ]
    for row in SPECS:
        dps_lines.append("| " + " | ".join(esc(v) for v in row) + " |")
    write(ROOT / "Shared" / "All-Playstyles-Role-Matrix.md", "\n".join(dps_lines))


def generate_total_audit():
    lines = [
        "# Total Coverage Pass Audit",
        "",
        "Generated after the user's second request for another pass across dungeons, raiding, PvP, all spells, all playstyles, healing, and tanking.",
        "",
        "## Added Coverage",
        "",
        "| Area | Artifact | Status |",
        "|---|---|---|",
        "| All DB2 spells | `All-Spells-Usage-Index.csv`, `All-Spells-and-Talents-Usage.md` | Complete index/tag pass |",
        "| All DB2 talents | `All-Talents-Usage-Index.csv`, `All-Spells-and-Talents-Usage.md` | Complete index/tag pass |",
        "| Dungeons | `Encounters/All-Dungeons-Deep-Matrix.md` | All TBC dungeons listed with bosses and role modifiers |",
        "| Raids | `Encounters/All-Raids-Deep-Matrix.md` | All TBC raids/outdoor bosses listed with bosses and mechanic buckets |",
        "| PvP | `Shared/PvP-Total-Coverage-Matrix.md` | Brackets, enemy class responses, spec playstyles |",
        "| Healing | `Shared/Healing-Total-Playbook.md` | All healer playstyles and decision ladder |",
        "| Tanking | `Shared/Tanking-Total-Playbook.md` | All tank playstyles and decision ladder |",
        "| Playstyles | `Shared/All-Playstyles-Role-Matrix.md` | All 29 specs summarized |",
        "",
        "## Remaining Truth Boundary",
        "",
        "This pass indexes and structures every requested area. Boss-by-boss exact ability timers, every individual trash mob spell, and matchup-by-matchup arena scripts are effectively unbounded; those should be added as encounter-specific child pages only when implementing a concrete rotation behavior.",
    ]
    write(ROOT / "TOTAL_COVERAGE_PASS_AUDIT.md", "\n".join(lines))


def update_readme_sources():
    readme = ROOT / "README.md"
    text = readme.read_text(encoding="utf-8")
    block = """

## Total Coverage Pass

The second expansion pass adds:

- `All-Spells-Usage-Index.csv` and `All-Talents-Usage-Index.csv`.
- `All-Spells-and-Talents-Usage.md`.
- `Encounters/All-Dungeons-Deep-Matrix.md`.
- `Encounters/All-Raids-Deep-Matrix.md`.
- `Shared/PvP-Total-Coverage-Matrix.md`.
- `Shared/Healing-Total-Playbook.md`.
- `Shared/Tanking-Total-Playbook.md`.
- `Shared/All-Playstyles-Role-Matrix.md`.
- `TOTAL_COVERAGE_PASS_AUDIT.md`.
"""
    if "## Total Coverage Pass" not in text:
        readme.write_text(text.rstrip() + block + "\n", encoding="utf-8")

    sources = ROOT / "Sources.md"
    source_text = sources.read_text(encoding="utf-8")
    source_block = """

## Total Coverage Pass Sources

- Wowhead TBC dungeon overview: https://www.wowhead.com/tbc/guide/dungeons-overview-burning-crusade-classic
- Wowhead TBC dungeon guide index: https://www.wowhead.com/tbc/guides/dungeons
- Icy Veins TBC dungeon guides: https://www.icy-veins.com/tbc-classic/dungeon-guides
- Warcraft Tavern TBC dungeons and raids hub: https://www.warcrafttavern.com/tbc/guides/dungeons-raids/
- Wowhead TBC raid overview: https://www.wowhead.com/tbc/guide/raids-overview-burning-crusade-classic
- TBCPVP arena guide hub: https://www.tbcpvp.com/pages/arena-guides
- Wowhead Hunter PvP guide example: https://www.wowhead.com/tbc/guide/classes/hunter/dps-pvp-arena
"""
    if "## Total Coverage Pass Sources" not in source_text:
        sources.write_text(source_text.rstrip() + source_block + "\n", encoding="utf-8")


def main():
    generate_all_spell_and_talent_indexes()
    generate_dungeon_docs()
    generate_raid_docs()
    generate_pvp_docs()
    generate_role_playbooks()
    generate_total_audit()
    update_readme_sources()


if __name__ == "__main__":
    main()
