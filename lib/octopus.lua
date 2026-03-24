-- bucha octopus
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
    index_ceiling = 1.8,
    ratio_style = "wide",       -- big intervallic leaps in ratios
    ws_change_rate = 0.12,
    -- filter character
    cutoff_center = 7000,
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
    index_ceiling = 1.2,
    ratio_style = "harmonic",
    ws_change_rate = 0.03,
    cutoff_center = 5500,
    cutoff_range = 5000,
    res_love = 0.3,
    drive_love = 0.05,
    density_range = {0.1, 0.4},
    ratchet_love = 0.02,
    condition_variety = 0.1,
    markov = "clustered",
    melody_inject_rate = 0.05,
    phaser_love = 0.8,
    exciter_love = 0.6,
    tilt_center = 0.3,
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
    index_ceiling = 1.5,
    ratio_style = "harmonic",
    ws_change_rate = 0.08,
    cutoff_center = 6500,
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
    tilt_center = 0.1,
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
    index_ceiling = 2.2,
    ratio_style = "angular",
    ws_change_rate = 0.20,
    cutoff_center = 6000,
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
    index_ceiling = 1.3,
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
    index_ceiling = 1.8,
    ratio_style = "melodic",
    ws_change_rate = 0.10,
    cutoff_center = 7000,
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
    index_ceiling = 1.5,
    ratio_style = "harmonic",
    ws_change_rate = 0.06,
    cutoff_center = 6000,
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
    index_ceiling = 1.8,
    ratio_style = "angular",
    ws_change_rate = 0.15,
    cutoff_center = 6500,
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

  -- FUNK: Clyde Stubblefield meets Zigaboo Modeliste meets Tony Allen.
  -- THE ONE is sacred. Everything syncopates around it.
  -- Ghost notes, displaced accents, auto-wah, tight pocket.
  FUNK = {
    name = "FUNK",
    -- RHYTHM tentacle is the STAR. FILTER is the wah. MELODY is tight.
    activity = {0.5, 0.8, 1.5, 2.0, 1.0, 0.6, 1.2, 0.4},
    -- topologies: warm, fat, not metallic
    topo_drift  = {0, 1, 4},
    topo_build  = {0, 1, 3, 4},
    topo_peak   = {0, 2, 3, 5},
    topo_rest   = {0, 4, 1},
    -- spectrum: warm, fat, sub-heavy
    index_ceiling = 1.3,           -- enough for character, not just warmth
    ratio_style = "harmonic",      -- clean ratios
    ws_change_rate = 0.04,         -- stable waveshape
    -- filter: auto-wah territory
    cutoff_center = 4000,          -- higher center, wah sweeps around it
    cutoff_range = 6000,           -- wide for wah sweeps
    res_love = 0.5,                -- enough for wah character
    drive_love = 0.35,             -- warm saturation
    -- rhythm: THIS IS IT
    density_range = {0.6, 0.95},   -- dense but with pockets
    ratchet_love = 0.15,           -- tasteful 16th fills, not machine gun
    condition_variety = 0.35,      -- syncopation through conditions
    -- melody: tight, pentatonic, close to root
    markov = "funky",
    melody_inject_rate = 0.18,     -- regular injection
    -- space: tight, dry
    phaser_love = 0.15,            -- minimal phasing
    exciter_love = 0.2,            -- subtle presence
    tilt_center = -0.1,            -- slightly dark
    -- form: locked groove, occasional breaks
    form_dramatics = 0.8,          -- longer phases = deeper pocket
    silence_love = 0.08,           -- almost never silent — the groove doesn't stop
    -- chaos: minimal — funk is DISCIPLINE
    chaos_freq = 0.05,
    chaos_magnitude = 0.3,
    -- FUNK-SPECIFIC fields
    is_funk = true,
    swing_range = {55, 68},        -- swing amount range
    ghost_velocity = 0.25,         -- ghost note velocity
    accent_velocity = 1.0,         -- accent velocity
  },

  -- REICH: Steve Reich — phasing, gradual process, pulsing textures.
  -- Minimal changes, long form. The octopus barely moves but when it does, SIGNIFICANT.
  REICH = {
    name = "REICH",
    activity = {0.2, 0.3, 0.4, 0.6, 0.7, 1.0, 1.8, 0.1},  -- FORM is hyperactive, rhythm steady
    topo_drift  = {0, 1, 4},
    topo_build  = {0, 1, 3},
    topo_peak   = {0, 1, 2, 3},
    topo_rest   = {0, 4},
    index_ceiling = 1.0,
    ratio_style = "harmonic",    -- pure intervals
    ws_change_rate = 0.01,       -- almost never changes
    cutoff_center = 8000,        -- bright, present
    cutoff_range = 3000,         -- narrow range
    res_love = 0.2,
    drive_love = 0.1,
    density_range = {0.7, 0.95}, -- dense, pulsing
    ratchet_love = 0.05,
    condition_variety = 0.1,     -- very regular
    markov = "melodic",
    melody_inject_rate = 0.03,   -- barely injects — the PATTERN is the music
    phaser_love = 0.9,           -- phasing IS the point
    exciter_love = 0.5,
    tilt_center = 0.15,
    form_dramatics = 0.3,        -- very gradual, long arcs
    silence_love = 0.05,         -- almost never silent
    chaos_freq = 0.02,
    chaos_magnitude = 0.2,
  },

  -- DAVIS: Electric Miles — Bitches Brew, dark star, wah-wah trumpet through effects.
  -- Space, tension, explosion.
  DAVIS = {
    name = "DAVIS",
    activity = {0.7, 0.8, 1.4, 0.6, 1.0, 1.2, 1.5, 0.5},  -- FILTER and FORM are stars
    topo_drift  = {0, 1, 4},
    topo_build  = {0, 2, 3, 5},
    topo_peak   = {2, 5, 8, 9},
    topo_rest   = {0, 4, 1},
    index_ceiling = 1.6,
    ratio_style = "melodic",
    ws_change_rate = 0.08,
    cutoff_center = 5000,        -- mid-focused like a trumpet
    cutoff_range = 8000,         -- wide wah sweeps
    res_love = 0.6,              -- resonant, vocal quality
    drive_love = 0.5,            -- warm distortion
    density_range = {0.3, 0.7},  -- spacious
    ratchet_love = 0.08,
    condition_variety = 0.2,
    markov = "melodic",
    melody_inject_rate = 0.15,
    phaser_love = 0.6,
    exciter_love = 0.5,
    tilt_center = 0.0,           -- balanced, not bright
    form_dramatics = 1.6,        -- very dramatic arcs
    silence_love = 0.45,         -- silence is part of the music
    chaos_freq = 0.08,
    chaos_magnitude = 0.5,
  },

  -- SUN_RA: cosmic chaos, cluster chords, free rhythm. Space is the place.
  -- The wildest soul.
  SUN_RA = {
    name = "SUN RA",
    activity = {1.5, 1.4, 1.0, 1.3, 1.2, 1.0, 0.8, 2.0},  -- everything is ON, CHAOS is king
    topo_drift  = {5, 6, 9, 10, 11},
    topo_build  = {2, 5, 8, 9, 11, 7},
    topo_peak   = {9, 8, 7, 11, 5, 2},
    topo_rest   = {5, 6, 10},
    index_ceiling = 2.5,          -- EXTREME FM
    ratio_style = "angular",      -- inharmonic, alien
    ws_change_rate = 0.25,        -- constant shape shifting
    cutoff_center = 7000,         -- bright, cosmic
    cutoff_range = 12000,         -- full range sweeps
    res_love = 0.7,
    drive_love = 0.6,
    density_range = {0.4, 1.0},   -- can go to total density
    ratchet_love = 0.45,          -- machine gun ratchets
    condition_variety = 0.7,      -- very irregular
    markov = "angular",
    melody_inject_rate = 0.30,    -- constant injection
    phaser_love = 0.5,
    exciter_love = 0.6,
    tilt_center = 0.1,
    form_dramatics = 1.8,         -- extreme dramatics
    silence_love = 0.15,
    chaos_freq = 0.40,            -- VERY chaotic
    chaos_magnitude = 1.2,        -- EXTREME magnitude
  },
}

local SOUL_NAMES = {
  "SUBOTNICK", "OLIVEROS", "BUCHLA", "XENAKIS",
  "ENO", "COLTRANE", "MILES", "APHEX", "FUNK",
  "REICH", "DAVIS", "SUN_RA"
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

-- funk templates: heavy groove, short breaks, locked pocket
local FUNK_FORM_TEMPLATES = {
  {"BUILD", "PEAK", "PEAK", "PEAK", "REST"},              -- long groove, short break
  {"BUILD", "PEAK", "PEAK", "BUILD", "PEAK", "REST"},     -- double build
  {"PEAK", "PEAK", "PEAK", "REST", "PEAK", "PEAK"},       -- barely rests
  {"DRIFT", "BUILD", "PEAK", "PEAK", "PEAK", "PEAK", "REST"}, -- slow burn to locked groove
  {"PEAK", "REST", "PEAK", "PEAK", "REST", "PEAK"},       -- call and response sections
  {"BUILD", "BUILD", "PEAK", "PEAK", "PEAK", "REST", "BUILD", "PEAK"}, -- long build
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
octopus.next_pan = nil  -- spatial pan set by SPACE tentacle, consumed by seq_step

-- scene anchors
octopus.anchors = nil

-- per-tentacle state
octopus.tentacles = {}

-- melodic memory for MELODY tentacle
octopus.melody_memory = {}
octopus.melody_last_note = 48
octopus.melody_root = 48

-- duo mode state
octopus.duo_voice = "A"      -- current speaking voice
octopus.duo_phrase_notes = 0  -- notes played in current phrase

-- note callback
octopus.note_on_fn = nil

-- phase change callback (for scale progression)
octopus.on_phase_change = nil

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

  -- init all tentacles — start hot, already breathing
  for i = 1, NUM_TENTACLES do
    octopus.tentacles[i] = init_tentacle(i)
    -- stagger phases but start with high energy so it's immediately alive
    local phases = {"play", "play", "build", "play", "play", "play", "play", "build"}
    octopus.tentacles[i].breath_phase = phases[i]
    octopus.tentacles[i].energy = 0.5 + math.random() * 0.4
  end

  -- form
  local soul = octopus.get_soul()

  -- pick form template based on soul
  if soul.is_funk then
    octopus.form_template = FUNK_FORM_TEMPLATES[math.random(#FUNK_FORM_TEMPLATES)]
  else
    octopus.form_template = FORM_TEMPLATES[math.random(#FORM_TEMPLATES)]
  end
  octopus.form_idx = 1
  octopus.form_phase = octopus.form_template[1]
  octopus.form_beat = 0

  octopus.form_length = math.random(20, 40)

  -- save anchors
  octopus.save_anchors()

  -- enable generative sequencer
  local seq = octopus.seq
  seq.markov_style = soul.markov

  -- FUNK: lay down initial groove pattern + set swing + start sequencer
  if soul.is_funk then
    -- ensure 16-step pattern for funk
    seq.track_len[seq.TRACK_MELODY] = 16
    seq.track_len[seq.TRACK_RHYTHM] = 16
    seq.track_len[seq.TRACK_TIMBRE] = 16
    apply_funk_pattern(seq, soul)
    local sw = soul.swing_range or {55, 65}
    seq.swing = math.random(sw[1], sw[2])
    -- start the sequencer if not already playing
    if not seq.playing then
      seq.playing = true
      seq.reset()
    end
    -- FUNK TIMBRE: short punchy envelope, warm filter, sub bass
    params:set("attack", 0.001)
    params:set("decay", 0.15)
    params:set("sustain_level", 0.3)
    params:set("release", 0.08)
    params:set("sub_osc", 0.3)
    params:set("noise", 0.02)
    params:set("cutoff", 1800)
    params:set("resonance", 0.8)
    params:set("drive", 0.15)
    params:set("lfo_filter", 0.25)
    params:set("lfo_filter_rate", 4)
    -- warm topology
    params:set("config", 1)  -- SYMMETRIC = fat
    params:set("master_index", 0.4)
    -- seq division to 1/16 for funk
    params:set("seq_division", 5)
    -- set seq gate short for tight funk
    params:set("seq_gate", 0.3)
    -- add timbre p-locks for variation
    for i = 1, 16 do
      local step = seq.timbre[i]
      if math.random() < 0.35 then
        step.config = ({0, 1, 3, 4})[math.random(4)]  -- warm topologies
      end
      if math.random() < 0.25 then
        step.cutoff = math.random(800, 4000)  -- filter variation per step
      end
      -- accented steps get brighter filter
      if seq.melody[i] and seq.melody[i].vel > 0.7 then
        step.cutoff = math.random(2500, 6000)
      end
    end
  end
end

function octopus.stop()
  octopus.active = false
  -- restore anchors gently
  if octopus.anchors then
    octopus.restore_anchors(0.4)
  end
  local seq = octopus.seq
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
    "wsa_preset", "wsb_preset", "attack", "decay", "sustain_level", "release",
    "noise", "sub_osc", "trem_rate", "trem_depth", "lfo_filter", "lfo_filter_rate",
    "delay_mix", "delay_time", "delay_feedback", "reverb_mix", "reverb_size",
    "chorus_mix"}
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
    t.energy = math.min(1.0, t.energy + 0.04 * act)
    -- higher activity = longer play, but always eventually fade
    local fade_prob = 0.03 / math.max(act, 0.3)
    if t.breath_timer > math.floor(12 * act) and math.random() < fade_prob then
      t.breath_phase = "fade"
      t.breath_timer = 0
    end

  elseif t.breath_phase == "fade" then
    t.energy = math.max(0.15, t.energy - 0.05)  -- never fully dies
    if t.energy <= 0.2 then
      t.breath_phase = "build"  -- skip silence, go straight to build
      t.breath_timer = 0
    end

  elseif t.breath_phase == "silence" then
    t.energy = 0.1  -- even silence has a pulse
    local rest_dur = math.random(2, math.floor(6 / math.max(act, 0.3)))
    if t.breath_timer > rest_dur then
      t.breath_phase = "build"
      t.breath_timer = 0
    end

  elseif t.breath_phase == "build" then
    t.energy = math.min(0.9, t.energy + 0.06 * act)
    if t.energy >= 0.4 then
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
  -- low gate threshold = more active
  local function should_act(idx, interval)
    local t = octopus.tentacles[idx]
    if t.cooldown > 0 then
      t.cooldown = t.cooldown - 1
      return false
    end
    if octopus.step % interval ~= 0 then return false end
    -- very low threshold: even tired tentacles act sometimes
    return math.random() < (0.3 + t.energy * 0.7) * t.activity
  end

  -- ALL tentacles fire frequently — this thing is ALIVE
  -- 1. TOPOLOGY (every 4 beats)
  if should_act(T_TOPOLOGY, 4) then octopus.act_topology(soul) end

  -- 2. SPECTRUM (EVERY beat — this is the pulse)
  if should_act(T_SPECTRUM, 1) then octopus.act_spectrum(soul) end

  -- 3. FILTER (every 2 beats — breathing)
  if should_act(T_FILTER, 2) then octopus.act_filter(soul) end

  -- 4. RHYTHM (every 3 beats)
  if should_act(T_RHYTHM, 3) then octopus.act_rhythm(soul) end

  -- 5. MELODY (every 2 beats — always generating)
  if should_act(T_MELODY, 2) then octopus.act_melody(soul) end

  -- 6. SPACE (every 3 beats)
  if should_act(T_SPACE, 3) then octopus.act_space(soul) end

  -- 7. FORM (every beat — conductor is always listening)
  octopus.act_form(soul)

  -- 8. CHAOS (every 3 beats)
  if should_act(T_CHAOS, 3) then octopus.act_chaos(soul) end
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

  -- FUNK: timbral variation — not organ, ALIVE
  if soul.is_funk then
    local mag = t.energy * 0.1

    -- envelope variation: short stabs vs medium groove vs occasional legato
    if math.random() < 0.25 then
      local roll = math.random()
      if roll < 0.4 then
        -- tight stab
        params:set("attack", 0.001)
        params:set("decay", 0.05 + math.random() * 0.1)
        params:set("sustain_level", 0.1 + math.random() * 0.2)
        params:set("release", 0.03 + math.random() * 0.05)
      elseif roll < 0.75 then
        -- medium groove
        params:set("attack", 0.001 + math.random() * 0.01)
        params:set("decay", 0.1 + math.random() * 0.2)
        params:set("sustain_level", 0.2 + math.random() * 0.3)
        params:set("release", 0.05 + math.random() * 0.1)
      else
        -- occasional legato
        params:set("attack", 0.01 + math.random() * 0.05)
        params:set("decay", 0.3 + math.random() * 0.3)
        params:set("sustain_level", 0.5 + math.random() * 0.3)
        params:set("release", 0.2 + math.random() * 0.3)
      end
    end

    -- gate length variation on sequencer steps
    if math.random() < 0.3 then
      local seq = octopus.seq
      local len = seq.track_len[seq.TRACK_MELODY]
      for i = 1, len do
        local step = seq.melody[i]
        if step then
          if step.vel < 0.4 then
            step.gate = 0.1 + math.random() * 0.1  -- ghost = very short
          elseif step.vel > 0.7 then
            step.gate = 0.3 + math.random() * 0.2  -- accent = medium
          else
            step.gate = math.random() < 0.2 and 0.7 or 0.2  -- occasional legato
          end
        end
      end
    end

    -- drive variation: gritty vs clean
    if math.random() < 0.2 then
      nudge("drive", rand_delta(0.06), 0.0, 0.35)
    end

    -- sub + noise during PEAK
    if octopus.form_phase == "PEAK" then
      nudge("sub_osc", rand_delta(0.03), 0.1, 0.4)
      nudge("noise", rand_delta(0.01), 0.0, 0.06)
    end

    -- cutoff variation: wah-like movement
    nudge("cutoff", rand_delta(300 * t.energy), 600, 5000)

    -- topology: occasionally switch between warm configs
    if math.random() < 0.08 then
      local warm_configs = {0, 1, 3, 4}
      params:set("config", warm_configs[math.random(#warm_configs)] + 1)
    end

    return
  end

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

  -- texture: noise, sub, tremolo, LFO filter, envelope
  -- ALL of these should be much more active
  if math.random() < 0.45 * t.energy then
    -- noise: builds with form phase
    if octopus.form_phase == "PEAK" then
      nudge("noise", math.random() * 0.06, 0.0, 0.4)
    elseif octopus.form_phase == "BUILD" then
      nudge("noise", rand_delta(0.04) * t.energy, 0.0, 0.3)
    else
      nudge("noise", -0.02, 0.0, 0.4)
    end
  end
  if math.random() < 0.35 * t.energy then
    -- sub: adds real weight during intense passages
    if octopus.form_phase == "BUILD" or octopus.form_phase == "PEAK" then
      nudge("sub_osc", math.random() * 0.06, 0.0, 0.45)
    elseif octopus.form_phase == "REST" then
      nudge("sub_osc", -0.04, 0.0, 0.45)
    else
      nudge("sub_osc", rand_delta(0.02), 0.0, 0.3)
    end
  end
  if math.random() < 0.3 then
    -- tremolo: more dramatic, form-dependent
    if octopus.form_phase == "BUILD" or octopus.form_phase == "PEAK" then
      nudge("trem_depth", rand_delta(0.08 * t.energy), 0.0, 0.7)
      nudge("trem_rate", rand_delta(2.0), 0.5, 18)
    else
      nudge("trem_depth", -0.03, 0.0, 0.7)
    end
  end
  if math.random() < 0.35 then
    -- LFO > filter (auto-wah): dramatic sweeps
    if octopus.form_phase == "PEAK" then
      nudge("lfo_filter", math.random() * 0.08, 0.0, 0.8)
      nudge("lfo_filter_rate", rand_delta(1.5), 0.2, 15)
    elseif octopus.form_phase == "BUILD" then
      nudge("lfo_filter", rand_delta(0.05 * t.energy), 0.0, 0.6)
      nudge("lfo_filter_rate", rand_delta(0.8), 0.2, 12)
    else
      nudge("lfo_filter", -0.03, 0.0, 0.8)
    end
  end
  if math.random() < 0.3 then
    -- envelope shape shifting: dramatic character changes
    local roll = math.random()
    if octopus.form_phase == "PEAK" then
      -- PEAK: short punchy attacks, variable everything
      if roll < 0.3 then
        params:set("attack", math.random() * 0.02 + 0.001)
      elseif roll < 0.6 then
        nudge("decay", rand_delta(0.25 * t.energy), 0.01, 3.0)
      elseif roll < 0.8 then
        nudge("sustain_level", rand_delta(0.12), 0.1, 1.0)
      else
        nudge("release", rand_delta(0.3 * t.energy), 0.01, 4.0)
      end
    elseif octopus.form_phase == "DRIFT" then
      -- DRIFT: longer attacks, sustained
      if roll < 0.4 then
        nudge("attack", math.random() * 0.15, 0.01, 1.5)
      elseif roll < 0.7 then
        nudge("sustain_level", rand_delta(0.06), 0.3, 1.0)
      else
        nudge("release", rand_delta(0.2), 0.1, 4.0)
      end
    else
      -- BUILD/REST: moderate changes
      if roll < 0.3 then
        nudge("attack", rand_delta(0.08 * t.energy), 0.001, 1.5)
      elseif roll < 0.6 then
        nudge("decay", rand_delta(0.15 * t.energy), 0.01, 3.0)
      elseif roll < 0.8 then
        nudge("sustain_level", rand_delta(0.08), 0.1, 1.0)
      else
        nudge("release", rand_delta(0.15 * t.energy), 0.01, 4.0)
      end
    end
  end
end

-- 3. FILTER: the lungs — BREATHES with dramatic sweeps
function octopus.act_filter(soul)
  local t = octopus.tentacles[T_FILTER]
  local mag = t.energy * 0.25

  -- FUNK: auto-wah behavior — LFO filter does the talking
  if soul.is_funk then
    local current = params:get("cutoff")
    -- cutoff: tight around center, the LFO does the sweep
    local pull = (soul.cutoff_center - current) * 0.06  -- gentler pull for FUNK too
    params:set("cutoff", util.clamp(current + pull + rand_delta(200), 40, 18000))

    -- LFO > filter: the auto-wah engine
    if octopus.form_phase == "PEAK" or octopus.form_phase == "BUILD" then
      -- open the wah: push LFO filter amount up
      nudge("lfo_filter", math.random() * 0.06 * t.energy, 0.0, 0.7)
      -- rate syncs loosely to groove feel
      local wah_rates = {2, 3, 4, 6, 8}
      if math.random() < 0.2 then
        params:set("lfo_filter_rate", wah_rates[math.random(#wah_rates)])
      end
    elseif octopus.form_phase == "REST" then
      nudge("lfo_filter", -0.04, 0.0, 0.8)
    else
      nudge("lfo_filter", rand_delta(0.03), 0.0, 0.5)
    end

    -- resonance: enough for wah character
    nudge("resonance", rand_delta(mag * 3), 0.0, 1.8)

    -- drive: warm, not harsh
    nudge("drive", rand_delta(0.02), 0.0, soul.drive_love)
    return
  end

  -- NON-FUNK: original behavior
  local current = params:get("cutoff")
  local pull = (soul.cutoff_center - current) * 0.03  -- gentle pull, don't fight the user

  local sweep_mult = 1.0
  if octopus.form_phase == "PEAK" then sweep_mult = 2.5
  elseif octopus.form_phase == "BUILD" then sweep_mult = 1.8
  elseif octopus.form_phase == "REST" then sweep_mult = 0.5 end

  local sweep = rand_delta(soul.cutoff_range * mag * 0.15 * sweep_mult)
  params:set("cutoff", util.clamp(current + pull + sweep, 40, 18000))

  -- resonance: more dramatic, form-dependent
  if math.random() < soul.res_love * (0.8 + t.energy * 0.4) then
    local res_delta = rand_delta(mag * 8)
    if octopus.form_phase == "PEAK" then
      res_delta = res_delta * 1.5
    end
    nudge("resonance", res_delta, 0.0, 3.2)
  end

  -- drive: builds significantly during BUILD/PEAK
  if octopus.form_phase == "PEAK" then
    nudge("drive", math.random() * 0.10 * soul.drive_love, 0.0, soul.drive_love * 1.3)
  elseif octopus.form_phase == "BUILD" then
    nudge("drive", math.random() * 0.06 * soul.drive_love, 0.0, soul.drive_love)
  elseif octopus.form_phase == "REST" then
    nudge("drive", -0.06, 0.0, 1.0)
  else
    nudge("drive", rand_delta(0.02), 0.0, soul.drive_love * 0.7)
  end
end

-- --------------------------------------------------------------------------
-- FUNK RHYTHM ENGINE
-- syncopation patterns inspired by classic funk drumming
-- --------------------------------------------------------------------------

-- funk accent patterns (16 steps): 1 = accent, 0.5 = ghost, 0 = rest
-- these are the SKELETON — the tentacle mutates around them
local FUNK_PATTERNS = {
  -- Clyde Stubblefield "Funky Drummer" feel
  {1, 0, 0.5, 0, 0.5, 0, 1, 0.5, 0, 0.5, 1, 0, 0.5, 0, 0.5, 0},
  -- Zigaboo Modeliste "Cissy Strut" feel
  {1, 0, 0, 0.5, 0, 0.5, 1, 0, 0.5, 0, 0, 0.5, 1, 0, 0.5, 0},
  -- Tony Allen Afrobeat
  {1, 0, 0.5, 0.5, 0, 1, 0, 0.5, 0, 0.5, 1, 0, 0.5, 0, 0.5, 0.5},
  -- David Garibaldi "What Is Hip" linear funk
  {1, 0, 0, 0.5, 0.5, 0, 1, 0, 0, 0.5, 0, 1, 0, 0.5, 0, 0.5},
  -- Questlove pocket
  {1, 0, 0.5, 0, 0, 0.5, 0, 1, 0, 0.5, 0, 0, 1, 0, 0.5, 0},
  -- Jabo Starks "Super Bad" feel
  {1, 0.5, 0, 0.5, 0, 0, 1, 0, 0.5, 0, 0.5, 0, 0, 1, 0, 0.5},
  -- Parliament "Flashlight" feel
  {1, 0, 0, 0, 0.5, 0, 0.5, 0, 1, 0, 0, 0.5, 0, 0.5, 0, 0},
  -- Tower of Power displaced pocket
  {0.5, 0, 1, 0, 0, 0.5, 0, 1, 0.5, 0, 0, 1, 0, 0.5, 0, 0.5},
}

local function apply_funk_pattern(seq, soul)
  local pattern = FUNK_PATTERNS[math.random(#FUNK_PATTERNS)]
  local mel_len = seq.track_len[seq.TRACK_MELODY]
  local rhy_len = seq.track_len[seq.TRACK_RHYTHM]

  -- generate funk bass line: pentatonic around root
  local root = seq.root or 48
  -- ensure root is in a good bass range (36-60)
  while root < 36 do root = root + 12 end
  while root > 60 do root = root - 12 end
  local penta = {0, 3, 5, 7, 10, 12}
  for i = 1, math.min(mel_len, 16) do
    local step = seq.melody[i]
    -- funk bass: mostly root and fifth, with pentatonic fills
    local roll = math.random()
    if roll < 0.35 then
      step.note = root  -- sit on the root
    elseif roll < 0.55 then
      step.note = root + 7  -- the fifth
    elseif roll < 0.7 then
      step.note = root + 12  -- octave up
    else
      step.note = root + penta[math.random(#penta)]
    end
  end

  for i = 1, math.min(mel_len, 16) do
    local p = pattern[i] or 0
    local step = seq.melody[i]
    local rstep = seq.rhythm[i]

    if p >= 1 then
      -- ACCENT: loud, always fire
      step.on = true
      step.vel = soul.accent_velocity or 1.0
      if rstep then
        rstep.condition = 1   -- ALWAYS
        rstep.accent = true
        rstep.ratchet = 1
      end
    elseif p >= 0.5 then
      -- GHOST NOTE: quiet, high probability
      step.on = true
      step.vel = (soul.ghost_velocity or 0.25) + math.random() * 0.1
      if rstep then
        rstep.condition = math.random() < 0.8 and 1 or 2  -- mostly ALWAYS, sometimes 75%
        rstep.accent = false
        rstep.ratchet = 1
      end
    else
      -- REST: sometimes a ghost sneaks in
      step.on = math.random() < 0.15
      step.vel = (soul.ghost_velocity or 0.25) * 0.7
      if rstep then
        rstep.condition = math.random() < 0.7 and 4 or 10  -- 25% or RANDOM
        rstep.accent = false
        rstep.ratchet = 1
      end
    end
  end
end

local function mutate_funk_step(seq, soul, step_idx)
  -- funk-aware single step mutation
  local step = seq.melody[step_idx]
  local rstep = seq.rhythm[step_idx]
  if not step or not rstep then return end

  local roll = math.random()
  if roll < 0.25 then
    -- flip accent/ghost: the heart of syncopation
    if step.vel > 0.6 then
      -- accent becomes ghost
      step.vel = (soul.ghost_velocity or 0.25) + math.random() * 0.1
      rstep.accent = false
    else
      -- ghost becomes accent
      step.vel = 0.8 + math.random() * 0.2
      rstep.accent = true
    end
  elseif roll < 0.4 then
    -- displace: toggle step on/off (creates holes and fills)
    step.on = not step.on
  elseif roll < 0.55 then
    -- swing: add ratchet to ghost notes (double-time ghost = very funky)
    if step.vel < 0.5 and step.on then
      rstep.ratchet = 2
    else
      rstep.ratchet = 1
    end
  elseif roll < 0.7 then
    -- condition variety on non-accent steps
    if not rstep.accent then
      rstep.condition = ({1, 2, 3, 5, 10})[math.random(5)]
    end
  elseif roll < 0.85 then
    -- velocity drift (humanize)
    if step.vel > 0.6 then
      step.vel = util.clamp(step.vel + rand_delta(0.08), 0.7, 1.0)
    else
      step.vel = util.clamp(step.vel + rand_delta(0.06), 0.15, 0.45)
    end
  else
    -- gate length variation (short = tight, long = lazy)
    step.gate = math.random() < 0.6 and 0.3 or 0.6
  end
end

-- 4. RHYTHM: mutates sequencer rhythm track
function octopus.act_rhythm(soul)
  local t = octopus.tentacles[T_RHYTHM]
  local seq = octopus.seq
  local len = seq.track_len[seq.TRACK_RHYTHM]

  -- FUNK SOUL: specialized rhythm intelligence
  if soul.is_funk then
    -- occasionally lay down a new funk pattern (like a drummer switching grooves)
    if math.random() < 0.04 * t.energy then
      apply_funk_pattern(seq, soul)
      -- set swing
      local sw = soul.swing_range or {55, 65}
      seq.swing = math.random(sw[1], sw[2])
    end

    -- mutate 1-3 individual steps (like a drummer varying the pocket)
    local num_mutations = math.random(1, math.floor(1 + t.energy * 2))
    for _ = 1, num_mutations do
      local i = math.random(1, math.min(len, 16))
      mutate_funk_step(seq, soul, i)
    end

    -- THE ONE is SACRED — step 1 is always an accent
    if seq.melody[1] then
      seq.melody[1].on = true
      seq.melody[1].vel = math.max(seq.melody[1].vel, 0.85)
      if seq.rhythm[1] then
        seq.rhythm[1].accent = true
        seq.rhythm[1].condition = 1
      end
    end

    -- swing rides with energy
    local sw = soul.swing_range or {55, 65}
    seq.swing = util.clamp(seq.swing + rand_delta(1.5), sw[1], sw[2])

    -- fill mode: tasteful fills during PEAK (not destruction)
    if octopus.form_phase == "PEAK" and t.energy > 0.7 and math.random() < 0.15 then
      -- fill: add ratchets to last 4 steps
      for i = math.max(1, len - 3), len do
        if seq.rhythm[i] then
          seq.rhythm[i].ratchet = math.random(2, 3)
        end
      end
    end

    return
  end

  -- NON-FUNK: original behavior
  local i = math.random(1, len)
  local step = seq.rhythm[i]

  local roll = math.random()
  if roll < 0.35 then
    if math.random() < soul.condition_variety then
      step.condition = math.random(1, 10)
    else
      step.condition = 1
    end
  elseif roll < 0.55 then
    if math.random() < soul.ratchet_love * t.energy then
      step.ratchet = math.random(2, 4)
    else
      step.ratchet = 1
    end
  elseif roll < 0.7 then
    step.accent = not step.accent
  elseif roll < 0.85 then
    local mi = math.random(1, seq.track_len[seq.TRACK_MELODY])
    seq.melody[mi].on = not seq.melody[mi].on
  else
    if octopus.form_phase == "PEAK" or octopus.form_phase == "BUILD" then
      seq.track_len[seq.TRACK_RHYTHM] = math.random(5, 13)
    end
  end

  seq.fill_mode = (octopus.form_phase == "PEAK" and t.energy > 0.6)
end

-- 5. MELODY: markov evolution + note injection
function octopus.act_melody(soul)
  local t = octopus.tentacles[T_MELODY]
  local seq = octopus.seq
  local len = seq.track_len[seq.TRACK_MELODY]

  -- FUNK: tight pentatonic riffs, chromatic approaches, octave locks
  if soul.is_funk then
    local root = octopus.melody_root
    -- funk stays within one octave of the root
    local funk_range_lo = root - 5
    local funk_range_hi = root + 12

    -- mutate 1-2 steps with funk logic
    local num = math.random(1, 2)
    for _ = 1, num do
      local i = math.random(1, len)
      local step = seq.melody[i]

      local roll = math.random()
      if roll < 0.3 then
        -- pentatonic snap: minor pentatonic from root
        local penta = {0, 3, 5, 7, 10}
        local degree = penta[math.random(#penta)]
        local octave = math.random(0, 1)
        step.note = util.clamp(root + degree + octave * 12, funk_range_lo, funk_range_hi)
      elseif roll < 0.5 then
        -- chromatic approach: half step below a scale tone
        step.note = seq.markov_next(step.note)
        -- clamp to funk range
        step.note = util.clamp(step.note, funk_range_lo, funk_range_hi)
      elseif roll < 0.7 then
        -- repeat root or fifth (the ANCHOR — funk sits on the root)
        local anchors = {root, root, root + 7, root - 5, root + 12}
        step.note = anchors[math.random(#anchors)]
      else
        -- motivic: reuse from memory
        if #octopus.melody_memory > 2 then
          local mem = octopus.melody_memory[math.random(#octopus.melody_memory)]
          step.note = util.clamp(mem, funk_range_lo, funk_range_hi)
        end
      end

      table.insert(octopus.melody_memory, step.note)
      if #octopus.melody_memory > 8 then table.remove(octopus.melody_memory, 1) end
    end

    -- note injection: funky stabs and fills
    local inject_rate = soul.melody_inject_rate * (0.4 + t.energy * 0.6)
    if math.random() < inject_rate then
      -- funk note: root, fifth, or octave
      local funk_notes = {root, root + 7, root + 12, root + 5, root - 5, root + 3, root + 10}
      local note = funk_notes[math.random(#funk_notes)]
      octopus.melody_last_note = note
      -- short, punchy gate (funk = tight)
      local vel = 0.5 + t.energy * 0.4
      local gate = 0.08 + math.random() * 0.2
      if octopus.note_on_fn then
        octopus.note_on_fn(note, vel, gate)
      end
      -- occasional octave double (very funky)
      if math.random() < t.energy * 0.25 then
        clock.run(function()
          clock.sleep(math.random() * 0.02)
          if octopus.note_on_fn then
            octopus.note_on_fn(note + 12, vel * 0.6, gate * 0.7)
          end
        end)
      end
    end

    seq.generative = (octopus.form_phase == "PEAK")
    return
  end

  -- NON-FUNK: original behavior
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

  -- direct note injection: polyphonic autonomous notes
  -- the octopus PLAYS the instrument, not just mutates the sequencer
  local inject_rate = soul.melody_inject_rate * (0.5 + t.energy)
  if math.random() < inject_rate then
    local note = seq.markov_next(octopus.melody_last_note)
    local vel = 0.25 + t.energy * 0.55
    local gate = 0.08 + math.random() * 0.5
    local pan_val = nil

    -- DUO MODE: alternate between voice A and voice B
    if params:get("duo_mode") == 2 then
      octopus.duo_phrase_notes = octopus.duo_phrase_notes + 1
      if octopus.duo_voice == "A" then
        -- Voice A: current root, current topology
        pan_val = -0.5
        if octopus.duo_phrase_notes >= math.random(2, 4) then
          octopus.duo_voice = "B"
          octopus.duo_phrase_notes = 0
        end
      else
        -- Voice B: root + 7 semitones (a fifth up), different topology
        note = note + 7
        -- clamp
        while note > octopus.melody_root + 36 do note = note - 12 end
        pan_val = 0.5
        -- different topology for voice B
        local alt_topos = soul.topo_build or {0, 1, 2}
        params:set("config", alt_topos[math.random(#alt_topos)] + 1)
        if octopus.duo_phrase_notes >= math.random(2, 4) then
          octopus.duo_voice = "A"
          octopus.duo_phrase_notes = 0
        end
      end
    end

    octopus.melody_last_note = note
    if octopus.note_on_fn then
      octopus.note_on_fn(note, vel, gate, pan_val)
    end

    -- polyphonic: sometimes play 2-3 notes at once (chords/clusters)
    if math.random() < t.energy * 0.35 then
      local intervals = {3, 4, 5, 7, 12, -5, -7, -12}
      local chord_note = note + intervals[math.random(#intervals)]
      clock.run(function()
        clock.sleep(math.random() * 0.03) -- micro-stagger
        if octopus.note_on_fn then
          octopus.note_on_fn(chord_note, vel * 0.7, gate * 0.8, pan_val)
        end
      end)
    end
    -- occasional third note for density
    if math.random() < t.energy * 0.15 then
      local third = note + ({7, 12, -12, 5, -5})[math.random(5)]
      clock.run(function()
        clock.sleep(math.random() * 0.05)
        if octopus.note_on_fn then
          octopus.note_on_fn(third, vel * 0.5, gate * 0.5, pan_val)
        end
      end)
    end
  end

  -- enable/disable generative mode based on form
  seq.generative = (octopus.form_phase == "PEAK" or
    (octopus.form_phase == "BUILD" and t.energy > 0.6))
end

-- 6. SPACE: phaser, exciter, tilt, delay, reverb, chorus
-- THIS IS THE ROOM — it should MOVE dramatically
function octopus.act_space(soul)
  local t = octopus.tentacles[T_SPACE]
  local mag = t.energy * 0.2  -- 2.5x bigger base magnitude

  -- phaser: dramatic sweeps
  if octopus.form_phase == "PEAK" then
    nudge("phaser_intensity", math.random() * 0.12 * soul.phaser_love, 0.0, 0.9)
    nudge("phaser_rate", rand_delta(0.5), 0.1, 6.0)
    nudge("phaser_depth", rand_delta(0.08), 0.1, 1.0)
  elseif octopus.form_phase == "BUILD" then
    nudge("phaser_intensity", rand_delta(mag) * soul.phaser_love, 0.0, 0.9)
    if math.random() < 0.35 then nudge("phaser_rate", rand_delta(0.4), 0.1, 5.0) end
  elseif octopus.form_phase == "REST" then
    nudge("phaser_intensity", -0.06, 0.0, 1.0)
  else -- DRIFT
    nudge("phaser_intensity", rand_delta(0.04) * soul.phaser_love, 0.0, 0.5)
  end

  -- exciter: presence shifts — phase-aware riding
  if octopus.form_phase == "PEAK" then
    -- push exciter up aggressively during peaks
    nudge("exciter_amount", math.random() * 0.1 * soul.exciter_love + mag * soul.exciter_love, 0.0, 0.9)
  elseif octopus.form_phase == "BUILD" then
    -- gradually raise exciter during build
    nudge("exciter_amount", math.random() * 0.06 * soul.exciter_love, 0.0, 0.75)
  elseif octopus.form_phase == "REST" then
    -- pull exciter down during rest
    nudge("exciter_amount", -0.05 * soul.exciter_love, 0.0, 0.8)
  else -- DRIFT
    -- gentle nudges
    nudge("exciter_amount", rand_delta(mag * 0.8) * soul.exciter_love, 0.0, 0.6)
  end

  -- tilt: dramatic bright/dark shifts
  local tilt_pull = (soul.tilt_center - params:get("tilt_eq")) * 0.1
  nudge("tilt_eq", tilt_pull + rand_delta(0.08 * t.energy), -0.8, 0.8)

  -- delay: the room OPENS and CLOSES (capped to stay present)
  if octopus.form_phase == "PEAK" then
    nudge("delay_mix", math.random() * 0.08 * t.energy, 0.0, 0.4)
    nudge("delay_time", rand_delta(0.08), 0.05, 1.0)
    nudge("delay_feedback", rand_delta(0.06), 0.15, 0.65)
  elseif octopus.form_phase == "BUILD" then
    nudge("delay_mix", math.random() * 0.05 * t.energy, 0.0, 0.3)
    if math.random() < 0.35 then nudge("delay_time", rand_delta(0.06), 0.05, 1.0) end
    if math.random() < 0.3 then nudge("delay_feedback", rand_delta(0.04), 0.1, 0.55) end
  elseif octopus.form_phase == "REST" then
    nudge("delay_mix", -0.08, 0.0, 0.5)
    nudge("delay_feedback", -0.05, 0.0, 0.7)
  elseif octopus.form_phase == "DRIFT" then
    if math.random() < 0.3 then
      nudge("delay_mix", rand_delta(0.03), 0.0, 0.25)
    end
  end

  -- reverb: the space itself breathes (keep it tight)
  if octopus.form_phase == "PEAK" then
    nudge("reverb_mix", math.random() * 0.06, 0.0, 0.35)
    nudge("reverb_size", rand_delta(0.04), 0.2, 0.75)
    nudge("reverb_damp", rand_delta(0.03), 0.2, 0.6)
  elseif octopus.form_phase == "BUILD" then
    nudge("reverb_mix", math.random() * 0.04, 0.0, 0.3)
    nudge("reverb_size", rand_delta(0.03), 0.2, 0.7)
  elseif octopus.form_phase == "REST" then
    nudge("reverb_mix", -0.04, 0.0, 0.4)
    nudge("reverb_size", -0.03, 0.3, 0.75)
  elseif octopus.form_phase == "DRIFT" then
    nudge("reverb_mix", rand_delta(0.02), 0.0, 0.25)
  end

  -- chorus: thickening (capped low)
  if math.random() < 0.35 then
    if octopus.form_phase == "BUILD" or octopus.form_phase == "PEAK" then
      nudge("chorus_mix", math.random() * 0.05 * t.energy, 0.0, 0.3)
      nudge("chorus_rate", rand_delta(0.2), 0.1, 3.0)
    else
      nudge("chorus_mix", rand_delta(0.03 * t.energy), 0.0, 0.2)
    end
  end

  -- tape loop: rec and play drift with form
  if math.random() < 0.3 * t.energy then
    if octopus.form_phase == "PEAK" then
      nudge("tape_rec", math.random() * 0.12, 0.0, 1.0)
      nudge("tape_play", math.random() * 0.12, 0.0, 1.0)
    elseif octopus.form_phase == "BUILD" then
      nudge("tape_rec", math.random() * 0.06, 0.0, 0.8)
      nudge("tape_play", math.random() * 0.08, 0.0, 0.8)
    elseif octopus.form_phase == "REST" then
      nudge("tape_rec", -0.06, 0.0, 1.0)
      -- keep playback alive for ghostly tails
      nudge("tape_play", rand_delta(0.04), 0.0, 0.6)
    else
      nudge("tape_rec", rand_delta(0.03), 0.0, 0.5)
      nudge("tape_play", rand_delta(0.03), 0.0, 0.5)
    end
  end

  -- audio_in: occasional nudge during PEAK
  if octopus.form_phase == "PEAK" and math.random() < 0.08 * t.energy then
    nudge("audio_in", math.random() * 0.1, 0.0, 0.6)
  elseif octopus.form_phase == "REST" then
    nudge("audio_in", -0.03, 0.0, 1.0)
  end

  -- SPATIAL: pan movement — notes drift across the stereo field
  if math.random() < 0.25 * t.energy then
    -- pan is per-note so we set it for next notes via a state var
    local pan_target
    if octopus.form_phase == "PEAK" then
      -- wide, dramatic panning
      pan_target = (math.random() - 0.5) * 1.6
    elseif octopus.form_phase == "DRIFT" then
      -- gentle drift around center
      pan_target = (math.random() - 0.5) * 0.6
    else
      pan_target = (math.random() - 0.5) * 1.0
    end
    octopus.next_pan = pan_target
  end

  -- FUNK: ride the drum synthesis params
  if soul.is_funk and math.random() < 0.2 * t.energy then
    local drum_roll = math.random()
    if drum_roll < 0.3 then
      -- kick character: pitch + decay variation
      nudge("kick_pitch", rand_delta(0.15), 0.5, 2.0)
      nudge("kick_decay", rand_delta(0.04), 0.05, 0.4)
    elseif drum_roll < 0.5 then
      -- kick drive: gritty vs clean
      nudge("kick_drive", rand_delta(0.1), 0.0, 0.8)
    elseif drum_roll < 0.7 then
      -- hat: pitch and decay (open/closed feel)
      nudge("hat_pitch", rand_delta(0.15), 0.3, 2.0)
      nudge("hat_decay", rand_delta(0.03), 0.02, 0.25)
    elseif drum_roll < 0.85 then
      -- snare: snappy + pitch
      nudge("rim_snappy", rand_delta(0.12), 0.1, 1.0)
      nudge("rim_pitch", rand_delta(0.15), 0.5, 2.0)
    else
      -- snare drive: lo-fi crunch
      nudge("rim_drive", rand_delta(0.1), 0.0, 0.7)
    end
  end
end

-- 7. FORM: the conductor
function octopus.act_form(soul)
  octopus.form_beat = octopus.form_beat + 1

  -- phase transition
  if octopus.form_beat >= octopus.form_length then
    octopus.form_beat = 0
    octopus.form_idx = octopus.form_idx + 1

    if octopus.form_idx > #octopus.form_template then
      -- new form template (funk gets funk templates)
      local soul = octopus.get_soul()
      if soul.is_funk then
        octopus.form_template = FUNK_FORM_TEMPLATES[math.random(#FUNK_FORM_TEMPLATES)]
      else
        octopus.form_template = FORM_TEMPLATES[math.random(#FORM_TEMPLATES)]
      end
      octopus.form_idx = 1
      octopus.cycle = octopus.cycle + 1

      -- occasionally re-anchor
      if math.random() < 0.25 then
        octopus.save_anchors()
      end
    end

    octopus.form_phase = octopus.form_template[octopus.form_idx]

    -- notify phase change listeners (scale progression etc.)
    if octopus.on_phase_change then
      octopus.on_phase_change(octopus.form_phase)
    end

    -- phase length varies by soul dramatics — SHORTER for more drama
    local base = math.random(10, 28)  -- shorter phases = more dynamic
    octopus.form_length = math.floor(base / soul.form_dramatics)

    -- phase entry effects — BIG GESTURES at transitions
    if octopus.form_phase == "REST" then
      -- pull toward anchors more strongly
      octopus.restore_anchors(0.45)
      -- amp: gentle breathe down (never below 0.75)
      nudge("amp", -0.03, 0.75, 1.0)
      -- dramatic: drop delay/reverb tails
      nudge("delay_feedback", -0.15, 0.0, 0.9)
      -- silence some tentacles for contrast
      if math.random() < soul.silence_love then
        local victim = math.random(1, 6)
        octopus.tentacles[victim].breath_phase = "fade"
      end
      -- second silence for really dramatic souls
      if math.random() < soul.silence_love * 0.5 then
        local victim2 = math.random(1, 6)
        octopus.tentacles[victim2].breath_phase = "fade"
      end
      -- tape: slow down, sometimes reverse
      if math.random() < 0.4 then
        local rest_rates = {0.5, 0.75, -0.5, -1.0, 0.25}
        params:set("tape_rate", rest_rates[math.random(#rest_rates)])
      end
    elseif octopus.form_phase == "PEAK" then
      -- EXPLODE: energize all tentacles
      for i = 1, NUM_TENTACLES do
        octopus.tentacles[i].energy = math.max(octopus.tentacles[i].energy, 0.7)
        octopus.tentacles[i].breath_phase = "play"
      end
      -- amp: full presence
      nudge("amp", 0.06, 0.8, 1.0)
      -- dramatic entry: boost intensity immediately
      nudge("delay_mix", 0.15, 0.0, 0.8)
      nudge("reverb_mix", 0.1, 0.0, 0.85)
      nudge("exciter_amount", 0.08, 0.0, 0.8)
      -- occasional dramatic filter sweep on PEAK entry
      if math.random() < 0.4 then
        params:set("cutoff", math.random(6000, 14000))
      end
      -- tape: occasional speed changes
      if math.random() < 0.5 then
        local peak_rates = {0.5, 0.75, 1.0, 1.5, 2.0}
        params:set("tape_rate", peak_rates[math.random(#peak_rates)])
      end
    elseif octopus.form_phase == "BUILD" then
      -- gentle wake-up: start building
      for i = 1, NUM_TENTACLES do
        octopus.tentacles[i].energy = math.max(octopus.tentacles[i].energy, 0.3)
        if octopus.tentacles[i].breath_phase == "silence" then
          octopus.tentacles[i].breath_phase = "build"
        end
      end
      -- amp: gradually rise
      nudge("amp", 0.04, 0.75, 1.0)
    elseif octopus.form_phase == "DRIFT" then
      -- gentle pull toward anchors
      octopus.restore_anchors(0.2)
      -- reduce effects gently
      nudge("delay_mix", -0.08, 0.0, 1.0)
      nudge("chorus_mix", -0.05, 0.0, 1.0)
      -- tape: rate stays near 1.0
      nudge("tape_rate", (1.0 - params:get("tape_rate")) * 0.3, -2.0, 2.0)
    end
  end
end

-- 8. CHAOS: the wild card — MORE FREQUENT, BIGGER GESTURES
function octopus.act_chaos(soul)
  local t = octopus.tentacles[T_CHAOS]
  -- higher base frequency: fires more often
  if math.random() > (soul.chaos_freq * 1.5) * (0.5 + t.energy * 0.8) then return end

  local mag = soul.chaos_magnitude * t.energy
  local seq = octopus.seq

  local roll = math.random()
  if roll < 0.15 then
    -- p-lock storm: add MANY random p-locks
    local num = math.random(3, 8)
    for _ = 1, num do
      local step_idx = math.random(1, seq.track_len[seq.TRACK_TIMBRE])
      local step = seq.timbre[step_idx]
      local what = math.random(1, 7)
      if what == 1 then step.config = math.random(0, 11)
      elseif what == 2 then step.cutoff = math.random(60, 16000)
      elseif what == 3 then step.master_index = math.random() * soul.index_ceiling * 1.3
      elseif what == 4 then step.wsa = math.random(0, 7)
      elseif what == 5 then step.wsb = math.random(0, 7)
      elseif what == 6 then step.drive = math.random() * 0.6
      elseif what == 7 then step.resonance = math.random() * 2.5
      end
    end
  elseif roll < 0.25 then
    -- polymetric disruption: randomize all track lengths
    seq.track_len[seq.TRACK_MELODY] = math.random(3, 15)
    seq.track_len[seq.TRACK_TIMBRE] = math.random(3, 15)
    seq.track_len[seq.TRACK_RHYTHM] = math.random(3, 15)
  elseif roll < 0.35 then
    -- index explosion: ALL indices go wild
    for i = 1, 6 do
      params:set("index" .. i, math.random() * soul.index_ceiling * mag * 1.3)
    end
    params:set("master_index", math.random() * soul.index_ceiling * mag)
  elseif roll < 0.45 then
    -- ratchet storm
    for i = 1, seq.track_len[seq.TRACK_RHYTHM] do
      if math.random() < 0.5 then
        seq.rhythm[i].ratchet = math.random(2, 4)
      end
    end
    t.cooldown = 3
  elseif roll < 0.55 then
    -- filter sweep: sudden dramatic cutoff change
    local target = math.random() < 0.5 and math.random(40, 200) or math.random(8000, 16000)
    params:set("cutoff", target)
    -- sometimes pair with resonance spike
    if math.random() < 0.4 then
      params:set("resonance", math.random() * 2.5 + 0.5)
    end
    t.cooldown = 2
  elseif roll < 0.65 then
    -- topology rapid-fire: set per-step topologies
    for i = 1, seq.track_len[seq.TRACK_TIMBRE] do
      if math.random() < 0.6 * mag then
        seq.timbre[i].config = math.random(0, 11)
      end
    end
  elseif roll < 0.75 then
    -- SPACE BOMB: sudden FX changes
    if math.random() < 0.5 then
      params:set("delay_mix", math.random() * 0.6)
      params:set("delay_feedback", 0.2 + math.random() * 0.4)
    else
      params:set("reverb_mix", math.random() * 0.6)
      params:set("reverb_size", 0.4 + math.random() * 0.5)
    end
    t.cooldown = 3
  elseif roll < 0.85 then
    -- TEXTURE SHOCK: sudden noise/sub/tremolo change
    local what = math.random(1, 4)
    if what == 1 then
      params:set("noise", math.random() * 0.3)
    elseif what == 2 then
      params:set("sub_osc", math.random() * 0.4)
    elseif what == 3 then
      params:set("trem_depth", math.random() * 0.5)
      params:set("trem_rate", math.random() * 12 + 1)
    else
      params:set("lfo_filter", math.random() * 0.5)
      params:set("lfo_filter_rate", math.random() * 10 + 0.5)
    end
  else
    -- ENVELOPE DISRUPTION: sudden character change
    local shapes = {
      {0.001, 0.05, 0.9, 0.1},   -- percussive
      {0.5, 0.3, 0.7, 2.0},      -- pad
      {0.001, 0.01, 1.0, 0.05},  -- pluck
      {0.2, 1.0, 0.3, 3.0},      -- swell
      {0.001, 0.1, 0.0, 0.3},    -- stab
    }
    local shape = shapes[math.random(#shapes)]
    params:set("attack", shape[1])
    params:set("decay", shape[2])
    params:set("sustain_level", shape[3])
    params:set("release", shape[4])
    t.cooldown = 4
  end
end

-- --------------------------------------------------------------------------
-- set soul
-- --------------------------------------------------------------------------

function octopus.set_soul(name)
  if SOULS[name] then
    octopus.soul = name
    -- update sequencer markov style
    local seq = octopus.seq
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
