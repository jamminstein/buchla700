-- buchla700 octopus
--
-- 8 tentacles, each a specialized intelligence
-- operating a different dimension of the instrument simultaneously.
-- like a human with 100 hands playing a machine.
--
-- tentacles:
--   1. TOPOLOGY  — rides FM routing with dramatic arc awareness
--   2. SPECTRUM  — rides indices, ratios, waveshapes (harmonic content)
--   3. FILTER    — breathes cutoff/resonance/drive (the lungs)
--   4. RHYTHM    — mutates sequencer rhythm track, conditions, ratchets
--   5. MELODY    — markov/motivic melody evolution + note injection
--   6. SPACE     — phaser, exciter, tilt (the room)
--   7. FORM      — long-arc conductor: builds, silences, transitions
--   8. CHAOS     — wild card: disruptions, p-lock storms, polymetric shifts
--
-- each tentacle has:
--   - independent energy (breathing cycle)
--   - a soul (personality preset that colors decisions)
--   - an activity level (modulated by the FORM conductor)
--   - its own tick interval
--
-- souls define the collective personality:
--   SUBOTNICK  — dramatic dynamics, wide intervallic leaps, sudden silences
--   OLIVEROS   — deep listening, glacial, sustained, overtone-focused
--   BUCHLA     — balanced, warm, the instrument as designed
--   XENAKIS    — stochastic, dense, probabilistic, granular
--   ENO        — ambient, generative, space as composition
--   COLTRANE   — sheets of sound, relentless forward motion, intensity
--   MILES      — space, restraint, melody, ensemble conversation
--   APHEX      — micro-rhythm, emotional synthesis, surprise

local octopus = {}

-- --------------------------------------------------------------------------
-- tentacle definitions
-- --------------------------------------------------------------------------

local TENTACLE_NAMES = {
  "TOPOLOGY", "SPECTRUM", "FILTER", "RHYTHM",
  "MELODY", "SPACE", "FORM", "CHAOS"
}

local NUM_TENTACLES = 8
local T_TOPOLOGY = 1
local T_SPECTRUM = 2
local T_FILTER   = 3
local T_RHYTHM   = 4
local T_MELODY   = 5
local T_SPACE    = 6
local T_FORM     = 7
local T_CHAOS    = 8

-- --------------------------------------------------------------------------
-- souls: collective personality presets
-- --------------------------------------------------------------------------

local SOULS = {
  SUBOTNICK = {
    name = "SUBOTNICK",
    -- per-tentacle activity multipliers (0-2, >1 = hyperactive)
    activity = {1.2, 1.0, 1.3, 0.8, 1.0, 0.9, 1.5, 0.7},
    -- topology preferences per form phase
    topo_drift  = {0, 1, 4, 10},
    topo_build  = {2, 3, 5, 6, 11},
    topo_peak   = {9, 8, 2, 5, 11},
    topo_rest   = {0, 4, 1},
    -- spectrum character
    index_ceiling = 1.5,
    ratio_style = "wide",       -- big intervallic leaps in ratios
    ws_change_rate = 0.12,
    -- filter character
    cutoff_center = 4000,
    cutoff_range = 8000,        -- how far it sweeps
    res_love = 0.6,
    drive_love = 0.4,
    -- rhythm
    density_range = {0.3, 0.9},
    ratchet_love = 0.2,
    condition_variety = 0.4,    -- how many non-ALWAYS conditions
    -- melody
    markov = "wide",
    melody_inject_rate = 0.15,  -- how often melody tentacle overrides seq
    -- space
    phaser_love = 0.5,
    exciter_love = 0.5,
    tilt_center = 0.1,
    -- form
    form_dramatics = 1.5,       -- how dramatic the arc is
    silence_love = 0.3,         -- probability of silence sections
    -- chaos
    chaos_freq = 0.15,
    chaos_magnitude = 0.8,
  },

  OLIVEROS = {
    name = "OLIVEROS",
    activity = {0.4, 0.6, 0.8, 0.3, 0.5, 1.4, 1.0, 0.2},
    topo_drift  = {0, 4, 1},
    topo_build  = {0, 1, 3, 10},
    topo_peak   = {3, 10, 0},
    topo_rest   = {0, 4},
    index_ceiling = 0.7,
    ratio_style = "harmonic",
    ws_change_rate = 0.03,
    cutoff_center = 2000,
    cutoff_range = 3000,
    res_love = 0.3,
    drive_love = 0.05,
    density_range = {0.1, 0.4},
    ratchet_love = 0.02,
    condition_variety = 0.1,
    markov = "clustered",
    melody_inject_rate = 0.05,
    phaser_love = 0.8,
    exciter_love = 0.6,
    tilt_center = 0.2,
    form_dramatics = 0.5,
    silence_love = 0.5,
    chaos_freq = 0.03,
    chaos_magnitude = 0.2,
  },

  BUCHLA = {
    name = "BUCHLA",
    activity = {0.8, 0.9, 1.0, 0.7, 0.8, 0.7, 1.0, 0.5},
    topo_drift  = {0, 1, 4, 10},
    topo_build  = {0, 1, 2, 3, 5, 6},
    topo_peak   = {2, 5, 8, 9},
    topo_rest   = {0, 1, 4},
    index_ceiling = 1.2,
    ratio_style = "harmonic",
    ws_change_rate = 0.08,
    cutoff_center = 3000,
    cutoff_range = 6000,
    res_love = 0.5,
    drive_love = 0.3,
    density_range = {0.4, 0.75},
    ratchet_love = 0.12,
    condition_variety = 0.25,
    markov = "melodic",
    melody_inject_rate = 0.10,
    phaser_love = 0.4,
    exciter_love = 0.3,
    tilt_center = 0.0,
    form_dramatics = 1.0,
    silence_love = 0.2,
    chaos_freq = 0.10,
    chaos_magnitude = 0.5,
  },

  XENAKIS = {
    name = "XENAKIS",
    activity = {1.0, 1.3, 0.8, 1.5, 0.7, 0.6, 0.8, 1.8},
    topo_drift  = {5, 6, 10, 3},
    topo_build  = {2, 5, 8, 11, 6},
    topo_peak   = {9, 8, 5, 2, 11},
    topo_rest   = {5, 6, 3},
    index_ceiling = 2.0,
    ratio_style = "angular",
    ws_change_rate = 0.20,
    cutoff_center = 2500,
    cutoff_range = 10000,
    res_love = 0.7,
    drive_love = 0.6,
    density_range = {0.5, 0.95},
    ratchet_love = 0.35,
    condition_variety = 0.6,
    markov = "angular",
    melody_inject_rate = 0.20,
    phaser_love = 0.3,
    exciter_love = 0.4,
    tilt_center = -0.1,
    form_dramatics = 1.2,
    silence_love = 0.1,
    chaos_freq = 0.30,
    chaos_magnitude = 1.0,
  },

  ENO = {
    name = "ENO",
    activity = {0.3, 0.5, 0.6, 0.2, 0.4, 1.6, 1.2, 0.1},
    topo_drift  = {0, 4, 1},
    topo_build  = {0, 1, 3, 10},
    topo_peak   = {3, 10, 0, 1},
    topo_rest   = {0, 4},
    index_ceiling = 0.8,
    ratio_style = "harmonic",
    ws_change_rate = 0.04,
    cutoff_center = 6000,
    cutoff_range = 4000,
    res_love = 0.2,
    drive_love = 0.05,
    density_range = {0.1, 0.35},
    ratchet_love = 0.01,
    condition_variety = 0.05,
    markov = "melodic",
    melody_inject_rate = 0.03,
    phaser_love = 0.9,
    exciter_love = 0.7,
    tilt_center = 0.3,
    form_dramatics = 0.4,
    silence_love = 0.6,
    chaos_freq = 0.02,
    chaos_magnitude = 0.15,
  },

  COLTRANE = {
    name = "COLTRANE",
    activity = {0.7, 1.2, 1.1, 1.0, 1.5, 0.5, 1.0, 0.6},
    topo_drift  = {0, 1, 2},
    topo_build  = {2, 3, 5, 6},
    topo_peak   = {2, 8, 9, 5, 11},
    topo_rest   = {0, 1},
    index_ceiling = 1.6,
    ratio_style = "melodic",
    ws_change_rate = 0.10,
    cutoff_center = 4500,
    cutoff_range = 7000,
    res_love = 0.4,
    drive_love = 0.35,
    density_range = {0.5, 0.90},
    ratchet_love = 0.25,
    condition_variety = 0.3,
    markov = "melodic",
    melody_inject_rate = 0.25,
    phaser_love = 0.2,
    exciter_love = 0.5,
    tilt_center = 0.15,
    form_dramatics = 1.3,
    silence_love = 0.15,
    chaos_freq = 0.12,
    chaos_magnitude = 0.6,
  },

  MILES = {
    name = "MILES",
    activity = {0.6, 0.7, 0.9, 0.5, 1.2, 0.8, 1.3, 0.3},
    topo_drift  = {0, 4, 1},
    topo_build  = {0, 1, 3},
    topo_peak   = {2, 3, 5},
    topo_rest   = {0, 4, 1},
    index_ceiling = 1.0,
    ratio_style = "harmonic",
    ws_change_rate = 0.06,
    cutoff_center = 3500,
    cutoff_range = 5000,
    res_love = 0.3,
    drive_love = 0.15,
    density_range = {0.25, 0.60},
    ratchet_love = 0.05,
    condition_variety = 0.15,
    markov = "melodic",
    melody_inject_rate = 0.12,
    phaser_love = 0.5,
    exciter_love = 0.3,
    tilt_center = 0.05,
    form_dramatics = 1.4,
    silence_love = 0.4,
    chaos_freq = 0.05,
    chaos_magnitude = 0.3,
  },

  APHEX = {
    name = "APHEX",
    activity = {1.1, 1.0, 0.9, 1.6, 0.8, 0.7, 0.9, 1.3},
    topo_drift  = {1, 5, 6},
    topo_build  = {2, 5, 6, 8},
    topo_peak   = {9, 8, 2, 11, 7},
    topo_rest   = {1, 4, 5},
    index_ceiling = 1.4,
    ratio_style = "angular",
    ws_change_rate = 0.15,
    cutoff_center = 3000,
    cutoff_range = 9000,
    res_love = 0.6,
    drive_love = 0.4,
    density_range = {0.4, 0.95},
    ratchet_love = 0.40,
    condition_variety = 0.5,
    markov = "angular",
    melody_inject_rate = 0.15,
    phaser_love = 0.3,
    exciter_love = 0.4,
    tilt_center = -0.05,
    form_dramatics = 1.1,
    silence_love = 0.2,
    chaos_freq = 0.20,
    chaos_magnitude = 0.7,
  },
}

local SOUL_NAMES = {
  "SUBOTNICK", "OLIVEROS", "BUCHLA", "XENAKIS",
  "ENO", "COLTRANE", "MILES", "APHEX"
}

-- --------------------------------------------------------------------------
-- form phases (controlled by FORM tentacle)
-- --------------------------------------------------------------------------

local FORM_PHASES = {"DRIFT", "BUILD", "PEAK", "REST"}
local FORM_TEMPLATES = {
  {"DRIFT", "BUILD", "PEAK", "REST"},
  {"DRIFT", "DRIFT", "BUILD", "PEAK", "REST", "REST"},
  {"REST", "DRIFT", "BUILD", "BUILD", "PEAK", "DRIFT"},
  {"DRIFT", "BUILD", "PEAK", "PEAK", "REST"},
  {"REST", "BUILD", "PEAK", "REST", "DRIFT", "BUILD", "PEAK"},
  {"DRIFT", "BUILD", "REST", "BUILD", "PEAK", "REST"},
}

-- --------------------------------------------------------------------------
-- state
-- --------------------------------------------------------------------------

octopus.active = false
octopus.soul = "BUCHLA"
octopus.step = 0

-- form state (FORM tentacle manages this)
octopus.form_phase = "DRIFT"
octopus.form_template = FORM_TEMPLATES[1]
octopus.form_idx = 1
octopus.form_beat = 0
octopus.form_length = 32
octopus.cycle = 0

-- scene anchors
octopus.anchors = nil

-- per-tentacle state
octopus.tentacles = {}

-- melodic memory for MELODY tentacle
octopus.melody_memory = {}
octopus.melody_last_note = 48
octopus.melody_root = 48

-- note callback
octopus.note_on_fn = nil

-- --------------------------------------------------------------------------
-- init tentacles
-- --------------------------------------------------------------------------

local function init_tentacle(idx)
  return {
    name = TENTACLE_NAMES[idx],
    energy = 0.0,
    breath_phase = "build",  -- build, play, fade, silence
    breath_timer = 0,
    activity = 1.0,          -- modulated by FORM
    last_action = 0,         -- step count of last action
    cooldown = 0,            -- steps to wait before next action
  }
end

-- --------------------------------------------------------------------------
-- lifecycle
-- --------------------------------------------------------------------------

function octopus.start(soul_name, root)
  octopus.active = true
  octopus.soul = soul_name or "BUCHLA"
  octopus.step = 0
  octopus.cycle = 0
  octopus.melody_root = root or 48
  octopus.melody_last_note = root or 48
  octopus.melody_memory = {}

  -- init all tentacles
  for i = 1, NUM_TENTACLES do
    octopus.tentacles[i] = init_tentacle(i)
    -- stagger initial breath phases so they don't all sync up
    local phases = {"build", "play", "silence", "build", "play", "fade", "build", "silence"}
    octopus.tentacles[i].breath_phase = phases[i]
    octopus.tentacles[i].energy = math.random() * 0.3
  end

  -- form
  octopus.form_template = FORM_TEMPLATES[math.random(#FORM_TEMPLATES)]
  octopus.form_idx = 1
  octopus.form_phase = octopus.form_template[1]
  octopus.form_beat = 0

  local soul = octopus.get_soul()
  octopus.form_length = math.random(20, 40)

  -- save anchors
  octopus.save_anchors()

  -- enable generative sequencer
  local seq = require "lib/sequencer"
  seq.markov_style = soul.markov
end

function octopus.stop()
  octopus.active = false
  -- restore anchors gently
  if octopus.anchors then
    octopus.restore_anchors(0.4)
  end
  local seq = require "lib/sequencer"
  seq.generative = false
  seq.fill_mode = false
end

function octopus.get_soul()
  return SOULS[octopus.soul] or SOULS.BUCHLA
end

function octopus.get_soul_names()
  return SOUL_NAMES
end

-- --------------------------------------------------------------------------
-- anchors
-- --------------------------------------------------------------------------

function octopus.save_anchors()
  octopus.anchors = {}
  local names = {"config", "master_index", "cutoff", "resonance", "drive",
    "phaser_intensity", "phaser_rate", "exciter_amount", "tilt_eq",
    "wsa_preset", "wsb_preset"}
  for _, n in ipairs(names) do
    octopus.anchors[n] = params:get(n)
  end
  for i = 1, 6 do
    octopus.anchors["index" .. i] = params:get("index" .. i)
  end
  for i = 2, 4 do
    octopus.anchors["ratio" .. i] = params:get("ratio" .. i)
  end
end

function octopus.restore_anchors(strength)
  if not octopus.anchors then return end
  local s = strength or 0.3
  for k, v in pairs(octopus.anchors) do
    local current = params:get(k)
    if type(current) == "number" and type(v) == "number" then
      params:set(k, current + (v - current) * s)
    end
  end
end

-- --------------------------------------------------------------------------
-- breathing: each tentacle breathes independently
-- --------------------------------------------------------------------------

local function breathe_tentacle(t, soul, idx)
  t.breath_timer = t.breath_timer + 1
  local act = soul.activity[idx] or 1.0

  if t.breath_phase == "play" then
    t.energy = math.min(1.0, t.energy + 0.02 * act)
    -- higher activity = longer play
    local fade_prob = 0.05 / math.max(act, 0.3)
    if t.breath_timer > math.floor(8 * act) and math.random() < fade_prob then
      t.breath_phase = "fade"
      t.breath_timer = 0
    end

  elseif t.breath_phase == "fade" then
    t.energy = math.max(0.0, t.energy - 0.07)
    if t.energy <= 0.03 then
      t.breath_phase = "silence"
      t.breath_timer = 0
    end

  elseif t.breath_phase == "silence" then
    t.energy = 0
    -- low activity tentacles rest longer
    local rest_dur = math.random(3, math.floor(12 / math.max(act, 0.3)))
    if t.breath_timer > rest_dur then
      t.breath_phase = "build"
      t.breath_timer = 0
    end

  elseif t.breath_phase == "build" then
    t.energy = math.min(0.8, t.energy + 0.04 * act)
    if t.energy >= 0.5 * act then
      t.breath_phase = "play"
      t.breath_timer = 0
    end
  end

  -- form phase modulation
  t.activity = soul.activity[idx] or 1.0
  if octopus.form_phase == "REST" then
    t.activity = t.activity * 0.3
    t.energy = t.energy * 0.5
  elseif octopus.form_phase == "PEAK" then
    t.activity = t.activity * 1.4
    t.energy = math.min(1.0, t.energy * 1.1)
  elseif octopus.form_phase == "BUILD" then
    t.activity = t.activity * 1.1
  end
end

-- --------------------------------------------------------------------------
-- tick: the heartbeat
-- --------------------------------------------------------------------------

function octopus.tick()
  if not octopus.active then return end

  octopus.step = octopus.step + 1
  local soul = octopus.get_soul()

  -- breathe all tentacles
  for i = 1, NUM_TENTACLES do
    breathe_tentacle(octopus.tentacles[i], soul, i)
  end

  -- each tentacle acts at its own interval, gated by energy
  local function should_act(idx, interval)
    local t = octopus.tentacles[idx]
    if t.energy < 0.1 then return false end
    if t.cooldown > 0 then
      t.cooldown = t.cooldown - 1
      return false
    end
    if octopus.step % interval ~= 0 then return false end
    return math.random() < t.energy * t.activity
  end

  -- 1. TOPOLOGY tentacle (every 6 beats)
  if should_act(T_TOPOLOGY, 6) then
    octopus.act_topology(soul)
  end

  -- 2. SPECTRUM tentacle (every 2 beats)
  if should_act(T_SPECTRUM, 2) then
    octopus.act_spectrum(soul)
  end

  -- 3. FILTER tentacle (every 3 beats)
  if should_act(T_FILTER, 3) then
    octopus.act_filter(soul)
  end

  -- 4. RHYTHM tentacle (every 4 beats)
  if should_act(T_RHYTHM, 4) then
    octopus.act_rhythm(soul)
  end

  -- 5. MELODY tentacle (every 3 beats)
  if should_act(T_MELODY, 3) then
    octopus.act_melody(soul)
  end

  -- 6. SPACE tentacle (every 5 beats)
  if should_act(T_SPACE, 5) then
    octopus.act_space(soul)
  end

  -- 7. FORM tentacle (every 1 beat — always active)
  octopus.act_form(soul)

  -- 8. CHAOS tentacle (every 4 beats)
  if should_act(T_CHAOS, 4) then
    octopus.act_chaos(soul)
  end
end

-- --------------------------------------------------------------------------
-- tentacle actions
-- --------------------------------------------------------------------------

local function nudge(name, amount, lo, hi)
  params:set(name, util.clamp(params:get(name) + amount, lo, hi))
end

local function rand_delta(mag)
  return (math.random() * 2 - 1) * mag
end

-- 1. TOPOLOGY: changes FM routing
function octopus.act_topology(soul)
  local t = octopus.tentacles[T_TOPOLOGY]
  local configs
  if octopus.form_phase == "DRIFT" then configs = soul.topo_drift
  elseif octopus.form_phase == "BUILD" then configs = soul.topo_build
  elseif octopus.form_phase == "PEAK" then configs = soul.topo_peak
  else configs = soul.topo_rest end

  local new = configs[math.random(#configs)]
  params:set("config", new + 1)
  t.cooldown = math.random(2, 6)  -- don't change too fast
end

-- 2. SPECTRUM: rides indices, ratios, waveshapes
function octopus.act_spectrum(soul)
  local t = octopus.tentacles[T_SPECTRUM]
  local mag = t.energy * 0.08

  -- indices
  local num = math.random(1, math.floor(1 + t.energy * 3))
  for _ = 1, num do
    local idx = math.random(1, 6)
    nudge("index" .. idx, rand_delta(mag), 0.0, soul.index_ceiling)
  end

  -- master index
  if math.random() < 0.3 then
    nudge("master_index", rand_delta(mag * 2), 0.0, soul.index_ceiling)
  end

  -- ratios (style-dependent)
  if math.random() < 0.15 * t.activity then
    local osc = math.random(2, 4)
    local current = params:get("ratio" .. osc)
    if soul.ratio_style == "harmonic" then
      -- snap toward harmonic
      local harmonics = {0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0}
      local nearest = harmonics[1]
      for _, h in ipairs(harmonics) do
        if math.abs(current - h) < math.abs(current - nearest) then nearest = h end
      end
      params:set("ratio" .. osc, util.clamp(nearest + rand_delta(0.15), 0.25, 8.0))
    elseif soul.ratio_style == "wide" then
      params:set("ratio" .. osc, util.clamp(current + rand_delta(0.5 * t.energy), 0.25, 8.0))
    else -- angular
      params:set("ratio" .. osc, util.clamp(current + rand_delta(0.3 * t.energy), 0.25, 8.0))
    end
  end

  -- waveshape (rare)
  if math.random() < soul.ws_change_rate * t.energy then
    if math.random() < 0.5 then
      params:set("wsa_preset", math.random(1, 8))
    else
      params:set("wsb_preset", math.random(1, 8))
    end
  end
end

-- 3. FILTER: breathes cutoff/resonance/drive
function octopus.act_filter(soul)
  local t = octopus.tentacles[T_FILTER]
  local mag = t.energy * 0.15

  -- cutoff: gravitates toward soul's center, breathes with energy
  local current = params:get("cutoff")
  local pull = (soul.cutoff_center - current) * 0.04
  local sweep = rand_delta(soul.cutoff_range * mag * 0.1)
  params:set("cutoff", util.clamp(current + pull + sweep, 40, 18000))

  -- resonance
  if math.random() < soul.res_love then
    nudge("resonance", rand_delta(mag * 5), 0.0, 3.2)
  end

  -- drive
  if octopus.form_phase == "PEAK" or octopus.form_phase == "BUILD" then
    nudge("drive", math.random() * 0.06 * soul.drive_love, 0.0, soul.drive_love)
  elseif octopus.form_phase == "REST" then
    nudge("drive", -0.04, 0.0, 1.0)
  end
end

-- 4. RHYTHM: mutates sequencer rhythm track
function octopus.act_rhythm(soul)
  local t = octopus.tentacles[T_RHYTHM]
  local seq = require "lib/sequencer"
  local len = seq.track_len[seq.TRACK_RHYTHM]

  local i = math.random(1, len)
  local step = seq.rhythm[i]

  local roll = math.random()
  if roll < 0.35 then
    -- condition change
    if math.random() < soul.condition_variety then
      step.condition = math.random(1, 10)
    else
      step.condition = 1 -- ALWAYS
    end
  elseif roll < 0.55 then
    -- ratchet
    if math.random() < soul.ratchet_love * t.energy then
      step.ratchet = math.random(2, 4)
    else
      step.ratchet = 1
    end
  elseif roll < 0.7 then
    -- accent
    step.accent = not step.accent
  elseif roll < 0.85 then
    -- density: toggle melody steps
    local mi = math.random(1, seq.track_len[seq.TRACK_MELODY])
    seq.melody[mi].on = not seq.melody[mi].on
  else
    -- polymetric: shift rhythm track length
    if octopus.form_phase == "PEAK" or octopus.form_phase == "BUILD" then
      seq.track_len[seq.TRACK_RHYTHM] = math.random(5, 13)
    end
  end

  -- fill mode during PEAK
  seq.fill_mode = (octopus.form_phase == "PEAK" and t.energy > 0.6)
end

-- 5. MELODY: markov evolution + note injection
function octopus.act_melody(soul)
  local t = octopus.tentacles[T_MELODY]
  local seq = require "lib/sequencer"
  local len = seq.track_len[seq.TRACK_MELODY]

  -- mutate 1-2 steps
  local num = math.random(1, 2)
  for _ = 1, num do
    local i = math.random(1, len)
    local step = seq.melody[i]

    if math.random() < 0.5 then
      -- markov note change
      step.note = seq.markov_next(step.note)
      -- remember for motivic development
      table.insert(octopus.melody_memory, step.note)
      if #octopus.melody_memory > 12 then
        table.remove(octopus.melody_memory, 1)
      end
    else
      -- motivic: reuse a remembered interval
      if #octopus.melody_memory > 2 then
        local mem = octopus.melody_memory[math.random(#octopus.melody_memory)]
        local interval = mem - step.note
        while interval > 12 do interval = interval - 12 end
        while interval < -12 do interval = interval + 12 end
        step.note = util.clamp(step.note + interval, 24, 96)
      end
    end

    -- velocity dynamics
    step.vel = util.clamp(step.vel + rand_delta(0.1), 0.2, 1.0)
  end

  -- direct note injection: bandmate-like autonomous notes
  if math.random() < soul.melody_inject_rate * t.energy then
    local note = seq.markov_next(octopus.melody_last_note)
    octopus.melody_last_note = note
    local vel = 0.3 + t.energy * 0.5
    local gate = 0.1 + math.random() * 0.6
    if octopus.note_on_fn then
      octopus.note_on_fn(note, vel, gate)
    end
  end

  -- enable/disable generative mode based on form
  seq.generative = (octopus.form_phase == "PEAK" or
    (octopus.form_phase == "BUILD" and t.energy > 0.6))
end

-- 6. SPACE: phaser, exciter, tilt
function octopus.act_space(soul)
  local t = octopus.tentacles[T_SPACE]
  local mag = t.energy * 0.06

  -- phaser
  if octopus.form_phase ~= "REST" then
    nudge("phaser_intensity", rand_delta(mag) * soul.phaser_love, 0.0, 0.9)
    if math.random() < 0.25 then
      nudge("phaser_rate", rand_delta(0.3), 0.1, 5.0)
    end
  else
    nudge("phaser_intensity", -0.03, 0.0, 1.0)
  end

  -- exciter
  nudge("exciter_amount", rand_delta(mag) * soul.exciter_love, 0.0, 0.8)

  -- tilt: drift toward soul center
  local tilt_pull = (soul.tilt_center - params:get("tilt_eq")) * 0.08
  nudge("tilt_eq", tilt_pull + rand_delta(0.05), -0.8, 0.8)
end

-- 7. FORM: the conductor
function octopus.act_form(soul)
  octopus.form_beat = octopus.form_beat + 1

  -- phase transition
  if octopus.form_beat >= octopus.form_length then
    octopus.form_beat = 0
    octopus.form_idx = octopus.form_idx + 1

    if octopus.form_idx > #octopus.form_template then
      -- new form template
      octopus.form_template = FORM_TEMPLATES[math.random(#FORM_TEMPLATES)]
      octopus.form_idx = 1
      octopus.cycle = octopus.cycle + 1

      -- occasionally re-anchor
      if math.random() < 0.25 then
        octopus.save_anchors()
      end
    end

    octopus.form_phase = octopus.form_template[octopus.form_idx]

    -- phase length varies by soul dramatics
    local base = math.random(16, 40)
    octopus.form_length = math.floor(base / soul.form_dramatics)

    -- phase entry effects
    if octopus.form_phase == "REST" then
      -- pull toward anchors
      octopus.restore_anchors(0.3)
      -- silence some tentacles
      if math.random() < soul.silence_love then
        local victim = math.random(1, 6)  -- not FORM or CHAOS
        octopus.tentacles[victim].breath_phase = "fade"
      end
    elseif octopus.form_phase == "PEAK" then
      -- energize all tentacles
      for i = 1, NUM_TENTACLES do
        octopus.tentacles[i].energy = math.max(octopus.tentacles[i].energy, 0.6)
        octopus.tentacles[i].breath_phase = "play"
      end
    elseif octopus.form_phase == "DRIFT" then
      -- gentle pull toward anchors
      octopus.restore_anchors(0.15)
    end
  end
end

-- 8. CHAOS: the wild card
function octopus.act_chaos(soul)
  local t = octopus.tentacles[T_CHAOS]
  if math.random() > soul.chaos_freq * t.energy then return end

  local mag = soul.chaos_magnitude * t.energy
  local seq = require "lib/sequencer"

  local roll = math.random()
  if roll < 0.2 then
    -- p-lock storm: add multiple random p-locks
    local num = math.random(2, 5)
    for _ = 1, num do
      local step_idx = math.random(1, seq.track_len[seq.TRACK_TIMBRE])
      local step = seq.timbre[step_idx]
      local what = math.random(1, 5)
      if what == 1 then step.config = math.random(0, 11)
      elseif what == 2 then step.cutoff = math.random(100, 12000)
      elseif what == 3 then step.master_index = math.random() * soul.index_ceiling
      elseif what == 4 then step.wsa = math.random(0, 7)
      elseif what == 5 then step.wsb = math.random(0, 7)
      end
    end
  elseif roll < 0.35 then
    -- polymetric disruption: randomize all track lengths
    seq.track_len[seq.TRACK_MELODY] = math.random(5, 13)
    seq.track_len[seq.TRACK_TIMBRE] = math.random(5, 13)
    seq.track_len[seq.TRACK_RHYTHM] = math.random(5, 13)
  elseif roll < 0.5 then
    -- index explosion
    for i = 1, 6 do
      params:set("index" .. i, math.random() * soul.index_ceiling * mag)
    end
  elseif roll < 0.65 then
    -- ratchet storm
    for i = 1, seq.track_len[seq.TRACK_RHYTHM] do
      if math.random() < 0.4 then
        seq.rhythm[i].ratchet = math.random(2, 4)
      end
    end
    t.cooldown = 4
  elseif roll < 0.8 then
    -- filter sweep: sudden dramatic cutoff change
    local target = math.random() < 0.5 and 100 or 12000
    params:set("cutoff", target)
    t.cooldown = 3
  else
    -- topology rapid-fire: set per-step topologies
    for i = 1, seq.track_len[seq.TRACK_TIMBRE] do
      if math.random() < 0.5 * mag then
        seq.timbre[i].config = math.random(0, 11)
      end
    end
  end
end

-- --------------------------------------------------------------------------
-- set soul
-- --------------------------------------------------------------------------

function octopus.set_soul(name)
  if SOULS[name] then
    octopus.soul = name
    -- update sequencer markov style
    local seq = require "lib/sequencer"
    seq.markov_style = SOULS[name].markov
  end
end

-- --------------------------------------------------------------------------
-- info
-- --------------------------------------------------------------------------

function octopus.get_info()
  local energies = {}
  for i = 1, NUM_TENTACLES do
    energies[i] = octopus.tentacles[i] and octopus.tentacles[i].energy or 0
  end
  return {
    soul = octopus.soul,
    form = octopus.form_phase,
    form_beat = octopus.form_beat,
    form_length = octopus.form_length,
    cycle = octopus.cycle,
    energies = energies,
    tentacle_names = TENTACLE_NAMES,
  }
end

function octopus.get_tentacle_energy(idx)
  if octopus.tentacles[idx] then
    return octopus.tentacles[idx].energy
  end
  return 0
end

-- exports
octopus.SOUL_NAMES = SOUL_NAMES
octopus.TENTACLE_NAMES = TENTACLE_NAMES
octopus.NUM_TENTACLES = NUM_TENTACLES

return octopus
