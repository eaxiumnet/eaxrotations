# EAX Priest Shadow

Shadow Priest automation that keeps Vampiric Touch / Shadow Word: Pain rolling, bursts Mind Blast when the DoTs are stable or about to expire, and uses Mind Flay as a filler.

## Highlights

- **DoT stewardship:** The `DoT Refresh Window` ensures Vampiric Touch and Shadow Word: Pain are refreshed before their ticks fall off.
- **Mind Blast timing:** The addon waits for the DoTs to be up but will burst with `Mind Blast Burst` when they are close to expiring.
- **Mind Flay fill-in:** When Mind Blast is not available the addon queues Mind Flay on the current target.
- **Shadowfiend and Shadowform:** Automatically maintains Shadowform and fires Shadowfiend on cooldown for mana regen.
- **Modes:** Auto, Solo, Dungeon, and Raid modes adjust behavior to match group size.

## Menu Options

- `Enabled` / `Debug Logging`
- `Mode` — Auto, Solo, Dungeon, or Raid.
- `DoT Refresh Window`, `Mind Blast Burst`, and `Burst Window`
- `Shadowfiend` toggle and cooldown setting
- `Keep Shadowform` toggle

## Usage

1. Adjust the DoT window and burst window until Mind Blast aligns with your preferred timing.
2. Leave `Shadowfiend` enabled for automatic mana return when the cooldown expires.
3. The addon will maintain DoTs, refresh Shadowform, and queue Mind Flay between Mind Blast casts.
