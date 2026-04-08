import os

def fix_paladin_retribution():
    path = 'C:/newbot/scripts/EAXPaladinRetribution/libraries/middleware_manager.lua'
    with open(path, 'r') as f:
        content = f.read()
    
    old = 'execute = function(icon, ctx)\n                if core.spell_queue and core.spell_queue.add then\n                    core.spell_queue.add(PALADIN_SPELLS.ARCANE_TORRENT, "arcane_torrent", 70)\n                    return true, "[MW] Arcane Torrent queued"\n                elseif icon and icon.cast then\n                    icon:cast(PALADIN_SPELLS.ARCANE_TORRENT)\n                    return true, "[MW] Arcane Torrent"\n                end\n                return false\n            end'
    
    new = 'execute = function(icon, ctx)\n                if icon and icon.cast then\n                    icon:cast(PALADIN_SPELLS.ARCBE_TORRENT)\n                    return true, "[MW] Arcane Torrent"\n                end\n                return false\n            end'
    
    if old in content:
        content = content.replace(old, new)
        with open(path, 'w') as f:
            f.write(content)
        return 1
    return 0

if __name__ == '__main__':
    count = fix_paladin_retribution()
    print(f'Removed {count} blocks')