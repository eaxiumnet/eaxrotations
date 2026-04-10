import re
import os
import subprocess

compat_files = [
    'EAXWarriorFury/libraries/compat.lua',
    'EAXWarriorArms/libraries/compat.lua',
    'EAXWarriorProtection/libraries/compat.lua',
    'EAXDruidFeral/libraries/compat.lua',
    'EAXDruidBear/libraries/compat.lua',
    'EAXDruidBalance/libraries/compat.lua',
    'EAXDruidResto/libraries/compat.lua',
    'EAXHunterBM/libraries/compat.lua',
    'EAXHunterMM/libraries/compat.lua',
    'EAXHunterSurvival/libraries/compat.lua',
    'EAXMageArcane/libraries/compat.lua',
    'EAXMageFire/libraries/compat.lua',
    'EAXMageFrost/libraries/compat.lua',
    'EAXPaladinHoly/libraries/compat.lua',
    'EAXPaladinRetribution/libraries/compat.lua',
    'EAXPaladinProtection/libraries/compat.lua',
    'EAXPriestDiscipline/libraries/compat.lua',
    'EAXPriestHoly/libraries/compat.lua',
    'EAXPriestShadow/libraries/compat.lua',
    'EAXPriestSmite/libraries/compat.lua',
    'EAXRogueAssassination/libraries/compat.lua',
    'EAXRogueCombat/libraries/compat.lua',
    'EAXRogueSubtlety/libraries/compat.lua',
    'EAXShamanElemental/libraries/compat.lua',
    'EAXShamanEnhancement/libraries/compat.lua',
    'EAXShamanRestoration/libraries/compat.lua',
    'EAXWarlockAffliction/libraries/compat.lua',
    'EAXWarlockDemonology/libraries/compat.lua',
    'EAXWarlockDestruction/libraries/compat.lua',
]

def fix_compat_file(filepath):
    full_path = f'C:\\newbot\\scripts\\{filepath}'
    
    with open(full_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    changes = []
    
    if 'context.in_combat = me.is_in_combat and me:is_in_combat() or false' in content:
        content = content.replace(
            'context.in_combat = me.is_in_combat and me:is_in_combat() or false',
            'local ok_combat, in_combat = pcall(function() return me:is_in_combat() end)\n    context.in_combat = (ok_combat and in_combat) or false'
        )
        changes.append('Fixed: me:is_in_combat()')
    
    if 'local max_power = me:get_max_power()' in content:
        content = content.replace(
            'local max_power = me:get_max_power()',
            'local ok_max_power, max_power = pcall(function() return me:get_max_power() end)\n        max_power = (ok_max_power and max_power) or 0'
        )
        changes.append('Fixed: me:get_max_power()')
    
    if 'context.mana_pct = (me:get_power() / max_power) * 100' in content:
        content = content.replace(
            'context.mana_pct = (me:get_power() / max_power) * 100',
            'local ok_power, power = pcall(function() return me:get_power() end)\n        context.mana_pct = (ok_power and power and max_power > 0) and ((power / max_power) * 100) or 0'
        )
        changes.append('Fixed: me:get_power()')
    
    if 'local target = (me.get_target and me:get_target()) or nil' in content:
        content = content.replace(
            'local target = (me.get_target and me:get_target()) or nil',
            'local ok_target, target = pcall(function() return (me.get_target and me:get_target()) or nil end)\n    target = ok_target and target or nil'
        )
        changes.append('Fixed: me:get_target()')
    
    if 'local me_x, me_y, me_z = me:get_position()' in content:
        content = content.replace(
            'local me_x, me_y, me_z = me:get_position()',
            'local ok_pos, me_x, me_y, me_z = pcall(function() return me:get_position() end)\n        if not ok_pos then me_x, me_y, me_z = nil, nil, nil end'
        )
        changes.append('Fixed: me:get_position()')
    
    if 'local tgt_x, tgt_y, tgt_z = target:get_position()' in content:
        content = content.replace(
            'local tgt_x, tgt_y, tgt_z = target:get_position()',
            'local ok_tgt_pos, tgt_x, tgt_y, tgt_z = pcall(function() return target:get_position() end)\n        if not ok_tgt_pos then tgt_x, tgt_y, tgt_z = nil, nil, nil end'
        )
        changes.append('Fixed: target:get_position()')
    
    if 'local tgt_max_hp = target.get_max_health and target:get_max_health() or 0' in content:
        content = content.replace(
            'local tgt_max_hp = target.get_max_health and target:get_max_health() or 0',
            'local ok_tgt_max, tgt_max_hp = pcall(function() return (target.get_max_health and target:get_max_health()) or 0 end)\n        tgt_max_hp = (ok_tgt_max and tgt_max_hp) or 0'
        )
        changes.append('Fixed: target:get_max_health()')
    
    if content != original_content:
        with open(full_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        result = subprocess.run(['luac', '-p', full_path], capture_output=True, text=True)
        if result.returncode != 0:
            print(f'  ERROR: Syntax error in {filepath}:')
            print(f'    {result.stderr}')
            return False, changes
        
        print(f'  Fixed {filepath}: {len(changes)} changes')
        for c in changes:
            print(f'    - {c}')
        return True, changes
    else:
        print(f'  No changes needed for {filepath}')
        return True, []

print('=' * 60)
print('Fixing compat.lua files with pcall protection')
print('=' * 60)

fixed_count = 0
error_count = 0
total_changes = 0

for filepath in compat_files:
    success, changes = fix_compat_file(filepath)
    if success and changes:
        fixed_count += 1
        total_changes += len(changes)
    elif not success:
        error_count += 1

print('=' * 60)
print(f'Summary: {fixed_count} files fixed, {error_count} errors, {total_changes} total changes')
print('=' * 60)
