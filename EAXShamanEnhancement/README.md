# EAX Shaman Enhancement

Enhancement Shaman melee rotation centered on Stormstrike, Shock maintenance, totem twists, and dual-wield friendly weaves.

## Rotation

- **Primary Attack** – Stormstrike is always the first cast once the target is within 5 yards; all other decisions defer until it is off cooldown.
- **Shock Priority** – The `Shock Mode` combo keeps Earth / Flame / Frost Shock up depending on player preference; the addon only refreshes a shock when it is missing.
- **Chain Lightning Weaves** – Chain Lightning is allowed between melee swings when the swing clip window stretches beyond the `Swing Clip (ms)` slider and mana remains above the profile floor.
- **Shamanistic Rage** – Rage fires when health or mana drops below the configured sliders so the melee window has instant survivability.
- **Totem Twisting** – Auto Totems keeps Totem of Wrath + Windfury rotating for maximum weapon proc uptime.

## Modes

- **Auto** – Detects party size to flip between the solo/dungeon/raid defaults.
- **Solo** – Low mana floor (5%), aggressive swing clip, minimal AoE gating for open-world grinding.
- **Dungeon** – Higher mana floor (10%), Chain Lightning only when at least three enemies are present, and longer swing clip buffering.
- **Raid** – The tightest Chain Lightning gating, the highest mana floor (15%), and dual-wield focus to stay on the main target.

## Install

1. Install `EAXShamanEnhancement` inside `scripts/`.
2. Reload Sylvanas or restart the client.
3. Enable the addon in the menu and choose the desired Mode (Auto / Solo / Dungeon / Raid).

## Use

- Toggle `Use Chain Lightning Weave` to force weaves between swings; adjust `Swing Clip (ms)` to match your ping.
- `Shock Mode` selects the Shock spell the addon should keep refreshed on the target.
- Totem toggles keep Wrath and Windfury totems active so Stormstrike keeps benefiting from weapon procs.
- Use the rage sliders to have Shamanistic Rage fire only when you need the defensive / mana regen boost.

## Notes

- The addon resolves Stormstrike, Chain Lightning, all three Shocks, and Shamanistic Rage at load.
- Mode defaults are combined with manual slider adjustments so you can fine-tune AoE thresholds.
