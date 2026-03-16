# EAX Warrior Protection

EAX Warrior Protection is a compact TBC Protection Warrior plugin for Project Sylvanas with a dungeon-first tank profile. It keeps Defensive Stance as the combat home stance and preserves the core single-target order of Shield Slam -> Revenge -> Devastate -> Sunder fallback -> Execute, with Thunder Clap leading the AoE lane.

Mode now matters. `Solo` keeps the more flexible opener and burst behavior, but runs rotation-first after interrupts and true emergency survivals so the core rotation stays dominant. Automatic recovery in `Solo` is interrupts-only. `Dungeon` and `Raid` shift the profile toward tank safety, conservative burst, and off-target recovery, with mitigation earlier in the flow once melee auto attack is established. `Auto` resolves from group size. Shout upkeep respects the Battle Shout and Commanding Shout checkboxes honestly, combat Bloodrage and pre-pull Bloodrage are separate paths, `show_notifications` drives high-signal on-screen notifications, and the manual Intimidating Shout keybind remains available.

The tanking tree adds conservative recovery tools: Shield Bash, Taunt, Concussion Blow, Mocking Blow, Challenging Shout, and optional peel Intercept. In `Solo`, only the interrupt side of that toolkit stays automatic. In `Dungeon` and `Raid`, Auto-peel never changes the player's HUD target; it works with internal object targets and only takes over when a recovery target is clearly more dangerous than the current kill target. Challenging Shout and peel Intercept stay conservative by default.

Optional utility controls include Demo Shout, direct-cast Rend, Sunder Armor fallback when Devastate is not being honored, solo-only Hamstring filler, and solo-only automatic Intercept that temporarily swaps out of Defensive Stance, performs the queued action, then returns home on the next update. Shield Block and Ironshield Potion stay conservative in `Solo`: they are held for emergency, elite, or real heavy-pressure windows instead of consuming the opener on normal pulls. In dungeon and raid modes, Death Wish and Recklessness are suppressed automatically, while Blood Fury, Berserking, and ready self-cast trinkets only open on safe burst windows.

The control panel is intentionally minimal and only exposes the master enable toggle. Detailed behavior stays in the main plugin menu.

Current repo folder: `EAXProtection`  
Plugin name in-game: `EAX Warrior Protection`
