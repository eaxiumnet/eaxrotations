# Total Healing Playbook

All TBC healing playstyles in one implementation-oriented matrix.

| Spec | Healing identity | Single-target plan | Multi-target plan | Dispel/utility |
|---|---|---|---|---|
| Restoration Druid | HoT/rolling tank and mobile raid support | Lifebloom stack, Rejuvenation, Regrowth, Swiftmend/NS | Pre-HoT before damage; avoid blooming unless burst healing is needed | Remove Curse, Abolish Poison |
| Holy Paladin | Efficient single-target/tank healer | Flash of Light, Holy Light ranks, Holy Shock, Divine Favor | Maintain Light's Grace for heavy periods; Cleanse can outrank filler | Cleanse magic/poison/disease |
| Discipline Priest | Mitigation/utility healer | PW:S with rage caveat, Flash/Greater Heal, Pain Suppression, Power Infusion | Shield only when Weakened Soul and rage concerns allow | Dispel Magic, Abolish Disease |
| Holy Priest | Flexible tank/raid healer | Greater Heal, Flash Heal, Renew, Prayer of Healing, Circle of Healing if talented | Downrank and cancel-cast; use group heals by injured-count | Dispel Magic, Abolish Disease |
| Restoration Shaman | Chain Heal raid healer | Earth Shield, Chain Heal, Healing Wave, Lesser Healing Wave, Nature's Swiftness | Bounce planning and Mana Tide timing are core | Poison/Disease cleansing totems and direct cures |

## Healing Priority Ladder

1. Prevent immediate lethal damage on assigned tank or objective carrier.
2. Remove lethal debuff if dispel is faster than healing through it.
3. Use emergency cooldown if the next boss swing/global would kill.
4. Use efficient planned heal/rank for predictable damage.
5. Use group/raid heal only when enough targets benefit.
6. Conserve, drink, or mana restore before the next scripted spike.

## Downrank/Overheal Rules

- Downrank when the target is not in lethal range and the lower rank lands before the next damage event.
- Cancel-cast if incoming damage does not happen and no other target needs that heal.
- Do not downrank emergency saves.
- Add incoming-damage prediction when local API support is reliable.
