#!/usr/bin/env python3
"""
Fix leveling test files with outdated strategy indices.
Reads source leveling files to extract strategy order,
then fixes corresponding test files.
"""
import re
import os

BASE = "C:/newbot/scripts"

# ============================================================
# Extract strategy order from source files
# ============================================================
def extract_strategies(filepath):
    """Extract ordered list of strategy names from a source leveling file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find the strategies table
    # Pattern: { name = "StrategyName",
    names = re.findall(r'name\s*=\s*"([^"]+)"', content)
    
    # Filter to only strategy names (not other name= fields)
    # Strategy entries look like: { name = "StrategyName",
    # But there can be other name= fields too. Let's look specifically after local strategies = { 
    strategies_section = re.search(r'local strategies = \{.*?(?=\n\})', content, re.DOTALL)
    if not strategies_section:
        strategies_section = re.search(r'local strategies = \{(.*?)\n\}', content, re.DOTALL)
    
    if strategies_section:
        section = strategies_section.group(1)
        strat_names = re.findall(r'name\s*=\s*"([^"]+)"', section)
        return strat_names
    
    return names

# ============================================================
# Extract strategy references from test files
# ============================================================
def extract_test_refs(filepath, prefix="strategies"):
    """Extract all strategy[N] references from test file with context."""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    refs = []
    pattern = re.compile(r'(' + re.escape(prefix) + r')\[(\d+)\]')
    for m in pattern.finditer(content):
        refs.append({
            'full': m.group(0),
            'prefix': m.group(1),
            'index': int(m.group(2)),
            'start': m.start(),
            'end': m.end(),
        })
    return refs

# ============================================================
# Map old index -> new index based on strategy name context
# ============================================================
def compute_mappings(source_names, test_refs, content, old_count, new_count):
    """Compute index mappings by matching strategy names in test context to source order."""
    mappings = {}
    
    # For each reference, look at surrounding context to guess which strategy it's for
    for ref in test_refs:
        old_idx = ref['index']
        full_match = ref['full']
        prefix = ref['prefix']
        
        # Look at context around this reference (50 chars before, 200 after)
        start = max(0, ref['start'] - 50)
        end = min(len(content), ref['end'] + 200)
        context = content[start:end]
        
        # Try to find strategy name in context
        for i, name in enumerate(source_names):
            new_idx = i + 1
            # Look for camelCase, snake_case, or spaced versions of the name
            patterns = [
                name,
                name.lower(),
                name.replace('_', ' '),
            ]
            for p in patterns:
                if p.lower() in context.lower():
                    if old_idx != new_idx:
                        mappings[(prefix, old_idx)] = {'new_idx': new_idx, 'name': name}
                    break
            else:
                continue
            break
    
    return mappings

# ============================================================
# Manual mappings based on deep analysis
# ============================================================

# MAGE: 19 strategies (old test had 13, edge_cases uses 15-based)
# Source order:
MAGE_ORDER = [
    "ArcaneIntellect", "FrostArmor", "RemoveCurse", "ConjureManaGem",
    "Polymorph", "Counterspell", "ManaShield", "IceBarrier", "FrostNova",
    "ConeOfCold", "Blink", "Blizzard", "Evocation", "FireBlast",
    "Scorch", "ArcaneMissiles", "Frostbolt", "UseManaGem", "Wand"
]

# PRIEST: 20 strategies (old test had 18)
PRIEST_ORDER = [
    "PowerWordFortitude", "InnerFire", "Shadowform", "PowerWordShield",
    "Renew", "FlashHeal", "InnerFocus", "GreaterHeal", "PsychicScream",
    "Fade", "ShackleUndead", "ShadowWordPain", "VampiricTouch", "ShadowWordDeath",
    "HolyFire", "MindBlast", "MindFlay", "HolyNova", "Smite", "Wand"
]

# ROGUE: 20 strategies (old test had 17)
ROGUE_ORDER = [
    "Stealth", "Ambush", "Garrote", "Kick", "Gouge", "ShivPurge",
    "Vanish", "Evasion", "Sprint", "Blind", "Disarm", "ColdBlood",
    "AdrenalineRush", "BladeFlurry", "SliceAndDice", "Rupture",
    "ExposeArmor", "KidneyShot", "Eviscerate", "SinisterStrike"
]

# SHAMAN: 23 strategies (old test had 18)
SHAMAN_ORDER = [
    "WeaponImbue", "LightningShield", "WaterShield", "EarthShockInterrupt",
    "ShamanisticRage", "HealingWave", "LesserHealingWave", "SearingTotem",
    "StrengthOfEarthTotem", "WaterTotem", "GroundingTotem", "TremorTotem",
    "Stormstrike", "ChainLightning", "FlameShock", "EarthShock",
    "Purge", "FrostShock", "EarthbindTotem", "StoneclawTotem",
    "LightningBolt", "GhostWolf", "Wand"
]

# ============================================================
# Fix: test_leveling_mage.lua
# Current assertions: #strategies = 19 (already correct!)
# The failures are all strategy index mismatches
# ============================================================

def fix_mage_test():
    filepath = os.path.join(BASE, "EaxRotations/tests/test_leveling_mage.lua")
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # The test already has 19 strategies count. Fix individual indices.
    # Based on test failures, old indices map to specific strategies.
    # Let me search for which strategy name each test references by reading the test.
    
    # From the test output, I can map test name -> strategy name:
    # "polymorph_matches" -> index was probably 2 or similar
    # "counterspell_matches" -> index was probably 3
    # "mana_shield_matches" -> index was probably 5
    # etc.
    
    # Let me find all strategies[N] references and their surrounding context
    refs = extract_test_refs(filepath)
    
    replacements = []
    
    for ref in refs:
        old_idx = ref['index']
        
        # Get context around reference
        start = max(0, ref['start'] - 200)
        end = min(len(content), ref['end'] + 100)
        ctx = content[start:end].lower()
        
        new_idx = old_idx  # default: no change
        
        # Map based on context clues
        if 'wand' in ctx and 'mana_pct' in ctx:
            new_idx = 19
        elif 'frostbolt' in ctx or 'frostbolt_matches' in ctx:
            new_idx = 17
        elif 'arcane_missiles' in ctx or 'arcane missiles' in ctx:
            new_idx = 16
        elif 'scorch' in ctx:
            new_idx = 15
        elif 'fire_blast' in ctx or 'fire blast' in ctx:
            new_idx = 14
        elif 'evocation' in ctx:
            new_idx = 13
        elif 'blizzard' in ctx:
            new_idx = 12
        elif 'blink' in ctx:
            new_idx = 11
        elif 'cone_of_cold' in ctx or 'cone of cold' in ctx:
            new_idx = 10
        elif 'frost_nova' in ctx or 'frost nova' in ctx:
            new_idx = 9
        elif 'ice_barrier' in ctx or 'ice barrier' in ctx:
            new_idx = 8
        elif 'mana_shield' in ctx or 'mana shield' in ctx:
            new_idx = 7
        elif 'counterspell' in ctx:
            new_idx = 6
        elif 'polymorph' in ctx:
            new_idx = 5
        elif 'conjure' in ctx or 'mana_gem' in ctx or 'mana gem' in ctx:
            if 'use' in ctx or 'UseManaGem' in ctx:
                new_idx = 18
            else:
                new_idx = 4
        elif 'remove_curse' in ctx or 'remove curse' in ctx:
            new_idx = 3
        elif 'frost_armor' in ctx or 'frost armor' in ctx:
            new_idx = 2
        elif 'arcane_intellect' in ctx or 'arcane intellect' in ctx:
            new_idx = 1
        elif 'frost' in ctx and 'nova' not in ctx and 'armor' not in ctx:
            new_idx = 17  # Frostbolt
        
        if new_idx != old_idx:
            old_str = f"strategies[{old_idx}]"
            new_str = f"strategies[{new_idx}]"
            replacements.append((old_str, new_str))
            print(f"  MAGE: strategies[{old_idx}] -> strategies[{new_idx}]")
    
    # Apply replacements (descending old_idx order to avoid cascade)
    replacements.sort(key=lambda x: -int(re.search(r'\[(\d+)\]', x[0]).group(1)))
    
    for old_str, new_str in replacements:
        content = content.replace(old_str, new_str)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"  MAGE: Applied {len(replacements)} replacements")
    return len(replacements)

# ============================================================
# Fix: test_leveling_priest.lua
# ============================================================

def fix_priest_test():
    filepath = os.path.join(BASE, "EaxRotations/tests/test_leveling_priest.lua")
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix strategy count
    content = content.replace(
        'assert_eq(#strategies, 18, "should have 18 strategies")',
        'assert_eq(#strategies, 20, "should have 20 strategies")'
    )
    
    # Fix "15 strategies in correct priority order"
    content = content.replace(
        '"should have 15 strategies"',
        '"should have 20 strategies"'
    )
    # Fix expected count in the test
    content = re.sub(
        r'local expected_count\s*=\s*15',
        'local expected_count = 20',
        content
    )
    
    refs = extract_test_refs(filepath)
    
    replacements = []
    
    for ref in refs:
        old_idx = ref['index']
        start = max(0, ref['start'] - 200)
        end = min(len(content), ref['end'] + 100)
        ctx = content[start:end].lower()
        
        new_idx = old_idx
        
        if 'wand' in ctx and ('mana' in ctx or 'threshold' in ctx):
            new_idx = 20
        elif 'smite' in ctx:
            new_idx = 19
        elif 'holy_nova' in ctx or 'holy nova' in ctx:
            new_idx = 18
        elif 'mind_flay' in ctx or 'mind flay' in ctx:
            new_idx = 17
        elif 'mind_blast' in ctx or 'mind blast' in ctx:
            new_idx = 16
        elif 'holy_fire' in ctx or 'holy fire' in ctx:
            new_idx = 15
        elif 'swd' in ctx or 'shadow_word_death' in ctx or 'shadow word death' in ctx or 'death' in ctx:
            new_idx = 14
        elif 'vamp' in ctx or 'vampiric' in ctx:
            new_idx = 13
        elif 'swp' in ctx or 'shadow_word_pain' in ctx or 'shadow word pain' in ctx or 'pain' in ctx:
            new_idx = 12
        elif 'shackle' in ctx:
            new_idx = 11
        elif 'fade' in ctx:
            new_idx = 10
        elif 'scream' in ctx or 'psychic' in ctx:
            new_idx = 9
        elif 'greater_heal' in ctx or 'greater heal' in ctx or 'heal_matches' in ctx:
            new_idx = 8
        elif 'inner_focus' in ctx or 'inner focus' in ctx:
            new_idx = 7
        elif 'flash_heal' in ctx or 'flash heal' in ctx:
            new_idx = 6
        elif 'renew' in ctx:
            new_idx = 5
        elif 'shield' in ctx and ('power_word' in ctx or 'pw' in ctx):
            new_idx = 4
        elif 'shadowform' in ctx or 'shadow_form' in ctx or 'shadow form' in ctx:
            new_idx = 3
        elif 'inner_fire' in ctx or 'inner fire' in ctx:
            new_idx = 2
        elif 'fortitude' in ctx or 'power_word_fortitude' in ctx:
            new_idx = 1
        elif 'rotation' in ctx and 'heal' in ctx:
            new_idx = 4  # shield in rotation context
        
        if new_idx != old_idx:
            old_str = f"strategies[{old_idx}]"
            new_str = f"strategies[{new_idx}]"
            replacements.append((old_str, new_str))
            print(f"  PRIEST: strategies[{old_idx}] -> strategies[{new_idx}]")
    
    replacements.sort(key=lambda x: -int(re.search(r'\[(\d+)\]', x[0]).group(1)))
    
    for old_str, new_str in replacements:
        content = content.replace(old_str, new_str)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"  PRIEST: Applied {len(replacements)} replacements")
    return len(replacements)

# ============================================================
# Fix: test_leveling_rogue.lua
# ============================================================

def fix_rogue_test():
    filepath = os.path.join(BASE, "EaxRotations/tests/test_leveling_rogue.lua")
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix strategy count
    content = content.replace(
        'assert_eq(#strategies, 17, "should have 17 strategies")',
        'assert_eq(#strategies, 20, "should have 20 strategies")'
    )
    content = content.replace(
        '"should have 13 strategies"',
        '"should have 20 strategies"'
    )
    
    refs = extract_test_refs(filepath)
    
    replacements = []
    
    for ref in refs:
        old_idx = ref['index']
        start = max(0, ref['start'] - 200)
        end = min(len(content), ref['end'] + 100)
        ctx = content[start:end].lower()
        
        new_idx = old_idx
        
        if 'sinister' in ctx or 'sinister_strike' in ctx:
            new_idx = 20
        elif 'eviscerate' in ctx:
            new_idx = 19
        elif 'kidney' in ctx:
            new_idx = 18
        elif 'expose' in ctx:
            new_idx = 17
        elif 'rupture' in ctx:
            new_idx = 16
        elif 'slice' in ctx:
            new_idx = 15
        elif 'blade_flurry' in ctx or 'blade flurry' in ctx:
            new_idx = 14
        elif 'adrenaline' in ctx:
            new_idx = 13
        elif 'cold_blood' in ctx or 'cold blood' in ctx:
            new_idx = 12
        elif 'disarm' in ctx or 'dismantle' in ctx:
            new_idx = 11
        elif 'blind' in ctx:
            new_idx = 10
        elif 'sprint' in ctx:
            new_idx = 9
        elif 'evasion' in ctx:
            new_idx = 8
        elif 'vanish' in ctx:
            new_idx = 7
        elif 'shiv' in ctx or 'purge' in ctx:
            new_idx = 6
        elif 'gouge' in ctx:
            new_idx = 5
        elif 'kick' in ctx:
            new_idx = 4
        elif 'garrote' in ctx:
            new_idx = 3
        elif 'ambush' in ctx:
            new_idx = 2
        elif 'stealth' in ctx:
            new_idx = 1
        
        if new_idx != old_idx:
            old_str = f"strategies[{old_idx}]"
            new_str = f"strategies[{new_idx}]"
            replacements.append((old_str, new_str))
            print(f"  ROGUE: strategies[{old_idx}] -> strategies[{new_idx}]")
    
    replacements.sort(key=lambda x: -int(re.search(r'\[(\d+)\]', x[0]).group(1)))
    
    for old_str, new_str in replacements:
        content = content.replace(old_str, new_str)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"  ROGUE: Applied {len(replacements)} replacements")
    return len(replacements)

# ============================================================
# Fix: test_leveling_shaman.lua
# ============================================================

def fix_shaman_test():
    filepath = os.path.join(BASE, "EaxRotations/tests/test_leveling_shaman.lua")
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix strategy count
    content = content.replace(
        'assert_eq(#strategies, 18, "should have 18 strategies")',
        'assert_eq(#strategies, 23, "should have 23 strategies")'
    )
    content = content.replace(
        '"should have 15 strategies"',
        '"should have 23 strategies"'
    )
    
    refs = extract_test_refs(filepath)
    
    replacements = []
    
    for ref in refs:
        old_idx = ref['index']
        start = max(0, ref['start'] - 200)
        end = min(len(content), ref['end'] + 100)
        ctx = content[start:end].lower()
        
        new_idx = old_idx
        
        if 'wand' in ctx:
            new_idx = 23
        elif 'ghost' in ctx or 'wolf' in ctx:
            new_idx = 22
        elif 'lightning_bolt' in ctx or 'lightning bolt' in ctx:
            new_idx = 21
        elif 'stoneclaw' in ctx:
            new_idx = 20
        elif 'earthbind' in ctx:
            new_idx = 19
        elif 'frost_shock' in ctx or 'frost shock' in ctx:
            new_idx = 18
        elif 'purge' in ctx:
            new_idx = 17
        elif 'earth_shock' in ctx or 'earth shock' in ctx:
            if 'interrupt' in ctx or 'casting' in ctx:
                new_idx = 4
            else:
                new_idx = 16
        elif 'flame_shock' in ctx or 'flame shock' in ctx:
            new_idx = 15
        elif 'chain_lightning' in ctx or 'chain lightning' in ctx:
            new_idx = 14
        elif 'stormstrike' in ctx:
            new_idx = 13
        elif 'tremor' in ctx:
            new_idx = 12
        elif 'grounding' in ctx:
            new_idx = 11
        elif 'water_totem' in ctx or 'water totem' in ctx:
            new_idx = 10
        elif 'strength' in ctx and 'totem' in ctx:
            new_idx = 9
        elif 'searing' in ctx:
            new_idx = 8
        elif 'lesser_heal' in ctx or 'lesser heal' in ctx:
            new_idx = 7
        elif 'healing_wave' in ctx or 'healing wave' in ctx or 'heal' in ctx:
            new_idx = 6
        elif 'shamanistic' in ctx:
            new_idx = 5
        elif 'water_shield' in ctx or 'water shield' in ctx:
            new_idx = 3
        elif 'lightning_shield' in ctx or 'lightning shield' in ctx:
            new_idx = 2
        elif 'weapon_imbue' in ctx or 'weapon imbue' in ctx or 'imbue' in ctx:
            new_idx = 1
        elif 'rotation' in ctx and 'heal' in ctx:
            new_idx = 6
        
        if new_idx != old_idx:
            old_str = f"strategies[{old_idx}]"
            new_str = f"strategies[{new_idx}]"
            replacements.append((old_str, new_str))
            print(f"  SHAMAN: strategies[{old_idx}] -> strategies[{new_idx}]")
    
    # Add mock spells for new strategies
    # Shaman test file missing: WeaponImbue, WaterShield, LesserHealingWave, SearingTotem,
    # StrengthOfEarthTotem, WaterTotem, GroundingTotem, TremorTotem, Stormstrike,
    # ShamanisticRage, StoneclawTotem, Purge
    mock_spells_block = 'local MOCK_SHAMAN_SPELLS = {'
    if mock_spells_block in content:
        # Add missing spells
        missing = [
            ('WindfuryWeapon', '{ 33757 }'),
            ('RockbiterWeapon', '{ 25479 }'),
            ('FlametongueWeapon', '{ 25477 }'),
            ('FrostbrandWeapon', '{ 25471 }'),
            ('WaterShield', '{ 33736 }'),
            ('LesserHealingWave', '{ 25423 }'),
            ('SearingTotem', '{ 25533 }'),
            ('StrengthOfEarthTotem', '{ 25528 }'),
            ('ManaSpringTotem', '{ 25570 }'),
            ('HealingStreamTotem', '{ 25567 }'),
            ('GroundingTotem', '{ 8177 }'),
            ('TremorTotem', '{ 8143 }'),
            ('Stormstrike', '{ 17364 }'),
            ('ShamanisticRage', '{ 30823 }'),
            ('StoneclawTotem', '{ 25525 }'),
            ('Purge', '{ 25448 }'),
        ]
        for spell_name, spell_id in missing:
            if spell_name not in content.split(mock_spells_block)[1].split('\n}')[0]:
                insert_pos = content.find('local MOCK_SHAMAN_SPELLS = {')
                insert_pos = content.find('\n', insert_pos) + 1
                content = content[:insert_pos] + f'    {spell_name} = {spell_id},\n' + content[insert_pos:]
    
    replacements.sort(key=lambda x: -int(re.search(r'\[(\d+)\]', x[0]).group(1)))
    
    for old_str, new_str in replacements:
        content = content.replace(old_str, new_str)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"  SHAMAN: Applied {len(replacements)} replacements")
    return len(replacements)

# ============================================================
# Fix: test_leveling_edge_cases.lua
# ============================================================

def fix_edge_cases_test():
    filepath = os.path.join(BASE, "EaxRotations/tests/test_leveling_edge_cases.lua")
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    refs = extract_test_refs(filepath, "mage_strategies")
    rouge_refs = extract_test_refs(filepath, "rogue_strategies")
    
    all_refs = refs + rouge_refs
    
    replacements = []
    
    for ref in all_refs:
        old_idx = ref['index']
        prefix = ref['prefix']
        start = max(0, ref['start'] - 200)
        end = min(len(content), ref['end'] + 100)
        ctx = content[start:end].lower()
        
        new_idx = old_idx
        
        if prefix == "mage_strategies":
            if 'wand' in ctx and ('mana' in ctx or 'threshold' in ctx):
                new_idx = 19
            elif 'conjure' in ctx or 'mana_gem' in ctx:
                new_idx = 4  # ConjureManaGem (but could be 18 for UseManaGem)
                if 'use' in ctx:
                    new_idx = 18
            elif 'frostbolt' in ctx:
                new_idx = 17
            elif 'arcane_missiles' in ctx:
                new_idx = 16
            elif 'scorch' in ctx:
                new_idx = 15
            elif 'fire_blast' in ctx or 'fire blast' in ctx:
                new_idx = 14
            elif 'evocation' in ctx:
                new_idx = 13
            elif 'blizzard' in ctx:
                new_idx = 12
            elif 'blink' in ctx:
                new_idx = 11
            elif 'cone_of_cold' in ctx or 'cone' in ctx:
                new_idx = 10
            elif 'frost_nova' in ctx or 'frost nova' in ctx or 'nova' in ctx:
                new_idx = 9
            elif 'ice_barrier' in ctx or 'ice barrier' in ctx or 'barrier' in ctx:
                new_idx = 8
            elif 'mana_shield' in ctx or 'mana shield' in ctx:
                new_idx = 7
            elif 'counterspell' in ctx or 'counter' in ctx:
                new_idx = 6
            elif 'polymorph' in ctx or 'poly' in ctx:
                new_idx = 5
            elif 'remove_curse' in ctx or 'remove curse' in ctx or 'curse' in ctx:
                new_idx = 3
            elif 'frost_armor' in ctx or 'frost armor' in ctx:
                new_idx = 2
            elif 'arcane_intellect' in ctx or 'arcane intellect' in ctx or 'ai' in ctx:
                new_idx = 1
        
        elif prefix == "rogue_strategies":
            if 'sinister' in ctx:
                new_idx = 20
            elif 'eviscerate' in ctx:
                new_idx = 19
            elif 'kidney' in ctx:
                new_idx = 18
            elif 'expose' in ctx:
                new_idx = 17
            elif 'rupture' in ctx:
                new_idx = 16
            elif 'slice' in ctx:
                new_idx = 15
            elif 'blade_flurry' in ctx or 'flurry' in ctx:
                new_idx = 14
            elif 'adrenaline' in ctx or 'rush' in ctx:
                new_idx = 13
            elif 'cold_blood' in ctx or 'cold' in ctx:
                new_idx = 12
            elif 'disarm' in ctx or 'dismantle' in ctx:
                new_idx = 11
            elif 'blind' in ctx:
                new_idx = 10
            elif 'sprint' in ctx:
                new_idx = 9
            elif 'evasion' in ctx:
                new_idx = 8
            elif 'vanish' in ctx:
                new_idx = 7
            elif 'shiv' in ctx or 'purge' in ctx:
                new_idx = 6
            elif 'gouge' in ctx:
                new_idx = 5
            elif 'kick' in ctx:
                new_idx = 4
            elif 'garrote' in ctx:
                new_idx = 3
            elif 'ambush' in ctx:
                new_idx = 2
            elif 'stealth' in ctx:
                new_idx = 1
        
        if new_idx != old_idx:
            old_str = f"{prefix}[{old_idx}]"
            new_str = f"{prefix}[{new_idx}]"
            replacements.append((old_str, new_str))
            print(f"  EDGE: {prefix}[{old_idx}] -> {prefix}[{new_idx}]")
    
    # Also fix mage execute tests that reference strategy 13 (wand) and 8 (frost_nova)
    # "wand" is now at index 19 instead of 15
    # "frost_nova" is now at index 9 instead of 8
    
    # Also need to add missing mock spells for Mage
    mock_mage_spells = 'local MOCK_MAGE_SPELLS = {'
    if mock_mage_spells in content:
        missing = [
            ('FrostArmor', '{ 27125 }'),
            ('Blink', '{ 27134 }'),  # reusing ice barrier ID, close enough for mock
            ('ConeOfCold', '{ 27087 }'),
        ]
        spell_section = content.split('local MOCK_MAGE_SPELLS = {')[1].split('\n}')[0]
        for spell_name, spell_id in missing:
            if spell_name not in spell_section:
                insert_pos = content.find(mock_mage_spells)
                insert_pos = content.find('\n', insert_pos) + 1
                content = content[:insert_pos] + f'    {spell_name} = {spell_id},\n' + content[insert_pos:]
    
    # Add Rogue mock spells that are missing  
    mock_rogue_spells = 'local MOCK_ROGUE_SPELLS = {'
    if mock_rogue_spells in content:
        missing_rogue = [
            ('Dismantle', '{ 51722 }'),
            ('KidneyShot', '{ 8643 }'),
            ('Shiv', '{ 5938 }'),
        ]
        rogue_section = content.split('local MOCK_ROGUE_SPELLS = {')[1].split('\n}')[0]
        for spell_name, spell_id in missing_rogue:
            if spell_name not in rogue_section:
                insert_pos = content.find(mock_rogue_spells)
                insert_pos = content.find('\n', insert_pos) + 1
                content = content[:insert_pos] + f'    {spell_name} = {spell_id},\n' + content[insert_pos:]
    
    replacements.sort(key=lambda x: -int(re.search(r'\[(\d+)\]', x[0]).group(1)))
    
    for old_str, new_str in replacements:
        content = content.replace(old_str, new_str)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"  EDGE: Applied {len(replacements)} replacements")
    return len(replacements)

# ============================================================
# Main
# ============================================================
if __name__ == "__main__":
    print("=== Fixing Leveling Tests ===")
    print()
    print("1. MAGE:")
    fix_mage_test()
    print()
    print("2. PRIEST:")
    fix_priest_test()
    print()
    print("3. ROGUE:")
    fix_rogue_test()
    print()
    print("4. SHAMAN:")
    fix_shaman_test()
    print()
    print("5. EDGE CASES:")
    fix_edge_cases_test()
    print()
    print("=== Done ===")
