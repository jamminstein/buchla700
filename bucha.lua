-- bucha
-- norns port of the bucha
-- FM + waveshaping + OTA ladder
-- 12 FM routing topologies
--
-- E1: page
-- E2/E3: context per page
-- K2: play/stop (hold=shift)
-- K3: page action / toggle bandmate+explorer
--
-- grid (8x16):
--   row 1: topology select (1-12) + bandmate (14) + explorer (15) + play (16)
--   row 2: waveshape A (1-8) + waveshape B (9-16)
--   row 3: sequencer steps (toggle, playhead)
--   row 4: per-step topology override (hold to cycle)
--   rows 5-8: index faders (1-6) + master (8-16) + status meters (15-16)
--
-- autonomous systems:
--   explorer: rides topology, indices, filter, effects
--   bandmate: generates melodic material with breathing + song form

engine.name = "Bucha"

local musicutil = require "musicutil"
local lattice_lib = require "lattice"

local seq = include "lib/sequencer"
local explorer = include "lib/explorer"
local bandmate = include "lib/bandmate"
local octopus = include "lib/octopus"

-- wire module cross-references
explorer.seq = seq
octopus.seq = seq

-- pages
local PAGES = {"TOPOLOGY", "RATIOS", "SHAPE", "FILTER", "EFFECTS", "OCTOPUS"}
local page = 1

-- topology names
local CONFIG_NAMES = {
  [0]  = "SYMMETRIC",
  [1]  = "SPLIT",
  [2]  = "CASCADE",
  [3]  = "SHARED",
  [4]  = "MINIMAL",
  [5]  = "CROSS",
  [6]  = "TRIPLE",
  [7]  = "CENTRIC",
  [8]  = "FEEDBACK",
  [9]  = "CIRCULAR",
  [10] = "PARALLEL",
  [11] = "MULTI"
}

-- waveshape preset names
local WS_NAMES = {
  [0] = "LINEAR",
  [1] = "SOFT",
  [2] = "HARD",
  [3] = "FOLD",
  [4] = "SINEFOLD",
  [5] = "ASYM",
  [6] = "STAIR",
  [7] = "CHEBY3"
}

-- harmonic ratios for easy selection
local RATIOS = {0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0, 7.0, 8.0}

-- bandmate style names
local BANDMATE_VOICES = {"DRIFT", "PULSE", "BELLS", "VOICE", "SWARM"}
local EXPLORER_STYLES = {"EASEL", "STREGA", "SUBOTNICK", "SERGE", "ENO"}

-- state
local config = 0
local master_index = 0.5
local ratio_select = 1
local ratios = {2.0, 3.0, 4.0}
local ratio_idx = {6, 8, 10}
local wsa_preset = 0
local wsb_preset = 0
local cutoff = 6000
local resonance = 0.3
local drive = 0.0
local phaser_intensity = 0.0
local phaser_rate = 1.0
local phaser_depth = 0.5
local exciter_amount = 0.3
local tilt_eq = 0.0
local k2_held = false
local k3_press_time = 0

-- MIDI
local midi_in_device
local midi_out_device
local current_note = nil
local max_voices = 6

-- CC out: track last sent values to avoid flooding
local last_cc = {}

-- drums (creative metronome)
local drum_active = false
local drum_step = 0
local drum_pattern = 1
local drum_vol = 0.4
local drum_tone = 0.5
local drum_kick_vol = 1.0
local drum_snare_vol = 1.0
local drum_hat_vol = 0.6
-- drum synthesis params
local drum_kick_pitch = 1.0
local drum_kick_decay = 0.3
local drum_kick_drive = 0.5
local drum_kick_click = 0.3
local drum_hat_pitch = 1.0
local drum_hat_decay = 0.08
local drum_hat_drive = 0.0
local drum_hat_ring = 0.0
local drum_rim_pitch = 1.0
local drum_rim_decay = 0.06
local drum_rim_drive = 0.0
local drum_rim_snappy = 0.5
local drum_lpf = 12000
local DRUM_PATTERNS = {
  -- name, kick[], hat[], rim[]  (1 = hit, 0 = rest, 0.5 = ghost)
  { name = "FOUR",       kick = {1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0},
                          hat  = {0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0},
                          rim  = {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0} },
  { name = "BACKBEAT",    kick = {1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0},
                          hat  = {1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0},
                          rim  = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0} },
  { name = "FUNK",        kick = {1,0,0,0, 0,0,1,0, 0,0,1,0, 0,0,0,0},
                          hat  = {1,0.5,1,0.5, 1,0.5,1,0.5, 1,0.5,1,0.5, 1,0.5,1,0.5},
                          rim  = {0,0,0,0, 1,0,0,0.5, 0,0,0,0, 1,0,0.5,0} },
  { name = "BREAKBEAT",   kick = {1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0},
                          hat  = {1,0,1,0.5, 1,0,1,0, 1,0.5,1,0, 1,0,1,0.5},
                          rim  = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0.5} },
  { name = "HALFTIME",    kick = {1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
                          hat  = {0,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0},
                          rim  = {0,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0} },
  { name = "PULSE",       kick = {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
                          hat  = {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
                          rim  = {1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0} },
  -- NEW PATTERNS
  { name = "STUBBLEFIELD", kick = {1,0,0,0, 0,0,0.5,0, 0,0,1,0, 0,0,0,0},
                          hat  = {1,0.5,1,0.5, 1,0.5,1,0, 1,0.5,1,0.5, 1,0,1,0.5},
                          rim  = {0,0,0,0, 1,0,0,0.5, 0,0,0,0.5, 1,0,0,0} },
  { name = "ZIGABOO",     kick = {1,0,0,0.5, 0,0,1,0, 0,0.5,0,0, 1,0,0,0},
                          hat  = {1,1,1,0.5, 1,0.5,1,1, 1,0.5,1,0.5, 1,1,1,0.5},
                          rim  = {0,0,0,0, 1,0,0,0, 0,0,0,0.5, 0,0,1,0} },
  { name = "AFROBEAT",    kick = {1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0},
                          hat  = {1,0,1,1, 0,1,1,0, 1,1,0,1, 1,0,1,0},
                          rim  = {0,0,0,0, 1,0,0,0, 0,0,1,0, 0,0,0,0} },
  { name = "BOSSA",       kick = {1,0,0,0, 0,0,1,0, 0,1,0,0, 0,0,0,0},
                          hat  = {0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0},
                          rim  = {1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,1,0} },
  { name = "REGGAETON",   kick = {1,0,0,0, 0,0,0,1, 0,0,0,0, 0,0,0,1},
                          hat  = {1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0},
                          rim  = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0} },
  { name = "TRAP",        kick = {1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0},
                          hat  = {1,1,0,1, 1,0,1,1, 0,1,1,1, 1,0,1,1},
                          rim  = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0} },
  { name = "SHUFFLE",     kick = {1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,0},
                          hat  = {1,0,0.5,1, 0,0.5,1,0, 0.5,1,0,0.5, 1,0,0.5,0},
                          rim  = {0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0} },
}
local DRUM_PATTERN_NAMES = {}
for _, p in ipairs(DRUM_PATTERNS) do table.insert(DRUM_PATTERN_NAMES, p.name) end

-- lattice
local my_lattice
local seq_sprocket
local explorer_sprocket
local bandmate_sprocket
local drum_sprocket
local octopus_sprocket
local midi_clock_sprocket

-- grid
local g = grid.connect()
local grid_dirty = true
local grid_held = {}  -- track held keys for gestures
local index_values = {0.5, 0.3, 0.2, 0.1, 0.1, 0.1}  -- local tracking for grid display

-- grid keyboard mode
local grid_mode = "FADERS"  -- "FADERS" or "KEYS"
local grid_keys_held = {}   -- track held notes for keyboard mode {[col_row_key] = midi_note}

-- preset snapshots
local presets = {}  -- 8 slots: presets[1..8] = {param_name = value, ...}
local preset_active = 0  -- currently recalling slot (0 = none)
local preset_press_time = {}  -- for long-press detection

-- scale lock
local scale_lock_scale = {}  -- cached scale array for snap_note_to_array
local SCALE_NAMES = {"OFF"}
for i = 1, #musicutil.SCALES do
  table.insert(SCALE_NAMES, musicutil.SCALES[i].name)
end
local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

-- softcut tape loop
local tape_loop_length = 4  -- beats

-- duo mode
local duo_voice = "A"  -- which voice is currently speaking
local duo_phrase_count = 0

-- scale progression state
local progression_idx = 0          -- position in current progression sequence
local progression_phase_count = 0  -- count phase changes for speed gating
local PROGRESSIONS = {
  DIATONIC  = {0, 5, 7, 0},                                          -- I IV V I
  MODAL     = {0, 3, 5, 10, 0},                                      -- I bIII IV bVII I
  CHROMATIC = {0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5, 0},           -- cycle of fifths
}

-- chord mode state
local chord_notes = {}     -- chord_notes[root] = {note1, note2, ...}
local chord_mode_override = nil  -- temporary override for duo voice B (nil = use param)

-- screen
local screen_dirty = true
local anim_phase = 0

-- FM topology connection maps for screen visualization
local TOPOLOGY_CONNECTIONS = {
  [0]  = {{2,1,1},{4,1,2},{2,3,4},{4,3,5}},
  [1]  = {{2,1,1},{4,3,4}},
  [2]  = {{3,2,2},{2,1,1},{1,4,5}},
  [3]  = {{3,1,2},{3,2,5},{4,1,0},{4,2,0}},
  [4]  = {{2,1,2}},
  [5]  = {{4,1,2},{2,3,5}},
  [6]  = {{3,2,1},{2,1,2},{4,1,4}},
  [7]  = {{4,1,4},{4,0,5}},
  [8]  = {{2,1,2},{3,1,1},{3,2,4},{1,0,5}},
  [9]  = {{4,1,1},{2,3,4},{1,4,5},{3,2,2}},
  [10] = {{2,1,2},{2,3,5},{3,1,1},{1,3,4}},
  [11] = {{3,1,5},{1,0,1},{2,0,2},{4,0,4}},
}

-- --------------------------------------------------------------------------
-- scale lock helper
-- --------------------------------------------------------------------------

local function rebuild_scale()
  local lock_idx = params:get("scale_lock")
  if lock_idx == 1 then
    -- OFF
    scale_lock_scale = {}
    return
  end
  local scale_idx = lock_idx - 1
  local root_num = params:get("scale_root") - 1  -- 0-11
  -- generate_scale wants a MIDI root note; generate from low C + root
  scale_lock_scale = musicutil.generate_scale(0 + root_num, musicutil.SCALES[scale_idx].name, 10)
end

local function quantize_note(note)
  if #scale_lock_scale == 0 then return note end
  return musicutil.snap_note_to_array(note, scale_lock_scale)
end

-- --------------------------------------------------------------------------
-- scale progression
-- --------------------------------------------------------------------------

local function advance_progression(new_phase)
  local mode = params:get("progression_mode")
  if mode == 1 then return end  -- OFF

  -- count phase changes and gate by speed setting
  progression_phase_count = progression_phase_count + 1
  local speed = params:get("progression_speed")
  local thresholds = {1, 2, 3, 4, 6, 8, 12, 16, 0}  -- 0 = random
  local threshold = thresholds[speed]
  if threshold == 0 then
    -- RANDOM: roll the dice each phase (30-70% chance depending on intensity)
    if math.random() > 0.45 then return end
  elseif progression_phase_count < threshold then return end
  progression_phase_count = 0

  -- determine the semitone offset
  local offset = 0
  local mode_name = ({"OFF", "DIATONIC", "MODAL", "CHROMATIC", "RANDOM"})[mode]

  if mode_name == "RANDOM" then
    -- pick a random degree from the current scale
    if #scale_lock_scale > 0 then
      local random_note = scale_lock_scale[math.random(#scale_lock_scale)]
      offset = random_note % 12
    else
      offset = math.random(0, 11)
    end
  else
    local prog = PROGRESSIONS[mode_name]
    if not prog then return end
    progression_idx = progression_idx + 1
    if progression_idx > #prog then progression_idx = 1 end
    offset = prog[progression_idx]
  end

  -- update scale root (1-indexed into NOTE_NAMES)
  local base_root = 1  -- C by default; offset from current base
  -- we apply the offset relative to index 1 (C)
  local new_root = ((offset) % 12) + 1
  params:set("scale_root", new_root)  -- this triggers rebuild_scale()

  -- update sequencer root
  seq.root = 48 + offset  -- low C + progression offset
  seq.last_note = seq.root

  -- update octopus melody root
  octopus.melody_root = 48 + offset
  octopus.melody_last_note = 48 + offset
end

-- --------------------------------------------------------------------------
-- chord building
-- --------------------------------------------------------------------------

local function note_in_scale(note)
  if #scale_lock_scale == 0 then return false end
  local pc = note % 12
  for _, sn in ipairs(scale_lock_scale) do
    if sn % 12 == pc then return true end
  end
  return false
end

local function is_major_third(root)
  -- check if root+4 is in scale (major third); if not, use minor third
  if #scale_lock_scale > 0 then
    return note_in_scale(root + 4)
  else
    -- no scale lock: 40% major, 60% minor
    return math.random() < 0.4
  end
end

local function is_major_seventh(root)
  if #scale_lock_scale > 0 then
    return note_in_scale(root + 11)
  else
    return math.random() < 0.35
  end
end

local function apply_inversion(notes, inversion)
  if #notes < 2 then return notes end
  local inv = inversion
  if inv == 4 then inv = math.random(1, 3) end  -- RANDOM

  if inv == 2 then
    -- 1st inversion: move lowest note up an octave
    notes[1] = notes[1] + 12
    table.sort(notes)
  elseif inv == 3 then
    -- 2nd inversion: move two lowest notes up an octave
    notes[1] = notes[1] + 12
    if notes[2] then notes[2] = notes[2] + 12 end
    table.sort(notes)
  end
  -- inv == 1 (ROOT): leave as-is
  return notes
end

local function build_chord(root_note, mode, inversion)
  if mode == 1 then return {root_note} end  -- OFF

  local notes = {}
  local third = is_major_third(root_note) and 4 or 3
  local seventh = is_major_seventh(root_note) and 11 or 10

  if mode == 2 then
    -- TRIADS: root, 3rd, 5th
    notes = {root_note, root_note + third, root_note + 7}

  elseif mode == 3 then
    -- 7THS: root, 3rd, 5th, 7th
    notes = {root_note, root_note + third, root_note + 7, root_note + seventh}

  elseif mode == 4 then
    -- SUS: alternate sus2/sus4
    if math.random() < 0.5 then
      notes = {root_note, root_note + 5, root_note + 7}  -- sus4
    else
      notes = {root_note, root_note + 2, root_note + 7}  -- sus2
    end

  elseif mode == 5 then
    -- CLUSTERS: tight voicings
    if math.random() < 0.5 then
      notes = {root_note, root_note + 1, root_note + 2}  -- tight cluster
    else
      notes = {root_note, root_note + 1, root_note + 3}  -- wider cluster
    end

  elseif mode == 6 then
    -- OPEN: spread across octaves
    notes = {root_note, root_note + 7, root_note + 12 + third}
  end

  -- apply scale quantization to chord tones
  if #scale_lock_scale > 0 then
    for i = 2, #notes do
      notes[i] = quantize_note(notes[i])
    end
  end

  -- apply inversion
  notes = apply_inversion(notes, inversion)

  return notes
end

-- --------------------------------------------------------------------------
-- preset snapshot helpers
-- --------------------------------------------------------------------------

local PRESET_PARAMS = {
  "config", "master_index", "index1", "index2", "index3", "index4", "index5", "index6",
  "ratio2", "ratio3", "ratio4", "wsa_preset", "wsb_preset",
  "cutoff", "resonance", "drive", "attack", "decay", "sustain_level", "release",
  "noise", "sub_osc", "trem_rate", "trem_depth", "lfo_filter", "lfo_filter_rate",
  "delay_time", "delay_feedback", "delay_mix", "reverb_size", "reverb_damp", "reverb_mix",
  "chorus_rate", "chorus_mix", "phaser_intensity", "phaser_rate",
  "exciter_amount", "tilt_eq"
}

local PRESET_OPTION_PARAMS = {config=true, wsa_preset=true, wsb_preset=true}

local function save_preset(slot)
  presets[slot] = {}
  for _, name in ipairs(PRESET_PARAMS) do
    presets[slot][name] = params:get(name)
  end
end

local function recall_preset(slot)
  if not presets[slot] then return end
  preset_active = slot
  clock.run(function()
    local target = presets[slot]
    local start = {}
    for _, name in ipairs(PRESET_PARAMS) do
      start[name] = params:get(name)
    end
    local steps = 20
    for step = 1, steps do
      local t = step / steps
      for _, name in ipairs(PRESET_PARAMS) do
        if PRESET_OPTION_PARAMS[name] then
          -- snap option params at halfway
          if t >= 0.5 then
            params:set(name, target[name])
          end
        else
          -- lerp numeric params
          local v = start[name] + (target[name] - start[name]) * t
          params:set(name, v)
        end
      end
      clock.sleep(0.025)
    end
    preset_active = 0
    grid_dirty = true
  end)
end

-- --------------------------------------------------------------------------
-- softcut tape loop setup
-- --------------------------------------------------------------------------

local function init_softcut()
  softcut.buffer_clear()
  -- voice 1: tape loop
  softcut.enable(1, 1)
  softcut.buffer(1, 1)
  softcut.level(1, 1.0)
  softcut.pan(1, 0)
  softcut.rate(1, 1.0)
  softcut.loop(1, 1)
  softcut.loop_start(1, 0)
  local loop_len = clock.get_beat_sec() * tape_loop_length
  softcut.loop_end(1, loop_len)
  softcut.position(1, 0)
  softcut.play(1, 1)
  softcut.rec(1, 1)
  softcut.rec_level(1, 0)   -- tape_rec controls this
  softcut.pre_level(1, 0.8) -- tape_feedback controls this
  softcut.fade_time(1, 0.01)
  softcut.rate_slew_time(1, 0.1)
  -- filter on playback
  softcut.post_filter_lp(1, 1.0)
  softcut.post_filter_hp(1, 0.0)
  softcut.post_filter_bp(1, 0.0)
  softcut.post_filter_dry(1, 0.0)
  softcut.post_filter_fc(1, 4000)
  -- route engine to softcut
  audio.level_eng_cut(1)
end

-- --------------------------------------------------------------------------
-- init
-- --------------------------------------------------------------------------

function init()
  params:add_separator("BUCHA")

  -- FM TOPOLOGY
  params:add_group("FM TOPOLOGY", 8)
  params:add_option("config", "FM config", {
    "00 SYMMETRIC", "01 SPLIT", "02 CASCADE", "03 SHARED",
    "04 MINIMAL", "05 CROSS", "06 TRIPLE", "07 CENTRIC",
    "08 FEEDBACK", "09 CIRCULAR", "10 PARALLEL", "11 MULTI"
  }, 1)
  params:set_action("config", function(v)
    config = v - 1
    engine.config(config)
    screen_dirty = true
  end)

  params:add_control("master_index", "master index",
    controlspec.new(0, 2.0, 'lin', 0.05, 0.5, ""))
  params:set_action("master_index", function(v)
    master_index = v
    engine.master_index(v)
    screen_dirty = true
  end)

  for i = 1, 6 do
    params:add_control("index" .. i, "index " .. i,
      controlspec.new(0, 2, 'lin', 0.01, ({1.0,0.8,0.8,0.6,0.5,0.6})[i], ""))
    local idx_num = i
    params:set_action("index" .. i, function(v)
      index_values[idx_num] = v
      engine["index" .. idx_num](v)
      grid_dirty = true
    end)
  end

  -- OSCILLATORS
  params:add_group("OSCILLATORS", 3)
  for i = 2, 4 do
    params:add_control("ratio" .. i, "osc " .. i .. " ratio",
      controlspec.new(0.25, 8, 'exp', 0, ({2,3,4})[i-1], "x"))
    params:set_action("ratio" .. i, function(v)
      ratios[i-1] = v
      engine["ratio" .. i](v)
      screen_dirty = true
    end)
  end

  -- WAVESHAPE
  params:add_group("WAVESHAPE", 2)
  params:add_option("wsa_preset", "waveshape A", {
    "LINEAR", "SOFT", "HARD", "FOLD", "SINEFOLD", "ASYM", "STAIR", "CHEBY3"
  }, 1)
  params:set_action("wsa_preset", function(v)
    wsa_preset = v - 1
    engine.wsa(wsa_preset)
    screen_dirty = true
  end)

  params:add_option("wsb_preset", "waveshape B", {
    "LINEAR", "SOFT", "HARD", "FOLD", "SINEFOLD", "ASYM", "STAIR", "CHEBY3"
  }, 1)
  params:set_action("wsb_preset", function(v)
    wsb_preset = v - 1
    engine.wsb(wsb_preset)
    screen_dirty = true
  end)

  -- FILTER
  params:add_group("FILTER", 3)
  params:add_control("cutoff", "cutoff",
    controlspec.new(20, 18000, 'exp', 0, 6000, "hz"))
  params:set_action("cutoff", function(v)
    cutoff = v
    engine.cutoff(v)
    screen_dirty = true
  end)

  params:add_control("resonance", "resonance",
    controlspec.new(0, 3.5, 'lin', 0.01, 0.3, ""))
  params:set_action("resonance", function(v)
    resonance = v
    engine.resonance(v)
    screen_dirty = true
  end)

  params:add_control("drive", "drive",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("drive", function(v) drive = v; engine.drive(v) end)

  params:add_group("ENVELOPE", 4)
  params:add_control("attack", "attack",
    controlspec.new(0.001, 2, 'exp', 0, 0.005, "s"))
  params:set_action("attack", function(v) engine.attack(v) end)
  params:add_control("decay", "decay",
    controlspec.new(0.01, 4, 'exp', 0, 0.2, "s"))
  params:set_action("decay", function(v) engine.decay(v) end)
  params:add_control("sustain_level", "sustain",
    controlspec.new(0, 1, 'lin', 0.01, 0.8, ""))
  params:set_action("sustain_level", function(v) engine.sustain(v) end)
  params:add_control("release", "release",
    controlspec.new(0.01, 8, 'exp', 0, 0.3, "s"))
  params:set_action("release", function(v) engine.release(v) end)

  params:add_group("TEXTURE", 6)
  params:add_control("noise", "noise",
    controlspec.new(0, 0.5, 'lin', 0.01, 0, ""))
  params:set_action("noise", function(v) engine.noise(v) end)
  params:add_control("sub_osc", "sub oscillator",
    controlspec.new(0, 0.7, 'lin', 0.01, 0.15, ""))
  params:set_action("sub_osc", function(v) engine.sub(v) end)
  params:add_control("trem_rate", "tremolo rate",
    controlspec.new(0, 20, 'lin', 0.1, 0, "hz"))
  params:set_action("trem_rate", function(v) engine.trem_rate(v) end)
  params:add_control("trem_depth", "tremolo depth",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("trem_depth", function(v) engine.trem_depth(v) end)
  params:add_control("lfo_filter", "LFO > filter",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("lfo_filter", function(v) engine.lfo_filter(v) end)
  params:add_control("lfo_filter_rate", "LFO filter rate",
    controlspec.new(0.1, 20, 'exp', 0, 2, "hz"))
  params:set_action("lfo_filter_rate", function(v) engine.lfo_filter_rate(v) end)

  params:add_group("SPACE FX", 8)
  params:add_control("delay_time", "delay time",
    controlspec.new(0.05, 1.0, 'lin', 0.01, 0.3, "s"))
  params:set_action("delay_time", function(v) engine.delay_time(v) end)
  params:add_control("delay_feedback", "delay feedback",
    controlspec.new(0, 0.9, 'lin', 0.01, 0.4, ""))
  params:set_action("delay_feedback", function(v) engine.delay_feedback(v) end)
  params:add_control("delay_mix", "delay mix",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("delay_mix", function(v) engine.delay_mix(v) end)
  params:add_control("reverb_size", "reverb size",
    controlspec.new(0, 1, 'lin', 0.01, 0.6, ""))
  params:set_action("reverb_size", function(v) engine.reverb_size(v) end)
  params:add_control("reverb_damp", "reverb damp",
    controlspec.new(0, 1, 'lin', 0.01, 0.5, ""))
  params:set_action("reverb_damp", function(v) engine.reverb_damp(v) end)
  params:add_control("reverb_mix", "reverb mix",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("reverb_mix", function(v) engine.reverb_mix(v) end)
  params:add_control("chorus_rate", "chorus rate",
    controlspec.new(0.1, 5, 'lin', 0.01, 0.5, "hz"))
  params:set_action("chorus_rate", function(v) engine.chorus_rate(v) end)
  params:add_control("chorus_mix", "chorus mix",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("chorus_mix", function(v) engine.chorus_mix(v) end)

  -- EFFECTS
  params:add_group("EFFECTS", 5)
  params:add_control("phaser_intensity", "phaser intensity",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("phaser_intensity", function(v)
    phaser_intensity = v
    engine.phaser_intensity(v)
    screen_dirty = true
  end)

  params:add_control("phaser_rate", "phaser rate",
    controlspec.new(0.1, 5, 'lin', 0.01, 1, "hz"))
  params:set_action("phaser_rate", function(v)
    phaser_rate = v
    engine.phaser_rate(v)
  end)

  params:add_control("phaser_depth", "phaser depth",
    controlspec.new(0, 1, 'lin', 0.01, 0.5, ""))
  params:set_action("phaser_depth", function(v)
    phaser_depth = v
    engine.phaser_depth(v)
  end)

  params:add_control("exciter_amount", "exciter",
    controlspec.new(0, 1, 'lin', 0.01, 0.3, ""))
  params:set_action("exciter_amount", function(v)
    exciter_amount = v
    engine.exciter_amount(v)
    screen_dirty = true
  end)

  params:add_control("tilt_eq", "tilt eq",
    controlspec.new(-1, 1, 'lin', 0.01, 0, ""))
  params:set_action("tilt_eq", function(v)
    tilt_eq = v
    engine.tilt(v)
  end)

  -- SEQUENCER
  params:add_group("SEQUENCER", 4)
  params:add_number("seq_steps", "steps", 1, 16, 8)
  params:set_action("seq_steps", function(v) seq.num_steps = v end)

  params:add_number("seq_probability", "probability", 0, 100, 100)
  params:set_action("seq_probability", function(v) seq.probability = v end)

  params:add_control("seq_swing", "swing",
    controlspec.new(50, 75, 'lin', 1, 50, "%"))
  params:set_action("seq_swing", function(v) seq.swing = v end)

  params:add_control("seq_gate", "gate length",
    controlspec.new(0.05, 1.0, 'lin', 0.01, 0.5, ""))
  params:set_action("seq_gate", function(v) seq.gate_length = v end)

  params:add_option("seq_division", "seq division",
    {"1/1", "1/2", "1/4", "1/8", "1/16", "1/32"}, 4)  -- default 1/8
  params:set_action("seq_division", function(v)
    local divs = {1, 1/2, 1/4, 1/8, 1/16, 1/32}
    if seq_sprocket then seq_sprocket:set_division(divs[v]) end
  end)

  params:add_option("octopus_speed", "octopus speed",
    {"slow", "normal", "fast", "hyper"}, 3)  -- default fast
  params:set_action("octopus_speed", function(v)
    local divs = {1/4, 1/8, 1/16, 1/32}
    if octopus_sprocket then octopus_sprocket:set_division(divs[v]) end
    if bandmate_sprocket then bandmate_sprocket:set_division(divs[v]) end
  end)

  -- AUTONOMOUS
  params:add_group("AUTONOMOUS", 5)
  params:add_option("octopus_soul", "octopus soul",
    octopus.SOUL_NAMES, 3)  -- default BUCHLA
  params:set_action("octopus_soul", function(v)
    octopus.set_soul(octopus.SOUL_NAMES[v])
  end)

  params:add_option("explorer_style", "explorer style",
    EXPLORER_STYLES, 1)
  params:set_action("explorer_style", function(v)
    explorer.set_style(EXPLORER_STYLES[v])
  end)

  params:add_option("bandmate_voice", "bandmate voice",
    BANDMATE_VOICES, 1)
  params:set_action("bandmate_voice", function(v)
    bandmate.set_voice(BANDMATE_VOICES[v])
  end)

  params:add_number("bandmate_root", "bandmate root", 24, 72, 48)

  params:add_option("markov_style", "markov style",
    {"melodic", "angular", "clustered", "wide"}, 1)
  params:set_action("markov_style", function(v)
    seq.markov_style = ({"melodic", "angular", "clustered", "wide"})[v]
  end)

  -- MIDI
  params:add_group("MIDI", 9)
  params:add_number("midi_in_ch", "midi in ch", 1, 16, 1)
  params:add_number("midi_out_ch", "midi out ch", 1, 16, 1)
  params:add_number("midi_out_device", "midi out device", 1, 16, 2)
  params:add_option("cc_out_enabled", "CC out", {"off", "on"}, 1)
  params:add_number("cc_out_channel", "CC out ch", 1, 16, 1)
  params:add_option("midi_clock_out", "MIDI clock out", {"off", "on"}, 1)
  params:add_option("midi_transport", "MIDI transport", {"off", "on"}, 1)
  params:add_option("midi_plock_cc", "p-lock CC out", {"off", "on"}, 1)
  params:add_number("max_voices", "max voices", 2, 8, 6)
  params:set_action("max_voices", function(v)
    max_voices = v
    engine.max_voices(v)
  end)

  -- DRUMS (creative metronome)
  params:add_group("DRUMS", 20)
  params:add_option("drum_active", "drums", {"off", "on"}, 1)
  params:set_action("drum_active", function(v)
    drum_active = (v == 2)
  end)
  params:add_option("drum_pattern", "pattern", DRUM_PATTERN_NAMES, 1)
  params:set_action("drum_pattern", function(v)
    drum_pattern = v
    drum_step = 0
  end)
  params:add_control("drum_vol", "drum vol",
    controlspec.new(0, 1, 'lin', 0.05, 0.4, ""))
  params:set_action("drum_vol", function(v) drum_vol = v end)
  params:add_control("drum_kick_vol", "kick vol",
    controlspec.new(0, 1, 'lin', 0.05, 1.0, ""))
  params:set_action("drum_kick_vol", function(v) drum_kick_vol = v end)
  params:add_control("drum_snare_vol", "snare vol",
    controlspec.new(0, 1, 'lin', 0.05, 1.0, ""))
  params:set_action("drum_snare_vol", function(v) drum_snare_vol = v end)
  params:add_control("drum_hat_vol", "hat vol",
    controlspec.new(0, 1, 'lin', 0.05, 0.6, ""))
  params:set_action("drum_hat_vol", function(v) drum_hat_vol = v end)
  params:add_control("drum_tone", "drum tone",
    controlspec.new(0, 1, 'lin', 0.05, 0.5, ""))
  params:set_action("drum_tone", function(v) drum_tone = v end)
  params:add_control("drum_lpf", "drum filter",
    controlspec.new(200, 16000, 'exp', 0, 12000, "hz"))
  params:set_action("drum_lpf", function(v) drum_lpf = v end)
  -- kick synth
  params:add_separator("KICK")
  params:add_control("kick_pitch", "kick pitch",
    controlspec.new(0.3, 3.0, 'exp', 0.01, 1.0, "x"))
  params:set_action("kick_pitch", function(v) drum_kick_pitch = v end)
  params:add_control("kick_decay", "kick decay",
    controlspec.new(0.05, 1.5, 'exp', 0.01, 0.3, "s"))
  params:set_action("kick_decay", function(v) drum_kick_decay = v end)
  params:add_control("kick_drive", "kick drive",
    controlspec.new(0, 1, 'lin', 0.05, 0.5, ""))
  params:set_action("kick_drive", function(v) drum_kick_drive = v end)
  params:add_control("kick_click", "kick click",
    controlspec.new(0, 1, 'lin', 0.05, 0.3, ""))
  params:set_action("kick_click", function(v) drum_kick_click = v end)
  -- hat synth
  params:add_separator("HAT")
  params:add_control("hat_pitch", "hat pitch",
    controlspec.new(0.3, 3.0, 'exp', 0.01, 1.0, "x"))
  params:set_action("hat_pitch", function(v) drum_hat_pitch = v end)
  params:add_control("hat_decay", "hat decay",
    controlspec.new(0.01, 0.8, 'exp', 0.01, 0.08, "s"))
  params:set_action("hat_decay", function(v) drum_hat_decay = v end)
  params:add_control("hat_drive", "hat drive",
    controlspec.new(0, 1, 'lin', 0.05, 0.0, ""))
  params:set_action("hat_drive", function(v) drum_hat_drive = v end)
  params:add_control("hat_ring", "hat ring",
    controlspec.new(0, 1, 'lin', 0.05, 0.0, ""))
  params:set_action("hat_ring", function(v) drum_hat_ring = v end)
  -- rim/snare synth
  params:add_separator("SNARE")
  params:add_control("rim_pitch", "snare pitch",
    controlspec.new(0.3, 3.0, 'exp', 0.01, 1.0, "x"))
  params:set_action("rim_pitch", function(v) drum_rim_pitch = v end)
  params:add_control("rim_decay", "snare decay",
    controlspec.new(0.01, 0.5, 'exp', 0.01, 0.06, "s"))
  params:set_action("rim_decay", function(v) drum_rim_decay = v end)
  params:add_control("rim_drive", "snare drive",
    controlspec.new(0, 1, 'lin', 0.05, 0.0, ""))
  params:set_action("rim_drive", function(v) drum_rim_drive = v end)
  params:add_control("rim_snappy", "snare snappy",
    controlspec.new(0, 1, 'lin', 0.05, 0.5, ""))
  params:set_action("rim_snappy", function(v) drum_rim_snappy = v end)

  -- SCALE LOCK
  params:add_group("SCALE LOCK", 2)
  params:add_option("scale_lock", "scale lock", SCALE_NAMES, 1)
  params:set_action("scale_lock", function(v) rebuild_scale() end)
  params:add_option("scale_root", "scale root", NOTE_NAMES, 1)
  params:set_action("scale_root", function(v) rebuild_scale() end)

  -- SCALE PROGRESSION
  params:add_group("SCALE PROGRESSION", 2)
  params:add_option("progression_mode", "progression",
    {"OFF", "DIATONIC", "MODAL", "CHROMATIC", "RANDOM"}, 1)
  params:add_option("progression_speed", "prog speed",
    {"EVERY PHASE", "EVERY 2", "EVERY 3", "EVERY 4", "EVERY 6", "EVERY 8", "EVERY 12", "EVERY 16", "RANDOM"}, 1)

  -- CHORD MODE
  params:add_group("CHORD MODE", 2)
  params:add_option("chord_mode", "chord mode",
    {"OFF", "TRIADS", "7THS", "SUS", "CLUSTERS", "OPEN"}, 1)
  params:add_option("chord_inversion", "inversion",
    {"ROOT", "1ST", "2ND", "RANDOM"}, 1)

  -- AUDIO INPUT
  params:add_group("AUDIO INPUT", 1)
  params:add_control("audio_in", "audio in",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("audio_in", function(v) engine.audio_in(v) end)

  params:add_control("amp", "master amp",
    controlspec.new(0.5, 1.0, 'lin', 0.01, 1.0, ""))
  params:set_action("amp", function(v) engine.amp(v) end)

  -- SOFTCUT TAPE LOOP
  params:add_group("TAPE LOOP", 5)
  params:add_control("tape_rec", "tape rec",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("tape_rec", function(v)
    softcut.rec_level(1, v)
  end)
  params:add_control("tape_play", "tape play",
    controlspec.new(0, 1, 'lin', 0.01, 0, ""))
  params:set_action("tape_play", function(v)
    softcut.level(1, v)
  end)
  params:add_control("tape_rate", "tape rate",
    controlspec.new(-2.0, 2.0, 'lin', 0.01, 1.0, "x"))
  params:set_action("tape_rate", function(v)
    softcut.rate(1, v)
  end)
  params:add_control("tape_feedback", "tape feedback",
    controlspec.new(0, 0.95, 'lin', 0.01, 0.5, ""))
  params:set_action("tape_feedback", function(v)
    softcut.pre_level(1, v)
  end)
  params:add_control("tape_filter", "tape filter",
    controlspec.new(200, 8000, 'exp', 0, 4000, "hz"))
  params:set_action("tape_filter", function(v)
    softcut.post_filter_fc(1, v)
  end)

  -- DUO MODE
  params:add_group("DUO MODE", 1)
  params:add_option("duo_mode", "duo mode", {"off", "on"}, 1)

  -- connect MIDI
  midi_in_device = midi.connect(1)
  midi_in_device.event = midi_event
  midi_out_device = midi.connect(params:get("midi_out_device"))

  -- init modules
  seq.init()
  init_softcut()
  rebuild_scale()

  -- autonomous note callbacks
  local auto_note_fn = function(note, vel, gate, pan_val)
    -- duo mode Voice B: use complementary chord type
    if params:get("duo_mode") == 2 and params:get("chord_mode") > 1 and
       octopus.active and octopus.duo_voice == "B" then
      -- complementary mapping: TRIADS<->SUS, 7THS<->OPEN, CLUSTERS<->TRIADS
      local complements = {[1]=1, [2]=4, [3]=6, [4]=2, [5]=2, [6]=3}
      chord_mode_override = complements[params:get("chord_mode")] or params:get("chord_mode")
    end
    note_on(note, vel, pan_val)
    clock.run(function()
      clock.sleep(gate * clock.get_beat_sec())
      note_off(note)
    end)
  end
  bandmate.note_on_fn = auto_note_fn
  octopus.note_on_fn = auto_note_fn

  -- scale progression: hook into octopus form phase changes
  octopus.on_phase_change = function(new_phase)
    advance_progression(new_phase)
  end

  -- lattice: sequencer, explorer, bandmate on separate sprockets
  my_lattice = lattice_lib:new()

  seq_sprocket = my_lattice:new_sprocket{
    action = function(t)
      if seq.playing then seq_step() end
    end,
    division = 1/8,  -- 8th notes default
    enabled = true
  }

  explorer_sprocket = my_lattice:new_sprocket{
    action = function(t)
      explorer.tick()
      bandmate.sync_explorer(
        explorer.phase,
        explorer.intensity,
        explorer.tension
      )
      grid_dirty = true
    end,
    division = 1/8,
    enabled = true
  }

  bandmate_sprocket = my_lattice:new_sprocket{
    action = function(t)
      bandmate.advance()
      grid_dirty = true
    end,
    division = 1/16,  -- 16th notes — fast autonomous melody
    enabled = true
  }

  octopus_sprocket = my_lattice:new_sprocket{
    action = function(t)
      octopus.tick()
      -- CC output: send tentacle energies + key params as CC
      if params:get("cc_out_enabled") == 2 and octopus.active and midi_out_device then
        local cc_ch = params:get("cc_out_channel")
        -- helper: only send if value changed by more than 1
        local function send_cc(num, val)
          local v = util.clamp(math.floor(val), 0, 127)
          if not last_cc[num] or math.abs(v - last_cc[num]) > 1 then
            midi_out_device:cc(num, v, cc_ch)
            last_cc[num] = v
          end
        end
        -- tentacle energies -> CC 20-27
        for i = 1, 8 do
          local e = octopus.get_tentacle_energy(i)
          send_cc(19 + i, e * 127)
        end
        -- cutoff -> CC 74
        send_cc(74, util.linlin(20, 18000, 0, 127, params:get("cutoff")))
        -- resonance -> CC 71
        send_cc(71, util.linlin(0, 3.5, 0, 127, params:get("resonance")))
        -- master_index -> CC 1
        send_cc(1, util.linlin(0, 1.5, 0, 127, params:get("master_index")))
        -- drive -> CC 16
        send_cc(16, util.linlin(0, 1, 0, 127, params:get("drive")))
        -- attack -> CC 73
        send_cc(73, util.linlin(0.001, 2, 0, 127, params:get("attack")))
        -- decay -> CC 75
        send_cc(75, util.linlin(0.01, 4, 0, 127, params:get("decay")))
        -- delay_mix -> CC 12
        send_cc(12, util.linlin(0, 1, 0, 127, params:get("delay_mix")))
        -- reverb_mix -> CC 91
        send_cc(91, util.linlin(0, 1, 0, 127, params:get("reverb_mix")))
        -- phaser_intensity -> CC 93
        send_cc(93, util.linlin(0, 1, 0, 127, params:get("phaser_intensity")))
        -- noise -> CC 15
        send_cc(15, util.linlin(0, 0.5, 0, 127, params:get("noise")))
        -- sub_osc -> CC 17
        send_cc(17, util.linlin(0, 0.5, 0, 127, params:get("sub_osc")))
        -- tilt_eq -> CC 18
        send_cc(18, util.linlin(-1, 1, 0, 127, params:get("tilt_eq")))
        -- lfo_filter -> CC 19
        send_cc(19, util.linlin(0, 1, 0, 127, params:get("lfo_filter")))
      end
      grid_dirty = true
    end,
    division = 1/16,  -- 16th notes — the octopus moves FAST
    enabled = true
  }

  midi_clock_sprocket = my_lattice:new_sprocket{
    action = function(t)
      if params:get("midi_clock_out") == 2 and midi_out_device then
        midi_out_device:clock()
      end
    end,
    division = 1/96,  -- 24ppqn: 24 clocks per quarter note = 96 per whole note
    enabled = true
  }

  drum_sprocket = my_lattice:new_sprocket{
    action = function(t)
      if not drum_active then return end
      drum_step = (drum_step % 16) + 1
      local pat = DRUM_PATTERNS[drum_pattern]
      if not pat then return end

      local k = pat.kick[drum_step] or 0
      local h = pat.hat[drum_step] or 0
      local r = pat.rim[drum_step] or 0

      if k > 0 then
        engine.drum_kick(drum_vol * drum_kick_vol * k, drum_tone,
          drum_kick_pitch, drum_kick_decay, drum_kick_drive, drum_lpf, drum_kick_click)
      end
      if h > 0 then
        engine.drum_hat(drum_vol * drum_hat_vol * h, drum_tone,
          drum_hat_pitch, drum_hat_decay, drum_hat_drive, drum_lpf, drum_hat_ring)
      end
      if r > 0 then
        engine.drum_rim(drum_vol * drum_snare_vol * r, drum_tone,
          drum_rim_pitch, drum_rim_decay, drum_rim_drive, drum_lpf, drum_rim_snappy)
      end
    end,
    division = 1/16,  -- 16th note grid
    enabled = true
  }

  my_lattice:start()

  -- grid
  g.key = grid_key
  g.remove = function() end
  g.add = function()
    g = grid.connect()
    g.key = grid_key
  end

  -- screen + grid redraw
  clock.run(function()
    while true do
      clock.sleep(1/15)
      anim_phase = anim_phase + 0.05
      if anim_phase > 2 * math.pi then anim_phase = anim_phase - 2 * math.pi end
      -- CPU protection removed (norns.cpu is not a simple number)
      screen_dirty = true
      redraw()
      if grid_dirty then
        grid_redraw()
        grid_dirty = false
      end
    end
  end)
end

-- --------------------------------------------------------------------------
-- MIDI
-- --------------------------------------------------------------------------

function midi_event(data)
  local msg = midi.to_msg(data)
  local ch = params:get("midi_in_ch")
  if msg.ch ~= ch then return end
  if msg.type == "note_on" then
    note_on(msg.note, msg.vel / 127)
  elseif msg.type == "note_off" then
    note_off(msg.note)
  end
end

function note_on(note, vel, pan_override)
  note = quantize_note(note)
  local chord_mode = chord_mode_override or params:get("chord_mode")
  local inversion = params:get("chord_inversion")
  chord_mode_override = nil  -- consume the override

  if chord_mode > 1 then
    -- chord mode: build and play all chord notes
    local notes = build_chord(note, chord_mode, inversion)
    chord_notes[note] = notes

    local ch = params:get("midi_out_ch")
    for i, n in ipairs(notes) do
      -- slight velocity reduction for upper voices (voice leading)
      local v = (i == 1) and vel or vel * (0.85 - (i - 2) * 0.05)
      v = math.max(0.2, v)
      engine.note_on(n, v)
      if pan_override then engine.pan(n, pan_override) end
      midi_out_device:note_on(n, math.floor(v * 127), ch)
    end
  else
    -- single note mode (original)
    engine.note_on(note, vel)
    if pan_override then engine.pan(note, pan_override) end
    local ch = params:get("midi_out_ch")
    midi_out_device:note_on(note, math.floor(vel * 127), ch)
  end

  current_note = note
  screen_dirty = true
end

function note_off(note)
  note = quantize_note(note)
  local ch = params:get("midi_out_ch")

  if chord_notes[note] then
    -- release all chord notes
    for _, n in ipairs(chord_notes[note]) do
      engine.note_off(n)
      midi_out_device:note_off(n, 0, ch)
    end
    chord_notes[note] = nil
  else
    -- single note release
    engine.note_off(note)
    midi_out_device:note_off(note, 0, ch)
  end

  if current_note == note then current_note = nil end
  screen_dirty = true
end

-- --------------------------------------------------------------------------
-- sequencer step
-- --------------------------------------------------------------------------

function seq_step()
  if current_note then note_off(current_note) end

  -- swing
  local swing_delay = seq.get_swing_delay()
  if swing_delay > 0 then
    clock.sleep(swing_delay * clock.get_beat_sec())
  end

  -- conditional trigger check
  if seq.should_fire() then
    local melody = seq.get_melody_step()
    if melody and melody.on then

      -- apply p-locks (timbre track overrides)
      local plocks = seq.get_plocks()
      local restore = {}

      if plocks.config then
        engine.config(plocks.config)
      else
        engine.config(config)
      end
      if plocks.cutoff then
        restore.cutoff = params:get("cutoff")
        engine.cutoff(plocks.cutoff)
      end
      if plocks.master_index then
        restore.master_index = params:get("master_index")
        engine.master_index(plocks.master_index)
      end
      if plocks.wsa then engine.wsa(plocks.wsa) end
      if plocks.wsb then engine.wsb(plocks.wsb) end
      if plocks.drive then engine.drive(plocks.drive) end
      if plocks.resonance then engine.resonance(plocks.resonance) end

      -- p-lock CC out
      if params:get("midi_plock_cc") == 2 and midi_out_device then
        local cc_ch = params:get("cc_out_channel")
        if plocks.cutoff then
          midi_out_device:cc(74, util.clamp(math.floor(util.linlin(20, 18000, 0, 127, plocks.cutoff)), 0, 127), cc_ch)
        end
        if plocks.master_index then
          midi_out_device:cc(1, util.clamp(math.floor(util.linlin(0, 1.5, 0, 127, plocks.master_index)), 0, 127), cc_ch)
        end
        if plocks.drive then
          midi_out_device:cc(16, util.clamp(math.floor(util.linlin(0, 1, 0, 127, plocks.drive)), 0, 127), cc_ch)
        end
        if plocks.resonance then
          midi_out_device:cc(71, util.clamp(math.floor(util.linlin(0, 3.5, 0, 127, plocks.resonance)), 0, 127), cc_ch)
        end
      end

      -- velocity with accent
      local vel = melody.vel
      if seq.is_accent() then vel = math.min(1.0, vel * 1.3) end

      -- ratchets: subdivide the step
      local ratchet = seq.get_ratchet()
      local gate = seq.get_gate_length()

      -- apply octopus spatial pan if set
      local oct_pan = octopus and octopus.next_pan
      if oct_pan then octopus.next_pan = nil end

      if ratchet > 1 then
        -- ratcheted: multiple triggers within one step
        local sub_gate = gate / ratchet * 0.7
        for r = 1, ratchet do
          clock.run(function()
            clock.sleep((r - 1) * (1 / ratchet) * clock.get_beat_sec())
            note_on(melody.note, vel * (1 - (r-1) * 0.15), oct_pan)
            clock.sleep(sub_gate * clock.get_beat_sec())
            note_off(melody.note)
          end)
        end
      else
        -- normal single trigger
        note_on(melody.note, vel, oct_pan)
        clock.run(function()
          clock.sleep(gate * clock.get_beat_sec())
          note_off(melody.note)
          -- restore p-locked params
          if restore.cutoff then engine.cutoff(restore.cutoff) end
          if restore.master_index then engine.master_index(restore.master_index) end
          if not plocks.config then engine.config(config) end
        end)
      end
    end
  end

  seq.advance()
  screen_dirty = true
  grid_dirty = true
end

-- --------------------------------------------------------------------------
-- encoders and keys
-- --------------------------------------------------------------------------

function enc(n, d)
  if n == 1 then
    page = util.clamp(page + d, 1, #PAGES)
  elseif page == 1 then
    if n == 2 then
      config = util.clamp(config + d, 0, 11)
      params:set("config", config + 1)
    elseif n == 3 then
      params:delta("master_index", d)
    end
  elseif page == 2 then
    if n == 2 then
      ratio_select = util.clamp(ratio_select + d, 1, 3)
    elseif n == 3 then
      local idx = ratio_idx[ratio_select]
      idx = util.clamp(idx + d, 1, #RATIOS)
      ratio_idx[ratio_select] = idx
      params:set("ratio" .. (ratio_select + 1), RATIOS[idx])
    end
  elseif page == 3 then
    if n == 2 then
      wsa_preset = util.clamp(wsa_preset + d, 0, 7)
      params:set("wsa_preset", wsa_preset + 1)
    elseif n == 3 then
      wsb_preset = util.clamp(wsb_preset + d, 0, 7)
      params:set("wsb_preset", wsb_preset + 1)
    end
  elseif page == 4 then
    if n == 2 then
      if k2_held then
        params:delta("drive", d)
      else
        params:delta("cutoff", d)
      end
    elseif n == 3 then
      params:delta("resonance", d)
    end
  elseif page == 5 then
    if n == 2 then
      if k2_held then
        params:delta("phaser_rate", d)
      else
        params:delta("phaser_intensity", d)
      end
    elseif n == 3 then
      if k2_held then
        params:delta("tilt_eq", d)
      else
        params:delta("exciter_amount", d)
      end
    end
  elseif page == 6 then
    -- OCTOPUS page
    if n == 2 then
      -- cycle soul
      params:delta("octopus_soul", d)
    elseif n == 3 then
      -- cycle bandmate voice
      params:delta("bandmate_voice", d)
    end
  end
  screen_dirty = true
end

function key(n, z)
  if n == 2 then
    -- K2: play/stop sequencer
    if z == 1 then
      k2_held = true
    else
      k2_held = false
      seq.playing = not seq.playing
      if not seq.playing and current_note then note_off(current_note) end
      if seq.playing then seq.reset() end
      if params:get("midi_transport") == 2 and midi_out_device then
        if seq.playing then midi_out_device:start() else midi_out_device:stop() end
      end
    end

  elseif n == 3 then
    if z == 1 then
      -- K3 press: start timer for long press detection
      k3_press_time = util.time()
    else
      -- K3 release: check duration
      local held = util.time() - (k3_press_time or 0)
      if held > 0.5 then
        -- LONG PRESS: toggle octopus (the 100-handed operator)
        if octopus.active then
          octopus.stop()
          bandmate.stop()
          explorer.stop()
        else
          -- reset progression state
          progression_idx = 0
          progression_phase_count = 0
          octopus.start(
            octopus.SOUL_NAMES[params:get("octopus_soul") or 3],
            params:get("bandmate_root")
          )
          -- also start bandmate for autonomous melody
          bandmate.start(
            params:get("bandmate_root"),
            BANDMATE_VOICES[params:get("bandmate_voice")]
          )
        end
      else
        -- SHORT TAP: page-specific randomize
        if page == 1 then
          config = math.random(0, 11)
          params:set("config", config + 1)
          for i = 1, 3 do
            ratio_idx[i] = math.random(1, #RATIOS)
            params:set("ratio" .. (i + 1), RATIOS[ratio_idx[i]])
          end
        elseif page == 2 then
          for i = 1, 3 do
            ratio_idx[i] = math.random(1, #RATIOS)
            params:set("ratio" .. (i + 1), RATIOS[ratio_idx[i]])
          end
        elseif page == 3 then
          wsa_preset = math.random(0, 7)
          wsb_preset = math.random(0, 7)
          params:set("wsa_preset", wsa_preset + 1)
          params:set("wsb_preset", wsb_preset + 1)
        elseif page == 4 then
          params:set("cutoff", math.random(100, 8000))
          params:set("resonance", math.random() * 2.5)
        elseif page == 5 then
          params:set("phaser_intensity", math.random() * 0.8)
          params:set("exciter_amount", math.random() * 0.6)
        elseif page == 6 then
          -- randomize soul + voice combo
          params:set("octopus_soul", math.random(1, #octopus.SOUL_NAMES))
          params:set("bandmate_voice", math.random(1, #BANDMATE_VOICES))
          -- randomize sequencer
          seq.randomize_all(params:get("bandmate_root"))
        end
      end
    end
  end
  screen_dirty = true
end

-- --------------------------------------------------------------------------
-- screen
-- --------------------------------------------------------------------------

function redraw()
  if not screen_dirty then return end
  screen_dirty = false

  screen.clear()
  screen.aa(1)

  -- header: page name
  screen.level(2)
  screen.move(1, 7)
  screen.text(PAGES[page])

  -- page dots
  for i = 1, #PAGES do
    screen.level(i == page and 15 or 2)
    screen.rect(100 + (i-1) * 2, 2, 1, 1)
    screen.fill()
  end

  -- autonomous systems indicator
  if bandmate.active then
    -- breathing pulse
    local pulse = math.floor(bandmate.energy * 10)
    screen.level(pulse + 2)
    screen.move(112, 7)
    screen.text(explorer.get_phase_name():sub(1,3))
  end

  -- sequencer dots (melody track position)
  if seq.playing then
    screen.level(6)
    screen.rect(60, 1, 2, 2)
    screen.fill()
    local mel_len = seq.track_len[seq.TRACK_MELODY]
    local mel_pos = seq.track_pos[seq.TRACK_MELODY]
    for i = 1, math.min(mel_len, 16) do
      screen.level(i == mel_pos and 15 or 3)
      screen.rect(64 + (i-1) * 3, 2, 1, 1)
      screen.fill()
    end
  end

  -- page content
  if page == 1 then
    draw_topology_page()
  elseif page == 2 then
    draw_ratios_page()
  elseif page == 3 then
    draw_shape_page()
  elseif page == 4 then
    draw_filter_page()
  elseif page == 5 then
    draw_effects_page()
  elseif page == 6 then
    draw_octopus_page()
  end

  screen.update()
end

-- --------------------------------------------------------------------------
-- page drawings
-- --------------------------------------------------------------------------

function draw_topology_page()
  screen.level(15)
  screen.font_size(16)
  screen.move(4, 32)
  screen.text(string.format("%02d", config))
  screen.font_size(8)
  screen.move(30, 32)
  screen.text(CONFIG_NAMES[config])

  -- FM topology diagram
  local osc_x = {80, 100, 80, 100}
  local osc_y = {20, 20, 42, 42}

  local conns = TOPOLOGY_CONNECTIONS[config] or {}
  for _, c in ipairs(conns) do
    local from, to = c[1], c[2]
    if from >= 1 and from <= 4 and to >= 1 and to <= 4 then
      local pulse = math.abs(math.sin(anim_phase * 2 + from))
      screen.level(math.floor(3 + pulse * 8))
      screen.move(osc_x[from], osc_y[from])
      screen.line(osc_x[to], osc_y[to])
      screen.stroke()
    end
  end

  for i = 1, 4 do
    screen.level(15)
    screen.circle(osc_x[i], osc_y[i], 5)
    screen.stroke()
    screen.level(4)
    screen.circle(osc_x[i], osc_y[i], 4)
    screen.fill()
    screen.level(15)
    screen.move(osc_x[i] - 2, osc_y[i] + 3)
    screen.text(i)
  end

  -- master index bar
  screen.level(6)
  screen.move(4, 52)
  screen.text("IDX")
  screen.level(3)
  screen.rect(22, 47, 40, 5)
  screen.stroke()
  screen.level(12)
  screen.rect(22, 47, util.clamp(master_index / 2.0, 0, 1) * 40, 5)
  screen.fill()

  -- progression root indicator
  if params:get("progression_mode") > 1 then
    local root_idx = params:get("scale_root")
    screen.level(6)
    screen.move(80, 52)
    screen.text("ROOT " .. NOTE_NAMES[root_idx])
  end

  screen.level(2)
  screen.move(1, 63)
  screen.text("E2:config E3:idx K3:rnd hold:auto")
end

function draw_ratios_page()
  local osc_names = {"OSC 2", "OSC 3", "OSC 4"}
  for i = 1, 3 do
    local y = 16 + (i-1) * 16
    local sel = (i == ratio_select)
    screen.level(sel and 15 or 4)
    screen.move(4, y)
    screen.text(osc_names[i])
    screen.level(sel and 15 or 8)
    screen.move(40, y)
    screen.text(string.format("%.2fx", ratios[i]))
    screen.level(sel and 3 or 1)
    screen.rect(70, y - 5, 50, 5)
    screen.stroke()
    screen.level(sel and 12 or 5)
    screen.rect(70, y - 5, util.clamp(ratios[i] / 8.0, 0, 1) * 50, 5)
    screen.fill()
  end
  screen.level(2)
  screen.move(1, 63)
  screen.text("E2:select  E3:ratio  K3:random")
end

function draw_shape_page()
  screen.level(8)
  screen.move(4, 14)
  screen.text("WSA")
  screen.level(4)
  screen.move(4, 22)
  screen.text(WS_NAMES[wsa_preset])
  draw_waveshape_curve(4, 26, 54, 28, wsa_preset)

  screen.level(8)
  screen.move(68, 14)
  screen.text("WSB")
  screen.level(4)
  screen.move(68, 22)
  screen.text(WS_NAMES[wsb_preset])
  draw_waveshape_curve(68, 26, 54, 28, wsb_preset)

  screen.level(2)
  screen.move(1, 63)
  screen.text("E2:WSA  E3:WSB  K3:random")
end

function draw_waveshape_curve(x, y, w, h, preset)
  screen.level(2)
  screen.rect(x, y, w, h)
  screen.stroke()
  screen.level(10)
  for i = 0, w - 1 do
    local input = (i / w) * 2 - 1
    local output = waveshape_approx(input, preset)
    local px = x + i
    local py = util.clamp(y + h/2 - output * h/2, y, y + h)
    if i == 0 then screen.move(px, py) else screen.line(px, py) end
  end
  screen.stroke()
end

function waveshape_approx(x, preset)
  if preset == 0 then return x
  elseif preset == 1 then return math.tanh(x * 1.5)
  elseif preset == 2 then return util.clamp(x * 1.5, -0.6, 0.6) / 0.6
  elseif preset == 3 then
    local v = x * 2
    while v > 1 do v = 2 - v end
    while v < -1 do v = -2 - v end
    return v
  elseif preset == 4 then return math.sin(x * math.pi)
  elseif preset == 5 then
    local sign = x >= 0 and 1 or -1
    return (x * x * sign * 0.8) + (x * 0.5)
  elseif preset == 6 then return math.floor(x * 6 + 0.5) / 6
  elseif preset == 7 then return 4 * x * x * x - 3 * x
  end
  return x
end

function draw_filter_page()
  screen.level(15)
  screen.move(4, 16)
  screen.text(string.format("%.0f hz", cutoff))
  screen.level(8)
  screen.move(80, 16)
  screen.text(string.format("Q %.2f", resonance))

  if drive > 0.01 then
    screen.level(6)
    screen.move(4, 24)
    screen.text(string.format("DRV %.0f%%", drive * 100))
  end

  local cx, cy, cw, ch = 4, 28, 120, 28
  screen.level(1)
  screen.rect(cx, cy, cw, ch)
  screen.stroke()

  for _, f in ipairs({100, 1000, 10000}) do
    local fx = cx + (math.log(f/20) / math.log(18000/20)) * cw
    screen.move(fx, cy)
    screen.line(fx, cy + ch)
    screen.stroke()
  end

  screen.level(12)
  local cutoff_log = math.log(cutoff / 20) / math.log(18000 / 20)
  for i = 0, cw - 1 do
    local diff = i / cw - cutoff_log
    local response
    if diff <= 0 then
      response = 1.0
      if math.abs(diff) < 0.08 then
        response = response + resonance * 0.5 * (1 - math.abs(diff) / 0.08)
      end
    else
      response = math.max(0, 1.0 - diff * 4)
      response = response * response
    end
    response = util.clamp(response, 0, 1.5)
    local py = util.clamp(cy + ch - response * ch * 0.6, cy, cy + ch)
    if i == 0 then screen.move(cx + i, py) else screen.line(cx + i, py) end
  end
  screen.stroke()

  screen.level(6)
  local marker_x = cx + cutoff_log * cw
  screen.move(marker_x, cy)
  screen.line(marker_x, cy + ch)
  screen.stroke()

  screen.level(2)
  screen.move(1, 63)
  screen.text(k2_held and "E2:drive  E3:res" or "E2:cutoff  E3:res  hK2:drive")
end

function draw_effects_page()
  screen.level(8)
  screen.move(4, 14)
  screen.text("PHASER")
  screen.level(phaser_intensity > 0.01 and 12 or 3)
  screen.move(50, 14)
  screen.text(string.format("%.0f%%", phaser_intensity * 100))

  if phaser_intensity > 0.01 then
    screen.level(6)
    for i = 0, 50 do
      local phase = anim_phase + i * 0.15
      local s = math.sin(phase)
      local val = s * (1.5 - 0.5 * s * s) * 0.7 + math.sin(phase) * 0.3
      local py = 24 + val * 6
      if i == 0 then screen.move(4 + i, py) else screen.line(4 + i, py) end
    end
    screen.stroke()
  end

  screen.level(8)
  screen.move(4, 40)
  screen.text("EXCITER")
  screen.level(exciter_amount > 0.01 and 12 or 3)
  screen.move(56, 40)
  screen.text(string.format("%.0f%%", exciter_amount * 100))

  if exciter_amount > 0.01 then
    for i, h in ipairs({1.0, 0.6, 0.3}) do
      local bh = h * exciter_amount * 12
      screen.level(math.floor(4 + h * 8))
      screen.rect(4 + (i-1) * 20, 50 - bh, 14, bh)
      screen.fill()
    end
    screen.level(2)
    screen.move(4, 54)
    screen.text("1   2   3")
  end

  if math.abs(tilt_eq) > 0.05 then
    screen.level(4)
    screen.move(80, 40)
    screen.text("TILT")
    screen.level(8)
    screen.move(105, 40)
    screen.text(tilt_eq < 0 and "DARK" or "BRIT")
  end

  -- octopus info (when active)
  if octopus.active then
    local oi = octopus.get_info()
    screen.level(6)
    screen.move(70, 42)
    screen.text(oi.soul:sub(1,5) .. " " .. oi.form)
    -- tentacle energy bars (8 tiny bars)
    for i = 1, 8 do
      local e = oi.energies[i] or 0
      local bx = 70 + (i-1) * 7
      local bh = math.floor(e * 10)
      screen.level(math.floor(2 + e * 10))
      screen.rect(bx, 56 - bh, 5, bh)
      screen.fill()
    end
    screen.level(2)
    screen.move(70, 62)
    screen.text("T S F R M P C X")
  elseif bandmate.active then
    local bi = bandmate.get_info()
    screen.level(4)
    screen.move(70, 54)
    screen.text(bi.voice .. " " .. bi.breath)
    screen.level(math.floor(bi.energy * 12) + 2)
    screen.rect(70, 56, bi.energy * 56, 2)
    screen.fill()
  end

  screen.level(2)
  screen.move(1, 63)
  screen.text(k2_held and "E2:rate  E3:tilt" or "E2:phaser  E3:exciter  hK2:alt")
end

function draw_octopus_page()
  local oi = octopus.get_info()

  -- center of the octopus
  local cx, cy = 64, 30

  -- 8 tentacles radiating from center
  -- each tentacle is a series of segments that curve based on energy + anim_phase
  for i = 1, 8 do
    local e = oi.energies[i] or 0
    local base_angle = (i - 1) * (2 * math.pi / 8) - math.pi / 2

    -- tentacle length scales with energy
    local length = 12 + e * 20
    local segments = 6

    -- draw tentacle as connected line segments
    screen.level(math.floor(2 + e * 12))
    local px, py = cx, cy

    for seg = 1, segments do
      local t = seg / segments
      -- each segment bends with a sine wave, phase-shifted per tentacle
      local wave = math.sin(anim_phase * (2 + i * 0.3) + seg * 0.8) * e * 0.6
      local angle = base_angle + wave * (0.5 + t * 0.5)

      local seg_len = length / segments
      local nx = px + math.cos(angle) * seg_len
      local ny = py + math.sin(angle) * seg_len

      -- thicker near base (brightness), thinner at tip
      screen.level(math.floor((1 - t * 0.6) * (3 + e * 12)))
      screen.move(px, py)
      screen.line(nx, ny)
      screen.stroke()

      -- tip glow when energy is high
      if seg == segments and e > 0.5 then
        local glow = math.abs(math.sin(anim_phase * 3 + i))
        screen.level(math.floor(glow * e * 8))
        screen.circle(nx, ny, 1 + e)
        screen.fill()
      end

      px, py = nx, ny
    end
  end

  -- center body: pulses with overall energy
  local total_energy = 0
  for i = 1, 8 do total_energy = total_energy + (oi.energies[i] or 0) end
  total_energy = total_energy / 8

  local body_pulse = 3 + math.sin(anim_phase * 2) * total_energy * 2
  screen.level(math.floor(4 + total_energy * 10))
  screen.circle(cx, cy, body_pulse)
  screen.fill()
  screen.level(15)
  screen.circle(cx, cy, body_pulse + 1)
  screen.stroke()

  -- soul name (top left)
  screen.level(15)
  screen.move(2, 7)
  screen.text(oi.soul)

  -- form phase (top right)
  screen.level(8)
  screen.move(96, 7)
  screen.text(oi.form)

  -- form progress bar
  screen.level(3)
  screen.rect(96, 9, 30, 2)
  screen.stroke()
  screen.level(10)
  local progress = oi.form_length > 0 and (oi.form_beat / oi.form_length) or 0
  screen.rect(96, 9, progress * 30, 2)
  screen.fill()

  -- duo mode labels near melody/topology tentacles
  if params:get("duo_mode") == 2 and octopus.active then
    local melody_angle = (5 - 1) * (2 * math.pi / 8) - math.pi / 2  -- MELODY = tentacle 5
    local topo_angle = (1 - 1) * (2 * math.pi / 8) - math.pi / 2   -- TOPOLOGY = tentacle 1
    local a_x = cx + math.cos(melody_angle) * 28
    local a_y = cy + math.sin(melody_angle) * 28
    local b_x = cx + math.cos(topo_angle) * 28
    local b_y = cy + math.sin(topo_angle) * 28
    screen.level(octopus.duo_voice == "A" and 15 or 4)
    screen.move(a_x - 2, a_y + 3)
    screen.text("A")
    screen.level(octopus.duo_voice == "B" and 15 or 4)
    screen.move(b_x - 2, b_y + 3)
    screen.text("B")
  end

  -- active / bandmate
  if octopus.active then
    screen.level(math.floor(4 + total_energy * 8))
    screen.move(2, 63)
    screen.text("ALIVE")
  else
    screen.level(3)
    screen.move(2, 63)
    screen.text("SLEEP")
  end

  -- chord mode indicator
  local cm = params:get("chord_mode")
  if cm > 1 then
    local chord_names = {"", "TRI", "7TH", "SUS", "CLU", "OPN"}
    screen.level(6)
    screen.move(36, 63)
    screen.text(chord_names[cm])
  end

  local bi = bandmate.get_info()
  screen.level(5)
  screen.move(54, 63)
  screen.text(bi.voice)

  screen.level(2)
  screen.move(80, 63)
  screen.text("E2:soul E3:voice")
end

-- --------------------------------------------------------------------------
-- grid
-- --------------------------------------------------------------------------
--
-- layout (8 rows x 16 cols):
--
-- row 1: [topology 1-12] . [bandmate 14] [explorer 15] [play 16]
-- row 2: [WSA 1-8] [WSB 9-16]
-- row 3: [sequencer steps 1-16] (toggle, playhead bright)
-- row 4: [per-step topology 1-16] (press to cycle config override)
-- rows 5-8: [index faders 1-6 vertical] . [master index 8-16 horizontal on row 5]
--           [bandmate style 8-12 on row 6]
--           [explorer phase 8-11 on row 7] [randomize 13-16 on row 7]
--           [status: explorer intensity col 15, bandmate energy col 16]

function grid_key(x, y, z)
  -- GRID MODE TOGGLE: col 16, row 8
  if x == 16 and y == 8 and z == 1 then
    grid_mode = (grid_mode == "FADERS") and "KEYS" or "FADERS"
    -- release all held keyboard notes on mode switch
    for k, note in pairs(grid_keys_held) do
      note_off(note)
      grid_keys_held[k] = nil
    end
    grid_dirty = true
    screen_dirty = true
    return
  end

  if z == 1 then
    -- ROW 1: topology select + system toggles
    if y == 1 then
      if x >= 1 and x <= 12 then
        config = x - 1
        params:set("config", config + 1)
      elseif x == 14 then
        -- toggle bandmate
        if bandmate.active then
          bandmate.stop()
        else
          bandmate.start(
            params:get("bandmate_root"),
            BANDMATE_VOICES[params:get("bandmate_voice")]
          )
        end
      elseif x == 15 then
        -- toggle explorer
        if explorer.active then
          explorer.stop()
        else
          explorer.start(EXPLORER_STYLES[params:get("explorer_style")])
        end
      elseif x == 16 then
        -- play/stop sequencer
        seq.playing = not seq.playing
        if not seq.playing and current_note then note_off(current_note) end
        if seq.playing then seq.reset() end
        if params:get("midi_transport") == 2 and midi_out_device then
          if seq.playing then midi_out_device:start() else midi_out_device:stop() end
        end
      end

    -- ROW 2: waveshape select
    elseif y == 2 then
      if x >= 1 and x <= 8 then
        wsa_preset = x - 1
        params:set("wsa_preset", wsa_preset + 1)
      elseif x >= 9 and x <= 16 then
        wsb_preset = x - 9
        params:set("wsb_preset", wsb_preset + 1)
      end

    -- ROW 3: melody step toggle
    elseif y == 3 then
      if x >= 1 and x <= seq.track_len[seq.TRACK_MELODY] then
        seq.melody[x].on = not seq.melody[x].on
      end

    -- ROW 4: timbre p-lock topology (press to cycle)
    elseif y == 4 then
      if x >= 1 and x <= seq.track_len[seq.TRACK_TIMBRE] then
        local step = seq.timbre[x]
        step.config = step.config + 1
        if step.config > 11 then step.config = -1 end
      end

    -- ROWS 5-8: keyboard mode OR fader mode
    elseif y >= 5 and y <= 8 then
      if grid_mode == "KEYS" then
        -- KEYBOARD MODE: isomorphic keyboard on rows 5-8
        local root = params:get("bandmate_root")
        local octave = 8 - y  -- row 8=0, row 7=1, row 6=2, row 5=3 (highest)
        local semitone = x - 1
        local midi_note = root + (octave * 12) + semitone
        local vel_map = {[5]=1.0, [6]=0.8, [7]=0.6, [8]=0.45}
        local vel = vel_map[y] or 0.7
        local key = x .. "_" .. y
        note_on(midi_note, vel)
        grid_keys_held[key] = midi_note
      else
        -- FADER MODE (original behavior)
        -- cols 1-6: FM index faders (vertical, 4 rows = 4 levels per index)
        if x >= 1 and x <= 6 then
          local val = util.linlin(8, 5, 0, 1.5, y)
          params:set("index" .. x, val)
        -- col 8-16, row 5: master index horizontal fader
        elseif x >= 8 and x <= 16 and y == 5 then
          local val = util.linlin(8, 16, 0, 2.0, x)
          params:set("master_index", val)
        -- col 8-12, row 6: bandmate voice
        elseif x >= 8 and x <= 12 and y == 6 then
          local voice_idx = x - 7
          if voice_idx >= 1 and voice_idx <= #BANDMATE_VOICES then
            params:set("bandmate_voice", voice_idx)
          end
        -- col 8-11, row 7: force explorer phase
        elseif x >= 8 and x <= 11 and y == 7 then
          if explorer.active then
            explorer.enter_phase(x - 7)
          end
        -- col 13-16, row 7: randomize actions
        elseif y == 7 then
          if x == 13 then
            config = math.random(0, 11)
            params:set("config", config + 1)
          elseif x == 14 then
            for i = 1, 3 do
              ratio_idx[i] = math.random(1, #RATIOS)
              params:set("ratio" .. (i + 1), RATIOS[ratio_idx[i]])
            end
          elseif x == 15 then
            for i = 1, 6 do
              params:set("index" .. i, math.random() * 1.5)
            end
          elseif x == 16 then
            wsa_preset = math.random(0, 7)
            wsb_preset = math.random(0, 7)
            params:set("wsa_preset", wsa_preset + 1)
            params:set("wsb_preset", wsb_preset + 1)
          end
        -- ROW 8, cols 8-15: preset slots (FADERS mode only)
        elseif y == 8 and x >= 8 and x <= 15 then
          local slot = x - 7  -- 1-8
          preset_press_time[slot] = util.time()
        end
      end
    end

  else  -- z == 0 (key release)
    -- keyboard mode note-off
    if grid_mode == "KEYS" and y >= 5 and y <= 8 then
      local key = x .. "_" .. y
      if grid_keys_held[key] then
        note_off(grid_keys_held[key])
        grid_keys_held[key] = nil
      end
    end

    -- preset slot release (FADERS mode): short=recall, long=save
    if grid_mode == "FADERS" and y == 8 and x >= 8 and x <= 15 then
      local slot = x - 7
      if preset_press_time[slot] then
        local held = util.time() - preset_press_time[slot]
        if held > 0.5 then
          save_preset(slot)
        else
          recall_preset(slot)
        end
        preset_press_time[slot] = nil
      end
    end
  end

  grid_dirty = true
  screen_dirty = true
end

function grid_redraw()
  g:all(0)

  -- ROW 1: topology select (1-12)
  for x = 1, 12 do
    if x - 1 == config then
      g:led(x, 1, 15)  -- current topology bright
    else
      g:led(x, 1, 3)   -- others dim
    end
  end
  -- progression indicator (col 13, row 1)
  if params:get("progression_mode") > 1 then
    local prog_brightness = 4 + math.floor(math.abs(math.sin(anim_phase * 2)) * 8)
    g:led(13, 1, prog_brightness)
  else
    g:led(13, 1, 0)
  end
  -- bandmate toggle
  g:led(14, 1, bandmate.active and 12 or 3)
  -- explorer toggle
  g:led(15, 1, explorer.active and 12 or 3)
  -- play/stop
  g:led(16, 1, seq.playing and 15 or 4)

  -- ROW 2: waveshape A (1-8) + B (9-16)
  for x = 1, 8 do
    g:led(x, 2, (x - 1) == wsa_preset and 12 or 3)
  end
  for x = 9, 16 do
    g:led(x, 2, (x - 9) == wsb_preset and 12 or 3)
  end

  -- ROW 3: melody steps
  local mel_len = seq.track_len[seq.TRACK_MELODY]
  local mel_pos = seq.track_pos[seq.TRACK_MELODY]
  for x = 1, mel_len do
    local step = seq.melody[x]
    local bright = 0
    if step and step.on then
      bright = math.floor(step.vel * 8) + 2
      if seq.playing and x == mel_pos then bright = 15 end
    else
      if seq.playing and x == mel_pos then bright = 4 end
    end
    g:led(x, 3, bright)
  end

  -- ROW 4: timbre p-lock topology
  local tim_len = seq.track_len[seq.TRACK_TIMBRE]
  local tim_pos = seq.track_pos[seq.TRACK_TIMBRE]
  for x = 1, tim_len do
    local step = seq.timbre[x]
    if step then
      if step.config >= 0 then
        g:led(x, 4, math.floor(3 + step.config))
      else
        g:led(x, 4, 1)
      end
      -- timbre playhead
      if seq.playing and x == tim_pos then
        g:led(x, 4, 15)
      end
    end
  end

  if grid_mode == "KEYS" then
    -- KEYBOARD MODE: rows 5-8 = isomorphic keyboard
    local root = params:get("bandmate_root")
    -- build set of currently sounding chord notes for dim display
    local chord_playing = {}
    for _, cnotes in pairs(chord_notes) do
      for _, n in ipairs(cnotes) do chord_playing[n] = true end
    end
    for row = 5, 8 do
      local octave = 8 - row
      for col = 1, 16 do
        local midi_note = root + (octave * 12) + (col - 1)
        local key = col .. "_" .. row
        if grid_keys_held[key] then
          g:led(col, row, 15)  -- held notes bright
        elseif chord_playing[midi_note] then
          g:led(col, row, 8)   -- chord notes medium
        elseif #scale_lock_scale > 0 then
          -- check if note is in scale
          local in_scale = false
          for _, sn in ipairs(scale_lock_scale) do
            if sn % 12 == midi_note % 12 then in_scale = true; break end
          end
          g:led(col, row, in_scale and 5 or 2)
        else
          g:led(col, row, 2)
        end
      end
    end
  else
    -- FADER MODE (original)
    -- ROWS 5-8: FM index faders (cols 1-6, vertical)
    for idx = 1, 6 do
      local val = index_values[idx]
      local fill_rows = math.floor(util.linlin(0, 1.5, 0, 4, val) + 0.5)
      for row = 8, 5, -1 do
        local row_from_bottom = 8 - row
        if row_from_bottom < fill_rows then
          g:led(idx, row, 10)
        else
          g:led(idx, row, 1)
        end
      end
    end

    -- ROW 5, cols 8-16: master index horizontal bar
    local master_fill = math.floor(util.linlin(0, 2.0, 0, 9, master_index) + 0.5)
    for x = 8, 16 do
      local col_from_left = x - 7
      if col_from_left <= master_fill then
        g:led(x, 5, 10)
      else
        g:led(x, 5, 1)
      end
    end

    -- ROW 6, cols 8-12: bandmate voice
    for i = 1, #BANDMATE_VOICES do
      local x = i + 7
      local is_current = (BANDMATE_VOICES[i] == bandmate.voice)
      g:led(x, 6, is_current and 12 or 3)
    end

    -- ROW 7, cols 8-11: octopus form phase / explorer phase
    if octopus.active then
      local form_idx = ({DRIFT=1, BUILD=2, PEAK=3, REST=4})[octopus.form_phase] or 1
      for i = 1, 4 do
        g:led(i + 7, 7, i == form_idx and 12 or 3)
      end
    elseif explorer.active then
      for i = 1, 4 do
        g:led(i + 7, 7, i == explorer.phase and 12 or 3)
      end
    else
      for i = 8, 11 do g:led(i, 7, 1) end
    end

    -- ROW 7, cols 13-16: randomize buttons
    for x = 13, 16 do
      g:led(x, 7, 4)
    end

    -- ROW 8, cols 8-15: preset slots
    for i = 1, 8 do
      local x = i + 7
      if i == preset_active then
        g:led(x, 8, 15)  -- recalling: bright
      elseif presets[i] then
        g:led(x, 8, 7)   -- saved: medium
      else
        g:led(x, 8, 2)   -- empty: dim
      end
    end

    -- STATUS METERS (col 15-16, rows 5-7)
    if octopus.active then
      g:led(16, 5, 10)
      g:led(16, 6, 10)
      g:led(16, 7, 10)
    elseif explorer.active then
      local exp_fill = math.floor(explorer.intensity * 3 + 0.5)
      for row = 7, 5, -1 do
        g:led(15, row, (7 - row) < exp_fill and 8 or 0)
      end
    end
    if bandmate.active then
      local bm_fill = math.floor(bandmate.energy * 3 + 0.5)
      for row = 7, 5, -1 do
        g:led(16, row, (7 - row) < bm_fill and 8 or 0)
      end
    end
  end

  -- grid mode toggle indicator (col 16, row 8)
  g:led(16, 8, grid_mode == "KEYS" and 15 or 4)

  g:refresh()
end

-- --------------------------------------------------------------------------
-- cleanup
-- --------------------------------------------------------------------------

function cleanup()
  if current_note then note_off(current_note) end
  -- release all chord notes
  for root, notes in pairs(chord_notes) do
    for _, n in ipairs(notes) do
      engine.note_off(n)
      midi_out_device:note_off(n, 0, params:get("midi_out_ch"))
    end
  end
  chord_notes = {}
  -- release all grid keyboard notes
  for k, note in pairs(grid_keys_held) do
    note_off(note)
  end
  grid_keys_held = {}
  octopus.stop()
  bandmate.stop()
  explorer.stop()
  softcut.play(1, 0)
  softcut.rec(1, 0)
  if my_lattice then my_lattice:destroy() end
end
