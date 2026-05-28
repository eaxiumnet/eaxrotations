#!/usr/bin/env python3
"""
Fix strategy indices, mock spells, and count assertions in leveling test files.
Uses descending-position replacement to avoid cascade issues.
"""
import re, os

BASE = "C:/newbot/scripts/EaxRotations"

# ===========================================================================
# Strategy index mappings: old_index → new_index
# ===========================================================================
MAGE_MAP = {
    1:1, 2:4, 3:5, 4:6, 5:7, 6:8, 7:9, 8:12, 9:13, 10:14,
    11:15, 12:16, 13:17, 14:18, 15:19,
}
PRIEST_MAP = {
    1:1, 2:2, 3:4, 4:5, 5:8, 6:9, 7:10, 8:11, 9:12, 10:14,
    11:15, 12:16, 13:18, 14:19, 15:20,
}
ROGUE_MAP = {
    1:1, 2:4, 3:7, 4:8, 5:9, 6:12, 7:13, 8:14, 9:15, 10:16,
    11:17, 12:19, 13:18,
}
SHAMAN_MAP = {
    1:17, 2:6, 3:1, 4:2, 5:3, 6:4, 7:5, 8:7, 9:8, 10:9,
    11:10, 12:11, 13:12, 14:13, 15:23,
}

# ===========================================================================
# Mock spell additions (to insert into MOCK_*_SPELLS tables)
# ===========================================================================
MAGE_MOCK_ADDITIONS = """
    FrostArmor = { 27125 },
    ConeOfCold = { 27087 },
    Blink = { 1953 },
    UseManaGem = { 22147 },
"""
PRIEST_MOCK_ADDITIONS = """
    Shadowform = { 15473 },
    VampiricTouch = { 34917 },
    MindFlay = { 15407 },
    InnerFocus = { 14751 },
    FlashHeal = { 2061 },
"""
ROGUE_MOCK_ADDITIONS = """
    Ambush = { 8676 },
    Garrote = { 7036 },
    Gouge = { 1776 },
    Blind = { 2094 },
    Shiv = { 5938 },
    Disarm = { 51722 },
"""
SHAMAN_MOCK_ADDITIONS = """
    CallOfElements = { 11993 },
    Bloodlust = { 2825 },
    FireResistanceTotem = { 8184 },
    FrostResistanceTotem = { 8181 },
    CureDisease = { 2870 },
    CleanseSpirit = { 51886 },
    Purge = { 370 },
    RemoveCurse = { 475 },
"""

# ===========================================================================
# Expected strategy name arrays for count tests
# ===========================================================================
MAGE_EXPECTED = """    local expected = {
        "ArcaneIntellect", "FrostArmor", "RemoveCurse", "ConjureManaGem",
        "Polymorph", "Counterspell", "ManaShield", "IceBarrier", "FrostNova",
        "ConeOfCold", "Blink", "Blizzard", "Evocation", "FireBlast",
        "Scorch", "ArcaneMissiles", "Frostbolt", "UseManaGem", "Wand",
    }"""

PRIEST_EXPECTED = """    local expected = {
        "PowerWordFortitude", "InnerFire", "Shadowform", "PowerWordShield",
        "Renew", "FlashHeal", "InnerFocus", "GreaterHeal", "PsychicScream",
        "Fade", "ShackleUndead", "ShadowWordPain", "VampiricTouch", "ShadowWordDeath",
        "HolyFire", "MindBlast", "MindFlay", "HolyNova", "Smite", "Wand",
    }"""

ROGUE_EXPECTED = """    local expected = {
        "Stealth", "Ambush", "Garrote", "Kick", "Gouge", "ShivPurge",
        "Vanish", "Evasion", "Sprint", "Blind", "Disarm", "ColdBlood",
        "AdrenalineRush", "BladeFlurry", "SliceAndDice", "Rupture", "ExposeArmor",
        "SinisterStrike", "Eviscerate", "Wand",
    }"""

SHAMAN_EXPECTED = """    local expected = {
        "EarthShockInterrupt", "HealingWave", "SearingTotem", "StrengthOfEarthTotem",
        "WaterTotem", "LightningShield", "ChainLightning", "FlameShock",
        "EarthShock", "FrostShock", "EarthbindTotem", "LightningBolt",
        "GhostWolf", "PurgeEnemy", "RemoveCurseCleanse", "CureDisease",
        "WeaponImbue", "FireResistanceTotem", "FrostResistanceTotem",
        "CallOfElements", "Bloodlust", "UseTrinket", "Wand",
    }"""

# ===========================================================================
# File-specific processing
# ===========================================================================

def replace_strategy_indices(text, index_map):
    """Replace all strategies[N] references using descending-position order."""
    pattern = re.compile(r'(strategies)\[(\d+)\]')
    matches = list(pattern.finditer(text))
    # Process right-to-left to avoid position shifts
    replacements = []
    for m in matches:
        old_idx = int(m.group(2))
        new_idx = index_map.get(old_idx)
        if new_idx is not None and old_idx != new_idx:
            start = m.start()
            end = m.end()
            new_text = f"{m.group(1)}[{new_idx}]"
            replacements.append((start, end, new_text))
    
    # Apply from right to left
    replacements.sort(key=lambda x: x[0], reverse=True)
    result = list(text)
    for start, end, new_text in replacements:
        result[start:end] = new_text
    return ''.join(result)

def replace_edge_indices(text, index_map):
    """Replace _strategies[N] references (in edge_cases file)."""
    # Handle mage_strategies[N], rogue_strategies[N], etc.
    # But note: edge_cases uses mage_strategies for mage, rogue_strategies for rogue
    # We need separate maps for each class
    
    result = text
    
    # Mage strategies in edge_cases
    mage_pattern = re.compile(r'(mage_strategies)\[(\d+)\]')
    for m in list(mage_pattern.finditer(result))[::-1]:
        old_idx = int(m.group(2))
        new_idx = MAGE_MAP.get(old_idx)
        if new_idx is not None and old_idx != new_idx:
            result = result[:m.start()] + f"{m.group(1)}[{new_idx}]" + result[m.end():]
    
    # Rogue strategies in edge_cases
    rogue_pattern = re.compile(r'(rogue_strategies)\[(\d+)\]')
    for m in list(rogue_pattern.finditer(result))[::-1]:
        old_idx = int(m.group(2))
        new_idx = ROGUE_MAP.get(old_idx)
        if new_idx is not None and old_idx != new_idx:
            result = result[:m.start()] + f"{m.group(1)}[{new_idx}]" + result[m.end():]
    
    # Also handle bare 'strategies[N]' in edge_cases (context-dependent)
    # These might be mixed - use only if surrounded by mage/rogue context
    # For now, skip bare strategies[] in edge_cases since they're ambiguous
    
    return result

def add_mock_spells(text, additions):
    """Insert mock spell entries before the closing } of MOCK_*_SPELLS table."""
    # Find the MOCK_*_SPELLS = { ... } block
    pattern = re.compile(r'(MOCK_\w+_SPELLS\s*=\s*\{)(.*?)(\n\})', re.DOTALL)
    m = pattern.search(text)
    if not m:
        print("  WARNING: Could not find MOCK_*_SPELLS block")
        return text
    
    # Check if entries already exist
    for line in additions.strip().split('\n'):
        line = line.strip().rstrip(',')
        if line and line not in text:
            # Insert before closing brace
            insert_pos = m.end() - 1  # position of closing }
            text = text[:insert_pos] + "\n" + line + "," + text[insert_pos:]
    
    return text

def update_strategy_count(text, old_count, new_count):
    """Update strategy count assertions and comments."""
    # Handle: assert_eq(#strategies, 15, ...)
    text = re.sub(
        rf'(assert_eq\(#strategies,\s*){old_count}(\s*,.*?should have\s*){old_count}(\s*strategies)',
        rf'\g<1>{new_count}\g<2>{new_count}\g<3>',
        text
    )
    # Handle: should have N strategies
    text = text.replace(f"should have {old_count} strategies", f"should have {new_count} strategies")
    text = text.replace(f"have {old_count} strategies", f"have {new_count} strategies")
    return text

def update_expected_array(text, new_expected, old_count, new_count):
    """Replace the expected strategy name array."""
    # Find and replace the expected = { ... } block
    pattern = re.compile(r'(\s*local expected\s*=\s*\{).*?(\n\s*\})', re.DOTALL)
    m = pattern.search(text)
    if m:
        # Replace the entire block
        text = text[:m.start()] + new_expected + text[m.end():]
    else:
        print("  WARNING: Could not find expected = {...} block")
    return text

def process_file(filepath, index_map, mock_additions, old_count, new_count, new_expected, is_edge=False):
    """Process a single test file."""
    print(f"\nProcessing: {os.path.basename(filepath)}")
    
    with open(filepath, 'r', encoding='utf-8') as f:
        text = f.read()
    
    original = text
    
    # 1. Add mock spells
    text = add_mock_spells(text, mock_additions)
    
    # 2. Update strategy count
    text = update_strategy_count(text, old_count, new_count)
    
    # 3. Replace strategy indices
    if is_edge:
        text = replace_edge_indices(text, index_map)
    else:
        text = replace_strategy_indices(text, index_map)
    
    # 4. Update expected array
    text = update_expected_array(text, new_expected, old_count, new_count)
    
    if text != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(text)
        # Count changes
        changes = sum(1 for a, b in zip(original, text) if a != b)
        print(f"  Applied changes (~{changes} chars modified)")
    else:
        print("  No changes made")

# ===========================================================================
# Main
# ===========================================================================

if __name__ == "__main__":
    # Mage
    process_file(
        os.path.join(BASE, "tests/test_leveling_mage.lua"),
        MAGE_MAP, MAGE_MOCK_ADDITIONS, 15, 19, MAGE_EXPECTED
    )
    
    # Priest
    process_file(
        os.path.join(BASE, "tests/test_leveling_priest.lua"),
        PRIEST_MAP, PRIEST_MOCK_ADDITIONS, 15, 20, PRIEST_EXPECTED
    )
    
    # Rogue
    process_file(
        os.path.join(BASE, "tests/test_leveling_rogue.lua"),
        ROGUE_MAP, ROGUE_MOCK_ADDITIONS, 13, 20, ROGUE_EXPECTED
    )
    
    # Shaman
    process_file(
        os.path.join(BASE, "tests/test_leveling_shaman.lua"),
        SHAMAN_MAP, SHAMAN_MOCK_ADDITIONS, 15, 23, SHAMAN_EXPECTED
    )
    
    # Edge cases
    process_file(
        os.path.join(BASE, "tests/test_leveling_edge_cases.lua"),
        {},  # Uses mage/rogue maps internally in replace_edge_indices
        "",  # No mock additions for edge_cases (uses shared mock)
        0, 0, "",  # No count/expected changes for edge_cases
        is_edge=True
    )
    
    print("\nDone processing all files.")
