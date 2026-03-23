-- buchla700 explorer
-- autonomous timbral topology exploration
--
-- the buchla 700 is about the journey through FM space:
-- changing the routing topology changes the *character* of the sound.
-- the explorer rides topologies, indices, and waveshapes
-- like a west coast operator rides a complex oscillator.
--
-- 4 phases: DRIFT -> MORPH -> CHAOS -> RESOLVE
-- DRIFT:   gentle index riding, stays on current topology
-- MORPH:   topology changes begin, waveshape switching, ratio drift
-- CHAOS:   rapid topology cycling, max indices, feedback configs
-- RESOLVE: pull back toward scene anchors, settle, breathe

local explorer = {}

-- phases
explorer.DRIFT   = 1
explorer.MORPH   = 2
explorer.CHAOS   = 3
explorer.RESOLVE = 4

local PHASE_NAMES = {"DRIFT", "MORPH", "CHAOS", "RESOLVE"}

-- state
explorer.active = false
explorer.phase = 1
explorer.phase_beat = 0
explorer.phase_length = 32
explorer.intensity = 0.1
explorer.intensity_start = 0.1
explorer.intensity_end = 0.4
explorer.step_count = 0
explorer.scene_anchors = nil
explorer.cycle_count = 0

-- phase configuration
local PHASE_CONFIG = {
  -- DRIFT: gentle, conservative
  [1] = {
    name = "DRIFT",
    length_range = {24, 40},
    intensity_start = 0.05,
    intensity_end = 0.35,
    topology_prob = 0.02,      -- very rare topology changes
    index_prob = 0.7,          -- frequent index riding
    ratio_prob = 0.1,          -- rare ratio drift
    waveshape_prob = 0.03,     -- very rare waveshape changes
    filter_prob = 0.4,         -- moderate filter movement
    effects_prob = 0.1,        -- subtle effects
    index_magnitude = 0.03,    -- tiny nudges
    filter_magnitude = 0.05,
    ratio_magnitude = 0.1,     -- small ratio adjustments
    prefer_configs = nil,      -- no preference
  },
  -- MORPH: building, more adventurous
  [2] = {
    name = "MORPH",
    length_range = {20, 36},
    intensity_start = 0.30,
    intensity_end = 0.70,
    topology_prob = 0.15,
    index_prob = 0.8,
    ratio_prob = 0.25,
    waveshape_prob = 0.12,
    filter_prob = 0.6,
    effects_prob = 0.3,
    index_magnitude = 0.06,
    filter_magnitude = 0.10,
    ratio_magnitude = 0.2,
    prefer_configs = {0, 1, 2, 3, 5, 6, 10},  -- avoid chaos configs
  },
  -- CHAOS: maximum exploration, feedback configs
  [3] = {
    name = "CHAOS",
    length_range = {12, 24},
    intensity_start = 0.65,
    intensity_end = 1.0,
    topology_prob = 0.35,
    index_prob = 0.9,
    ratio_prob = 0.4,
    waveshape_prob = 0.25,
    filter_prob = 0.8,
    effects_prob = 0.5,
    index_magnitude = 0.12,
    filter_magnitude = 0.20,
    ratio_magnitude = 0.4,
    prefer_configs = {2, 7, 8, 9},  -- feedback + chaos configs
  },
  -- RESOLVE: pulling back, settling
  [4] = {
    name = "RESOLVE",
    length_range = {24, 40},
    intensity_start = 0.50,
    intensity_end = 0.05,
    topology_prob = 0.05,
    index_prob = 0.5,
    ratio_prob = 0.08,
    waveshape_prob = 0.05,
    filter_prob = 0.3,
    effects_prob = 0.15,
    index_magnitude = 0.02,
    filter_magnitude = 0.03,
    ratio_magnitude = 0.05,
    prefer_configs = nil,  -- will pull toward anchor config
  },
}

-- mutation intervals (in beats)
local INTERVALS = {
  index = 2,        -- fast: indices are the expression
  filter = 4,       -- moderate: filter is the breath
  topology = 8,     -- slow: topology is the character
  ratio = 6,        -- moderate: ratios are the spectrum
  waveshape = 10,   -- slow: waveshape is the color
  effects = 12,     -- slowest: effects are the space
  sequencer = 8,    -- moderate: sequencer topology overrides
}

-- --------------------------------------------------------------------------
-- lifecycle
-- --------------------------------------------------------------------------

function explorer.start()
  explorer.active = true
  explorer.step_count = 0
  explorer.cycle_count = 0
  explorer.save_anchors()
  explorer.enter_phase(explorer.DRIFT)
end

function explorer.stop()
  explorer.active = false
  -- optionally restore anchors
  if explorer.scene_anchors then
    explorer.restore_anchors(0.5)
  end
end

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
    exciter_amount = params:get("exciter_amount"),
    tilt_eq = params:get("tilt_eq"),
  }
end

function explorer.restore_anchors(strength)
  if not explorer.scene_anchors then return end
  local a = explorer.scene_anchors
  local s = strength or 0.3

  -- pull params toward anchors
  local function pull(name, target)
    local current = params:get(name)
    local new_val = current + (target - current) * s
    params:set(name, new_val)
  end

  pull("master_index", a.master_index)
  pull("cutoff", a.cutoff)
  pull("resonance", a.resonance)
  pull("drive", a.drive)
  pull("phaser_intensity", a.phaser_intensity)
  pull("exciter_amount", a.exciter_amount)
  pull("tilt_eq", a.tilt_eq)

  for i = 1, 6 do
    pull("index" .. i, a["index" .. i])
  end
end

-- --------------------------------------------------------------------------
-- phase management
-- --------------------------------------------------------------------------

function explorer.enter_phase(phase_num)
  explorer.phase = phase_num
  explorer.phase_beat = 0

  local cfg = PHASE_CONFIG[phase_num]
  local lo, hi = cfg.length_range[1], cfg.length_range[2]
  explorer.phase_length = math.random(lo, hi)
  explorer.intensity_start = cfg.intensity_start
  explorer.intensity_end = cfg.intensity_end
  explorer.intensity = cfg.intensity_start
end

function explorer.advance_phase()
  local next_phase = explorer.phase + 1
  if next_phase > 4 then
    next_phase = 1
    explorer.cycle_count = explorer.cycle_count + 1
    -- re-anchor at start of new cycle
    if math.random() < 0.3 then
      explorer.save_anchors()
    end
  end
  explorer.enter_phase(next_phase)
end

function explorer.get_phase_name()
  return PHASE_NAMES[explorer.phase]
end

-- --------------------------------------------------------------------------
-- tick (called every beat from the lattice)
-- --------------------------------------------------------------------------

function explorer.tick()
  if not explorer.active then return end

  explorer.step_count = explorer.step_count + 1
  explorer.phase_beat = explorer.phase_beat + 1

  -- update intensity arc
  local progress = explorer.phase_beat / math.max(explorer.phase_length, 1)
  progress = math.min(progress, 1)
  explorer.intensity = explorer.intensity_start +
    (explorer.intensity_end - explorer.intensity_start) * progress

  local cfg = PHASE_CONFIG[explorer.phase]
  local int = explorer.intensity

  -- mutation checks at intervals
  if explorer.step_count % INTERVALS.index == 0 then
    if math.random() < cfg.index_prob * int then
      explorer.mutate_indices(cfg, int)
    end
  end

  if explorer.step_count % INTERVALS.filter == 0 then
    if math.random() < cfg.filter_prob * int then
      explorer.mutate_filter(cfg, int)
    end
  end

  if explorer.step_count % INTERVALS.topology == 0 then
    if math.random() < cfg.topology_prob * int then
      explorer.mutate_topology(cfg, int)
    end
  end

  if explorer.step_count % INTERVALS.ratio == 0 then
    if math.random() < cfg.ratio_prob * int then
      explorer.mutate_ratios(cfg, int)
    end
  end

  if explorer.step_count % INTERVALS.waveshape == 0 then
    if math.random() < cfg.waveshape_prob * int then
      explorer.mutate_waveshape(cfg, int)
    end
  end

  if explorer.step_count % INTERVALS.effects == 0 then
    if math.random() < cfg.effects_prob * int then
      explorer.mutate_effects(cfg, int)
    end
  end

  if explorer.step_count % INTERVALS.sequencer == 0 then
    if math.random() < cfg.topology_prob * int * 0.5 then
      explorer.mutate_sequencer(cfg, int)
    end
  end

  -- RESOLVE phase: pull toward anchors
  if explorer.phase == explorer.RESOLVE then
    if math.random() < 0.15 * progress then
      explorer.restore_anchors(0.15)
    end
  end

  -- phase transition
  if explorer.phase_beat >= explorer.phase_length then
    explorer.advance_phase()
  end
end

-- --------------------------------------------------------------------------
-- mutations
-- --------------------------------------------------------------------------

local function nudge(name, amount, lo, hi)
  local current = params:get(name)
  local new_val = util.clamp(current + amount, lo, hi)
  params:set(name, new_val)
end

local function rand_delta(magnitude)
  return (math.random() * 2 - 1) * magnitude
end

function explorer.mutate_indices(cfg, int)
  -- ride the FM indices — this is the core expressivity
  local mag = cfg.index_magnitude * (0.5 + int * 0.5)

  -- master index: broad strokes
  if math.random() < 0.4 then
    nudge("master_index", rand_delta(mag * 2), 0.0, 2.0)
  end

  -- individual indices: fine detail
  local num_to_change = math.random(1, math.floor(1 + int * 4))
  for _ = 1, num_to_change do
    local idx = math.random(1, 6)
    nudge("index" .. idx, rand_delta(mag), 0.0, 2.0)
  end
end

function explorer.mutate_filter(cfg, int)
  local mag = cfg.filter_magnitude * (0.5 + int * 0.5)

  -- cutoff: exponential nudge (multiply by factor)
  local cutoff_current = params:get("cutoff")
  local factor = 1.0 + rand_delta(mag)
  params:set("cutoff", util.clamp(cutoff_current * factor, 80, 16000))

  -- resonance
  if math.random() < 0.5 then
    nudge("resonance", rand_delta(mag * 8), 0.0, 3.0)
  end

  -- drive: builds during chaos, recedes during resolve
  if explorer.phase == explorer.CHAOS then
    if math.random() < 0.3 then
      nudge("drive", math.random() * 0.1, 0.0, 0.8)
    end
  elseif explorer.phase == explorer.RESOLVE then
    nudge("drive", -0.05, 0.0, 0.8)
  end
end

function explorer.mutate_topology(cfg, int)
  -- THE big move: changing FM routing topology
  local new_config

  if cfg.prefer_configs and math.random() < 0.7 then
    -- pick from preferred configs for this phase
    new_config = cfg.prefer_configs[math.random(#cfg.prefer_configs)]
  else
    -- random topology
    new_config = math.random(0, 11)
  end

  params:set("config", new_config + 1)
end

function explorer.mutate_ratios(cfg, int)
  local mag = cfg.ratio_magnitude

  -- pick one oscillator to shift
  local osc = math.random(2, 4)
  local current = params:get("ratio" .. osc)

  if math.random() < 0.6 then
    -- snap to nearby harmonic
    local harmonics = {0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0}
    local nearest = harmonics[1]
    local min_dist = math.abs(current - nearest)
    for _, h in ipairs(harmonics) do
      local dist = math.abs(current - h)
      if dist < min_dist then
        nearest = h
        min_dist = dist
      end
    end
    -- drift toward nearest harmonic
    local target = nearest + rand_delta(mag * 0.3)
    params:set("ratio" .. osc, util.clamp(target, 0.25, 8.0))
  else
    -- free drift
    local new_val = current + rand_delta(mag)
    params:set("ratio" .. osc, util.clamp(new_val, 0.25, 8.0))
  end
end

function explorer.mutate_waveshape(cfg, int)
  -- waveshape changes are dramatic — full preset swaps
  if math.random() < 0.5 then
    params:set("wsa_preset", math.random(1, 8))
  else
    params:set("wsb_preset", math.random(1, 8))
  end
end

function explorer.mutate_effects(cfg, int)
  -- phaser builds with intensity
  if explorer.phase == explorer.CHAOS or explorer.phase == explorer.MORPH then
    nudge("phaser_intensity", math.random() * 0.08 * int, 0.0, 1.0)
    if math.random() < 0.3 then
      nudge("phaser_rate", rand_delta(0.3), 0.1, 5.0)
    end
  elseif explorer.phase == explorer.RESOLVE then
    nudge("phaser_intensity", -0.05, 0.0, 1.0)
  end

  -- exciter: adds presence during buildup
  if explorer.phase == explorer.MORPH or explorer.phase == explorer.CHAOS then
    nudge("exciter_amount", rand_delta(0.05 * int), 0.0, 0.8)
  elseif explorer.phase == explorer.RESOLVE then
    nudge("exciter_amount", -0.03, 0.0, 0.8)
  end

  -- tilt: drift
  if math.random() < 0.3 then
    nudge("tilt_eq", rand_delta(0.1 * int), -0.8, 0.8)
  end
end

function explorer.mutate_sequencer(cfg, int)
  -- per-step topology overrides: the killer feature
  -- different FM routing per step creates rhythmic timbral variation
  local seq = require "lib/sequencer"

  if explorer.phase == explorer.CHAOS then
    -- assign random topologies to random steps
    local num_steps = math.random(1, 3)
    for _ = 1, num_steps do
      local step = math.random(1, seq.num_steps)
      if math.random() < 0.7 then
        seq.set_step(step, "config", math.random(0, 11))
      else
        seq.set_step(step, "config", -1)  -- restore global
      end
    end
  elseif explorer.phase == explorer.RESOLVE then
    -- clear per-step overrides
    for i = 1, seq.num_steps do
      if math.random() < 0.3 then
        seq.set_step(i, "config", -1)
      end
    end
  end
end

return explorer
