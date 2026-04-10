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
    
    # Pattern: target:get_target() in fallback threat check
    content = content.replace(
        'local target_target = target:get_target()',
        'local ok_tt, target_target = pcall(function() return target:get_target() end)'
    )
    content = content.replace(
        'if target_target and target_target:is_valid()',
        'if ok_tt and target_target then
                local ok_tt_valid, tt_valid = pcall(function() return target_target:is_valid() end)
                if ok_tt_valid and tt_valid'
    )
    
    # Fix the closing of the nested if
    content = content.replace(
        'else
                    ctx.threat_status = 1  -- Have threat but not tanking
                end
            else
                ctx.threat_status = 0  -- Loose mob
            end',
        'else
                        ctx.threat_status = 1  -- Have threat but not tanking
                    end
                else
                    ctx.threat_status = 0  -- Loose mob
                end
            else
                ctx.threat_status = 0  -- Loose mob
            end'
    )
    
    with open(full_path, 'w') as file:
        file.write(content)
    print('Updated: ' + f)

print('Threat fallback protections applied')
