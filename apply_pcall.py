import os
import re

files = [
    'EAXDruidBalance/libraries/context_builder.lua',
    'EAXDruidBear/libraries/context_builder.lua',
    'EAXDruidFeral/libraries/context_builder.lua',
    'EAXDruidResto/libraries/context_builder.lua',
    'EAXHunterBM/libraries/context_builder.lua',
    'EAXHunterMM/libraries/context_builder.lua',
    'EAXHunterSurvival/libraries/context_builder.lua'
]

base_path = 'C:/newbot/scripts'

for f in files:
    full_path = os.path.join(base_path, f)
    with open(full_path, 'r') as file:
        content = file.read()
    
    # Pattern 1: ctx.hp = me:get_health_percentage()
    content = re.sub(
        r'ctx\.hp = me:get_health_percentage\(\)',
        'local ok, hp = pcall(function() return me:get_health_percentage() end)\n    ctx.hp = ok and hp or 0',
        content
    )
    
    # Pattern 2: ctx.max_hp = me:get_max_health()
    content = re.sub(
        r'ctx\.max_hp = me:get_max_health\(\)',
        'local ok2, max_hp = pcall(function() return me:get_max_health() end)\n    ctx.max_hp = ok2 and max_hp or 0',
        content
    )
    
    with open(full_path, 'w') as file:
        file.write(content)
    print(f'Updated: {f}')

print('All files updated')
