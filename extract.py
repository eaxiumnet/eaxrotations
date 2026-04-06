
import re

# Read the original Subtlety file
with open('EAXRogueSubtlety_Flux/libraries/menu.lua', 'r') as f:
    original = f.read()

# Extract the menu items section
menu_items_match = re.search(r'(-- Controls.*?)(?=settings\.setup_major_toggle_keybinds)', original, re.DOTALL)
if menu_items_match:
    menu_items = menu_items_match.group(1)
    print('MENU_ITEMS_FOUND')
else:
    menu_items = ''
    print('MENU_ITEMS_NOT_FOUND')

# Extract settings call
settings_match = re.search(r'(settings\.setup_major_toggle_keybinds.*?\}\))', original, re.DOTALL)
if settings_match:
    print('SETTINGS_FOUND')
else:
    print('SETTINGS_NOT_FOUND')

# Extract AstroUI setup
astro_match = re.search(r'(menu\.ui = AstroUI\.new\(.*?\}\))', original, re.DOTALL)
if astro_match:
    print('ASTRO_FOUND')
else:
    print('ASTRO_NOT_FOUND')

# Extract tabs section
tabs_match = re.search(r'(menu\.ui:add_tab.*?)(?=AstroUI\.register_window)', original, re.DOTALL)
if tabs_match:
    print('TABS_FOUND')
else:
    print('TABS_NOT_FOUND')
