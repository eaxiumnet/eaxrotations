# EAX Real-World Validation Strategy

**Document**: EAX-REALWORLD-VALIDATION-v1.0  
**Date**: April 10, 2026  
**Status**: Gap 5 Fix - Real-World Validation Planning  
**Scope**: Beyond unit/integration testing - practical in-game validation

---

## Executive Summary

This document defines a practical, real-world validation strategy for EAX rotation improvements. While unit tests verify logic correctness and integration tests validate component interactions, **real-world validation** confirms that EAX recommendations produce actual DPS results matching wowsims predictions in live gameplay.

**Key Principle**: *"The only true validation is when a player using EAX achieves within 5% of their wowsims-simulated DPS on a real boss encounter."*

---

## Part 1: Three Real-World Validation Methods

### Method A: Recount/Skada Log Comparison

**Concept**: Parse EAX output logs alongside in-game damage meters (Recount/Skada) to compare recommended ability usage vs actual ability usage.

#### Implementation

```lua
-- EAX Validation Logger (add to main.lua)
local validation_logger = {
    enabled = false,
    session_id = nil,
    ability_log = {},
    start_time = 0,
}

function validation_logger.start_session(encounter_name)
    validation_logger.session_id = string.format("%s_%d", encounter_name, os.time())
    validation_logger.start_time = _core_time()
    validation_logger.ability_log = {}
    validation_logger.enabled = true
    core.log(string.format("[EAX-VALIDATION] Session started: %s", validation_logger.session_id))
end

function validation_logger.log_ability(spell_id, spell_name, target_hp, player_resource)
    if not validation_logger.enabled then return end
    
    table.insert(validation_logger.ability_log, {
        timestamp = _core_time() - validation_logger.start_time,
        spell_id = spell_id,
        spell_name = spell_name,
        target_hp_pct = target_hp,
        resource = player_resource,
        recommendation = true,  -- This was an EAX recommendation
    })
end

function validation_logger.export_session()
    if not validation_logger.enabled then return nil end
    
    local export = {
        session_id = validation_logger.session_id,
        duration = _core_time() - validation_logger.start_time,
        abilities = validation_logger.ability_log,
        -- Summary statistics
        ability_counts = {},
        timing_variance = {},
    }
    
    -- Count abilities
    for _, entry in ipairs(validation_logger.ability_log) do
        export.ability_counts[entry.spell_name] = (export.ability_counts[entry.spell_name] or 0) + 1
    end
    
    return export
end
```

#### Comparison Process

1. **Player enables EAX validation mode** before encounter
2. **EAX logs every recommendation** with timestamp and context
3. **Player runs encounter** with Recount/Skada recording
4. **Post-encounter export** generates JSON log file
5. **Comparison script** parses both EAX log and Recount data:

```python
# validation/compare_logs.py
import json
from dataclasses import dataclass
from typing import List, Dict, Tuple

@dataclass
class AbilityComparison:
    spell_name: str
    eax_count: int
    actual_count: int
    variance_pct: float
    timing_accuracy: float  # % of casts within 0.5s of recommendation
    
def compare_logs(eax_log_path: str, recount_export_path: str) -> List[AbilityComparison]:
    """Compare EAX recommendations vs actual in-game casts"""
    
    with open(eax_log_path) as f:
        eax_data = json.load(f)
    
    # Parse Recount/Skada export (CSV or JSON format)
    recount_data = parse_recount_export(recount_export_path)
    
    comparisons = []
    all_spells = set(eax_data['ability_counts'].keys()) | set(recount_data.keys())
    
    for spell in all_spells:
        eax_count = eax_data['ability_counts'].get(spell, 0)
        actual_count = recount_data.get(spell, 0)
        
        variance = abs(eax_count - actual_count) / max(eax_count, 1) * 100
        
        comparisons.append(AbilityComparison(
            spell_name=spell,
            eax_count=eax_count,
            actual_count=actual_count,
            variance_pct=variance,
            timing_accuracy=calculate_timing_accuracy(eax_data, recount_data, spell)
        ))
    
    return comparisons
```

#### Feasibility Assessment

| Aspect | Rating | Details |
|--------|--------|---------|
| **Implementation Effort** | ⭐⭐⭐ Low | ~2 days to add logging, ~3 days for comparison tool |
| **Player Burden** | ⭐⭐⭐ Low | Just enable mode, normal gameplay |
| **Accuracy** | ⭐⭐⭐⭐ High | Direct comparison of ability counts |
| **Scalability** | ⭐⭐⭐⭐⭐ High | Can run on every encounter |
| **Automation Potential** | ⭐⭐⭐⭐ High | Can be fully automated post-encounter |

**Pros**:
- Non-intrusive to gameplay
- High volume of data possible
- Direct ability-to-ability comparison
- Can detect systematic rotation drift

**Cons**:
- Requires manual log export from Recount/Skada
- Doesn't capture *why* deviations occurred (lag, movement, player error)
- Limited to ability counts, not timing precision

**Feasibility Score**: **8.5/10** - Highly feasible, should be primary validation method

---

### Method B: Video Analysis

**Concept**: Record gameplay footage and compare EAX on-screen recommendations with actual player actions and ability usage timing.

#### Implementation

**Recording Setup**:
```lua
-- EAX Video Sync Marker (add to main.lua)
local video_sync = {
    enabled = false,
    marker_count = 0,
}

function video_sync.mark_recommendation(spell_id, spell_name)
    if not video_sync.enabled then return end
    
    video_sync.marker_count = video_sync.marker_count + 1
    
    -- Visual flash on EAX UI when recommendation changes
    if core.graphics then
        core.graphics.draw_rect(
            10, 10, 50, 50,  -- Top-left corner marker
            {r=255, g=0, b=0, a=200},  -- Red flash
            3  -- 3 frames
        )
    end
    
    -- Audio beep (if enabled)
    if menu.validation_audio and menu.validation_audio:get() then
        core.play_sound("INTERFACE\\UI_TRAINER_STEP_NOISE.wav")
    end
    
    -- Log for post-sync
    validation_logger.log_ability(spell_id, spell_name, 
        get_target_hp_pct(), get_player_resource())
end
```

**Analysis Process**:

1. **Player records encounter** with OBS/ShadowPlay (60fps minimum)
2. **EAX validation mode** adds visual markers for recommendations
3. **Post-processing script** analyzes video frames:

```python
# validation/video_analyzer.py
import cv2
import numpy as np
from dataclasses import dataclass
from typing import List, Optional
import pytesseract  # OCR for reading ability names

@dataclass
class VideoEvent:
    frame_number: int
    timestamp_ms: float
    event_type: str  # 'eax_recommendation', 'player_cast', 'gcd_start', 'gcd_end'
    ability_name: Optional[str] = None
    confidence: float = 0.0

class EAXVideoAnalyzer:
    def __init__(self, video_path: str, eax_log_path: str):
        self.video = cv2.VideoCapture(video_path)
        self.fps = self.video.get(cv2.CAP_PROP_FPS)
        self.eax_log = self.load_eax_log(eax_log_path)
        
    def detect_eax_markers(self, frame) -> bool:
        """Detect red flash marker in top-left corner"""
        roi = frame[10:60, 10:60]  # Top-left 50x50 region
        red_mask = (roi[:,:,2] > 200) & (roi[:,:,1] < 100) & (roi[:,:,0] < 100)
        return np.sum(red_mask) > 500  # Significant red area
    
    def detect_ability_cast(self, frame) -> Optional[str]:
        """OCR on action bar to detect what ability was cast"""
        # Extract action bar region (customize per player UI)
        action_bar = frame[800:850, 400:800]  # Example coordinates
        
        # Preprocess for OCR
        gray = cv2.cvtColor(action_bar, cv2.COLOR_BGR2GRAY)
        _, thresh = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)
        
        # OCR
        text = pytesseract.image_to_string(thresh)
        return self.parse_ability_name(text)
    
    def analyze(self) -> List[VideoEvent]:
        """Full video analysis"""
        events = []
        frame_num = 0
        
        while True:
            ret, frame = self.video.read()
            if not ret:
                break
            
            timestamp_ms = frame_num / self.fps * 1000
            
            # Check for EAX recommendation marker
            if self.detect_eax_markers(frame):
                events.append(VideoEvent(
                    frame_number=frame_num,
                    timestamp_ms=timestamp_ms,
                    event_type='eax_recommendation'
                ))
            
            # Check for player cast (GCD animation, ability icon flash)
            ability = self.detect_ability_cast(frame)
            if ability:
                events.append(VideoEvent(
                    frame_number=frame_num,
                    timestamp_ms=timestamp_ms,
                    event_type='player_cast',
                    ability_name=ability,
                    confidence=0.85
                ))
            
            frame_num += 1
        
        return events
    
    def calculate_timing_accuracy(self, events: List[VideoEvent]) -> dict:
        """Calculate timing accuracy between EAX recommendation and player cast"""
        eax_events = [e for e in events if e.event_type == 'eax_recommendation']
        cast_events = [e for e in events if e.event_type == 'player_cast']
        
        timing_diffs = []
        for eax in eax_events:
            # Find nearest cast event within 2 seconds
            nearest_cast = None
            min_diff = float('inf')
            
            for cast in cast_events:
                diff = abs(cast.timestamp_ms - eax.timestamp_ms)
                if diff < 2000 and diff < min_diff:
                    min_diff = diff
                    nearest_cast = cast
            
            if nearest_cast:
                timing_diffs.append(min_diff)
        
        return {
            'avg_delay_ms': np.mean(timing_diffs) if timing_diffs else 0,
            'max_delay_ms': np.max(timing_diffs) if timing_diffs else 0,
            'within_500ms_pct': sum(1 for d in timing_diffs if d <= 500) / len(timing_diffs) * 100,
            'within_1s_pct': sum(1 for d in timing_diffs if d <= 1000) / len(timing_diffs) * 100,
        }
```

#### Feasibility Assessment

| Aspect | Rating | Details |
|--------|--------|---------|
| **Implementation Effort** | ⭐⭐⭐⭐ Medium-High | ~5 days for video analysis pipeline |
| **Player Burden** | ⭐⭐⭐⭐ Medium | Must record gameplay, upload videos |
| **Accuracy** | ⭐⭐⭐⭐⭐ Very High | Frame-by-frame timing analysis |
| **Scalability** | ⭐⭐ Low | Manual video processing bottleneck |
| **Automation Potential** | ⭐⭐⭐ Medium | Semi-automated with OCR |

**Pros**:
- Captures actual player reaction time
- Detects UI/UX issues (player didn't see recommendation)
- Validates timing precision (not just counts)
- Can detect lag, movement, and environmental factors

**Cons**:
- High overhead for players
- Video processing is compute-intensive
- Requires consistent UI layout for OCR
- Limited sample size (can't run on every pull)

**Feasibility Score**: **6.5/10** - Useful for deep-dive analysis, not for routine validation

---

### Method C: Warcraft Logs (WCL) Cross-Reference

**Concept**: Compare EAX-simulated DPS against actual Warcraft Logs reports from players using EAX.

#### Implementation

**WCL Integration Architecture**:

```lua
-- EAX WCL Reporter (libraries/wcl_reporter.lua)
local wcl_reporter = {
    api_key = nil,  -- Set from menu
    report_cache = {},
}

-- Build encounter payload for WCL comparison
function wcl_reporter.build_payload(encounter_name, duration, ability_log)
    local payload = {
        encounter = encounter_name,
        duration_seconds = duration,
        client = "EAX",
        version = GetAddOnMetadata("EAXCore", "Version"),
        spec = GetSpecializationInfo(),
        gear_ilvl = GetAverageItemLevel(),
        
        -- Ability breakdown
        abilities = {},
        
        -- Buff/debuff uptime
        buffs = {},
        debuffs = {},
        
        -- Resource metrics
        resource_waste = {},
    }
    
    -- Summarize ability log
    for _, entry in ipairs(ability_log) do
        local name = entry.spell_name
        payload.abilities[name] = payload.abilities[name] or {
            count = 0,
            total_damage = 0,
            crit_count = 0,
        }
        payload.abilities[name].count = payload.abilities[name].count + 1
    end
    
    return payload
end

-- Compare against WCL report
function wcl_reporter.compare_with_wcl(eax_payload, wcl_report_id)
    -- This would call WCL API (requires API key)
    -- For now, manual comparison via web interface
    core.log("[EAX-WCL] Please compare manually at:")
    core.log(string.format("https://classic.warcraftlogs.com/reports/%s", wcl_report_id))
end
```

**WCL Data Extraction** (Python backend):

```python
# validation/wcl_analyzer.py
import requests
from dataclasses import dataclass
from typing import Dict, List, Optional
import json

WCL_API_URL = "https://classic.warcraftlogs.com/api/v2"

@dataclass
class WCLEncounterData:
    encounter_name: str
    duration_ms: int
    player_name: str
    spec: str
    total_damage: int
    dps: float
    ability_breakdown: Dict[str, dict]  # spell_name -> {casts, hits, crits, damage}
    buff_uptime: Dict[str, float]  # buff_name -> pct
    
class WCLAnalyzer:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json"
        }
    
    def get_report(self, report_id: str) -> dict:
        """Fetch report metadata from WCL"""
        query = """
        query {
            reportData {
                report(code: "%s") {
                    fights {
                        id
                        name
                        startTime
                        endTime
                    }
                }
            }
        }
        """ % report_id
        
        response = requests.post(
            WCL_API_URL,
            headers=self.headers,
            json={"query": query}
        )
        return response.json()
    
    def get_player_performance(
        self, 
        report_id: str, 
        fight_id: int, 
        player_name: str
    ) -> WCLEncounterData:
        """Extract player performance data from specific fight"""
        
        query = """
        query {
            reportData {
                report(code: "%s") {
                    table(
                        fightIDs: [%d],
                        sourceName: "%s"
                    ) {
                        data
                    }
                }
            }
        }
        """ % (report_id, fight_id, player_name)
        
        response = requests.post(
            WCL_API_URL,
            headers=self.headers,
            json={"query": query}
        )
        
        data = response.json()['data']['reportData']['report']['table']['data']
        
        return WCLEncounterData(
            encounter_name=data['fightName'],
            duration_ms=data['totalTime'],
            player_name=player_name,
            spec=data['specName'],
            total_damage=data['totalDamage'],
            dps=data['totalDamage'] / (data['totalTime'] / 1000),
            ability_breakdown=self.parse_abilities(data['entries']),
            buff_uptime=self.parse_buffs(data.get('auras', []))
        )
    
    def compare_with_eax(
        self, 
        wcl_data: WCLEncounterData, 
        eax_simulation: dict
    ) -> dict:
        """Compare WCL actual vs EAX simulation"""
        
        comparison = {
            'dps_variance_pct': abs(wcl_data.dps - eax_simulation['dps']) / eax_simulation['dps'] * 100,
            'ability_variances': {},
            'buff_uptime_variances': {},
            'overall_grade': 'UNKNOWN',
        }
        
        # Grade the comparison
        if comparison['dps_variance_pct'] <= 5:
            comparison['overall_grade'] = 'EXCELLENT'
        elif comparison['dps_variance_pct'] <= 10:
            comparison['overall_grade'] = 'GOOD'
        elif comparison['dps_variance_pct'] <= 15:
            comparison['overall_grade'] = 'ACCEPTABLE'
        else:
            comparison['overall_grade'] = 'NEEDS_IMPROVEMENT'
        
        return comparison
```

#### Feasibility Assessment

| Aspect | Rating | Details |
|--------|--------|---------|
| **Implementation Effort** | ⭐⭐⭐⭐ Medium | ~4 days for WCL API integration |
| **Player Burden** | ⭐⭐⭐⭐⭐ Very Low | Just raid normally, WCL auto-uploads |
| **Accuracy** | ⭐⭐⭐⭐⭐ Very High | Ground truth from actual raid logs |
| **Scalability** | ⭐⭐⭐⭐⭐ Very High | Every WCL report is potential data |
| **Automation Potential** | ⭐⭐⭐⭐⭐ Very High | Fully automated with API key |

**Pros**:
- Uses actual raid data (ground truth)
- No player overhead (WCL already used by most raiders)
- Can aggregate data across hundreds of encounters
- Provides percentile rankings for context

**Cons**:
- Requires WCL API key and authentication
- 15-minute delay on log processing
- Can't isolate EAX impact from other factors (gear, buffs, player skill)
- Limited to encounters that are logged

**Feasibility Score**: **9/10** - Best for large-scale validation, requires API access

---

### Method Comparison Summary

| Method | Effort | Burden | Accuracy | Scale | Auto | Score | Best For |
|--------|--------|--------|----------|-------|------|-------|----------|
| **A: Recount/Skada** | Low | Low | High | High | High | 8.5/10 | Daily validation, drift detection |
| **B: Video Analysis** | High | Medium | Very High | Low | Medium | 6.5/10 | Deep-dive timing analysis |
| **C: WCL Cross-Ref** | Medium | Very Low | Very High | Very High | Very High | 9/10 | Large-scale accuracy validation |

**Recommendation**: Use **Method A** for development iteration, **Method C** for release validation, **Method B** for investigating specific issues.

---

## Part 2: Five Reference Encounters

These 5 TBC encounters stress different rotation aspects and provide comprehensive validation coverage.

### Encounter 1: Patchwerk (Naxxramas) - Pure DPS Validation

**Why This Encounter**:
- **No movement** - Standstill DPS check
- **No adds** - Pure single-target rotation
- **No mechanics** - No interruptions to rotation
- **3-minute enrage** - Sustained DPS validation
- **Well-documented** - Extensive wowsims data available

**Rotation Behaviors to Validate**:

| Class | Expected Behavior | Validation Metric |
|-------|-------------------|-------------------|
| **Warrior Fury** | BT > WW > Execute at 20% | BT CPM: 6.0-6.2, Execute CPM: 8.0+ |
| **Mage Fire** | 5-stack Scorch > Fireball spam | Scorch uptime: >98%, Ignite rolling |
| **Rogue Combat** | SnD > 5pt finishers, energy pooling | SnD uptime: >95%, CP efficiency: 4.8 avg |
| **Warlock Affliction** | DoT maintenance > Shadow Bolt filler | DoT uptime: >96%, clipping: <1/min |
| **Hunter BM** | French rotation 5:5:1:1 | Steady:Auto ratio: 5:5:1:1 |

**Success Criteria**:
- DPS within 5% of wowsims prediction for same gear/buffs
- Ability counts within 10% of sim
- No rotation pauses >2 seconds

**WCL Baseline**: Top 10% Patchwerk parses for each spec

---

### Encounter 2: Prince Malchezaar (Karazhan) - Movement & Positioning

**Why This Encounter**:
- **Infernal movement** - Forced repositioning every 30-45s
- **Enfeeble mechanic** - Brief DPS pauses
- **Phase transitions** - 3 distinct phases (100%, 60%, 30%)
- **Shadow Nova** - Ranged positioning requirements
- **Melee unfriendly** - Tests ranged rotation adaptation

**Rotation Behaviors to Validate**:

| Phase | Mechanic | Expected Adaptation |
|-------|----------|---------------------|
| **Phase 1 (100-60%)** | Infernal drops | Pre-move to safe zones, instant casts while moving |
| **Phase 2 (60-30%)** | Enfeeble | Stop DPS for 4s, resume without losing rotation |
| **Phase 3 (30-0%)** | Shadow Nova + Infernals | Max DPS while maintaining safety |

**Class-Specific Validation**:

| Class | Movement Adaptation |
|-------|----------------------|
| **Mage** | Scorch while moving, Fireball when stationary |
| **Warlock** | Instant DoTs while moving, Drain Life if desperate |
| **Hunter** | Arcane Shot while moving, Steady when stationary |
| **Melee** | Position pre-emptively, minimize travel time |

**Success Criteria**:
- DPS loss during movement <15% vs Patchwerk (standstill)
- No deaths to Infernals (positioning awareness)
- Rotation resumes within 1 GCD after Enfeeble ends

---

### Encounter 3: Gruul the Dragonkiller - Execute Phase & Scaling

**Why This Encounter**:
- **Execute phase emphasis** - 20% HP is significant portion
- **Hurtful Strike mechanic** - Threat management for melee
- **Cave-ins** - Random movement requirements
- **Growth stacks** - Increasing tank damage = healer stress
- **Long encounter** - 6-8 minutes tests sustained performance

**Rotation Behaviors to Validate**:

| Mechanic | Validation Focus |
|----------|------------------|
| **Growth (1-30 stacks)** | Maintain rotation under pressure |
| **Cave-in** | Instant reaction, minimal DPS loss |
| **Execute phase (20%)** | Proper CD staging, Execute priority |
| **Hurtful Strike** | Threat management, don't over-aggro |

**Execute Phase Specifics**:

```lua
-- Expected behavior at 20% HP transition
local execute_validation = {
    -- Warrior
    warrior = {
        recklessness_timing = "Within 2s of 20% HP",
        execute_priority = "Execute > BT > WW",
        rage_efficiency = "No Execute below 30 rage",
    },
    -- Warlock  
    warlock = {
        drain_soul_timing = "At 25% HP, not earlier",
        dot_clipping = "Stop refreshing long DoTs",
    },
    -- Hunter
    hunter = {
        kill_command_priority = "Maintain KC on CD",
        pet_management = "Pet alive throughout execute",
    }
}
```

**Success Criteria**:
- Execute phase DPS +15-20% vs normal phase
- CDs used within 5s of optimal timing
- No threat pulls (melee)

---

### Encounter 4: Magtheridon - Multi-Target & Burst Windows

**Why This Encounter**:
- **4 channelers** - Multi-target/AoE rotation validation
- **Cube clicking** - Brief DPS interruptions
- **Blast Nova** - Burst DPS windows (30s to interrupt)
- **Phase 2 transition** - Target switching
- **Enrage timer** - 20 minutes = sustained performance

**Rotation Behaviors to Validate**:

| Phase | Focus | Expected Behavior |
|-------|-------|-------------------|
| **P1: Channelers** | AoE efficiency | Seed of Corruption (Warlock), Chain Lightning (Shaman), Multi-Shot (Hunter) |
| **Transition** | Target switch | Seamless transition to Magtheridon |
| **P2: Mag** | Single-target | Standard rotation with cube breaks |
| **Blast Nova** | Burst window | Max DPS for 30s, interrupt at last moment |

**AoE Validation Metrics**:

| Class | AoE Ability | Target Threshold | Expected DPS Gain |
|-------|-------------|------------------|-------------------|
| **Warlock** | Seed of Corruption | 3+ targets | +40% vs ST |
| **Mage** | Flamestrike > Blast Wave > AE | 3+ targets | +35% vs ST |
| **Shaman** | Chain Lightning | 3+ targets | +25% vs ST |
| **Hunter** | Multi-Shot | 2+ targets | +15% vs ST |

**Success Criteria**:
- AoE rotation activates within 1 GCD of 3rd target
- Target switching time <2 GCDs
- Blast Nova DPS >120% of normal sustained

---

### Encounter 5: Lady Vashj (Serpentshrine Cavern) - Complex Mechanics

**Why This Encounter**:
- **Phase 1 (Tainted Elementals)** - Target switching, priority targets
- **Phase 2 (Cores)** - Full stop DPS, resource management
- **Phase 3 (Enrage)** - Execute phase, max DPS under pressure
- **Striders/Naga** - Multi-target with priorities
- **Toxic Spores** - Movement while maintaining DPS

**Rotation Behaviors to Validate**:

| Phase | Mechanics | Rotation Challenge |
|-------|-----------|-------------------|
| **P1** | Tainted Elementals, Striders | Priority: Elementals > Striders > Vashj |
| **P2** | Cores, Naga, Striders | Pause DPS for cores, resume efficiently |
| **P3** | Spores, Enrage | Max DPS while dodging spores |

**Complex Validation Points**:

```lua
-- Phase 1 priority validation
local p1_priorities = {
    {target = "Tainted Elemental", priority = 100, ttd_threshold = 5},
    {target = "Coilfang Strider", priority = 80, cc_required = true},
    {target = "Naga", priority = 60},
    {target = "Lady Vashj", priority = 40, only_if_no_adds = true},
}

-- Phase 2 core collection (DPS pause)
local p2_validation = {
    dps_pause_duration = "Until core equipped",
    resource_conservation = "Don't waste CDs during pause",
    resume_efficiency = "Full rotation within 2 GCDs of P3",
}
```

**Success Criteria**:
- Correct target priority 90%+ of the time
- DPS pause during core collection (no wasted CDs)
- Phase 3 DPS within 10% of Patchwerk (despite mechanics)

---

### Reference Encounter Summary

| # | Encounter | Primary Focus | Secondary Focus | Difficulty |
|---|-----------|---------------|-----------------|------------|
| 1 | **Patchwerk** | Pure DPS | Sustained rotation | ⭐⭐ Easy |
| 2 | **Prince** | Movement | Phase transitions | ⭐⭐⭐ Medium |
| 3 | **Gruul** | Execute phase | Threat management | ⭐⭐⭐ Medium |
| 4 | **Magtheridon** | Multi-target | Burst windows | ⭐⭐⭐⭐ Hard |
| 5 | **Lady Vashj** | Complex mechanics | Target priority | ⭐⭐⭐⭐⭐ Very Hard |

**Validation Coverage**:
- Single-target: Patchwerk, Gruul P1, Vashj P3
- Movement: Prince, Vashj
- Execute: Gruul, Vashj P3
- Multi-target: Magtheridon, Vashj P1/P2
- Burst: Magtheridon Blast Nova
- Target switching: All except Patchwerk

---

## Part 3: 2-Week Validation Phase Specification

### Phase Overview

**Duration**: 2 weeks (10 business days)  
**Goal**: Validate that EAX improvements achieve real-world accuracy targets  
**Entry Criteria**: All 29 specs migrated to shared libraries, >60% test coverage  
**Exit Criteria**: DPS variance <5% on 3+ reference encounters per spec

### Week 1: Internal Validation (Days 1-5)

#### Day 1-2: Setup & Baseline

**Tasks**:
1. Deploy validation logging to 3 pilot specs (WarriorFury, MageFire, RogueCombat)
2. Recruit 5 internal testers (1 per pilot spec)
3. Run 10 Patchwerk attempts per spec
4. Establish baseline DPS ranges

**Deliverables**:
- Validation logging confirmed working
- Baseline data: 50 encounters logged
- Initial variance report

**Success Gates**:
- [ ] Logging captures 95%+ of recommendations
- [ ] No crashes or performance issues
- [ ] Baseline DPS within 15% of wowsims (initial tolerance)

#### Day 3-4: Movement & Execute Testing

**Tasks**:
1. Run Prince Malchezaar (10 attempts per spec)
2. Run Gruul (10 attempts per spec)
3. Focus on movement adaptation and execute phase

**Deliverables**:
- Movement DPS loss quantified
- Execute phase accuracy measured
- Issue tracker updated with findings

**Success Gates**:
- [ ] Movement DPS loss <20% vs Patchwerk
- [ ] Execute phase DPS +15% vs normal
- [ ] <5 systematic rotation errors identified

#### Day 5: Analysis & Fixes

**Tasks**:
1. Analyze Week 1 data
2. Identify systematic issues
3. Implement fixes for critical issues
4. Prepare for Week 2

**Deliverables**:
- Week 1 report with findings
- Critical issues fixed
- Week 2 plan updated

---

### Week 2: Community Validation (Days 6-10)

#### Day 6-7: Community Recruitment

**Tasks**:
1. Open validation to 20 community testers
2. Distribute validation-enabled EAX builds
3. Provide validation guide
4. Set up data collection pipeline

**Resources Needed**:
- 20 community testers (4 per pilot spec)
- Discord channel for coordination
- Automated log collection server

**Deliverables**:
- 20 testers onboarded
- Validation builds distributed
- Data pipeline operational

#### Day 8-9: Live Raid Validation

**Tasks**:
1. Testers run all 5 reference encounters
2. Collect logs from 100+ encounters
3. Monitor for critical issues
4. Daily standup to review data

**Target Metrics**:
- 100+ encounters logged
- 5 encounters per tester minimum
- All 5 reference encounters covered

**Deliverables**:
- 100+ validation logs
- Daily variance reports
- Hotfixes for critical issues

#### Day 10: Final Analysis & Go/No-Go

**Tasks**:
1. Aggregate all validation data
2. Calculate final variance metrics
3. Compare against success criteria
4. Make Go/No-Go decision

**Decision Matrix**:

| Metric | Go Criteria | No-Go Triggers |
|--------|-------------|----------------|
| **DPS Variance** | <5% on 3+ encounters | >10% variance on majority |
| **Ability Counts** | Within 15% of wowsims | Systematic under/over-casting |
| **Tester Feedback** | 80%+ positive | >30% report issues |
| **Critical Bugs** | 0 blocking | Any rotation-breaking bug |

**Deliverables**:
- Final validation report
- Go/No-Go decision documented
- Release plan (if Go) or fix plan (if No-Go)

---

### Resource Requirements

#### Personnel (2 weeks)

| Role | Count | Hours/Week | Total Hours | Responsibilities |
|------|-------|------------|-------------|------------------|
| **Validation Lead** | 1 | 40 | 80 | Coordination, analysis, reporting |
| **Dev Support** | 2 | 20 | 80 | Hotfixes, logging improvements |
| **QA Tester** | 3 | 40 | 240 | Internal testing, encounter runs |
| **Community Manager** | 1 | 20 | 40 | Tester recruitment, communication |
| **Community Testers** | 20 | 10 | 400 | Live raid validation |
| **Total** | **27** | - | **840** | |

#### Infrastructure

| Resource | Purpose | Cost |
|----------|---------|------|
| **Log Collection Server** | Store validation logs | $50/month |
| **WCL API Access** | Automated log comparison | Free (rate limited) |
| **Video Storage** | Video analysis (if needed) | $20/month |
| **Discord Server** | Tester coordination | Free |
| **Test Realm Access** | Controlled testing | Included |

#### Tools & Software

| Tool | Purpose | License |
|------|---------|---------|
| **OBS/ShadowPlay** | Video recording | Free |
| **Recount/Skada** | In-game DPS meters | Free |
| **Warcraft Logs** | Raid log analysis | Free/Premium |
| **Python + OpenCV** | Video analysis | Open source |
| **Busted (Lua)** | Test framework | Open source |

---

### Timeline Visualization

```
Week 1: Internal Validation
├── Day 1-2: Setup & Baseline (Patchwerk)
│   └── 50 encounters, logging validation
├── Day 3-4: Movement & Execute (Prince, Gruul)
│   └── 60 encounters, adaptation testing
└── Day 5: Analysis & Fixes
    └── Week 1 report, critical fixes

Week 2: Community Validation
├── Day 6-7: Community Recruitment
│   └── 20 testers onboarded
├── Day 8-9: Live Raid Validation
│   └── 100+ encounters, all 5 bosses
└── Day 10: Final Analysis & Decision
    └── Go/No-Go, release plan
```

---

## Part 4: Validation Framework & Metrics

### Metrics to Track

#### Primary Metrics (Must Track)

| Metric | Definition | Target | Measurement |
|--------|------------|--------|-------------|
| **DPS Variance** | % difference from wowsims | <5% | (EAX_DPS - Sim_DPS) / Sim_DPS |
| **Ability Count Variance** | % difference in casts per minute | <10% | Per-ability comparison |
| **Rotation Uptime** | % of time rotation is active | >95% | No dead time >2s |
| **CD Usage Efficiency** | % of CDs used optimally | >90% | Timing vs optimal |

#### Secondary Metrics (Should Track)

| Metric | Definition | Target | Measurement |
|--------|------------|--------|-------------|
| **Reaction Time** | Delay from recommendation to cast | <500ms | Video analysis |
| **Movement DPS Loss** | % DPS lost during movement | <15% | Patchwerk vs Prince |
| **Execute Phase Gain** | % DPS increase in execute | +15-20% | 20% HP vs normal |
| **Resource Waste** | % resources capped/starved | <5% | Rage/Energy/Mana |

#### Diagnostic Metrics (Nice to Track)

| Metric | Definition | Use Case |
|--------|------------|----------|
| **Buff Uptime** | % time buffs active | Validate priority |
| **Debuff Uptime** | % time debuffs on target | Validate maintenance |
| **Overhealing** | % heals wasted | Healer specs only |
| **Threat Efficiency** | % threat vs DPS | Tank specs only |

### Comparison Against Wowsims Predictions

#### Wowsims Data Integration

```lua
-- wowsims_reference.lua
local wowsims_baseline = {
    -- Warrior Fury P1
    ["WARRIOR_FURY_P1"] = {
        dps = 1423.2,
        variance = 2.1,
        abilities = {
            BLOODTHIRST = {cpm = 6.1, variance = 0.3},
            WHIRLWIND = {cpm = 4.7, variance = 0.4},
            HEROIC_STRIKE = {cpm = 8.2, variance = 0.5},
            EXECUTE = {cpm = 0, variance = 0},  -- Non-execute phase
        },
        buffs = {
            BATTLE_SHOUT = {uptime = 100},
            FLASK = {uptime = 100},
        },
    },
    -- Add other specs...
}

function get_wowsims_baseline(class, spec, gear_phase)
    local key = string.format("%s_%s_%s", class:upper(), spec:upper(), gear_phase:upper())
    return wowsims_baseline[key]
end
```

#### Variance Calculation

```python
# validation/variance_calculator.py
from dataclasses import dataclass
from typing import Dict, List
import math

@dataclass
class VarianceReport:
    spec: str
    encounter: str
    dps_variance_pct: float
    ability_variances: Dict[str, float]
    overall_grade: str
    recommendations: List[str]

def calculate_variance(
    eax_data: dict,
    wowsims_baseline: dict,
    tolerance_pct: float = 5.0
) -> VarianceReport:
    """Calculate variance between EAX and wowsims"""
    
    # DPS variance
    dps_variance = abs(eax_data['dps'] - wowsims_baseline['dps']) / wowsims_baseline['dps'] * 100
    
    # Ability count variances
    ability_variances = {}
    for ability, eax_count in eax_data['ability_counts'].items():
        baseline_count = wowsims_baseline['abilities'].get(ability, {}).get('cpm', 0)
        if baseline_count > 0:
            variance = abs(eax_count - baseline_count) / baseline_count * 100
            ability_variances[ability] = variance
    
    # Grade the result
    if dps_variance <= tolerance_pct:
        grade = "PASS"
    elif dps_variance <= tolerance_pct * 2:
        grade = "WARNING"
    else:
        grade = "FAIL"
    
    # Generate recommendations
    recommendations = []
    if dps_variance > tolerance_pct:
        recommendations.append(f"DPS variance {dps_variance:.1f}% exceeds {tolerance_pct}% threshold")
    
    for ability, var in ability_variances.items():
        if var > 20:
            recommendations.append(f"{ability} variance {var:.1f}% - investigate rotation priority")
    
    return VarianceReport(
        spec=eax_data['spec'],
        encounter=eax_data['encounter'],
        dps_variance_pct=dps_variance,
        ability_variances=ability_variances,
        overall_grade=grade,
        recommendations=recommendations
    )
```

### Acceptable Variance Thresholds

#### By Metric Type

| Metric | Excellent | Acceptable | Warning | Critical |
|--------|-----------|------------|---------|----------|
| **DPS Variance** | <3% | 3-5% | 5-10% | >10% |
| **Ability Count** | <5% | 5-10% | 10-20% | >20% |
| **Buff Uptime** | <2% | 2-5% | 5-10% | >10% |
| **CD Timing** | <1s | 1-3s | 3-5s | >5s |
| **Reaction Time** | <300ms | 300-500ms | 500ms-1s | >1s |

#### By Encounter Type

| Encounter Type | DPS Tolerance | Notes |
|----------------|---------------|-------|
| **Patchwerk (standstill)** | ±3% | Baseline, minimal variables |
| **Movement-heavy** | ±5% | Prince, Vashj |
| **Multi-target** | ±7% | Magtheridon, depends on target count |
| **Execute phase** | ±5% | Gruul, Vashj P3 |
| **Progression (learning)** | ±10% | First kills, learning mechanics |

#### By Spec Complexity

| Spec Complexity | DPS Tolerance | Examples |
|-----------------|---------------|----------|
| **Low** | ±3% | Hunter BM, Warlock Destro |
| **Medium** | ±5% | Warrior Fury, Rogue Combat |
| **High** | ±7% | Mage Fire, Druid Balance |
| **Very High** | ±10% | Paladin Ret (seal twisting), Priest Shadow |

### Success Criteria for "Real-World Accuracy"

#### Tier 1: Release Blockers (Must Pass)

| Criterion | Threshold | Measurement |
|-----------|-----------|-------------|
| **Patchwerk DPS** | Within 5% of wowsims | 10+ pulls per spec |
| **No Crashes** | 0 crashes in 100+ encounters | Error tracking |
| **Rotation Active** | >95% uptime | Dead time <2s per pull |
| **CD Usage** | >80% of major CDs used | Timing analysis |

#### Tier 2: Quality Gates (Should Pass)

| Criterion | Threshold | Measurement |
|-----------|-----------|-------------|
| **Movement Loss** | <15% DPS loss vs Patchwerk | Prince/Magtheridon |
| **Execute Gain** | +15% DPS in execute phase | Gruul/Vashj P3 |
| **Ability Accuracy** | Within 15% of sim counts | Per-ability comparison |
| **Tester Satisfaction** | >75% positive feedback | Survey |

#### Tier 3: Excellence (Nice to Have)

| Criterion | Threshold | Measurement |
|-----------|-----------|-------------|
| **All Encounters** | Within 5% on all 5 reference | Full validation |
| **Reaction Time** | <500ms average | Video analysis |
| **Zero Wasted CDs** | 100% optimal CD usage | WCL analysis |
| **Community Adoption** | >50% of testers continue using | Post-validation survey |

### Validation Report Template

```markdown
# EAX Real-World Validation Report

**Date**: [Date]  
**Spec**: [Class/Spec]  
**Version**: [EAX Version]  
**Tester**: [Name/Anonymous]

## Summary

| Metric | Result | Target | Status |
|--------|--------|--------|--------|
| DPS Variance | X% | <5% | ✅/⚠️/❌ |
| Ability Count | X% | <10% | ✅/⚠️/❌ |
| Rotation Uptime | X% | >95% | ✅/⚠️/❌ |

## Encounter Breakdown

### Patchwerk (Baseline)
- DPS: X (wowsims: Y, variance: Z%)
- Abilities: [table]
- Issues: [list]

### Prince Malchezaar (Movement)
- DPS: X (vs Patchwerk: Y% loss)
- Movement adaptations: [observations]
- Issues: [list]

## Issues Found

1. [Issue description] - [Severity] - [Action taken]

## Recommendations

1. [Recommendation]

## Overall Grade: [PASS/WARNING/FAIL]
```

---

## Appendix A: Validation Tools Implementation

### Tool 1: EAX Validation Logger (Lua)

```lua
-- libraries/validation_logger.lua
local validation_logger = {
    enabled = false,
    session_id = nil,
    start_time = 0,
    ability_log = {},
    config = {
        max_log_size = 10000,  -- Prevent memory bloat
        auto_export = true,
        include_context = true,
    }
}

function validation_logger.enable()
    validation_logger.enabled = true
    validation_logger.session_id = string.format("%d_%s", os.time(), GetUnitName("player"))
    validation_logger.start_time = GetTime()
    validation_logger.ability_log = {}
    print("[EAX-Validation] Session started:", validation_logger.session_id)
end

function validation_logger.disable()
    if validation_logger.enabled and validation_logger.config.auto_export then
        validation_logger.export()
    end
    validation_logger.enabled = false
    print("[EAX-Validation] Session ended")
end

function validation_logger.log(spell_id, spell_name, context)
    if not validation_logger.enabled then return end
    if #validation_logger.ability_log >= validation_logger.config.max_log_size then
        return  -- Prevent memory bloat
    end
    
    local entry = {
        timestamp = GetTime() - validation_logger.start_time,
        spell_id = spell_id,
        spell_name = spell_name,
        recommendation = true,
    }
    
    if validation_logger.config.include_context then
        entry.context = {
            target_hp = context.target_hp,
            player_resource = context.resource,
            combat_time = context.combat_time,
            buffs = context.buffs,
        }
    end
    
    table.insert(validation_logger.ability_log, entry)
end

function validation_logger.export()
    local export = {
        session_id = validation_logger.session_id,
        spec = GetSpecializationInfo(),
        duration = GetTime() - validation_logger.start_time,
        abilities = validation_logger.ability_log,
        summary = validation_logger.summarize(),
    }
    
    -- Write to SavedVariables or external file
    local json = encode_json(export)
    write_to_file(string.format("EAX_Validation_%s.json", validation_logger.session_id), json)
end

return validation_logger
```

### Tool 2: Log Comparison Script (Python)

```python
#!/usr/bin/env python3
# tools/compare_validation_logs.py

import json
import argparse
from pathlib import Path
from dataclasses import dataclass
from typing import Dict, List
import csv

@dataclass
class ComparisonResult:
    spec: str
    encounter: str
    eax_dps: float
    wowsims_dps: float
    variance_pct: float
    grade: str

def load_eax_log(path: Path) -> dict:
    with open(path) as f:
        return json.load(f)

def load_wowsims_baseline(spec: str, encounter: str) -> dict:
    # Load from wowsims reference database
    baseline_path = Path(f"baselines/{spec}_{encounter}.json")
    with open(baseline_path) as f:
        return json.load(f)

def compare_logs(eax_log: dict, baseline: dict) -> ComparisonResult:
    eax_dps = calculate_dps_from_log(eax_log)
    baseline_dps = baseline['dps']
    
    variance = abs(eax_dps - baseline_dps) / baseline_dps * 100
    
    if variance <= 5:
        grade = "PASS"
    elif variance <= 10:
        grade = "WARNING"
    else:
        grade = "FAIL"
    
    return ComparisonResult(
        spec=eax_log['spec'],
        encounter=eax_log['encounter'],
        eax_dps=eax_dps,
        wowsims_dps=baseline_dps,
        variance_pct=variance,
        grade=grade
    )

def main():
    parser = argparse.ArgumentParser(description="Compare EAX validation logs to wowsims baselines")
    parser.add_argument("log_path", type=Path, help="Path to EAX validation log")
    parser.add_argument("--output", type=Path, default=Path("comparison_report.csv"))
    args = parser.parse_args()
    
    eax_log = load_eax_log(args.log_path)
    baseline = load_wowsims_baseline(eax_log['spec'], eax_log['encounter'])
    result = compare_logs(eax_log, baseline)
    
    print(f"Spec: {result.spec}")
    print(f"Encounter: {result.encounter}")
    print(f"EAX DPS: {result.eax_dps:.1f}")
    print(f"Wowsims DPS: {result.wowsims_dps:.1f}")
    print(f"Variance: {result.variance_pct:.1f}%")
    print(f"Grade: {result.grade}")
    
    # Export to CSV
    with open(args.output, 'a', newline='') as f:
        writer = csv.writer(f)
        writer.writerow([result.spec, result.encounter, result.eax_dps, 
                        result.wowsims_dps, result.variance_pct, result.grade])

if __name__ == "__main__":
    main()
```

### Tool 3: WCL Fetcher (Python)

```python
#!/usr/bin/env python3
# tools/fetch_wcl_report.py

import requests
import argparse
import json
from pathlib import Path

WCL_API_URL = "https://classic.warcraftlogs.com/api/v2"

def fetch_report(report_id: str, api_key: str) -> dict:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    query = """
    query {
        reportData {
            report(code: "%s") {
                fights {
                    id
                    name
                    startTime
                    endTime
                }
            }
        }
    }
    """ % report_id
    
    response = requests.post(WCL_API_URL, headers=headers, json={"query": query})
    return response.json()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("report_id", help="WCL report ID")
    parser.add_argument("--api-key", required=True, help="WCL API key")
    parser.add_argument("--output", type=Path, default=Path("wcl_report.json"))
    args = parser.parse_args()
    
    data = fetch_report(args.report_id, args.api_key)
    
    with open(args.output, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"Report saved to {args.output}")

if __name__ == "__main__":
    main()
```

---

## Appendix B: Quick Reference

### Validation Checklist

**Before Validation**:
- [ ] Validation logging enabled
- [ ] Wowsims baseline confirmed
- [ ] Testers briefed on procedure
- [ ] Data collection pipeline ready

**During Validation**:
- [ ] Minimum 10 encounters per spec
- [ ] All 5 reference encounters covered
- [ ] Logs uploading successfully
- [ ] No critical bugs reported

**After Validation**:
- [ ] Variance calculations complete
- [ ] Grade assigned (PASS/WARNING/FAIL)
- [ ] Issues documented
- [ ] Go/No-Go decision made

### Emergency Contacts

| Issue | Contact | Response Time |
|-------|---------|---------------|
| **Crash/Bug** | Dev Support | <2 hours |
| **Data Loss** | Validation Lead | <4 hours |
| **Tester Issue** | Community Manager | <24 hours |
| **WCL API Down** | Validation Lead | N/A (use backup methods) |

---

**Document End**

*This validation strategy ensures EAX improvements achieve real-world accuracy matching wowsims predictions. Execute this plan after unit/integration testing but before production release.*
