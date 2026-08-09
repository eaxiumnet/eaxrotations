-- run_wotlk_audit_tests.lua -- Audit _wotlk.lua rotation files for invalid spell IDs.
-- WHAT:  Scans WotLK rotation files for IDs that are neither indexed nor verified aliases.
-- WHEN:  Run manually or in CI before releases.
-- WHY:   The generated bridge omits rank and aura aliases, so absence alone is not invalidity.
-- SAFETY: Read-only text scan + static classification; --self-test has no filesystem writes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;" .. package.path

local bridge_ok, bridge = pcall(require, "shared/wowhead_data_bridge_spell_index_wotlk_sylvanas")
if not bridge_ok or not bridge then
    print("[ERROR] Could not load wowhead_data_bridge_spell_index_wotlk_sylvanas")
    print("        Run: python build_tools/fetch_lexxer_wotlk.py")
    os.exit(2)
end

local tbc_bridge_ok, tbc_bridge = pcall(require, "shared/wowhead_data_bridge_sylvanas")
local vanilla_bridge_ok, vanilla_bridge = pcall(require, "shared/wowhead_data_bridge_spell_index_vanilla_sylvanas")

local wotlk_index = bridge.spell_index_wotlk or {}
local tbc_index = (tbc_bridge_ok and tbc_bridge.spell_index_tbc) or {}
local vanilla_index = (vanilla_bridge_ok and vanilla_bridge.spell_index_vanilla) or {}

local valid_wotlk_ids = {}
for id in pairs(wotlk_index) do
    valid_wotlk_ids[id] = true
end

local valid_tbc_ids = {}
for id in pairs(tbc_index) do
    valid_tbc_ids[id] = true
end

local valid_vanilla_ids = {}
for id in pairs(vanilla_index) do
    valid_vanilla_ids[id] = true
end

local WOTLK_REFERENCE_SHA = "563e4a08cb15729f1fdcbcf68e6d68224553bfef"
local WOTLK_REFERENCE_ALIASES = {
    [27011] = { kind = "VALID_RANK_ALIAS", family = "Feral Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [17392] = { kind = "VALID_RANK_ALIAS", family = "Feral Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [17391] = { kind = "VALID_RANK_ALIAS", family = "Feral Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [17390] = { kind = "VALID_RANK_ALIAS", family = "Feral Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [26993] = { kind = "VALID_RANK_ALIAS", family = "Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [9907] = { kind = "VALID_RANK_ALIAS", family = "Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [9749] = { kind = "VALID_RANK_ALIAS", family = "Faerie Fire", source = "sim/druid/faerie_fire.go" },
    [13544] = { kind = "VALID_RANK_ALIAS", family = "Mend Pet", source = "sim/hunter/pet_abilities.go pet surface" },
    [3662] = { kind = "VALID_RANK_ALIAS", family = "Mend Pet", source = "sim/hunter/pet_abilities.go pet surface" },
    [3661] = { kind = "VALID_RANK_ALIAS", family = "Mend Pet", source = "sim/hunter/pet_abilities.go pet surface" },
    [38692] = { kind = "VALID_RANK_ALIAS", family = "Fireball", source = "sim/mage/fireball.go" },
    [55360] = { kind = "VALID_BRIDGE_GAP", family = "Living Bomb", source = "sim/mage/living_bomb.go" },
    [42873] = { kind = "VALID_BRIDGE_GAP", family = "Fire Blast", source = "sim/mage/fire_blast.go" },
    [44448] = { kind = "VALID_AURA_ALIAS", family = "Hot Streak", source = "sim/mage/talents.go" },
    [12873] = { kind = "VALID_AURA_ALIAS", family = "Scorch", source = "sim/core/debuffs.go" },
    [19940] = { kind = "VALID_RANK_ALIAS", family = "Flash of Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [19939] = { kind = "VALID_RANK_ALIAS", family = "Flash of Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [48785] = { kind = "VALID_RANK_ALIAS", family = "Flash of Light", source = "wowhead WotLK Classic spell=48785 (Flash of Light, top 3.3.x rank) + shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua rank family" },
    [25292] = { kind = "VALID_RANK_ALIAS", family = "Holy Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [10329] = { kind = "VALID_RANK_ALIAS", family = "Holy Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [10328] = { kind = "VALID_RANK_ALIAS", family = "Holy Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [3472] = { kind = "VALID_RANK_ALIAS", family = "Holy Light", source = "sim/paladin/holy/holy.go + shared/_dbc_spell_ids.lua + shared/wowhead_data_bridge_sylvanas.lua" },
    [48782] = { kind = "VALID_RANK_ALIAS", family = "Holy Light", source = "wowhead WotLK Classic spell=48782 (Holy Light, top 3.3.x rank) + shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua rank family" },
    [32700] = { kind = "VALID_RANK_ALIAS", family = "Avenger's Shield", source = "sim/paladin/avengers_shield.go" },
    [32699] = { kind = "VALID_RANK_ALIAS", family = "Avenger's Shield", source = "sim/paladin/avengers_shield.go" },
    [31935] = { kind = "VALID_RANK_ALIAS", family = "Avenger's Shield", source = "sim/paladin/avengers_shield.go" },
    [48826] = { kind = "VALID_RANK_ALIAS", family = "Avenger's Shield", source = "wowhead WotLK Classic spell=48826 (Avenger's Shield) + shared/wowhead_data_bridge_spell_index_wotlk_sylvanas.lua [48827] rank family" },
    [61411] = { kind = "VALID_BRIDGE_GAP", family = "Shield of Righteousness", source = "sim/paladin/shield_of_righteousness.go" },
    -- Rank-audit 2026-08-08 (shared-module sweep): signature-ladder tops from
    -- shared/talent_inference_sylvanas.lua that were still TBC-era. Verified on
    -- wowhead WotLK Classic + wowsims/wotlk sim source; the bridge omits them.
    [47488] = { kind = "VALID_RANK_ALIAS", family = "Shield Slam", source = "wowhead WotLK Classic spell=47488/shield-slam + sim/warrior/shield_slam.go (47487 disproven: 30356 is TBC-era rank 6)" },
    [48660] = { kind = "VALID_RANK_ALIAS", family = "Hemorrhage", source = "sim/rogue/hemorrhage.go" },
    [48089] = { kind = "VALID_RANK_ALIAS", family = "Circle of Healing", source = "sim/priest/circle_of_healing.go" },
    -- Pet-ability ladder tops (shared/pet_manager_sylvanas.lua) verified on wowhead
    -- WotLK Classic; these pet abilities never entered the player-spell bridge.
    [27047] = { kind = "VALID_RANK_ALIAS", family = "Pet: Growl", source = "wowhead WotLK Classic spell=27047/growl + prior TBC-era read" },
    [27049] = { kind = "VALID_RANK_ALIAS", family = "Pet: Claw", source = "wowhead WotLK Classic spell=27049/claw" },
    [27050] = { kind = "VALID_RANK_ALIAS", family = "Pet: Bite", source = "wowhead WotLK Classic spell=27050/bite" },
    [27051] = { kind = "VALID_RANK_ALIAS", family = "Pet: Demoralizing Screech", source = "wowhead WotLK Classic spell=27051/demoralizing-screech" },
    [39023] = { kind = "VALID_RANK_ALIAS", family = "Pet: Firebolt (imp)", source = "wowhead WotLK Classic spell=39023/firebolt" },
    [27270] = { kind = "VALID_RANK_ALIAS", family = "Pet: Torment (voidwalker)", source = "wowhead WotLK Classic spell=27270/torment" },
    [52472] = { kind = "VALID_RANK_ALIAS", family = "Pet: Claw (level 80)", source = "sim/hunter/pet_abilities.go ClawSpellID + wowhead WotLK Classic spell=52472/claw" },
    [52474] = { kind = "VALID_RANK_ALIAS", family = "Pet: Bite (level 80)", source = "sim/hunter/pet_abilities.go BiteSpellID + wowhead WotLK Classic spell=52474/bite" },
    [35291] = { kind = "VALID_RANK_ALIAS", family = "Pet: Gore", source = "wowhead WotLK Classic spell=35291/gore" },
    [25016] = { kind = "VALID_RANK_ALIAS", family = "Pet: Lightning Breath", source = "wowhead WotLK Classic spell=25016/lightning-breath" },
    -- Shared-module sweep part 2 (2026-08-08): remaining pet-ability ladder tails
    -- (shared/pet_manager_sylvanas.lua) + talent-signature heads (talent_inference).
    -- Furious Howl is the WotLK-era wolf Howl (TBC ladder topped at 24600, which
    -- wowhead shows as the NPC-collision 'Web Spin'); Thunderstomp stayed TBC-era.
    [64495] = { kind = "VALID_RANK_ALIAS", family = "Pet: Furious Howl (wolf)", source = "wowhead WotLK Classic spell=64495/furious-howl (Wolf Pet Abilities) + sim/hunter/pet_abilities.go FuriousHowl" },
    [26093] = { kind = "VALID_RANK_ALIAS", family = "Pet: Thunderstomp (wind serpent)", source = "local TBC DBC family 26090-26093 (26090 = Thunderstomp); wowhead WotLK/TBC page shows NPC collision 'Quake' (pet-book artifact); wowsims omits Thunderstomp in WotLK" },
    [19443] = { kind = "VALID_RANK_ALIAS", family = "Pet: Sacrifice (voidwalker)", source = "wowhead WotLK Classic spell=19443/sacrifice" },
    [17854] = { kind = "VALID_RANK_ALIAS", family = "Pet: Consume Shadows (voidwalker)", source = "wowhead WotLK Classic spell=17854/consume-shadows" },
    [11781] = { kind = "VALID_RANK_ALIAS", family = "Pet: Lash of Pain (succubus)", source = "wowhead WotLK Classic spell=11781/lash-of-pain" },
    [54053] = { kind = "VALID_RANK_ALIAS", family = "Pet: Shadow Bite (felhunter)", source = "wowhead WotLK Classic spell=54053/shadow-bite + sim/warlock/pet_abilities.go ShadowBite 54053" },
    [30198] = { kind = "VALID_RANK_ALIAS", family = "Pet: Intercept (felguard)", source = "wowhead WotLK Classic spell=30198/intercept (Warlock Pet Abilities)" },
    [33700] = { kind = "VALID_RANK_ALIAS", family = "Pet: Anguish (felguard)", source = "wowhead WotLK Classic spell=33700/anguish (Warlock Pet Abilities)" },
    [27068] = { kind = "VALID_RANK_ALIAS", family = "Wyvern Sting", source = "wowhead WotLK Classic spell=27068/wyvern-sting (survival signature head)" },
    -- Talent spells used as signature heads in shared/talent_inference_sylvanas.lua.
    -- These are era-stable TALENT spell IDs (no rank escalation), so they are not
    -- rank ladders; the pins document them as canonical WotLK talent signatures.
    [18272] = { kind = "VALID_TALENT_SPELL", family = "Talent: Shadow Mastery", source = "wowhead WotLK Classic spell=18272/shadow-mastery (Warlock Talents)" },
    [18769] = { kind = "VALID_TALENT_SPELL", family = "Talent: Unholy Power", source = "wowhead WotLK Classic spell=18769/unholy-power (Warlock Talents)" },
    [12295] = { kind = "VALID_TALENT_SPELL", family = "Talent: Tactical Mastery", source = "wowhead WotLK Classic spell=12295/tactical-mastery (Warrior Talents)" },
    [27170] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [20920] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [20919] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [20918] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [20915] = { kind = "VALID_RANK_ALIAS", family = "Seal of Command", source = "sim/paladin/seals.go" },
    [25533] = { kind = "VALID_RANK_ALIAS", family = "Searing Totem", source = "sim/shaman/fire_totems.go" },
    [6365] = { kind = "VALID_RANK_ALIAS", family = "Searing Totem", source = "sim/shaman/fire_totems.go" },
    [6364] = { kind = "VALID_RANK_ALIAS", family = "Searing Totem", source = "sim/shaman/fire_totems.go" },
    [30912] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [27266] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [18932] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [18931] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [18930] = { kind = "VALID_RANK_ALIAS", family = "Conflagrate", source = "sim/warlock/conflagrate.go" },
    [49045] = { kind = "VALID_BRIDGE_GAP", family = "Arcane Shot", source = "sim/hunter/arcane_shot.go" },
    [49050] = { kind = "VALID_BRIDGE_GAP", family = "Aimed Shot", source = "sim/hunter/aimed_shot.go" },
    [49052] = { kind = "VALID_BRIDGE_GAP", family = "Steady Shot", source = "sim/hunter/steady_shot.go" },
    [49067] = { kind = "VALID_BRIDGE_GAP", family = "Explosive Trap", source = "sim/hunter/explosive_trap.go + local DBC rank family" },
    [49284] = { kind = "VALID_BRIDGE_GAP", family = "Earth Shield", source = "sim/shaman/heals.go" },
    [2894] = { kind = "VALID_BRIDGE_GAP", family = "Fire Elemental Totem", source = "sim/shaman/fire_elemental_totem.go + ui/elemental_shaman/apls/default.apl.json" },
    [57722] = { kind = "VALID_BRIDGE_GAP", family = "Totem of Wrath", source = "sim/shaman/totems.go + ui/elemental_shaman/apls/default.apl.json" },
    -- Rank-audit 2026-08-08: verified WotLK 3.3.5 max-rank IDs (wowhead WotLK Classic + wowsims/wotlk APL JSONs + sim source).
    -- These replaced the TBC-era ladder tops in the _wotlk.lua defines; the bridge omits them.
    [48806] = { kind = "VALID_RANK_ALIAS", family = "Hammer of Wrath", source = "wowhead WotLK Classic spell=48806 + sim/paladin/hammer_of_wrath.go (48807 disproven: Runic Healing Injector)" },
    [47450] = { kind = "VALID_RANK_ALIAS", family = "Heroic Strike", source = "wowhead WotLK Classic spell=47450 (47497 disproven: Devastate rank 2)" },
    [47471] = { kind = "VALID_RANK_ALIAS", family = "Execute", source = "wowhead WotLK Classic spell=47471 (47498 disproven: Devastate rank 3)" },
    [11958] = { kind = "VALID_RANK_ALIAS", family = "Cold Snap", source = "wowhead WotLK Classic spell=11958 (12472 disproven: Icy Veins)" },
    [42873] = { kind = "VALID_RANK_ALIAS", family = "Fire Blast", source = "wowhead WotLK Classic spell=42873" },
    [42914] = { kind = "VALID_RANK_ALIAS", family = "Ice Lance", source = "wowhead WotLK Classic spell=42914" },
    [42931] = { kind = "VALID_RANK_ALIAS", family = "Cone of Cold", source = "wowhead WotLK Classic spell=42931" },
    [47838] = { kind = "VALID_RANK_ALIAS", family = "Incinerate", source = "ui/warlock/apls/destro.apl.json" },
    [47825] = { kind = "VALID_RANK_ALIAS", family = "Soul Fire", source = "wowhead WotLK Classic spell=47825" },
    [47864] = { kind = "VALID_RANK_ALIAS", family = "Curse of Agony", source = "ui/warlock/apls/affliction.apl.json" },
    [47843] = { kind = "VALID_RANK_ALIAS", family = "Unstable Affliction", source = "ui/warlock/apls/affliction.apl.json" },
    [47855] = { kind = "VALID_RANK_ALIAS", family = "Drain Soul", source = "wowhead WotLK Classic rank family" },
    [47857] = { kind = "VALID_RANK_ALIAS", family = "Drain Life", source = "wowhead WotLK Classic rank family" },
    [48127] = { kind = "VALID_RANK_ALIAS", family = "Mind Blast", source = "ui/priest/apls/shadow.apl.json" },
    [48156] = { kind = "VALID_RANK_ALIAS", family = "Mind Flay", source = "ui/priest/apls/shadow.apl.json" },
    [48123] = { kind = "VALID_RANK_ALIAS", family = "Smite", source = "wowhead WotLK Classic spell=48123" },
    [48071] = { kind = "VALID_RANK_ALIAS", family = "Flash Heal", source = "wowhead WotLK Classic spell=48071" },
    [48068] = { kind = "VALID_RANK_ALIAS", family = "Renew", source = "wowhead WotLK Classic spell=48068" },
    [48300] = { kind = "VALID_RANK_ALIAS", family = "Devouring Plague", source = "ui/priest/apls/shadow.apl.json" },
    [48160] = { kind = "VALID_RANK_ALIAS", family = "Vampiric Touch", source = "wowhead WotLK Classic spell=48160 + ui/priest/apls/shadow.apl.json" },
    [48638] = { kind = "VALID_RANK_ALIAS", family = "Sinister Strike", source = "ui/rogue/apls/combat.apl.json" },
    [48668] = { kind = "VALID_RANK_ALIAS", family = "Eviscerate", source = "ui/rogue/apls/combat.apl.json" },
    [48691] = { kind = "VALID_RANK_ALIAS", family = "Ambush", source = "sim/rogue/ambush.go" },
    [48666] = { kind = "VALID_RANK_ALIAS", family = "Mutilate", source = "ui/rogue/apls/mutilate.apl.json" },
    [48657] = { kind = "VALID_RANK_ALIAS", family = "Backstab", source = "wowhead WotLK Classic spell=48657" },
    [57993] = { kind = "VALID_RANK_ALIAS", family = "Envenom", source = "wowhead WotLK Classic spell=57993" },
    [48570] = { kind = "VALID_RANK_ALIAS", family = "Claw", source = "wowhead WotLK Classic spell=48570" },
    [48574] = { kind = "VALID_RANK_ALIAS", family = "Rake", source = "wowhead WotLK Classic spell=48574" },
    [48572] = { kind = "VALID_RANK_ALIAS", family = "Shred", source = "wowhead WotLK Classic spell=48572" },
    [49800] = { kind = "VALID_RANK_ALIAS", family = "Rip", source = "sim/druid/rip.go" },
    [48576] = { kind = "VALID_RANK_ALIAS", family = "Ferocious Bite", source = "wowhead WotLK Classic spell=48576" },
    [48566] = { kind = "VALID_RANK_ALIAS", family = "Mangle (Cat)", source = "wowhead WotLK Classic spell=48566 + sim/druid/mangle.go" },
    [48564] = { kind = "VALID_RANK_ALIAS", family = "Mangle (Bear)", source = "sim/druid/mangle.go" },
    [48568] = { kind = "VALID_RANK_ALIAS", family = "Lacerate", source = "wowhead WotLK Classic spell=48568" },
    [48468] = { kind = "VALID_RANK_ALIAS", family = "Insect Swarm", source = "wowhead WotLK Classic spell=48468" },
    [48443] = { kind = "VALID_RANK_ALIAS", family = "Regrowth", source = "wowhead WotLK Classic spell=48443" },
    [48451] = { kind = "VALID_RANK_ALIAS", family = "Lifebloom", source = "wowhead WotLK Classic spell=48451" },
    [48063] = { kind = "VALID_RANK_ALIAS", family = "Greater Heal", source = "sim/priest/greater_heal.go (48072 disproven: Prayer of Healing)" },
    [48480] = { kind = "VALID_RANK_ALIAS", family = "Maul", source = "wowhead WotLK Classic spell=48480 + sim/druid/maul.go" },
    [48562] = { kind = "VALID_RANK_ALIAS", family = "Swipe (Bear)", source = "wowhead WotLK Classic spell=48562 + sim/druid/swipe.go" },
    [48579] = { kind = "VALID_RANK_ALIAS", family = "Ravage", source = "wowhead WotLK Classic spell=48579" },
    [48378] = { kind = "VALID_RANK_ALIAS", family = "Healing Touch", source = "wowhead WotLK Classic spell=48378" },
    [57946] = { kind = "VALID_RANK_ALIAS", family = "Life Tap", source = "wowhead WotLK Classic spell=57946" },
    [48821] = { kind = "VALID_RANK_ALIAS", family = "Holy Shock", source = "wowhead WotLK Classic spell=48821 (33074 disproven: TBC-era top)" },
    [25742] = { kind = "VALID_RANK_ALIAS", family = "Seal of Righteousness", source = "wowhead WotLK Classic spell=25742 (21084 disproven: rank 2)" },
    -- Single-ID defines surfaced by the rank-top enforcement pass (Pattern 1 was
    -- previously dead code, so scalar defines like define("KillShot", 61006, ...)
    -- were never validated). All verified on wowhead WotLK Classic 2026-08-08.
    [61006] = { kind = "VALID_RANK_ALIAS", family = "Kill Shot", source = "wowhead WotLK Classic spell=61006/kill-shot" },
    [60053] = { kind = "VALID_RANK_ALIAS", family = "Explosive Shot", source = "wowhead WotLK Classic spell=60053/explosive-shot" },
    [60052] = { kind = "VALID_RANK_ALIAS", family = "Explosive Shot (rank 2 / proc trigger)", source = "wowhead WotLK Classic spell=60052 (Explosive Shot rank 2)" },
    [2825] = { kind = "VALID_RANK_ALIAS", family = "Bloodlust", source = "wowhead WotLK Classic spell=2825/bloodlust" },
    [16166] = { kind = "VALID_RANK_ALIAS", family = "Elemental Mastery", source = "wowhead WotLK Classic spell=16166/elemental-mastery" },
    [60043] = { kind = "VALID_RANK_ALIAS", family = "Lava Burst", source = "wowhead WotLK Classic spell=60043/lava-burst" },
    [59159] = { kind = "VALID_RANK_ALIAS", family = "Thunderstorm", source = "wowhead WotLK Classic spell=59159/thunderstorm" },
    [66842] = { kind = "VALID_RANK_ALIAS", family = "Call of the Elements", source = "wowhead WotLK Classic spell=66842/call-of-the-elements" },
    [61657] = { kind = "VALID_RANK_ALIAS", family = "Fire Nova", source = "wowhead WotLK Classic spell=61657/fire-nova" },
    [16190] = { kind = "VALID_RANK_ALIAS", family = "Mana Tide Totem", source = "wowhead WotLK Classic spell=16190/mana-tide-totem" },
    [55459] = { kind = "VALID_RANK_ALIAS", family = "Chain Heal", source = "wowhead WotLK Classic spell=55459/chain-heal" },
    [49276] = { kind = "VALID_RANK_ALIAS", family = "Lesser Healing Wave", source = "wowhead WotLK Classic spell=49276/lesser-healing-wave" },
}

-- Resolved 2026-08-08: 48785/48782/48826 verified as real WotLK ranks (now
-- pinned in WOTLK_REFERENCE_ALIASES above); 48999 disproven (wowhead WotLK
-- Classic spell=48999 is Warrior Counterattack, not Avenger's Shield — moved
-- to WOTLK_REJECTED_IDS). Keep the table for classify_id's lookup path.
local WOTLK_UNVERIFIED_ALIASES = {
}

local WOTLK_REJECTED_IDS = {
    [44459] = true, -- disproven Living Bomb alias
    [48999] = true, -- wowhead WotLK Classic spell=48999 = Counterattack (Warrior), NOT Avenger's Shield
}

-- Shared-module pin table (2026-08-08): every spell ID that legitimately lives
-- in shared/talent_inference_sylvanas.lua or shared/pet_manager_sylvanas.lua
-- but is ABSENT from the WotLK player-spell bridge.  Pet abilities are pet-book
-- spells that never enter the player index; talent mid-ranks are TBC-era ranks
-- of WotLK-max spells that the bridge omits.  The shared-ladder scan accepts
-- an ID when it is bridge-known OR pinned here OR in WOTLK_REFERENCE_ALIASES.
-- This closes the silent-typo hole: a wrong-family ID (e.g. 14261-14265 Raptor
-- Strike in the Claw ladder) is neither bridge-known nor pinned and FAILS.
-- IMPORTANT: WOTLK_SHARED_IDS documents TBC-era mid-list ranks and single-ID
-- ladders.  A multi-ID ladder's WotLK-era max (its TAIL for pet ladders, HEAD
-- for talent ladders) must instead be pinned in WOTLK_REFERENCE_ALIASES or
-- WOTLK_BRIDGE_MAX_RANKS — STALE_TOP requires it (see the 35298 Gore case: a
-- TBC-only rank at the tail fails until the WotLK max 35291 takes its place).
local WOTLK_SHARED_IDS = {
    -- Hunter pet abilities (DBC + wowhead TBC/WotLK verified 2026-08-08)
    [2649] = { kind = "VALID_SHARED_ID", family = "Pet: Growl r1", source = "wowhead TBC spell=2649/growl" },
    [14916] = { kind = "VALID_SHARED_ID", family = "Pet: Growl r2", source = "DBC family 14916-14925 (Growl); wowhead TBC 14916" },
    [14917] = { kind = "VALID_SHARED_ID", family = "Pet: Growl r3", source = "DBC family 14916-14925 (Growl)" },
    [14918] = { kind = "VALID_SHARED_ID", family = "Pet: Growl r4", source = "DBC family 14916-14925 (Growl)" },
    [14919] = { kind = "VALID_SHARED_ID", family = "Pet: Growl r5", source = "DBC family 14916-14925 (Growl)" },
    [14920] = { kind = "VALID_SHARED_ID", family = "Pet: Growl r6", source = "DBC family 14916-14925 (Growl)" },
    [14921] = { kind = "VALID_SHARED_ID", family = "Pet: Growl r7", source = "DBC family 14916-14925 (Growl)" },
    [14925] = { kind = "VALID_SHARED_ID", family = "Pet: Growl r8 (TBC top)", source = "DBC family 14916-14925 (Growl)" },
    [2981] = { kind = "VALID_SHARED_ID", family = "Pet: Claw r1 (learn entry)", source = "wowhead TBC spell=2981/claw (Uncategorized learn spell; NOT the druid cat-form Claw 1082/3029)" },
    [16827] = { kind = "VALID_SHARED_ID", family = "Pet: Claw r5", source = "DBC family 16827-16832 (Claw); wowhead TBC 16827/claw" },
    [16828] = { kind = "VALID_SHARED_ID", family = "Pet: Claw r6", source = "DBC family 16827-16832 (Claw)" },
    [16829] = { kind = "VALID_SHARED_ID", family = "Pet: Claw r7", source = "DBC family 16827-16832 (Claw)" },
    [16830] = { kind = "VALID_SHARED_ID", family = "Pet: Claw r8", source = "DBC family 16827-16832 (Claw)" },
    [16831] = { kind = "VALID_SHARED_ID", family = "Pet: Claw r9", source = "DBC family 16827-16832 (Claw)" },
    [16832] = { kind = "VALID_SHARED_ID", family = "Pet: Claw r10", source = "DBC family 16827-16832 (Claw)" },
    [3010] = { kind = "VALID_SHARED_ID", family = "Pet: Claw r4", source = "wowhead TBC spell=3010/claw" },
    [3009] = { kind = "VALID_SHARED_ID", family = "Pet: Claw r3", source = "wowhead TBC spell=3009/claw" },
    [17253] = { kind = "VALID_SHARED_ID", family = "Pet: Bite r1", source = "wowhead TBC spell=17253/bite" },
    [17254] = { kind = "VALID_SHARED_ID", family = "Pet: Bite r2", source = "wowhead TBC spell=17254/bite" },
    [17255] = { kind = "VALID_SHARED_ID", family = "Pet: Bite r3", source = "DBC family 17253-17261 (Bite)" },
    [17256] = { kind = "VALID_SHARED_ID", family = "Pet: Bite r4", source = "DBC family 17253-17261 (Bite)" },
    [17257] = { kind = "VALID_SHARED_ID", family = "Pet: Bite r5", source = "DBC family 17253-17261 (Bite)" },
    [17258] = { kind = "VALID_SHARED_ID", family = "Pet: Bite r6", source = "wowhead TBC spell=17258/bite" },
    [17259] = { kind = "VALID_SHARED_ID", family = "Pet: Bite r7", source = "wowhead TBC spell=17259/bite" },
    [17260] = { kind = "VALID_SHARED_ID", family = "Pet: Bite r8", source = "wowhead TBC spell=17260/bite" },
    [17261] = { kind = "VALID_SHARED_ID", family = "Pet: Bite r9", source = "wowhead TBC spell=17261/bite" },
    [35290] = { kind = "VALID_SHARED_ID", family = "Pet: Gore r1", source = "wowhead TBC spell=35290/gore" },
    [35298] = { kind = "VALID_SHARED_ID", family = "Pet: Gore r2 (TBC max)", source = "wowhead TBC spell=35298/gore; wowsims/tbc pet_abilities.go" },
    [24597] = { kind = "VALID_SHARED_ID", family = "Pet: Furious Howl r1", source = "wowhead TBC spell=24597/furious-howl" },
    [24599] = { kind = "VALID_SHARED_ID", family = "Pet: Furious Howl (learn)", source = "wowhead TBC spell=24599/furious-howl" },
    [24603] = { kind = "VALID_SHARED_ID", family = "Pet: Furious Howl r2", source = "wowhead TBC spell=24603/furious-howl" },
    [24604] = { kind = "VALID_SHARED_ID", family = "Pet: Furious Howl r3", source = "wowhead TBC spell=24604/furious-howl" },
    [24605] = { kind = "VALID_SHARED_ID", family = "Pet: Furious Howl r4", source = "wowhead TBC spell=24605/furious-howl" },
    [24423] = { kind = "VALID_SHARED_ID", family = "Pet: Screech r1", source = "wowhead TBC spell=24423/screech" },
    [26090] = { kind = "VALID_SHARED_ID", family = "Pet: Thunderstomp r1", source = "local TBC DBC family 26090-26093" },
    [25011] = { kind = "VALID_SHARED_ID", family = "Pet: Lightning Breath r1", source = "DBC family 25011-25016 (Lightning Breath)" },
    [25012] = { kind = "VALID_SHARED_ID", family = "Pet: Lightning Breath r2", source = "DBC family 25011-25016 (Lightning Breath)" },
    [25013] = { kind = "VALID_SHARED_ID", family = "Pet: Lightning Breath r3", source = "DBC family 25011-25016 (Lightning Breath)" },
    [25014] = { kind = "VALID_SHARED_ID", family = "Pet: Lightning Breath r4", source = "DBC family 25011-25016 (Lightning Breath)" },
    [25015] = { kind = "VALID_SHARED_ID", family = "Pet: Lightning Breath r5", source = "DBC family 25011-25016 (Lightning Breath)" },
    [24640] = { kind = "VALID_SHARED_ID", family = "Pet: Scorpid Poison", source = "wowhead TBC spell=24640" },
    [23099] = { kind = "VALID_SHARED_ID", family = "Pet: Dash", source = "wowhead TBC spell=23099/dash" },
    [23145] = { kind = "VALID_SHARED_ID", family = "Pet: Dive", source = "wowhead TBC spell=23145/dive" },
    -- Warlock pet abilities
    [3110] = { kind = "VALID_SHARED_ID", family = "Pet: Firebolt r1 (imp)", source = "DBC family 3110-39023 (Firebolt)" },
    [7799] = { kind = "VALID_SHARED_ID", family = "Pet: Firebolt r2 (imp)", source = "DBC family 3110-39023 (Firebolt)" },
    [7800] = { kind = "VALID_SHARED_ID", family = "Pet: Firebolt r3 (imp)", source = "DBC family 3110-39023 (Firebolt)" },
    [7801] = { kind = "VALID_SHARED_ID", family = "Pet: Firebolt r4 (imp)", source = "DBC family 3110-39023 (Firebolt)" },
    [7802] = { kind = "VALID_SHARED_ID", family = "Pet: Firebolt r5 (imp)", source = "DBC family 3110-39023 (Firebolt)" },
    [11762] = { kind = "VALID_SHARED_ID", family = "Pet: Firebolt r6 (imp)", source = "DBC family 3110-39023 (Firebolt)" },
    [11763] = { kind = "VALID_SHARED_ID", family = "Pet: Firebolt r7 (imp)", source = "DBC family 3110-39023 (Firebolt)" },
    [27267] = { kind = "VALID_SHARED_ID", family = "Pet: Firebolt r8 (imp)", source = "wowhead TBC spell=27267/firebolt" },
    [17735] = { kind = "VALID_SHARED_ID", family = "Pet: Torment r1 (voidwalker)", source = "wowhead TBC spell=17735/torment" },
    [11774] = { kind = "VALID_SHARED_ID", family = "Pet: Torment r2 (voidwalker)", source = "DBC family 11774-11775 (Torment)" },
    [11775] = { kind = "VALID_SHARED_ID", family = "Pet: Torment r3 (voidwalker)", source = "DBC family 11774-11775 (Torment)" },
    [7812] = { kind = "VALID_SHARED_ID", family = "Pet: Sacrifice r1 (voidwalker)", source = "wowhead TBC spell=7812/sacrifice" },
    [19438] = { kind = "VALID_SHARED_ID", family = "Pet: Sacrifice r2 (voidwalker)", source = "wowhead TBC spell=19438/sacrifice" },
    [19440] = { kind = "VALID_SHARED_ID", family = "Pet: Sacrifice r3 (voidwalker)", source = "wowhead TBC spell=19440/sacrifice" },
    [19441] = { kind = "VALID_SHARED_ID", family = "Pet: Sacrifice r4 (voidwalker)", source = "wowhead TBC spell=19441/sacrifice" },
    [19442] = { kind = "VALID_SHARED_ID", family = "Pet: Sacrifice r5 (voidwalker)", source = "wowhead TBC spell=19442/sacrifice" },
    [17767] = { kind = "VALID_SHARED_ID", family = "Pet: Consume Shadows r1 (voidwalker)", source = "DBC family 17767-17854 (Consume Shadows)" },
    [17850] = { kind = "VALID_SHARED_ID", family = "Pet: Consume Shadows r2 (voidwalker)", source = "DBC family 17767-17854 (Consume Shadows)" },
    [17851] = { kind = "VALID_SHARED_ID", family = "Pet: Consume Shadows r3 (voidwalker)", source = "DBC family 17767-17854 (Consume Shadows)" },
    [17852] = { kind = "VALID_SHARED_ID", family = "Pet: Consume Shadows r4 (voidwalker)", source = "DBC family 17767-17854 (Consume Shadows)" },
    [17853] = { kind = "VALID_SHARED_ID", family = "Pet: Consume Shadows r5 (voidwalker)", source = "DBC family 17767-17854 (Consume Shadows)" },
    [7814] = { kind = "VALID_SHARED_ID", family = "Pet: Lash of Pain r1 (succubus)", source = "wowhead TBC spell=7814/lash-of-pain" },
    [11778] = { kind = "VALID_SHARED_ID", family = "Pet: Lash of Pain r2 (succubus)", source = "DBC family 11778-11781 (Lash of Pain)" },
    [11779] = { kind = "VALID_SHARED_ID", family = "Pet: Lash of Pain r3 (succubus)", source = "DBC family 11778-11781 (Lash of Pain)" },
    [11780] = { kind = "VALID_SHARED_ID", family = "Pet: Lash of Pain r4 (succubus)", source = "DBC family 11778-11781 (Lash of Pain)" },
    [6358] = { kind = "VALID_SHARED_ID", family = "Pet: Seduction (succubus)", source = "wowhead TBC spell=6358/seduction" },
    [54049] = { kind = "VALID_SHARED_ID", family = "Pet: Shadow Bite r1 (felhunter)", source = "wowhead WotLK spell=54049/shadow-bite" },
    [54050] = { kind = "VALID_SHARED_ID", family = "Pet: Shadow Bite r2 (felhunter)", source = "wowhead WotLK spell=54050/shadow-bite" },
    [54051] = { kind = "VALID_SHARED_ID", family = "Pet: Shadow Bite r3 (felhunter)", source = "wowhead WotLK spell=54051/shadow-bite" },
    [54052] = { kind = "VALID_SHARED_ID", family = "Pet: Shadow Bite r4 (felhunter)", source = "wowhead WotLK spell=54052/shadow-bite" },
    [19505] = { kind = "VALID_SHARED_ID", family = "Pet: Devour Magic (felhunter)", source = "wowhead TBC spell=19505/devour-magic" },
    [30213] = { kind = "VALID_SHARED_ID", family = "Pet: Cleave (felguard)", source = "wowhead TBC spell=30213/cleave" },
    [30195] = { kind = "VALID_SHARED_ID", family = "Pet: Intercept r1 (felguard)", source = "wowhead WotLK spell=30195/intercept (rank 2); 30196 disproven (404)" },
    [30197] = { kind = "VALID_SHARED_ID", family = "Pet: Intercept r2 (felguard)", source = "wowhead WotLK spell=30197/intercept" },
    [33698] = { kind = "VALID_SHARED_ID", family = "Pet: Anguish r1 (felguard)", source = "wowhead WotLK spell=33698/anguish" },
    [33699] = { kind = "VALID_SHARED_ID", family = "Pet: Anguish r2 (felguard)", source = "wowhead WotLK spell=33699/anguish" },
    -- Mage pet abilities (Water Elemental)
    [31707] = { kind = "VALID_SHARED_ID", family = "Pet: Waterbolt (water elemental)", source = "wowhead TBC spell=31707/waterbolt" },
    [33395] = { kind = "VALID_SHARED_ID", family = "Pet: Freeze (water elemental)", source = "wowhead TBC spell=33395/freeze" },
    -- talent_inference mid-ranks (TBC-era ranks of WotLK-max spells, bridge-omitted)
    [34861] = { kind = "VALID_SHARED_ID", family = "Circle of Healing r1", source = "wowhead TBC spell=34861/circle-of-healing" },
    [34863] = { kind = "VALID_SHARED_ID", family = "Circle of Healing r2", source = "wowhead TBC spell=34863/circle-of-healing" },
    [34864] = { kind = "VALID_SHARED_ID", family = "Circle of Healing r3", source = "wowhead TBC spell=34864/circle-of-healing" },
    [34865] = { kind = "VALID_SHARED_ID", family = "Circle of Healing r4", source = "wowhead TBC spell=34865/circle-of-healing" },
    [34866] = { kind = "VALID_SHARED_ID", family = "Circle of Healing r5", source = "wowhead TBC spell=34866/circle-of-healing" },
    [18273] = { kind = "VALID_SHARED_ID", family = "Talent: Shadow Mastery r2", source = "wowhead WotLK talent ranks 18272-18275" },
    [18274] = { kind = "VALID_SHARED_ID", family = "Talent: Shadow Mastery r3", source = "wowhead WotLK talent ranks 18272-18275" },
    [18275] = { kind = "VALID_SHARED_ID", family = "Talent: Shadow Mastery r4", source = "wowhead WotLK talent ranks 18272-18275" },
    [18770] = { kind = "VALID_SHARED_ID", family = "Talent: Unholy Power r2", source = "wowhead WotLK talent ranks 18769-18773" },
    [18771] = { kind = "VALID_SHARED_ID", family = "Talent: Unholy Power r3", source = "wowhead WotLK talent ranks 18769-18773" },
    [18772] = { kind = "VALID_SHARED_ID", family = "Talent: Unholy Power r4", source = "wowhead WotLK talent ranks 18769-18773" },
    [18773] = { kind = "VALID_SHARED_ID", family = "Talent: Unholy Power r5", source = "wowhead WotLK talent ranks 18769-18773" },
    [12676] = { kind = "VALID_SHARED_ID", family = "Talent: Tactical Mastery r2", source = "wowhead WotLK talent ranks 12295/12676/12677" },
    [12677] = { kind = "VALID_SHARED_ID", family = "Talent: Tactical Mastery r3", source = "wowhead WotLK talent ranks 12295/12676/12677" },
    [16511] = { kind = "VALID_SHARED_ID", family = "Hemorrhage r1", source = "wowhead TBC spell=16511/hemorrhage" },
    [17347] = { kind = "VALID_SHARED_ID", family = "Hemorrhage r2", source = "wowhead TBC spell=17347/hemorrhage" },
    [17348] = { kind = "VALID_SHARED_ID", family = "Hemorrhage r3", source = "wowhead TBC spell=17348/hemorrhage" },
    [26864] = { kind = "VALID_SHARED_ID", family = "Hemorrhage r4", source = "wowhead TBC spell=26864/hemorrhage" },
    [19386] = { kind = "VALID_SHARED_ID", family = "Wyvern Sting r1", source = "wowhead TBC spell=19386/wyvern-sting" },
    [24132] = { kind = "VALID_SHARED_ID", family = "Wyvern Sting r2", source = "wowhead TBC spell=24132/wyvern-sting" },
    [24133] = { kind = "VALID_SHARED_ID", family = "Wyvern Sting r3", source = "wowhead TBC spell=24133/wyvern-sting" },
    [20929] = { kind = "VALID_SHARED_ID", family = "Holy Shock r2", source = "wowhead TBC spell=20929/holy-shock" },
    [20930] = { kind = "VALID_SHARED_ID", family = "Holy Shock r3", source = "wowhead TBC spell=20930/holy-shock" },
    [27174] = { kind = "VALID_SHARED_ID", family = "Holy Shock r4", source = "wowhead TBC spell=27174/holy-shock" },
    [27175] = { kind = "VALID_SHARED_ID", family = "Holy Shock r5", source = "wowhead TBC spell=27175/holy-shock" },
    -- talent_inference single-ID signatures absent from the bridge (talent spells)
    [33206] = { kind = "VALID_SHARED_ID", family = "Talent: Pain Suppression", source = "wowhead WotLK spell=33206/pain-suppression" },
    [10060] = { kind = "VALID_SHARED_ID", family = "Talent: Power Infusion", source = "wowhead WotLK spell=10060/power-infusion" },
    [19028] = { kind = "VALID_SHARED_ID", family = "Talent: Soul Link", source = "wowhead WotLK spell=19028/soul-link" },
    [13750] = { kind = "VALID_SHARED_ID", family = "Talent: Adrenaline Rush", source = "wowhead WotLK spell=13750/adrenaline-rush" },
    [14185] = { kind = "VALID_SHARED_ID", family = "Talent: Preparation", source = "wowhead WotLK spell=14185/preparation" },
    [19503] = { kind = "VALID_SHARED_ID", family = "Talent: Scatter Shot", source = "wowhead WotLK spell=19503/scatter-shot" },
    [16188] = { kind = "VALID_SHARED_ID", family = "Talent: Nature's Swiftness", source = "wowhead WotLK spell=16188/natures-swiftness" },
    [30798] = { kind = "VALID_SHARED_ID", family = "Talent: Dual Wield", source = "wowhead WotLK spell=30798/dual-wield" },
    [29166] = { kind = "VALID_SHARED_ID", family = "Talent: Innervate", source = "wowhead WotLK spell=29166/innervate" },
    [33831] = { kind = "VALID_SHARED_ID", family = "Talent: Force of Nature", source = "wowhead WotLK spell=33831/force-of-nature" },
    [20216] = { kind = "VALID_SHARED_ID", family = "Talent: Divine Favor", source = "wowhead WotLK spell=20216/divine-favor" },
}

-- Verified WotLK 3.3.5 max ranks that live in the wowhead bridge (they did NOT
-- need a REFERENCE_ALIAS entry). Every multi-ID define ladder's top-of-list ID
-- (the cast priority for a max-level player under first-known-wins resolution)
-- MUST be a pinned max rank. This makes a stale TBC-era ladder top structurally
-- impossible: it would be flagged as STALE_TOP and fail the audit.
local WOTLK_BRIDGE_MAX_RANKS = {
    -- warrior
    [47436] = "Battle Shout", [47439] = "Commanding Shout", [11578] = "Charge",
    [25275] = "Intercept", [47465] = "Rend", [47486] = "Mortal Strike",
    [11585] = "Overpower", [47475] = "Slam", [47502] = "Thunder Clap",
    [47437] = "Demoralizing Shout", [25212] = "Hamstring", [6554] = "Pummel",
    [30335] = "Bloodthirst", [12292] = "Death Wish", [47520] = "Cleave",
    -- 30356 removed 2026-08-08: wowhead + wowsims confirm 47488 is the real
    -- WotLK Shield Slam max (30356 is TBC-era rank 6, pinned via alias above).
    [30357] = "Revenge", [30022] = "Devastate",
    -- deathknight
    [49909] = "Icy Touch", [49921] = "Plague Strike", [51425] = "Obliterate",
    [51411] = "Howling Blast", [55268] = "Frost Strike", [49930] = "Blood Strike",
    [55262] = "Heart Strike", [49999] = "Death Strike", [49895] = "Death Coil",
    [49938] = "Death and Decay", [55271] = "Scourge Strike", [57623] = "Horn of Winter",
    [49941] = "Blood Boil",
    -- mage
    [42833] = "Fireball", [42859] = "Scorch", [42846] = "Arcane Missiles",
    [42940] = "Blizzard", [42921] = "Arcane Explosion", [42995] = "Arcane Intellect",
    [43024] = "Mage Armor", [33405] = "Ice Barrier", [42897] = "Arcane Blast",
    [44425] = "Arcane Barrage", [27131] = "Mana Shield", [27101] = "Conjure Mana Gem",
    [42842] = "Frostbolt", [42891] = "Pyroblast",
    -- warlock
    [28189] = "Fel Armor", [27260] = "Demon Armor", [27230] = "Create Healthstone",
    [47884] = "Create Soulstone", [47836] = "Seed of Corruption", [47820] = "Rain of Fire",
    [47809] = "Shadow Bolt", [47811] = "Immolate", [47813] = "Corruption", [59164] = "Haunt",
    -- priest
    [48161] = "Power Word: Fortitude", [48168] = "Inner Fire",
    [48066] = "Power Word: Shield", [48125] = "Shadow Word: Pain",
    -- rogue
    [6774] = "Slice and Dice", [11286] = "Gouge", [38768] = "Kick", [1787] = "Stealth",
    [48672] = "Rupture",
    -- druid
    [48461] = "Wrath", [48465] = "Starfire", [48463] = "Moonfire",
    [48441] = "Rejuvenation", [26989] = "Entangling Roots", [26990] = "Mark of the Wild",
    [26992] = "Thorns", [9634] = "Dire Bear Form",
    -- paladin
    [20271] = "Judgement", [48819] = "Consecration", [48801] = "Exorcism",
    [48932] = "Blessing of Might", [48942] = "Devotion Aura", [48827] = "Avenger's Shield",
    [53600] = "Shield of Righteousness",
    -- hunter
    [49001] = "Serpent Sting", [49048] = "Multi Shot", [14325] = "Hunter's Mark",
    [27044] = "Aspect of the Hawk", [48990] = "Mend Pet", [58434] = "Volley",
    -- shaman
    [49238] = "Lightning Bolt", [49231] = "Earth Shock", [49233] = "Flame Shock",
    [49273] = "Healing Wave", [49281] = "Lightning Shield", [58790] = "Flametongue Weapon",
    [58704] = "Searing Totem", [49271] = "Chain Lightning", [58734] = "Magma Totem",
}

-- Union of every pinned max rank: reference aliases (bridge-gap IDs) + bridge max ranks.
local WOTLK_MAX_RANK_IDS = {}
for id in pairs(WOTLK_REFERENCE_ALIASES) do
    WOTLK_MAX_RANK_IDS[id] = true
end
for id in pairs(WOTLK_BRIDGE_MAX_RANKS) do
    WOTLK_MAX_RANK_IDS[id] = true
end

local function is_max_rank(id)
    return WOTLK_MAX_RANK_IDS[id] == true
end

local root = "EaxRotations"

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close(); return true end
    return false
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local content = f:read("*a") or ""
    f:close()
    return content
end

local function extract_ids_from_line(line, tops)
    local ids = {}
    if type(line) ~= "string" then return ids end

    local function collect(block)
        if not block then return end
        if block:find("=") then return end
        for n in block:gmatch("(%d+)") do
            local v = tonumber(n)
            if v >= 1000 and v <= 99999 then
                ids[#ids + 1] = v
            end
        end
    end

    -- Pattern 1: define("Name", { ids }, ...) or define("Name", id, "...")
    -- Scan the whole line for define calls and pull the SECOND argument.
    -- NOTE: must be a PATTERN search (no `true` plain flag) so the %s* whitespace
    -- matcher is honored; a literal search for "define%s*(" never matches real code.
    -- Argument walk: track paren + brace depth; top-level commas (depth 1, braces 0)
    -- delimit arguments. Arg 2 runs from after the 1st comma to the 2nd comma (or the
    -- closing paren for a 2-arg call). Comma-skipping braces keeps nested tables intact.
    local pos = 1
    while true do
        local start_idx = line:find("define%s*%(", pos)
        if not start_idx then break end
        local paren_idx = line:find("%(", start_idx)
        local depth = 1
        local i = paren_idx + 1
        local arg_start = nil
        local arg_end = nil
        local comma_count = 0
        local brace_depth = 0
        local in_string = false
        local string_char = nil
        while i <= #line and depth > 0 do
            local c = line:sub(i, i)
            if in_string then
                if c == "\\" then
                    i = i + 1
                elseif c == string_char then
                    in_string = false
                end
            elseif c == '"' or c == "'" then
                in_string = true
                string_char = c
            elseif c == "(" then
                depth = depth + 1
            elseif c == ")" then
                depth = depth - 1
                if depth == 0 then
                    arg_end = i - 1
                    break
                end
            elseif c == "{" then
                brace_depth = brace_depth + 1
            elseif c == "}" then
                if brace_depth > 0 then brace_depth = brace_depth - 1 end
            elseif c == "," and depth == 1 and brace_depth == 0 then
                comma_count = comma_count + 1
                if comma_count == 1 then
                    arg_start = i + 1
                elseif comma_count == 2 then
                    arg_end = i - 1
                    break
                end
            end
            i = i + 1
        end
        if arg_start and arg_end then
            local second_arg = line:sub(arg_start, arg_end)
            local table_part = second_arg:match("(%b{})")
            if table_part then
                local inner = table_part:sub(2, -2)
                collect(inner)
                -- Rank-top enforcement: record the first (top-of-list) ID of every
                -- multi-ID define ladder so scan_content can require it to be a
                -- pinned max rank (first-known-wins cast priority).
                -- Mirror collect()'s `=` guard: keyed tables (e.g. { [1] = 47813 })
                -- are not numeric ladders, so their keys must not be treated as tops.
                if tops and not inner:find("=") then
                    local first_num = inner:match("(%d+)")
                    if first_num then
                        local count = 0
                        for _ in inner:gmatch("(%d+)") do count = count + 1 end
                        if count >= 2 then
                            tops[#tops + 1] = { id = tonumber(first_num), count = count }
                        end
                    end
                end
            else
                local num = second_arg:match("^%s*(%d+)%s*$")
                if num then
                    local v = tonumber(num)
                    if v and v >= 1000 and v <= 99999 then
                        ids[#ids + 1] = v
                    end
                end
            end
        end
        pos = (arg_end or start_idx) + 1
    end

    -- Pattern 2: pure numeric table literals like { 123, 456 } — common for spell/buff/debuff lists.
    for table_part in line:gmatch("(%b{})") do
        local inner = table_part:sub(2, -2)
        -- Only collect if the table contains only numbers, commas, and whitespace.
        if inner:match("^[%s,,%d]*$") then
            collect(inner)
        end
    end

    -- Deduplicate: Pattern 1 (define tables) and Pattern 2 (pure-numeric tables)
    -- overlap on define ladders; report each ID once per line.
    local seen = {}
    local deduped = {}
    for _, id in ipairs(ids) do
        if not seen[id] then
            seen[id] = true
            deduped[#deduped + 1] = id
        end
    end
    return deduped
end

local function classify_id(id)
    if valid_wotlk_ids[id] then return nil end

    local alias = WOTLK_REFERENCE_ALIASES[id]
    if alias then return alias.kind, alias.family end
    local unverified = WOTLK_UNVERIFIED_ALIASES[id]
    if unverified then return unverified.kind, unverified.family end
    if WOTLK_REJECTED_IDS[id] then return "INVALID" end
    if valid_tbc_ids[id] then return "TBC_ID_IN_WOTLK" end
    if valid_vanilla_ids[id] then return "VANILLA_ID_IN_WOTLK" end
    return "INVALID"
end

local function is_comment_line(line)
    return line:match("^%s*%-%-") ~= nil
end

local function scan_content(content)
    if type(content) ~= "string" then
        return { error = "content must be a string", hits = {} }
    end
    local hits = {}
    local unverified = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if not is_comment_line(line) then
            local tops = {}
            local ids = extract_ids_from_line(line, tops)
            for _, t in ipairs(tops) do
                if not is_max_rank(t.id) then
                    hits[#hits + 1] = {
                        line = line_no,
                        id = t.id,
                        kind = "STALE_TOP",
                        family = "ladder top is not a pinned WotLK max rank",
                        snippet = (line:match("^%s*(.-)%s*$") or line):sub(1, 100),
                    }
                end
            end
            for _, id in ipairs(ids) do
                local kind, family = classify_id(id)
                local hit = {
                    line = line_no,
                    id = id,
                    kind = kind,
                    family = family,
                    snippet = (line:match("^%s*(.-)%s*$") or line):sub(1, 100),
                }
                if kind == "INVALID" or kind == "TBC_ID_IN_WOTLK" or kind == "VANILLA_ID_IN_WOTLK" then
                    hits[#hits + 1] = hit
                elseif kind == "UNVERIFIED_ALIAS" then
                    unverified[#unverified + 1] = hit
                end
            end
        end
    end

    return { found = #hits > 0, hits = hits, unverified = unverified }
end

local function scan_file(filepath)
    if not file_exists(filepath) then
        return { skipped = true, hits = {}, unverified = {} }
    end
    local content = read_file(filepath)
    if not content then
        return { error = "could not read", hits = {}, unverified = {} }
    end
    return scan_content(content)
end

-- ============================================================================
-- Shared-module ladder scan (rank-audit 2026-08-08, part 2)
--
-- The class-file scan above only enforces STALE_TOP on define() ladders in
-- classes/.  Two shared modules ALSO carry era-sensitive rank ladders that the
-- campaign's verified-max convention must cover:
--
--   * shared/talent_inference_sylvanas.lua — `ids = { ... }` signature lists.
--     Resolution is ANY-match (has_any_spell_learned), but the campaign prepends
--     the verified WotLK max rank FIRST, so the ladder HEAD (first element) is
--     the pin target.  Talent spells (Shadow Mastery etc.) are era-stable
--     signatures, not rank ladders — pinned via VALID_TALENT_SPELL below.
--
--   * shared/pet_manager_sylvanas.lua — `local NAME = { ... }` pure-numeric pet
--     ability ladders.  The scanner iterates them TAIL-FIRST (for i = #list, 1, -1),
--     so the resolution head is the LAST element.  The campaign appended the
--     WotLK-era pet rank at the END of each ladder; the tail is the pin target.
--
--   Enforcement (2026-08-08 part 2): two checks per ladder --
--     * STALE_TOP: a multi-ID ladder head that is not a pinned WotLK max rank
--       fails (a single-ID ladder has no head/max contrast; its only ID is
--       covered by the UNPINNED check).
--     * UNPINNED_SHARED_ID: EVERY ID in every ladder (mid-list and single-ID
--       included) must be bridge-known, pinned in WOTLK_SHARED_IDS, or pinned
--       in WOTLK_REFERENCE_ALIASES.  This closes the silent-typo hole: a
--       wrong-family ID (e.g. 14261-14265 Raptor Strike in the Claw ladder)
--       is neither bridge-known nor pinned, so it FAILS.
--   Full classify_id INVALID/TBC checks are intentionally NOT run on shared
--   modules: pet abilities and TBC-era mid-ranks legitimately live outside the
--   player-spell bridge; the WOTLK_SHARED_IDS pin table documents them instead.
-- ============================================================================
local WOTLK_SHARED_LADDERS = {
    { file = "shared/talent_inference_sylvanas.lua", mode = "talent_ids",   head = "first" },
    { file = "shared/pet_manager_sylvanas.lua",      mode = "numeric_local", head = "last" },
}

-- Every ID inside a shared-module ladder must be bridge-known, pinned as a
-- shared-module ID, or pinned as a reference alias.  This is what makes a typo'd
-- mid-list rank (e.g. 14261-14265 Raptor Strike inside the Claw ladder) fail:
-- the ID is neither bridge-known nor pinned, so it is reported as UNPINNED.
local function shared_id_ok(id)
    if valid_wotlk_ids[id] then return true end
    if WOTLK_SHARED_IDS[id] then return true end
    if WOTLK_REFERENCE_ALIASES[id] then return true end
    return false
end

local function extract_shared_ladders(content, mode, head_pos)
    local ladders = {}
    if type(content) ~= "string" then return ladders end
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if not is_comment_line(line) then
            local tables = {}
            if mode == "talent_ids" then
                -- capture every `ids = { ... }` table on the line
                for t in line:gmatch("ids%s*=%s*(%b{})") do
                    tables[#tables + 1] = t
                end
            elseif mode == "numeric_local" then
                -- capture `local NAME = { ... }` tables whose contents are pure numeric
                -- ([%w_]+ matches PET_GROWL / FELHUNTER_BITE etc.; single-word locals only)
                for t in line:gmatch("local%s+[%w_]+%s*=%s*(%b{})") do
                    tables[#tables + 1] = t
                end
            end
            for _, t in ipairs(tables) do
                local inner = t:sub(2, -2)
                if not inner:find("=") then
                    local nums = {}
                    for n in inner:gmatch("(%d+)") do
                        local v = tonumber(n)
                        if v and v >= 1000 and v <= 99999 then nums[#nums + 1] = v end
                    end
                    -- Single-ID ladders are captured too: a lone typo'd rank must
                    -- still be pinned (no multi-ID head to catch it).
                    if #nums >= 1 then
                        local head = (head_pos == "last") and nums[#nums] or nums[1]
                        ladders[#ladders + 1] = { line = line_no, head = head, count = #nums, ids = nums }
                    end
                end
            end
        end
    end
    return ladders
end

local function scan_shared_ladders(content, mode, head_pos)
    local hits = {}
    for _, ladder in ipairs(extract_shared_ladders(content, mode, head_pos)) do
        -- STALE_TOP: a multi-ID ladder head must be a pinned WotLK max rank.
        -- (A single-ID ladder has no "head vs. max" contrast; its only ID is
        -- validated by the UNPINNED check below.)
        if ladder.count >= 2 and not is_max_rank(ladder.head) then
            hits[#hits + 1] = {
                line = ladder.line,
                id = ladder.head,
                kind = "STALE_TOP",
                family = "shared-module ladder head is not a pinned WotLK max rank",
                snippet = "head id " .. ladder.head .. " (" .. ladder.count .. " ids)",
            }
        end
        -- UNPINNED_SHARED_ID: every ID in the ladder (mid-list included) must be
        -- bridge-known or pinned.  Closes the silent-typo hole for pet ranks.
        for _, id in ipairs(ladder.ids) do
            if not shared_id_ok(id) then
                hits[#hits + 1] = {
                    line = ladder.line,
                    id = id,
                    kind = "UNPINNED_SHARED_ID",
                    family = "shared-module ladder ID is neither bridge-known nor pinned",
                    snippet = "id " .. id .. " in ladder " .. (ladder.count == 1 and "(single)" or "(" .. ladder.count .. " ids)"),
                }
            end
        end
    end
    return hits
end

local WOTLK_FILES = {
    "classes/deathknight/blood_wotlk.lua",
    "classes/deathknight/frost_wotlk.lua",
    "classes/deathknight/leveling_wotlk.lua",
    "classes/deathknight/unholy_wotlk.lua",
    "classes/druid/balance_wotlk.lua",
    "classes/druid/bear_wotlk.lua",
    "classes/druid/cat_wotlk.lua",
    "classes/druid/leveling_wotlk.lua",
    "classes/druid/resto_wotlk.lua",
    "classes/hunter/beast_mastery_wotlk.lua",
    "classes/hunter/leveling_wotlk.lua",
    "classes/hunter/marksmanship_wotlk.lua",
    "classes/hunter/survival_wotlk.lua",
    "classes/mage/arcane_wotlk.lua",
    "classes/mage/fire_wotlk.lua",
    "classes/mage/frost_wotlk.lua",
    "classes/mage/leveling_wotlk.lua",
    "classes/paladin/holy_wotlk.lua",
    "classes/paladin/leveling_wotlk.lua",
    "classes/paladin/protection_wotlk.lua",
    "classes/paladin/retribution_wotlk.lua",
    "classes/priest/discipline_wotlk.lua",
    "classes/priest/holy_wotlk.lua",
    "classes/priest/leveling_wotlk.lua",
    "classes/priest/shadow_wotlk.lua",
    "classes/rogue/assassination_wotlk.lua",
    "classes/rogue/combat_wotlk.lua",
    "classes/rogue/leveling_wotlk.lua",
    "classes/rogue/subtlety_wotlk.lua",
    "classes/shaman/elemental_wotlk.lua",
    "classes/shaman/enhancement_wotlk.lua",
    "classes/shaman/leveling_wotlk.lua",
    "classes/shaman/restoration_wotlk.lua",
    "classes/warlock/affliction_wotlk.lua",
    "classes/warlock/demonology_wotlk.lua",
    "classes/warlock/destruction_wotlk.lua",
    "classes/warlock/leveling_wotlk.lua",
    "classes/warrior/arms_wotlk.lua",
    "classes/warrior/fury_wotlk.lua",
    "classes/warrior/leveling_wotlk.lua",
    "classes/warrior/protection_wotlk.lua",
}

local function run_self_tests()
    local function expect(actual, expected, label)
        if actual ~= expected then
            error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
        end
    end

    expect(#extract_ids_from_line(nil), 0, "malformed nil line")
    expect(scan_content(nil).error, "content must be a string", "malformed content")
    expect(scan_file("__missing_wotlk_audit_fixture__.lua").skipped, true, "missing fixture")

    local function map_count(map)
        local count = 0
        for _ in pairs(map) do count = count + 1 end
        return count
    end

    local kind, family = classify_id(61411)
    expect(kind, "VALID_BRIDGE_GAP", "pinned bridge gap")
    expect(family, "Shield of Righteousness", "bridge gap family")
    expect(classify_id(27011), "VALID_RANK_ALIAS", "rank alias")
    expect(classify_id(44448), "VALID_AURA_ALIAS", "pinned aura alias")
    expect(classify_id(49045), "VALID_BRIDGE_GAP", "pinned Arcane Shot ID")
    expect(classify_id(49050), "VALID_BRIDGE_GAP", "pinned Aimed Shot ID")
    expect(classify_id(49052), "VALID_BRIDGE_GAP", "pinned Steady Shot ID")
    expect(classify_id(49067), "VALID_BRIDGE_GAP", "pinned Explosive Trap ID")
    expect(classify_id(49284), "VALID_BRIDGE_GAP", "pinned Earth Shield ID")
    expect(classify_id(2894), "VALID_BRIDGE_GAP", "pinned Fire Elemental Totem ID")
    expect(classify_id(57722), "VALID_BRIDGE_GAP", "pinned Totem of Wrath ID")
    expect(classify_id(48782), "VALID_RANK_ALIAS", "pinned Holy Light top rank")
    expect(classify_id(48785), "VALID_RANK_ALIAS", "pinned Flash of Light rank 8")
    expect(classify_id(48826), "VALID_RANK_ALIAS", "pinned Avenger's Shield rank")
    expect(classify_id(48999), "INVALID", "disproven Counterattack (not Avenger's Shield)")
    expect(classify_id(44459), "INVALID", "disproven Living Bomb alias")
    expect(classify_id(99999), "INVALID", "negative unknown ID")

    local result = scan_content and scan_content('define("Probe", { 61411, 27011, 48782, 48999, 44459, 99999 }, "Probe")')
    expect(result and #result.hits, 3, "negative scan hit count")
    expect(result.hits[1].id, 48999, "disproven Counterattack scan ID")
    expect(result.hits[2].id, 44459, "disproven alias scan ID")
    expect(result.hits[3].id, 99999, "negative scan ID")
    expect(result and #result.unverified, 0, "unverified aliases all resolved")

    -- Rank-top enforcement: a multi-ID ladder's top-of-list ID must be a pinned max rank.
    expect(is_max_rank(47813), true, "pinned max rank (warlock Corruption)")
    expect(is_max_rank(42842), true, "bridge max rank (mage Frostbolt)")
    expect(is_max_rank(27216), false, "stale TBC rank is not a max (Corruption 27216)")
    expect(is_max_rank(27072), false, "stale TBC rank is not a max (Frostbolt 27072)")
    local clean_ladder = scan_content('define("Probe", { 42842, 27072, 10175 }, "Probe")')
    expect(clean_ladder and #clean_ladder.hits, 0, "clean max-first ladder")
    local stale_ladder = scan_content('define("Probe", { 27072, 27071, 10175 }, "Probe")')
    expect(stale_ladder and #stale_ladder.hits, 1, "stale ladder top flagged")
    expect(stale_ladder.hits[1].kind, "STALE_TOP", "stale top kind")
    expect(stale_ladder.hits[1].id, 27072, "stale top id")

    expect(map_count(WOTLK_REFERENCE_ALIASES), 129, "pinned allowlist size")
    expect(map_count(WOTLK_BRIDGE_MAX_RANKS), 93, "bridge max rank count")
    expect(map_count(WOTLK_SHARED_IDS), 117, "shared pin count")
    expect(map_count(WOTLK_UNVERIFIED_ALIASES), 0, "unverified alias size")
    expect(WOTLK_REJECTED_IDS[48999], true, "disproven Counterattack ID rejected")
    expect(WOTLK_REFERENCE_ALIASES[44459], nil, "disproven ID absent from allowlist")
    expect(#WOTLK_FILES, 41, "WotLK inventory size")
    local seen = {}
    for _, file in ipairs(WOTLK_FILES) do
        expect(seen[file], nil, "duplicate inventory entry")
        seen[file] = true
    end

    -- Shared-module ladder scan: talent signature heads (first) + pet ladder
    -- tails (last) must all be pinned WotLK max ranks, and EVERY ID in every
    -- shared ladder (mid-list and single-ID included) must be bridge-known or
    -- pinned, so typo'd pet ranks can never pass silently.
    expect(#WOTLK_SHARED_LADDERS, 2, "shared ladder inventory size")
    local ti = read_file("EaxRotations/shared/talent_inference_sylvanas.lua")
    expect(ti ~= nil, true, "talent_inference file readable")
    local pm = read_file("EaxRotations/shared/pet_manager_sylvanas.lua")
    expect(pm ~= nil, true, "pet_manager file readable")
    expect(#scan_shared_ladders(ti, "talent_ids", "first"), 0, "talent_inference ids all pinned")
    expect(#scan_shared_ladders(pm, "numeric_local", "last"), 0, "pet_manager ids all pinned")
    -- extraction sanity: pet manager has 25 ladders (16 multi + 9 single),
    -- talent_inference has 40 (18 multi + 22 single-ID signatures)
    expect(#extract_shared_ladders(pm, "numeric_local", "last"), 25, "pet_manager ladder count")
    expect(#extract_shared_ladders(ti, "talent_ids", "first"), 40, "talent_inference ladder count")
    -- negative probe 1: unpinned shared HEAD (stale tail) must be flagged STALE_TOP
    local stale_shared = scan_shared_ladders('local FOO = { 2649, 14268, 14925 }', "numeric_local", "last")
    expect(#stale_shared, 2, "stale pet tail + unpinned mid flagged")
    expect(stale_shared[1].kind, "STALE_TOP", "stale pet tail kind")
    -- negative probe 2: a mid-list typo (14261 Raptor Strike in a Claw-style
    -- ladder) must be flagged UNPINNED_SHARED_ID even when the head is pinned
    local typo_shared = scan_shared_ladders('local FOO = { 14261, 14262, 27049 }', "numeric_local", "last")
    expect(#typo_shared, 2, "mid-list typo flagged twice (14261 + 14262)")
    local saw_unpinned = false
    for _, hit in ipairs(typo_shared) do
        if hit.kind == "UNPINNED_SHARED_ID" then saw_unpinned = true end
    end
    expect(saw_unpinned, true, "mid-list typo flagged as UNPINNED_SHARED_ID")
    -- negative probe 3: a single-ID ladder with an unpinned ID must be flagged
    local single_shared = scan_shared_ladders('local FOO = { 99999 }', "numeric_local", "last")
    expect(#single_shared, 1, "single-ID unpinned flagged")
    expect(single_shared[1].kind, "UNPINNED_SHARED_ID", "single-ID unpinned kind")
    -- positive probe: all-pinned ladder scans clean
    local clean_shared = scan_shared_ladders('local FOO = { 2649, 14916, 27047 }', "numeric_local", "last")
    expect(#clean_shared, 0, "all-pinned shared ladder clean")
    print("[PASS] WotLK audit self-tests: malformed input, pinned allowlist, rank-top enforcement, shared-ladder id validation, unverified aliases resolved, negative IDs, 41-file inventory")
end

local function run_invalid_probe()
    local result = scan_content('define("InvalidProbe", { 44459, 99999 }, "InvalidProbe")')
    if result.error or not result.found then
        print("[ERROR] invalid-ID probe did not produce a rejection")
        os.exit(2)
    end
    print("[FAIL] invalid-ID probe rejected as expected")
    os.exit(1)
end

local function run_stale_top_probe()
    local result = scan_content('define("StaleTopProbe", { 27072, 27071, 10175 }, "StaleTopProbe")')
    local saw_stale = false
    for _, hit in ipairs(result.hits or {}) do
        if hit.kind == "STALE_TOP" then saw_stale = true end
    end
    if not saw_stale then
        print("[ERROR] stale-top probe did not flag a TBC-era ladder top")
        os.exit(2)
    end
    print("[FAIL] stale-top probe rejected as expected: id 27072 [STALE_TOP]")
    os.exit(1)
end

local function run_missing_probe()
    local result = scan_file("__missing_wotlk_audit_fixture__.lua")
    if not result.skipped then
        print("[ERROR] missing-file probe did not report skipped input")
        os.exit(2)
    end
    print("[FAIL] missing-file probe rejected as expected")
    os.exit(1)
end

local function run_unverified_probe()
    -- 48782 was promoted from UNVERIFIED to a pinned VALID_RANK_ALIAS; the
    -- probe now asserts that resolution: zero unverified aliases are reported.
    local result = scan_content('define("UnverifiedProbe", { 48782 }, "UnverifiedProbe")')
    if result.error or (#result.unverified ~= 0) then
        print("[ERROR] unverified-alias probe observed unresolved aliases (expected 0 after promotion)")
        os.exit(2)
    end
    print("[FAIL] unverified-alias probe rejected as expected: id 48782 resolved to VALID_RANK_ALIAS, 0 unverified")
    os.exit(1)
end

local function run_malformed_probe()
    local result = scan_content(nil)
    if result.error ~= "content must be a string" then
        print("[ERROR] malformed probe was not controlled")
        os.exit(2)
    end
    print("[PASS] malformed probe returned a controlled error")
    os.exit(0)
end

if arg and arg[1] == "--self-test" then
    run_self_tests()
    os.exit(0)
elseif arg and arg[1] == "--probe-invalid" then
    run_invalid_probe()
elseif arg and arg[1] == "--probe-stale-top" then
    run_stale_top_probe()
elseif arg and arg[1] == "--probe-missing" then
    run_missing_probe()
elseif arg and arg[1] == "--probe-unverified" then
    run_unverified_probe()
elseif arg and arg[1] == "--probe-malformed" then
    run_malformed_probe()
end

print("=============================================================================")
print("  WOTLK SPELL ID AUDIT (bridge + pinned semantic aliases)")
print("  Reference: wowsims/wotlk@" .. WOTLK_REFERENCE_SHA)
print("  Bridge: " .. tostring(require("shared/wowhead_data_bridge_spell_index_wotlk_sylvanas").spell_index_wotlk and "loaded" or "missing"))
print("=============================================================================")
print("")

local total, skipped, passed, failed, unverified_total = 0, 0, 0, 0, 0
local failures = {}

for _, file in ipairs(WOTLK_FILES) do
    local path = root .. "/" .. file
    total = total + 1

    local result = scan_file(path)
    if result.skipped then
        skipped = skipped + 1
    elseif result.error then
        failed = failed + 1
        failures[#failures + 1] = { file = file, error = result.error }
        print(string.format("  [ ERROR ] %-50s %s", file, result.error))
    elseif result.found then
        failed = failed + 1
        failures[#failures + 1] = { file = file, hits = result.hits }
        print(string.format("  [ FAIL ]  %-50s %d invalid ID(s)", file, #result.hits))
        for _, hit in ipairs(result.hits) do
            print(string.format("            line %4d: id %d [%s]  %s",
                hit.line, hit.id, hit.kind, hit.snippet))
        end
    else
        passed = passed + 1
        print(string.format("  [ PASS ]  %-50s clean", file))
    end
    if result.unverified and #result.unverified > 0 then
        unverified_total = unverified_total + #result.unverified
        print(string.format("  [ WARN ]  %-50s %d unverified alias(es)", file, #result.unverified))
        for _, hit in ipairs(result.unverified) do
            print(string.format("            line %4d: id %d [%s]  %s",
                hit.line, hit.id, hit.kind, hit.snippet))
        end
    end
end

-- Shared-module ladder scan: talent signature heads + pet ladder tails.
for _, spec in ipairs(WOTLK_SHARED_LADDERS) do
    local path = root .. "/" .. spec.file
    total = total + 1
    local content = read_file(path)
    if not content then
        skipped = skipped + 1
        print(string.format("  [ SKIP ]  %-50s file not present", spec.file))
    else
        local hits = scan_shared_ladders(content, spec.mode, spec.head)
        if #hits > 0 then
            failed = failed + 1
            failures[#failures + 1] = { file = spec.file, hits = hits }
            print(string.format("  [ FAIL ]  %-50s %d stale shared-ladder top(s)", spec.file, #hits))
            for _, hit in ipairs(hits) do
                print(string.format("            line %4d: id %d [%s]  %s",
                    hit.line, hit.id, hit.kind, hit.snippet))
            end
        else
            passed = passed + 1
            print(string.format("  [ PASS ]  %-50s shared ladders clean", spec.file))
        end
    end
end

print("")
print("=============================================================================")
print("  WOTLK SPELL AUDIT RESULTS")
print("=============================================================================")
print(string.format("  Total:     %3d wotlk files", total))
print(string.format("  Skipped:   %3d (file not present)", skipped))
print(string.format("  Clean:     %3d", passed))
print(string.format("  Invalid:   %3d", failed))
print(string.format("  Unverified:%3d IDs (reported separately; not allowlisted)", unverified_total))
print("")

if failed > 0 or skipped > 0 then
    print("  Invalid spell IDs found in wotlk files:")
    for _, f in ipairs(failures) do
        if f.error then
            print("    " .. f.file .. "  ERROR: " .. f.error)
        else
            for _, hit in ipairs(f.hits) do
                print(string.format("    %s  line %d: id %d [%s]",
                    f.file, hit.line, hit.id, hit.kind))
            end
        end
    end
    print("")
    print("  ID 'TBC_ID_IN_WOTLK' means the ID exists in TBC data but not WotLK.")
    print("  ID 'VANILLA_ID_IN_WOTLK' means the ID exists in Vanilla data but not WotLK.")
    print("  ID 'STALE_TOP' means a multi-ID define ladder's top-of-list ID is not a pinned WotLK max rank.")
    print("  VALID_RANK_ALIAS, VALID_AURA_ALIAS, and VALID_BRIDGE_GAP IDs are accepted only from the pinned reference table.")
    print("  UNVERIFIED_ALIAS IDs are reported separately and are not part of the valid allowlist.")
    print("  ID 'INVALID' means no WotLK bridge or pinned alias classification exists.")
    os.exit(1)
end

print("  All 41 WotLK files + 2 shared-module ladder sets accounted for; unknown IDs")
print("  and unpinned shared ladder heads/tails are the only audit failures.")
os.exit(0)
