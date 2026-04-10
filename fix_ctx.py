import os
import subprocess

files = [
    'EAXWarriorFury/libraries/context_builder.lua',
    'EAXWarriorArms/libraries/context_builder.lua',
    'EAXWarriorProtection/libraries/context_builder.lua'
]

for filepath in files:
    full_path = os.path.join('C:\\\\newbot\\\\scripts', filepath)
    print(f'Processing {filepath}...')
