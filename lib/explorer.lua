-- bucha explorer
--
-- a west coast operator who lives inside the machine.
-- not a parameter randomizer — a musician with aesthetic convictions.
--
-- 4 phases with distinct personalities:
--   DRIFT:   morton subotnick at dawn. gentle spectral shimmer.
--            small index rides, filter breathing, rare topology shifts.
--            the sequencer thins out, notes sustain, space opens.
--
--   MORPH:   the patch cables start moving. topology changes arrive
--            like weather fronts. ratios drift through the harmonic series.
--            the sequencer grows p-locks, timbre varies step to step.
--            waveshapes shift. the filter opens and closes like breath.
--
--   CHAOS:   silver apples of the moon. feedback configs dominate.
--            indices spike, ratios go inharmonic, the exciter cranks.
--            sequencer goes generative — markov chains replace patterns.
--            ratchets appear. fills trigger. the phaser swirls.
--
--   RESOLVE: the storm passes. parameters pull toward home.
--            the sequencer returns to its original pattern.
--            indices recede, filter settles, topology finds anchor.
--            space clears. breath slows. silence reclaims its territory.
--
-- the explorer also has STYLES that flavor everything:
--   EASEL:   classic buchla — balanced, warm, melodic exploration
--   STREGA:  dark drones — feedback-heavy, slow, saturated
--   SUBOTNICK: wide dynamics — dramatic swells, sudden silences
--   SERGE:   modular chaos — rapid patching, dense textures
--   ENO:     ambient — glacial movement, overtone focus, space

local explorer = {}

-- --------------------------------------------------------------------------
-- phases
-- --------------------------------------------------------------------------

explorer.DRIFT   = 1
explorer.MORPH   = 2
explorer.CHAOS   = 3
explorer.RESOLVE = 4

local PHASE_NAMES = {"DRIFT", "MORPH", "CHAOS", "RESOLVE"}

-- --------------------------------------------------------------------------
-- styles: aesthetic personalities that color all mutations
-- --------------------------------------------------------------------------

local STYLES = {
  EASEL = {
    name = "EASEL",
    -- topology preferences per phase
    drift_configs  = {0, 1, 4, 10},       -- simple, clean
    morph_configs  = {0, 1, 2, 3, 5, 6},  -- moderate complexity
    chaos_configs  = {2, 5, 8, 9},         -- feedback but not insane
    -- parameter tendencies
    index_ceiling = 1.2,       -- moderate FM depth
    cutoff_center = 3000,      -- mid-bright
    drive_love = 0.3,          -- gentle saturation
    phaser_love = 0.4,         -- moderate phasing
    exciter_love = 0.3,        -- subtle presence
    ratio_drift = 0.15,        -- harmonic, stable ratios
    seq_density = 0.6,         -- moderate density
    markov_style = "melodic",  -- stepwise motion
    phase_lengths = {28, 24, 16, 32},
  },
  STREGA = {
    name = "STREGA",
    drift_configs  = {7, 4, 0},
    morph_configs  = {7, 8, 2, 3},
    chaos_configs  = {8, 9, 2, 7},
    index_ceiling = 1.8,
    cutoff_center = 800,       -- dark
    drive_love = 0.7,          -- heavy saturation
    phaser_love = 0.6,
    exciter_love = 0.15,       -- minimal exciter (already saturated)
    ratio_drift = 0.08,        -- very slow drift
    seq_density = 0.35,        -- sparse, droney
    markov_style = "clustered",
    phase_lengths = {40, 32, 20, 48},
  },
  SUBOTNICK = {
    name = "SUBOTNICK",
    drift_configs  = {0, 1, 10, 4},
    morph_configs  = {2, 3, 5, 6, 11},
    chaos_configs  = {9, 8, 2, 5, 11},
    index_ceiling = 1.5,
    cutoff_center = 4000,
    drive_love = 0.4,
    phaser_love = 0.5,
    exciter_love = 0.5,        -- bright, present
    ratio_drift = 0.25,        -- adventurous
    seq_density = 0.7,
    markov_style = "wide",     -- big intervallic leaps
    phase_lengths = {20, 20, 12, 28},
  },
  SERGE = {
    name = "SERGE",
    drift_configs  = {5, 6, 10, 3},
    morph_configs  = {2, 5, 6, 8, 11},
    chaos_configs  = {9, 8, 5, 2, 11, 6},
    index_ceiling = 2.0,       -- max FM depth
    cutoff_center = 2000,
    drive_love = 0.5,
    phaser_love = 0.3,
    exciter_love = 0.4,
    ratio_drift = 0.35,        -- aggressive ratio changes
    seq_density = 0.85,        -- dense, rapid
    markov_style = "angular",  -- tritones, major 7ths
    phase_lengths = {16, 16, 12, 20},
  },
  ENO = {
    name = "ENO",
    drift_configs  = {0, 4, 1},
    morph_configs  = {0, 1, 3, 10},
    chaos_configs  = {3, 10, 0, 1},   -- even chaos is gentle
    index_ceiling = 0.8,       -- low FM = pure overtones
    cutoff_center = 6000,      -- open, airy
    drive_love = 0.1,          -- almost no drive
    phaser_love = 0.7,         -- lots of phasing
    exciter_love = 0.6,        -- bright, harmonic-rich
    ratio_drift = 0.1,         -- glacial
    seq_density = 0.3,         -- very sparse
    markov_style = "melodic",
    phase_lengths = {48, 40, 24, 56},
  },
}

-- --------------------------------------------------------------------------
-- state
-- --------------------------------------------------------------------------

explorer.active = false
explorer.phase = 1
explorer.phase_beat = 0
explorer.phase_length = 32
explorer.intensity = 0.1
explorer.intensity_start = 0.1
explorer.intensity_end = 0.4
explorer.step_count = 0
explorer.cycle_count = 0
explorer.style = "EASEL"
explorer.scene_anchors = nil

-- internal dynamics
explorer.momentum = 0.0        -- builds during phase, affects mutation magnitude
explorer.tension = 0.0         -- rises in MORPH/CHAOS, drops in RESOLVE
explorer.recent_topology = -1  -- tracks last topology set (avoids redundant changes)

-- phase configuration (base values, multiplied by style)
local PHASE_BASE = {
  [1] = { -- DRIFT
    intensity_range = {0.05, 0.30},
    topology_prob = 0.03,
    index_prob = 0.6,
    ratio_prob = 0.08,
    waveshape_prob = 0.02,
    filter_prob = 0.4,
    effects_prob = 0.15,
    seq_mutate_prob = 0.05,
    seq_plock_prob = 0.02,
    magnitude = 0.3,
  },
  [2] = { -- MORPH
    intensity_range = {0.25, 0.70},
    topology_prob = 0.15,
    index_prob = 0.75,
    ratio_prob = 0.20,
    waveshape_prob = 0.10,
    filter_prob = 0.6,
    effects_prob = 0.3,
    seq_mutate_prob = 0.15,
    seq_plock_prob = 0.12,
    magnitude = 0.6,
  },
  [3] = { -- CHAOS
    intensity_range = {0.60, 1.0},
    topology_prob = 0.30,
    index_prob = 0.9,
    ratio_prob = 0.35,
    waveshape_prob = 0.20,
    filter_prob = 0.8,
    effects_prob = 0.5,
    seq_mutate_prob = 0.30,
    seq_plock_prob = 0.25,
    magnitude = 1.0,
  },
  [4] = { -- RESOLVE
    intensity_range = {0.50, 0.05},
    topology_prob = 0.05,
    index_prob = 0.4,
    ratio_prob = 0.05,
    waveshape_prob = 0.03,
    filter_prob = 0.25,
    effects_prob = 0.1,
    seq_mutate_prob = 0.03,
    seq_plock_prob = 0.01,
    magnitude = 0.2,
  },
}

-- mutation intervals (in beats)
local INTERVALS = {
  index = 2,
  filter = 3,
  topology = 6,
  ratio = 5,
  waveshape = 8,
  effects = 10,
  seq_melody = 4,
  seq_timbre = 6,
  seq_rhythm = 8,
  dynamics = 4,     -- internal dynamics update
}

-- --------------------------------------------------------------------------
-- lifecycle
-- --------------------------------------------------------------------------

function explorer.start(style_name)
  explorer.active = true
  explorer.style = style_name or "EASEL"
  explorer.step_count = 0
  explorer.cycle_count = 0
  explorer.momentum = 0
  explorer.tension = 0
  explorer.recent_topology = -1
  explorer.save_anchors()
  explorer.enter_phase(explorer.DRIFT)
end

function explorer.stop()
  explorer.active = false
  if explorer.scene_anchors then
    explorer.restore_anchors(0.6)
  end
end

function explorer.set_style(name)
  if STYLES[name] then explorer.style = name end
end

function explorer.get_style()
  return STYLES[explorer.style] or STYLES.EASEL
end

function explorer.get_style_names()
  return {"EASEL", "STREGA", "SUBOTNICK", "SERGE", "ENO"}
end

-- --------------------------------------------------------------------------
-- scene anchors
-- --------------------------------------------------------------------------

function explorer.save_anchors()
  explorer.scene_anchors = {
    config = params:get("config"),
    master_index = params:get("master_index"),
    index1 = params:get("index1"),
    index2 = params:get("index2"),
    index3 = params:get("index3"),
    index4 = params:get("index4"),
    index5 = params:get("index5"),
    index6 = params:get("index6"),
    ratio2 = params:get("ratio2"),
    ratio3 = params:get("ratio3"),
    ratio4 = params:get("ratio4"),
    cutoff = params:get("cutoff"),
    resonance = params:get("resonance"),
    drive = params:get("drive"),
    wsa_preset = params:get("wsa_preset"),
    wsb_preset = params:get("wsb_preset"),
    phaser_intensity = params:get("phaser_intensity"),
    phaser_rate = params:get("phaser_rate"),
    exciter_amount = params:get("exciter_amount"),
    tilt_eq = params:get("tilt_eq"),
  }
end

function explorer.restore_anchors(strength)
  if not explorer.scene_anchors then return end
  local a = explorer.scene_anchors
  local s = strength or 0.3

  local function pull(name, target)
    local current = params:get(name)
    params:set(name, current + (target - current) * s)
  end

  pull("master_index", a.master_index)
  pull("cutoff", a.cutoff)
  pull("resonance", a.resonance)
  pull("drive", a.drive)
  pull("phaser_intensity", a.phaser_intensity)
  pull("exciter_amount", a.exciter_amount)
  pull("tilt_eq", a.tilt_eq)
  for i = 1, 6 do pull("index" .. i, a["index" .. i]) end
end

-- --------------------------------------------------------------------------
-- phase management
-- --------------------------------------------------------------------------

function explorer.enter_phase(phase_num)
  explorer.phase = phase_num
  explorer.phase_beat = 0

  local sty = explorer.get_style()
  local base_len = sty.phase_lengths[phase_num]
  -- jitter: +/- 25%
  local jitter = math.floor(base_len * 0.25)
  explorer.phase_length = base_len + math.random(-jitter, jitter)

  local base = PHASE_BASE[phase_num]
  explorer.intensity_start = base.intensity_range[1]
  explorer.intensity_end = base.intensity_range[2]
  explorer.intensity = explorer.intensity_start

  -- phase entry actions
  if phase_num == explorer.CHAOS then
    -- chaos entry: enable generative sequencer, trigger fill
    local seq = explorer.seq
    seq.generative = true
    seq.markov_style = sty.markov_style
    seq.fill_mode = true
  elseif phase_num == explorer.RESOLVE then
    -- resolve entry: disable generative, clear fill
    local seq = explorer.seq
    seq.generative = false
    seq.fill_mode = false
  elseif phase_num == explorer.DRIFT then
    -- new cycle starts
    local seq = explorer.seq
    seq.generative = false
    seq.fill_mode = false
    seq.lsystem_gen = 0
  end
end

function explorer.advance_phase()
  local next_phase = explorer.phase + 1
  if next_phase > 4 then
    next_phase = 1
    explorer.cycle_count = explorer.cycle_count + 1
    -- re-anchor every few cycles
    if math.random() < 0.25 then
      explorer.save_anchors()
    end
  end
  explorer.enter_phase(next_phase)
end

function explorer.get_phase_name()
  return PHASE_NAMES[explorer.phase]
end

-- --------------------------------------------------------------------------
-- tick
-- --------------------------------------------------------------------------

function explorer.tick()
  if not explorer.active then return end

  explorer.step_count = explorer.step_count + 1
  explorer.phase_beat = explorer.phase_beat + 1

  -- intensity arc
  local progress = explorer.phase_beat / math.max(explorer.phase_length, 1)
  progress = math.min(progress, 1)
  explorer.intensity = explorer.intensity_start +
    (explorer.intensity_end - explorer.intensity_start) * progress

  -- internal dynamics
  explorer.update_dynamics(progress)

  local sty = explorer.get_style()
  local base = PHASE_BASE[explorer.phase]
  local int = explorer.intensity
  local mag = base.magnitude * (0.5 + explorer.momentum * 0.5)

  -- mutations at intervals
  if explorer.step_count % INTERVALS.index == 0 then
    if math.random() < base.index_prob * int then
      explorer.mutate_indices(sty, mag)
    end
  end

  if explorer.step_count % INTERVALS.filter == 0 then
    if math.random() < base.filter_prob * int then
      explorer.mutate_filter(sty, mag)
    end
  end

  if explorer.step_count % INTERVALS.topology == 0 then
    if math.random() < base.topology_prob * int then
      explorer.mutate_topology(sty)
    end
  end

  if explorer.step_count % INTERVALS.ratio == 0 then
    if math.random() < base.ratio_prob * int then
      explorer.mutate_ratios(sty, mag)
    end
  end

  if explorer.step_count % INTERVALS.waveshape == 0 then
    if math.random() < base.waveshape_prob * int then
      explorer.mutate_waveshape()
    end
  end

  if explorer.step_count % INTERVALS.effects == 0 then
    if math.random() < base.effects_prob * int then
      explorer.mutate_effects(sty, mag)
    end
  end

  -- sequencer mutations
  if explorer.step_count % INTERVALS.seq_melody == 0 then
    if math.random() < base.seq_mutate_prob * int then
      explorer.mutate_seq_melody(sty, mag)
    end
  end

  if explorer.step_count % INTERVALS.seq_timbre == 0 then
    if math.random() < base.seq_plock_prob * int then
      explorer.mutate_seq_timbre(sty, mag)
    end
  end

  if explorer.step_count % INTERVALS.seq_rhythm == 0 then
    if math.random() < base.seq_mutate_prob * int * 0.5 then
      explorer.mutate_seq_rhythm(sty, mag)
    end
  end

  -- RESOLVE: pull toward anchors
  if explorer.phase == explorer.RESOLVE then
    if math.random() < 0.12 * progress then
      explorer.restore_anchors(0.12 + progress * 0.15)
    end
  end

  -- phase transition
  if explorer.phase_beat >= explorer.phase_length then
    explorer.advance_phase()
  end
end

-- --------------------------------------------------------------------------
-- internal dynamics
-- --------------------------------------------------------------------------

function explorer.update_dynamics(progress)
  -- momentum: builds within a phase, resets on transition
  if explorer.phase == explorer.CHAOS then
    explorer.momentum = math.min(1.0, explorer.momentum + 0.03)
  elseif explorer.phase == explorer.MORPH then
    explorer.momentum = math.min(0.8, explorer.momentum + 0.015)
  elseif explorer.phase == explorer.RESOLVE then
    explorer.momentum = math.max(0, explorer.momentum - 0.04)
  else -- DRIFT
    explorer.momentum = math.max(0.1, explorer.momentum - 0.01)
  end

  -- tension: rises through MORPH->CHAOS, drops in RESOLVE
  if explorer.phase <= 2 then
    explorer.tension = math.min(1.0, explorer.tension + 0.008 * explorer.intensity)
  elseif explorer.phase == 3 then
    explorer.tension = math.min(1.0, explorer.tension + 0.02)
  else
    explorer.tension = math.max(0, explorer.tension - 0.05)
  end
end

-- --------------------------------------------------------------------------
-- mutations
-- --------------------------------------------------------------------------

local function nudge(name, amount, lo, hi)
  params:set(name, util.clamp(params:get(name) + amount, lo, hi))
end

local function rand_delta(mag)
  return (math.random() * 2 - 1) * mag
end

function explorer.mutate_indices(sty, mag)
  local idx_mag = mag * 0.08 * (1 + explorer.tension * 0.5)

  -- master index: broad gesture
  if math.random() < 0.35 + explorer.tension * 0.2 then
    nudge("master_index", rand_delta(idx_mag * 3), 0.0, sty.index_ceiling)
  end

  -- individual indices: detail work
  local num = math.random(1, math.floor(1 + explorer.intensity * 4))
  for _ = 1, num do
    local idx = math.random(1, 6)
    nudge("index" .. idx, rand_delta(idx_mag), 0.0, sty.index_ceiling)
  end
end

function explorer.mutate_filter(sty, mag)
  local filter_mag = mag * 0.12

  -- cutoff: gravitates toward style center
  local current = params:get("cutoff")
  local pull = (sty.cutoff_center - current) * 0.05
  local delta = pull + rand_delta(filter_mag * current * 0.3)
  params:set("cutoff", util.clamp(current + delta, 60, 16000))

  -- resonance
  if math.random() < 0.4 + explorer.tension * 0.3 then
    nudge("resonance", rand_delta(filter_mag * 6), 0.0, 3.0)
  end

  -- drive: style-dependent
  if explorer.phase == explorer.CHAOS or explorer.phase == explorer.MORPH then
    if math.random() < sty.drive_love then
      nudge("drive", math.random() * 0.08 * mag, 0.0, sty.drive_love)
    end
  elseif explorer.phase == explorer.RESOLVE then
    nudge("drive", -0.04, 0.0, 1.0)
  end
end

function explorer.mutate_topology(sty)
  local configs
  if explorer.phase == explorer.DRIFT then
    configs = sty.drift_configs
  elseif explorer.phase == explorer.MORPH then
    configs = sty.morph_configs
  elseif explorer.phase == explorer.CHAOS then
    configs = sty.chaos_configs
  else
    -- RESOLVE: pull toward anchor config
    if explorer.scene_anchors and math.random() < 0.6 then
      params:set("config", explorer.scene_anchors.config)
      return
    end
    configs = sty.drift_configs
  end

  -- pick from preferred configs, avoid repeating
  local new_config
  for _ = 1, 5 do
    new_config = configs[math.random(#configs)]
    if new_config ~= explorer.recent_topology then break end
  end

  explorer.recent_topology = new_config
  params:set("config", new_config + 1)
end

function explorer.mutate_ratios(sty, mag)
  local ratio_mag = sty.ratio_drift * mag

  local osc = math.random(2, 4)
  local current = params:get("ratio" .. osc)

  -- style-dependent: harmonic snap vs free drift
  if math.random() < (1 - ratio_mag) then
    -- snap toward nearest harmonic
    local harmonics = {0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0}
    local nearest = harmonics[1]
    for _, h in ipairs(harmonics) do
      if math.abs(current - h) < math.abs(current - nearest) then
        nearest = h
      end
    end
    params:set("ratio" .. osc, util.clamp(
      nearest + rand_delta(ratio_mag * 0.2), 0.25, 8.0))
  else
    -- free inharmonic drift
    params:set("ratio" .. osc, util.clamp(
      current + rand_delta(ratio_mag), 0.25, 8.0))
  end
end

function explorer.mutate_waveshape()
  if math.random() < 0.5 then
    params:set("wsa_preset", math.random(1, 8))
  else
    params:set("wsb_preset", math.random(1, 8))
  end
end

function explorer.mutate_effects(sty, mag)
  -- phaser: style-driven
  if explorer.phase == explorer.CHAOS or explorer.phase == explorer.MORPH then
    nudge("phaser_intensity",
      math.random() * 0.06 * mag * sty.phaser_love, 0.0, 0.9)
    if math.random() < 0.3 then
      nudge("phaser_rate", rand_delta(0.3), 0.1, 5.0)
    end
  elseif explorer.phase == explorer.RESOLVE then
    nudge("phaser_intensity", -0.04, 0.0, 1.0)
  end

  -- exciter: style-driven
  if explorer.phase ~= explorer.RESOLVE then
    nudge("exciter_amount",
      rand_delta(0.04 * mag * sty.exciter_love), 0.0, 0.8)
  else
    nudge("exciter_amount", -0.03, 0.0, 1.0)
  end

  -- tilt: drift toward style center
  local tilt_target = 0
  if sty.cutoff_center > 3000 then tilt_target = 0.2  -- bright styles tilt bright
  elseif sty.cutoff_center < 1500 then tilt_target = -0.2 end
  nudge("tilt_eq", (tilt_target - params:get("tilt_eq")) * 0.1, -0.8, 0.8)
end

-- --------------------------------------------------------------------------
-- sequencer mutations
-- --------------------------------------------------------------------------

function explorer.mutate_seq_melody(sty, mag)
  local seq = explorer.seq
  local len = seq.track_len[seq.TRACK_MELODY]

  -- pick 1-3 steps to modify
  local num = math.random(1, math.floor(1 + mag * 2))
  for _ = 1, num do
    local i = math.random(1, len)
    local step = seq.melody[i]

    local roll = math.random()
    if roll < 0.4 then
      -- markov note change
      step.note = seq.markov_next(step.note)
    elseif roll < 0.6 then
      -- velocity shift
      step.vel = util.clamp(step.vel + rand_delta(0.15 * mag), 0.2, 1.0)
    elseif roll < 0.8 then
      -- toggle step
      step.on = not step.on
    else
      -- gate length variation
      step.gate = math.random() < 0.5 and -1 or (0.1 + math.random() * 0.8)
    end
  end

  -- during CHAOS: occasionally change track length (polymetric drift)
  if explorer.phase == explorer.CHAOS and math.random() < 0.15 then
    seq.track_len[seq.TRACK_MELODY] = math.random(5, 12)
  end
end

function explorer.mutate_seq_timbre(sty, mag)
  local seq = explorer.seq
  local len = seq.track_len[seq.TRACK_TIMBRE]

  local i = math.random(1, len)
  local step = seq.timbre[i]

  local roll = math.random()
  if roll < 0.25 then
    -- topology p-lock
    local configs
    if explorer.phase == explorer.CHAOS then
      configs = sty.chaos_configs
    else
      configs = sty.morph_configs
    end
    step.config = configs[math.random(#configs)]
  elseif roll < 0.45 then
    -- cutoff p-lock
    step.cutoff = sty.cutoff_center * (0.3 + math.random() * 1.4)
  elseif roll < 0.6 then
    -- index p-lock
    step.master_index = math.random() * sty.index_ceiling
  elseif roll < 0.7 then
    -- waveshape p-lock
    step.wsa = math.random(0, 7)
  elseif roll < 0.8 then
    step.wsb = math.random(0, 7)
  else
    -- clear a p-lock (return to global)
    local keys = {"config", "cutoff", "master_index", "wsa", "wsb",
      "drive", "resonance", "ratio2", "ratio3", "ratio4"}
    step[keys[math.random(#keys)]] = -1
  end

  -- polymetric: drift timbre track length independently
  if explorer.phase >= explorer.MORPH and math.random() < 0.1 then
    seq.track_len[seq.TRACK_TIMBRE] = math.random(5, 13)
  end
end

function explorer.mutate_seq_rhythm(sty, mag)
  local seq = explorer.seq
  local len = seq.track_len[seq.TRACK_RHYTHM]

  local i = math.random(1, len)
  local step = seq.rhythm[i]

  local roll = math.random()
  if roll < 0.4 then
    -- change condition
    if explorer.phase == explorer.DRIFT then
      step.condition = ({1, 1, 1, 2, 3})[math.random(5)]  -- mostly ALWAYS
    elseif explorer.phase == explorer.CHAOS then
      step.condition = math.random(1, 10)  -- anything goes
    else
      step.condition = ({1, 1, 2, 3, 5, 6})[math.random(6)]
    end
  elseif roll < 0.6 then
    -- ratchet
    if explorer.phase == explorer.CHAOS then
      step.ratchet = math.random(1, 4)
    else
      step.ratchet = math.random(1, 2)
    end
  elseif roll < 0.8 then
    -- accent
    step.accent = not step.accent
  else
    -- toggle fill condition
    step.condition = step.condition == 9 and 1 or 9
  end

  -- rhythm track polymetric drift
  if explorer.phase >= explorer.MORPH and math.random() < 0.08 then
    seq.track_len[seq.TRACK_RHYTHM] = math.random(6, 11)
  end
end

-- --------------------------------------------------------------------------
-- info
-- --------------------------------------------------------------------------

function explorer.get_info()
  return {
    phase = PHASE_NAMES[explorer.phase],
    style = explorer.style,
    intensity = explorer.intensity,
    momentum = explorer.momentum,
    tension = explorer.tension,
    beat = explorer.phase_beat,
    length = explorer.phase_length,
    cycle = explorer.cycle_count,
  }
end

return explorer
