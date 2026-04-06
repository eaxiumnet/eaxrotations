
import re

# Read the original Subtlety file
with open('EAXRogueSubtlety_Flux/libraries/menu.lua', 'r') as f:
    original = f.read()

# Extract the menu items section (from -- Controls to settings.setup_major_toggle_keybinds)
menu_items_match = re.search(r'(-- Controls.*?)(?=settings\.setup_major_toggle_keybinds)', original, re.DOTALL)
if menu_items_match:
    menu_items = menu_items_match.group(1)
else:
    menu_items = ''

# Extract the settings.setup_major_toggle_keybinds call
settings_match = re.search(r'(settings\.setup_major_toggle_keybinds.*?\}\))', original, re.DOTALL)
settings_call = settings_match.group(1) if settings_match else ''

# Extract the AstroUI setup
astro_match = re.search(r'(menu\.ui = AstroUI\.new\(.*?\}))', original, re.DOTALL)
astro_setup = astro_match.group(1) if astro_match else ''

# Extract the safe_elements function
safe_elements_match = re.search(r'(local function safe_elements.*?end)', original, re.DOTALL)
safe_elements_func = safe_elements_match.group(1) if safe_elements_match else ''

# Extract the tabs
tabs_match = re.search(r'(-- ============================================================================
-- TABS.*?)(?=AstroUI\.register_window)', original, re.DOTALL)
tabs_section = tabs_match.group(1) if tabs_match else ''

# Extract render callbacks
render_match = re.search(r'(function menu\.on_render.*?menu\.ui:on_menu_render\(\)
end)', original, re.DOTALL)
render_funcs = render_match.group(1) if render_match else ''

print('Extracted sections:')
print('  menu_items:', len(menu_items), 'chars')
print('  settings_call:', len(settings_call), 'chars')
print('  astro_setup:', len(astro_setup), 'chars')
print('  safe_elements_func:', len(safe_elements_func), 'chars')
print('  tabs_section:', len(tabs_section), 'chars')
print('  render_funcs:', len(render_funcs), 'chars')
