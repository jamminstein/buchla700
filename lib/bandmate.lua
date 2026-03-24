-- bucha bandmate
--
-- not a note generator. a musician.
-- aware of what the explorer is doing, responds to it.
-- has memory, taste, and the sense to shut up when it should.
--
-- 5 voices (not just styles — personalities):
--
--   DRIFT:    slow, sustained. held notes with gentle vibrato.
--             thinks in long arcs. barely moves when explorer is in DRIFT,
--             becomes more active when explorer enters MORPH.
--             inspired by: buchla easel meditation, pauline oliveros
--
--   PULSE:    rhythmic, driving. locks to the clock.
--             creates interlocking patterns with the sequencer.
--             during CHAOS, goes into rapid-fire 16th mode.
--             inspired by: silver apples of the moon, morton subotnick
--
--   BELLS:    crystalline attacks, wide intervals, quick decay.
--             metallic FM territory — inharmonic ratios.
--             plays sparse during DRIFT, dense clusters in CHAOS.
--             inspired by: buchla thunder, don buchla performances
--
--   VOICE:    singing, legato. small intervals, long phrases.
--             chromatic approaches, breath-like phrasing.
--             the most "human" voice — rests often, responds to tension.
--             inspired by: coltrane sheets of sound through a buchla
--
--   SWARM:    granular thinking. rapid repeated notes, micro-clusters.
--             density controlled by explorer intensity.
--             in DRIFT: occasional chirps. in CHAOS: insect cloud.
--             inspired by: xenakis, iannis, stochastic music

local bandmate = {}

-- --------------------------------------------------------------------------
-- state
-- --------------------------------------------------------------------------

bandmate.active = false
bandmate.energy = 0.0
bandmate.breath_phase = "build"
bandmate.breath_timer = 0
bandmate.breath_target = 0.8    -- where energy is heading

-- song form
bandmate.form_phase = "home"
bandmate.form_bar = 0
bandmate.form_length = 8
bandmate.form_template = {}
bandmate.form_idx = 1
bandmate.home_state = nil

-- pattern
bandmate.pattern = {}
bandmate.pattern_len = 8
bandmate.pattern_pos = 0
bandmate.phrase_count = 0

-- melodic state
bandmate.root = 48
bandmate.last_note = 48
bandmate.register = 0
bandmate.memory = {}          -- remembers last N notes for motivic development
bandmate.memory_size = 8

-- meta: awareness of explorer
bandmate.explorer_phase = 1
bandmate.explorer_intensity = 0
bandmate.explorer_tension = 0

-- style
bandmate.voice = "DRIFT"

-- callbacks
bandmate.note_on_fn = nil
bandmate.note_off_fn = nil

-- --------------------------------------------------------------------------
-- voices: deep personality profiles
-- --------------------------------------------------------------------------

local VOICES = {
  DRIFT = {
    -- interval pools per explorer phase
    intervals = {
      drift  = {0, 0, 0, 0, 5, 7, -5, 12},          -- sparse, open
      morph  = {0, 0, 2, -2, 5, 7, -5, 3},            -- gentle motion
      chaos  = {0, 3, -3, 5, -5, 7, -7, 2, -2},       -- more active
      resolve = {0, 0, 0, 5, -5, 0, 0},                -- settling
    },
    density = {0.25, 0.40, 0.55, 0.20},    -- per explorer phase
    gate_range = {0.6, 1.2},               -- long sustains
    vel_base = 0.35,
    vel_range = 0.25,
    ghost_prob = 0.08,
    rest_love = 0.4,                       -- loves silence
    phrase_lengths = {6, 8, 10, 12},
    -- special behavior
    sustain_mode = true,                    -- holds notes longer
    vibrato = true,                         -- subtle pitch movement
  },
  PULSE = {
    intervals = {
      drift  = {0, 0, 0, 12, 7, 0, 0, -12},
      morph  = {0, 0, 12, 7, -5, 0, 5, 0},
      chaos  = {0, 12, -12, 7, -7, 5, -5, 0, 0, 0},
      resolve = {0, 0, 0, 0, 7, 0, 12, 0},
    },
    density = {0.55, 0.70, 0.90, 0.45},
    gate_range = {0.1, 0.35},               -- short, percussive
    vel_base = 0.5,
    vel_range = 0.4,
    ghost_prob = 0.2,
    rest_love = 0.1,
    phrase_lengths = {8, 8, 16, 8},
    -- special behavior
    sync_to_beat = true,                    -- quantized to clock divisions
    accent_pattern = {1, 0, 0, 1, 0, 1, 0, 0},  -- rhythmic accent mask
  },
  BELLS = {
    intervals = {
      drift  = {0, 7, 14, -7, 12, 0, 19},
      morph  = {7, -5, 14, 0, -7, 12, 19, -12},
      chaos  = {6, -6, 11, -11, 14, -14, 1, -1, 7},
      resolve = {0, 7, 12, 0, -12, 0},
    },
    density = {0.20, 0.35, 0.60, 0.15},
    gate_range = {0.05, 0.2},              -- quick attacks, fast decay
    vel_base = 0.6,
    vel_range = 0.35,
    ghost_prob = 0.25,
    rest_love = 0.45,
    phrase_lengths = {5, 7, 4, 6},
    -- special behavior
    cluster_prob = 0.15,                    -- probability of multi-note cluster
    cluster_size = {2, 3},
  },
  VOICE = {
    intervals = {
      drift  = {0, 2, -2, 0, 3, -1, 0, 5},
      morph  = {2, -2, 3, -3, 5, -1, 1, 0},
      chaos  = {1, -1, 2, -2, 3, -3, 5, -5, 7, -7},
      resolve = {0, 0, 2, -2, 0, -1, 0},
    },
    density = {0.45, 0.60, 0.75, 0.35},
    gate_range = {0.4, 0.9},              -- legato
    vel_base = 0.3,
    vel_range = 0.3,
    ghost_prob = 0.1,
    rest_love = 0.25,
    phrase_lengths = {8, 10, 12, 8},
    -- special behavior
    chromatic_approach = 0.2,              -- semitone leading tones
    portamento = true,                     -- slides between notes
  },
  SWARM = {
    intervals = {
      drift  = {0, 0, 0, 1, -1, 0, 0, 2},
      morph  = {0, 1, -1, 2, -2, 0, 3, -3},
      chaos  = {0, 1, -1, 2, -2, 3, -3, 0, 0, 1, -1},
      resolve = {0, 0, 0, 0, 1, 0, -1, 0},
    },
    density = {0.15, 0.45, 0.90, 0.10},   -- sparse→insect cloud
    gate_range = {0.02, 0.12},             -- micro-events
    vel_base = 0.25,
    vel_range = 0.5,
    ghost_prob = 0.35,
    rest_love = 0.05,                      -- barely rests in chaos
    phrase_lengths = {4, 6, 3, 5},
    -- special behavior
    burst_prob = 0.2,                       -- probability of rapid burst
    burst_size = {3, 6},
  },
}

-- song form templates
local FORM_TEMPLATES = {
  {"home", "depart", "home", "grow", "home", "silence"},
  {"home", "home", "depart", "grow", "silence", "home"},
  {"home", "depart", "grow", "grow", "silence", "home"},
  {"silence", "home", "depart", "home"},
  {"home", "depart", "depart", "grow", "silence", "home", "home"},
  {"home", "grow", "silence", "depart", "grow", "home"},
  {"silence", "silence", "home", "grow", "depart", "home"},
}

-- --------------------------------------------------------------------------
-- lifecycle
-- --------------------------------------------------------------------------

function bandmate.start(root_note, voice_name)
  bandmate.active = true
  bandmate.root = root_note or 48
  bandmate.last_note = bandmate.root
  bandmate.voice = voice_name or "DRIFT"
  bandmate.energy = 0.0
  bandmate.breath_phase = "build"
  bandmate.breath_timer = 0
  bandmate.breath_target = 0.8
  bandmate.phrase_count = 0
  bandmate.pattern_pos = 0
  bandmate.memory = {}
  bandmate.register = 0

  bandmate.form_template = FORM_TEMPLATES[math.random(#FORM_TEMPLATES)]
  bandmate.form_idx = 1
  bandmate.form_bar = 0
  bandmate.form_phase = bandmate.form_template[1]
  bandmate.form_length = math.random(6, 12)

  bandmate.save_home()
  bandmate.generate_phrase()
end

function bandmate.stop()
  bandmate.active = false
  bandmate.energy = 0
end

function bandmate.save_home()
  bandmate.home_state = {
    root = bandmate.root,
    voice = bandmate.voice,
    register = bandmate.register,
  }
end

-- --------------------------------------------------------------------------
-- explorer awareness: called from main script to sync state
-- --------------------------------------------------------------------------

function bandmate.sync_explorer(phase, intensity, tension)
  bandmate.explorer_phase = phase or 1
  bandmate.explorer_intensity = intensity or 0
  bandmate.explorer_tension = tension or 0

  -- adjust breath target based on explorer phase
  if phase == 1 then      -- DRIFT
    bandmate.breath_target = 0.4
  elseif phase == 2 then  -- MORPH
    bandmate.breath_target = 0.7
  elseif phase == 3 then  -- CHAOS
    bandmate.breath_target = 1.0
  elseif phase == 4 then  -- RESOLVE
    bandmate.breath_target = 0.3
  end
end

-- --------------------------------------------------------------------------
-- breathing
-- --------------------------------------------------------------------------

function bandmate.breathe()
  bandmate.breath_timer = bandmate.breath_timer + 1

  -- breath responds to explorer tension
  local tension_boost = bandmate.explorer_tension * 0.3

  if bandmate.breath_phase == "play" then
    local target = bandmate.breath_target + tension_boost
    bandmate.energy = bandmate.energy + (target - bandmate.energy) * 0.05
    -- transition to fade based on tension (low tension = fade sooner)
    local fade_prob = 0.04 * (1 - bandmate.explorer_tension * 0.5)
    if bandmate.breath_timer > 6 and math.random() < fade_prob then
      bandmate.breath_phase = "fade"
      bandmate.breath_timer = 0
    end

  elseif bandmate.breath_phase == "fade" then
    bandmate.energy = math.max(0.0, bandmate.energy - 0.06)
    if bandmate.energy <= 0.05 then
      bandmate.breath_phase = "silence"
      bandmate.breath_timer = 0
    end

  elseif bandmate.breath_phase == "silence" then
    bandmate.energy = 0
    -- shorter silence during high tension
    local silence_dur = math.random(3, 10) - math.floor(bandmate.explorer_tension * 4)
    silence_dur = math.max(2, silence_dur)
    if bandmate.breath_timer > silence_dur then
      bandmate.breath_phase = "build"
      bandmate.breath_timer = 0
    end

  elseif bandmate.breath_phase == "build" then
    bandmate.energy = math.min(bandmate.breath_target,
      bandmate.energy + 0.04 + tension_boost * 0.02)
    if bandmate.energy >= bandmate.breath_target * 0.6 then
      bandmate.breath_phase = "play"
      bandmate.breath_timer = 0
    end
  end

  -- form phase modulation
  if bandmate.form_phase == "silence" then
    bandmate.energy = bandmate.energy * 0.2
  elseif bandmate.form_phase == "grow" then
    bandmate.energy = math.min(1.0, bandmate.energy * 1.08)
  end
end

-- --------------------------------------------------------------------------
-- phrase generation
-- --------------------------------------------------------------------------

function bandmate.generate_phrase()
  local v = VOICES[bandmate.voice]
  if not v then v = VOICES.DRIFT end

  -- get intervals for current explorer phase
  local phase_name = ({"drift", "morph", "chaos", "resolve"})[bandmate.explorer_phase] or "drift"
  local intervals = v.intervals[phase_name]

  -- density varies by explorer phase
  local density = v.density[bandmate.explorer_phase] or 0.5

  local lengths = v.phrase_lengths
  bandmate.pattern_len = lengths[math.random(#lengths)]
  bandmate.pattern = {}

  local note = bandmate.last_note

  for i = 1, bandmate.pattern_len do
    local step = {}
    local play_prob = density * (0.3 + bandmate.energy * 0.7)

    -- rest love
    if math.random() < v.rest_love then
      play_prob = play_prob * 0.25
    end

    step.play = math.random() < play_prob

    if step.play then
      -- pick interval
      local interval = intervals[math.random(#intervals)]

      -- motivic development: sometimes re-use a remembered interval
      if #bandmate.memory > 2 and math.random() < 0.25 then
        local mem_idx = math.random(#bandmate.memory)
        local mem_note = bandmate.memory[mem_idx]
        interval = mem_note - note
        -- clamp to reasonable range
        while interval > 12 do interval = interval - 12 end
        while interval < -12 do interval = interval + 12 end
      end

      -- chromatic approach (voice-specific)
      if v.chromatic_approach and math.random() < v.chromatic_approach then
        interval = interval + (math.random() < 0.5 and 1 or -1)
      end

      note = note + interval
      while note > bandmate.root + 24 do note = note - 12 end
      while note < bandmate.root - 12 do note = note + 12 end

      step.note = note
      step.vel = v.vel_base + math.random() * v.vel_range
      step.gate = v.gate_range[1] + math.random() * (v.gate_range[2] - v.gate_range[1])

      -- ghost
      step.ghost = math.random() < v.ghost_prob
      if step.ghost then
        step.vel = step.vel * 0.3
        step.gate = step.gate * 0.4
      end

      -- remember note for motivic development
      table.insert(bandmate.memory, note)
      if #bandmate.memory > bandmate.memory_size then
        table.remove(bandmate.memory, 1)
      end

      -- burst (SWARM special)
      step.burst = 1
      if v.burst_prob and math.random() < v.burst_prob * bandmate.explorer_intensity then
        step.burst = math.random(v.burst_size[1], v.burst_size[2])
        step.gate = 0.03  -- micro gates for bursts
      end

      -- cluster (BELLS special)
      step.cluster = {}
      if v.cluster_prob and math.random() < v.cluster_prob * bandmate.explorer_intensity then
        local num = math.random(v.cluster_size[1], v.cluster_size[2])
        for _ = 1, num do
          table.insert(step.cluster, note + intervals[math.random(#intervals)])
        end
      end

    else
      step.play = false
      step.note = note
      step.vel = 0
      step.gate = 0
      step.ghost = false
      step.burst = 1
      step.cluster = {}
    end

    bandmate.pattern[i] = step
  end

  bandmate.pattern_pos = 0
  bandmate.last_note = note
end

-- --------------------------------------------------------------------------
-- advance
-- --------------------------------------------------------------------------

function bandmate.advance()
  if not bandmate.active then return end

  bandmate.breathe()

  bandmate.pattern_pos = bandmate.pattern_pos + 1

  if bandmate.pattern_pos > bandmate.pattern_len then
    bandmate.phrase_count = bandmate.phrase_count + 1
    bandmate.generate_phrase()
    bandmate.pattern_pos = 1

    bandmate.form_bar = bandmate.form_bar + 1
    if bandmate.form_bar >= bandmate.form_length then
      bandmate.advance_form()
    end
  end

  local step = bandmate.pattern[bandmate.pattern_pos]
  if not step then return end

  if bandmate.energy < 0.08 then return end
  if not step.play then return end

  -- ghost notes flicker with energy
  if step.ghost and math.random() > bandmate.energy then return end

  local vel = step.vel

  -- accent: PULSE voice uses pattern mask
  local v = VOICES[bandmate.voice]
  if v and v.accent_pattern then
    local mask_pos = ((bandmate.pattern_pos - 1) % #v.accent_pattern) + 1
    if v.accent_pattern[mask_pos] == 1 then
      vel = math.min(1.0, vel * 1.3)
    end
  end

  -- spontaneous accent
  if vel > 0.35 and vel < 0.65 and math.random() < 0.08 then
    vel = math.min(1.0, vel * 1.4)
  end

  -- play main note
  if bandmate.note_on_fn then
    bandmate.note_on_fn(step.note, vel, step.gate)
  end

  -- cluster notes (BELLS)
  if step.cluster and #step.cluster > 0 then
    for _, cn in ipairs(step.cluster) do
      if bandmate.note_on_fn then
        -- slight timing spread via clock
        clock.run(function()
          clock.sleep(math.random() * 0.05)
          bandmate.note_on_fn(cn, vel * 0.6, step.gate * 0.7)
        end)
      end
    end
  end

  -- burst (SWARM)
  if step.burst and step.burst > 1 then
    for b = 2, step.burst do
      clock.run(function()
        clock.sleep((b - 1) * 0.04)
        if bandmate.note_on_fn then
          bandmate.note_on_fn(step.note, vel * (0.8 / b), 0.03)
        end
      end)
    end
  end
end

-- --------------------------------------------------------------------------
-- song form
-- --------------------------------------------------------------------------

function bandmate.advance_form()
  bandmate.form_bar = 0
  bandmate.form_idx = bandmate.form_idx + 1

  if bandmate.form_idx > #bandmate.form_template then
    bandmate.form_template = FORM_TEMPLATES[math.random(#FORM_TEMPLATES)]
    bandmate.form_idx = 1
  end

  bandmate.form_phase = bandmate.form_template[bandmate.form_idx]
  bandmate.form_length = math.random(6, 14)

  if bandmate.form_phase == "home" then
    if bandmate.home_state then
      bandmate.register = bandmate.home_state.register
      bandmate.last_note = bandmate.last_note +
        math.floor((bandmate.root - bandmate.last_note) * 0.5 + 0.5)
    end
  elseif bandmate.form_phase == "depart" then
    if math.random() < 0.4 then
      bandmate.register = math.random(-1, 1)
      bandmate.root = (bandmate.home_state and bandmate.home_state.root or 48) +
        bandmate.register * 12
    end
  elseif bandmate.form_phase == "grow" then
    bandmate.energy = math.min(1.0, bandmate.energy + 0.25)
  elseif bandmate.form_phase == "silence" then
    bandmate.breath_phase = "fade"
    bandmate.breath_timer = 0
  end
end

-- --------------------------------------------------------------------------
-- style
-- --------------------------------------------------------------------------

function bandmate.set_voice(name)
  if VOICES[name] then bandmate.voice = name end
end

function bandmate.get_voice_names()
  return {"DRIFT", "PULSE", "BELLS", "VOICE", "SWARM"}
end

function bandmate.get_info()
  return {
    voice = bandmate.voice,
    energy = bandmate.energy,
    breath = bandmate.breath_phase,
    form = bandmate.form_phase,
    phrase = bandmate.phrase_count,
    pos = bandmate.pattern_pos .. "/" .. bandmate.pattern_len,
    memory = #bandmate.memory,
  }
end

return bandmate
