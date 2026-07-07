# Holy Paladin — Light's Grace Chaining + Configurable HL Threshold

## Goal
Close the gap vs Holy Paladin on two advertised features:
1. **Light's Grace chaining** — refresh the 0.5s haste buff before it expires with a cheap HL R4
2. **Configurable Holy Light HP threshold** — expose the hardcoded 70% as a user setting

## Scope
- `EaxRotations/classes/paladin/holy_sylvanas.lua`
- `EaxRotations/classes/paladin/schema_sylvanas.lua`
- `EaxRotations/tests/test_paladin_holy_custom_matches.lua`

## Changes

### 1. State tracking
- Add `lights_grace_remains` to `state` table
- Populate it in `build_state()` via `NS.buff_remains(me, BUFF_LIGHTS_GRACE)`

### 2. Configurable HL threshold
- Replace hardcoded `70` in `choose_smart_heal()` with `safe_setting(context, "holy_light_hp", 70)`
- Preserve +10 LG bonus: `hl_hp_threshold = has_lights_grace and (base + 10) or base`

### 3. Light's Grace chaining strategy
- Insert after `DivineFavorHolyLightFollowup`, before `BlessingOfSacrificeTank`
- Matches when: LG active + <3s remains + in combat + valid target HP <= 95% + no emergency (lowest > 40%)
- Casts: HolyLightRank4 on heal_target (cheap refresh)
- Gated by `holy_lights_grace_chaining` setting (default true)

### 4. Schema additions
- `holy_light_hp`: slider 40-100, default 70
- `holy_lights_grace_chaining`: checkbox, default true

### 5. Tests
- Add `LightsGraceChaining` match tests
- Update mock to include `buff_remains`

## Validation
- [ ] `luac -p EaxRotations/classes/paladin/holy_sylvanas.lua`
- [ ] `luac -p EaxRotations/tests/test_paladin_holy_custom_matches.lua`
- [ ] `lua EaxRotations/tests/run_rotation_tests.lua`
