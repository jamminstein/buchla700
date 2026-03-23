-- buchla700 bandmate
--
-- an autonomous FM synthesist who thinks in timbral topology.
-- generates melodic material through intervallic movement,
-- breathes naturally (play/fade/silence/build),
-- and structures long-form music with song form arcs.
--
-- the bandmate is a buchla operator: it thinks in ratios,
-- harmonic series, and spectral evolution. notes are chosen
-- not from scales but from harmonic relationships to a fundamental.

local bandmate = {}

-- --------------------------------------------------------------------------
-- state
-- --------------------------------------------------------------------------

bandmate.active = false
bandmate.energy = 0.0           -- 0=silent, 1=full presence
bandmate.breath_phase = "build" -- play, fade, silence, build
bandmate.breath_timer = 0

-- song form
bandmate.form_phase = "home"    -- home, depart, grow, silence, return
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
bandmate.root = 48              -- base note (C3)
bandmate.last_note = 48
bandmate.register = 0           -- octave offset: -1, 0, +1

-- style
bandmate.style = "DRIFT"        -- DRIFT, PULSE, BELLS, VOICE, CHAOS

-- note callback (set by main script)
bandmate.note_on_fn = nil
bandmate.note_off_fn = nil

-- --------------------------------------------------------------------------
-- styles: how the bandmate thinks about melody
-- --------------------------------------------------------------------------

local STYLES = {
  DRIFT = {
    -- slow, evolving tones. long gates. harmonic series intervals.
    -- think: buchla easel through spring reverb
    intervals = {0, 0, 7, 12, -5, 5, -12, 7, 0, 3},
    density = 0.5,          -- probability of playing on a step
    gate_range = {0.4, 0.9},
    vel_range = {0.4, 0.7},
    ghost_prob = 0.15,
    chromatic_approach = 0.05,
    rest_affinity = 0.3,    -- loves silence
    phrase_lengths = {6, 8, 8, 10},
  },
  PULSE = {
    -- rhythmic, driving. shorter gates. octave + fifth relationships.
    -- think: buchla music easel sequencer
    intervals = {0, 0, 0, 12, 7, -5, 0, 12, -12, 5, 0, 7},
    density = 0.75,
    gate_range = {0.15, 0.4},
    vel_range = {0.5, 0.9},
    ghost_prob = 0.2,
    chromatic_approach = 0.1,
    rest_affinity = 0.1,
    phrase_lengths = {8, 8, 16, 8},
  },
  BELLS = {
    -- bright, metallic. wide intervals. inharmonic ratios.
    -- think: buchla 259 complex oscillator, FM bell tones
    intervals = {0, 7, 14, -5, 12, 19, -7, 0, 17, 5},
    density = 0.4,
    gate_range = {0.1, 0.3},
    vel_range = {0.6, 1.0},
    ghost_prob = 0.25,
    chromatic_approach = 0.15,
    rest_affinity = 0.35,
    phrase_lengths = {5, 7, 6, 8},
  },
  VOICE = {
    -- singing, legato. small intervals. stepwise motion.
    -- think: 700 as a voice synthesizer
    intervals = {0, 2, -2, 3, -1, 5, -3, 0, 2, 7, -5},
    density = 0.65,
    gate_range = {0.5, 0.95},
    vel_range = {0.3, 0.65},
    ghost_prob = 0.1,
    chromatic_approach = 0.2,
    rest_affinity = 0.2,
    phrase_lengths = {8, 8, 12, 8},
  },
  CHAOS = {
    -- wild, unpredictable. wide leaps. high density.
    -- think: morton subotnick, silver apples of the moon
    intervals = {0, -12, 12, -7, 14, -5, 17, 0, -14, 7, 19, -19},
    density = 0.85,
    gate_range = {0.05, 0.5},
    vel_range = {0.3, 1.0},
    ghost_prob = 0.3,
    chromatic_approach = 0.25,
    rest_affinity = 0.05,
    phrase_lengths = {4, 6, 5, 7},
  },
}

-- song form templates
local FORM_TEMPLATES = {
  {"home", "depart", "home", "grow", "home", "silence"},
  {"home", "home", "depart", "grow", "silence", "home"},
  {"home", "depart", "grow", "grow", "silence", "home"},
  {"silence", "build", "home", "depart", "home"},
  {"home", "depart", "depart", "grow", "silence", "home", "home"},
}

-- --------------------------------------------------------------------------
-- lifecycle
-- --------------------------------------------------------------------------

function bandmate.start(root_note, style_name)
  bandmate.active = true
  bandmate.root = root_note or 48
  bandmate.last_note = bandmate.root
  bandmate.style = style_name or "DRIFT"
  bandmate.energy = 0.0
  bandmate.breath_phase = "build"
  bandmate.breath_timer = 0
  bandmate.phrase_count = 0
  bandmate.pattern_pos = 0

  -- pick a song form
  bandmate.form_template = FORM_TEMPLATES[math.random(#FORM_TEMPLATES)]
  bandmate.form_idx = 1
  bandmate.form_bar = 0
  bandmate.form_phase = bandmate.form_template[1]
  bandmate.form_length = math.random(6, 12)

  -- save home state
  bandmate.save_home()

  -- generate first phrase
  bandmate.generate_phrase()
end

function bandmate.stop()
  bandmate.active = false
  bandmate.energy = 0
end

function bandmate.save_home()
  bandmate.home_state = {
    root = bandmate.root,
    style = bandmate.style,
    register = bandmate.register,
  }
end

-- --------------------------------------------------------------------------
-- breathing: natural energy arcs
-- --------------------------------------------------------------------------

function bandmate.breathe()
  bandmate.breath_timer = bandmate.breath_timer + 1

  if bandmate.breath_phase == "play" then
    -- gradually build to peak, then chance of fading
    bandmate.energy = math.min(1.0, bandmate.energy + 0.02)
    if bandmate.breath_timer > 8 and math.random() < 0.06 then
      bandmate.breath_phase = "fade"
      bandmate.breath_timer = 0
    end

  elseif bandmate.breath_phase == "fade" then
    bandmate.energy = math.max(0.0, bandmate.energy - 0.08)
    if bandmate.energy <= 0.05 then
      bandmate.breath_phase = "silence"
      bandmate.breath_timer = 0
    end

  elseif bandmate.breath_phase == "silence" then
    bandmate.energy = 0
    -- rest for a while, then rebuild
    if bandmate.breath_timer > math.random(4, 12) then
      bandmate.breath_phase = "build"
      bandmate.breath_timer = 0
    end

  elseif bandmate.breath_phase == "build" then
    bandmate.energy = math.min(0.8, bandmate.energy + 0.05)
    if bandmate.energy >= 0.5 then
      bandmate.breath_phase = "play"
      bandmate.breath_timer = 0
    end
  end

  -- form phase modulates energy
  if bandmate.form_phase == "silence" then
    bandmate.energy = bandmate.energy * 0.3
  elseif bandmate.form_phase == "grow" then
    bandmate.energy = math.min(1.0, bandmate.energy * 1.1)
  end
end

-- --------------------------------------------------------------------------
-- phrase generation: the compositional brain
-- --------------------------------------------------------------------------

function bandmate.generate_phrase()
  local s = STYLES[bandmate.style]
  if not s then s = STYLES["DRIFT"] end

  -- pick phrase length
  local lengths = s.phrase_lengths
  bandmate.pattern_len = lengths[math.random(#lengths)]
  bandmate.pattern = {}

  local note = bandmate.last_note

  for i = 1, bandmate.pattern_len do
    local step = {}

    -- decide if this step plays
    local play_prob = s.density
    -- adjust for breathing
    play_prob = play_prob * (0.3 + bandmate.energy * 0.7)
    -- rest affinity
    if math.random() < s.rest_affinity then
      play_prob = play_prob * 0.3
    end

    step.play = math.random() < play_prob

    if step.play then
      -- pick interval
      local interval = s.intervals[math.random(#s.intervals)]

      -- chromatic approach: semitone leading tone
      if math.random() < s.chromatic_approach then
        local approach_dir = math.random() < 0.5 and 1 or -1
        interval = interval + approach_dir
      end

      -- apply register offset
      note = note + interval
      -- keep in range (roughly 2 octaves around root)
      while note > bandmate.root + 24 do note = note - 12 end
      while note < bandmate.root - 12 do note = note + 12 end

      step.note = note
      step.vel = s.vel_range[1] + math.random() * (s.vel_range[2] - s.vel_range[1])
      step.gate = s.gate_range[1] + math.random() * (s.gate_range[2] - s.gate_range[1])

      -- ghost notes: quiet, short
      step.ghost = math.random() < s.ghost_prob
      if step.ghost then
        step.vel = step.vel * 0.35
        step.gate = step.gate * 0.5
      end
    else
      step.play = false
      step.note = note
      step.vel = 0
      step.gate = 0
      step.ghost = false
    end

    bandmate.pattern[i] = step
  end

  bandmate.pattern_pos = 0
  bandmate.last_note = note
end

-- --------------------------------------------------------------------------
-- advance: called each beat
-- --------------------------------------------------------------------------

function bandmate.advance()
  if not bandmate.active then return end

  -- breathe
  bandmate.breathe()

  -- advance pattern position
  bandmate.pattern_pos = bandmate.pattern_pos + 1

  -- end of phrase: generate new one
  if bandmate.pattern_pos > bandmate.pattern_len then
    bandmate.phrase_count = bandmate.phrase_count + 1
    bandmate.generate_phrase()
    bandmate.pattern_pos = 1

    -- advance song form
    bandmate.form_bar = bandmate.form_bar + 1
    if bandmate.form_bar >= bandmate.form_length then
      bandmate.advance_form()
    end
  end

  -- get current step
  local step = bandmate.pattern[bandmate.pattern_pos]
  if not step then return end

  -- breathing gate: low energy = skip notes
  if bandmate.energy < 0.1 then return end
  if not step.play then return end

  -- ghost notes flicker
  if step.ghost and math.random() > bandmate.energy then return end

  -- spontaneous accent on medium-velocity notes
  local vel = step.vel
  if vel > 0.4 and vel < 0.7 and math.random() < 0.1 then
    vel = vel * 1.4
  end

  -- play the note
  if bandmate.note_on_fn then
    bandmate.note_on_fn(step.note, vel, step.gate)
  end
end

-- --------------------------------------------------------------------------
-- song form: long-arc structure
-- --------------------------------------------------------------------------

function bandmate.advance_form()
  bandmate.form_bar = 0
  bandmate.form_idx = bandmate.form_idx + 1

  if bandmate.form_idx > #bandmate.form_template then
    -- pick new form template
    bandmate.form_template = FORM_TEMPLATES[math.random(#FORM_TEMPLATES)]
    bandmate.form_idx = 1
  end

  bandmate.form_phase = bandmate.form_template[bandmate.form_idx]
  bandmate.form_length = math.random(6, 12)

  -- form-driven actions
  if bandmate.form_phase == "home" then
    -- pull toward home state
    if bandmate.home_state then
      bandmate.register = bandmate.home_state.register
      -- gently pull last_note toward root
      bandmate.last_note = bandmate.last_note +
        math.floor((bandmate.root - bandmate.last_note) * 0.5 + 0.5)
    end
  elseif bandmate.form_phase == "depart" then
    -- shift register or root
    if math.random() < 0.4 then
      bandmate.register = math.random(-1, 1)
      bandmate.root = bandmate.home_state.root + bandmate.register * 12
    end
  elseif bandmate.form_phase == "grow" then
    -- intensify
    bandmate.energy = math.min(1.0, bandmate.energy + 0.2)
  elseif bandmate.form_phase == "silence" then
    -- force breathing into fade
    bandmate.breath_phase = "fade"
    bandmate.breath_timer = 0
  end
end

-- --------------------------------------------------------------------------
-- style switching
-- --------------------------------------------------------------------------

function bandmate.set_style(name)
  if STYLES[name] then
    bandmate.style = name
  end
end

function bandmate.get_style_names()
  return {"DRIFT", "PULSE", "BELLS", "VOICE", "CHAOS"}
end

function bandmate.get_info()
  return {
    style = bandmate.style,
    energy = bandmate.energy,
    breath = bandmate.breath_phase,
    form = bandmate.form_phase,
    phrase = bandmate.phrase_count,
    pos = bandmate.pattern_pos .. "/" .. bandmate.pattern_len,
  }
end

return bandmate
