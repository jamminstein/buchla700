-- buchla700 sequencer
--
-- a sequencer worthy of the buchla 700:
-- polymetric tracks, per-step parameter locks,
-- conditional triggers, generative evolution.
--
-- 3 independent tracks at different lengths:
--   MELODY: notes + velocity + gate
--   TIMBRE: topology + indices + waveshape + cutoff (p-locks)
--   RHYTHM: trigger probability + conditional logic
--
-- the original 700 had 16 sequencers with 1000 lines each.
-- this distills that into something playable on norns.

local seq = {}

-- --------------------------------------------------------------------------
-- constants
-- --------------------------------------------------------------------------

local MAX_STEPS = 16
local NUM_TRACKS = 3
local TRACK_MELODY = 1
local TRACK_TIMBRE = 2
local TRACK_RHYTHM = 3

-- conditional trigger types
local COND_ALWAYS    = 1  -- always fire
local COND_PROB_75   = 2  -- 75% chance
local COND_PROB_50   = 3  -- 50% chance
local COND_PROB_25   = 4  -- 25% chance
local COND_EVERY_2   = 5  -- every 2nd pass
local COND_EVERY_3   = 6  -- every 3rd pass
local COND_EVERY_4   = 7  -- every 4th pass
local COND_NOT_FIRST = 8  -- skip first pass
local COND_FILL      = 9  -- only during fill mode
local COND_RANDOM    = 10 -- random each pass (coin flip)

local COND_NAMES = {
  "ALWAYS", "75%", "50%", "25%",
  "EVERY2", "EVERY3", "EVERY4",
  "!FIRST", "FILL", "RANDOM"
}

-- markov transition weights for generative mode
-- each entry: {interval, weight}
local MARKOV_INTERVALS = {
  melodic = {
    {0, 3},    -- repeat
    {2, 2},    -- step up
    {-2, 2},   -- step down
    {5, 1.5},  -- fourth up
    {-5, 1.5}, -- fourth down
    {7, 1.5},  -- fifth up
    {-7, 1.5}, -- fifth down
    {12, 0.5}, -- octave up
    {-12, 0.5},-- octave down
    {3, 1},    -- minor third
    {-3, 1},   -- minor third down
  },
  angular = {
    {0, 1},
    {6, 2},    -- tritone
    {-6, 2},
    {11, 1.5}, -- major 7th
    {-11, 1.5},
    {14, 1},   -- 9th
    {-14, 1},
    {1, 1.5},  -- semitone
    {-1, 1.5},
    {7, 1},
  },
  clustered = {
    {0, 4},    -- heavy repeat
    {1, 3},    -- semitone up
    {-1, 3},   -- semitone down
    {2, 2},    -- whole tone
    {-2, 2},
    {3, 1},
    {-3, 1},
  },
  wide = {
    {12, 2},   -- octave
    {-12, 2},
    {7, 2},    -- fifth
    {-7, 2},
    {19, 1},   -- octave + fifth
    {-19, 1},
    {0, 1},
    {5, 1},
    {-5, 1},
  },
}

-- --------------------------------------------------------------------------
-- state
-- --------------------------------------------------------------------------

seq.playing = false
seq.fill_mode = false
seq.pass_count = 0           -- number of complete passes through pattern
seq.generative = false       -- generative mode
seq.markov_style = "melodic" -- markov transition style

-- track lengths (polymetric!)
seq.track_len = {8, 8, 8}
seq.track_pos = {0, 0, 0}

-- melody track: note + velocity + gate length
seq.melody = {}

-- timbre track: per-step parameter locks
seq.timbre = {}

-- rhythm track: trigger conditions
seq.rhythm = {}

-- global
seq.swing = 50
seq.gate_length = 0.5
seq.root = 60
seq.last_note = 60

-- l-system state for pattern evolution
seq.lsystem_gen = 0
seq.lsystem_axiom = ""

-- --------------------------------------------------------------------------
-- init
-- --------------------------------------------------------------------------

function seq.init()
  -- melody: default ascending pattern
  for i = 1, MAX_STEPS do
    seq.melody[i] = {
      note = 60 + ((i - 1) * 2) % 12,
      vel = 0.7 + math.random() * 0.2,
      gate = -1,  -- -1 = use global
      on = (i <= 8),
    }
  end

  -- timbre: all defaults (-1 = use global)
  for i = 1, MAX_STEPS do
    seq.timbre[i] = {
      config = -1,        -- FM topology override
      master_index = -1,  -- master FM index
      cutoff = -1,        -- filter cutoff
      resonance = -1,     -- filter Q
      drive = -1,         -- saturation
      wsa = -1,           -- waveshape A
      wsb = -1,           -- waveshape B
      ratio2 = -1,        -- osc ratios
      ratio3 = -1,
      ratio4 = -1,
    }
  end

  -- rhythm: default all-fire
  for i = 1, MAX_STEPS do
    seq.rhythm[i] = {
      condition = COND_ALWAYS,
      ratchet = 1,        -- 1 = normal, 2-4 = subdivisions
      accent = false,
    }
  end

  seq.pass_count = 0
end

-- --------------------------------------------------------------------------
-- track advancement (independent positions for polymetric)
-- --------------------------------------------------------------------------

function seq.advance_track(track)
  seq.track_pos[track] = seq.track_pos[track] + 1
  if seq.track_pos[track] > seq.track_len[track] then
    seq.track_pos[track] = 1
    if track == TRACK_MELODY then
      seq.pass_count = seq.pass_count + 1
      -- generative: evolve pattern on each pass
      if seq.generative then
        seq.evolve()
      end
    end
  end
end

function seq.advance()
  seq.advance_track(TRACK_MELODY)
  seq.advance_track(TRACK_TIMBRE)
  seq.advance_track(TRACK_RHYTHM)
end

function seq.reset()
  seq.track_pos = {0, 0, 0}
  seq.pass_count = 0
end

-- --------------------------------------------------------------------------
-- step queries
-- --------------------------------------------------------------------------

function seq.get_melody_step()
  local pos = seq.track_pos[TRACK_MELODY]
  if pos < 1 or pos > MAX_STEPS then return nil end
  return seq.melody[pos]
end

function seq.get_timbre_step()
  local pos = seq.track_pos[TRACK_TIMBRE]
  if pos < 1 or pos > MAX_STEPS then return nil end
  return seq.timbre[pos]
end

function seq.get_rhythm_step()
  local pos = seq.track_pos[TRACK_RHYTHM]
  if pos < 1 or pos > MAX_STEPS then return nil end
  return seq.rhythm[pos]
end

-- --------------------------------------------------------------------------
-- conditional trigger evaluation
-- --------------------------------------------------------------------------

function seq.should_fire()
  local step = seq.get_rhythm_step()
  if not step then return true end

  local melody = seq.get_melody_step()
  if melody and not melody.on then return false end

  local cond = step.condition

  if cond == COND_ALWAYS then return true
  elseif cond == COND_PROB_75 then return math.random() < 0.75
  elseif cond == COND_PROB_50 then return math.random() < 0.50
  elseif cond == COND_PROB_25 then return math.random() < 0.25
  elseif cond == COND_EVERY_2 then return seq.pass_count % 2 == 0
  elseif cond == COND_EVERY_3 then return seq.pass_count % 3 == 0
  elseif cond == COND_EVERY_4 then return seq.pass_count % 4 == 0
  elseif cond == COND_NOT_FIRST then return seq.pass_count > 0
  elseif cond == COND_FILL then return seq.fill_mode
  elseif cond == COND_RANDOM then return math.random() < 0.5
  end
  return true
end

function seq.get_ratchet()
  local step = seq.get_rhythm_step()
  if step then return step.ratchet end
  return 1
end

function seq.is_accent()
  local step = seq.get_rhythm_step()
  if step then return step.accent end
  return false
end

function seq.get_gate_length()
  local step = seq.get_melody_step()
  if step and step.gate >= 0 then return step.gate end
  return seq.gate_length
end

function seq.get_swing_delay()
  local pos = seq.track_pos[TRACK_MELODY]
  if pos % 2 == 0 then
    return (seq.swing - 50) / 100 * 0.5
  end
  return 0
end

-- --------------------------------------------------------------------------
-- p-lock application: returns table of overrides (only set values)
-- --------------------------------------------------------------------------

function seq.get_plocks()
  local step = seq.get_timbre_step()
  if not step then return {} end

  local locks = {}
  if step.config >= 0 then locks.config = step.config end
  if step.master_index >= 0 then locks.master_index = step.master_index end
  if step.cutoff >= 0 then locks.cutoff = step.cutoff end
  if step.resonance >= 0 then locks.resonance = step.resonance end
  if step.drive >= 0 then locks.drive = step.drive end
  if step.wsa >= 0 then locks.wsa = step.wsa end
  if step.wsb >= 0 then locks.wsb = step.wsb end
  if step.ratio2 >= 0 then locks.ratio2 = step.ratio2 end
  if step.ratio3 >= 0 then locks.ratio3 = step.ratio3 end
  if step.ratio4 >= 0 then locks.ratio4 = step.ratio4 end
  return locks
end

-- --------------------------------------------------------------------------
-- generative: markov chain note selection
-- --------------------------------------------------------------------------

function seq.markov_next(current_note)
  local transitions = MARKOV_INTERVALS[seq.markov_style] or MARKOV_INTERVALS.melodic
  local total_weight = 0
  for _, t in ipairs(transitions) do
    total_weight = total_weight + t[2]
  end

  local roll = math.random() * total_weight
  local sum = 0
  for _, t in ipairs(transitions) do
    sum = sum + t[2]
    if roll <= sum then
      local new_note = current_note + t[1]
      -- keep in range
      while new_note > seq.root + 24 do new_note = new_note - 12 end
      while new_note < seq.root - 12 do new_note = new_note + 12 end
      return new_note
    end
  end
  return current_note
end

-- --------------------------------------------------------------------------
-- generative: evolve pattern each pass (l-system inspired)
-- --------------------------------------------------------------------------

function seq.evolve()
  seq.lsystem_gen = seq.lsystem_gen + 1

  -- mutation probability increases with generation
  local mut_prob = math.min(0.4, 0.05 + seq.lsystem_gen * 0.02)

  for i = 1, seq.track_len[TRACK_MELODY] do
    local step = seq.melody[i]
    if not step then goto continue end

    -- markov: occasionally replace note with markov-generated one
    if math.random() < mut_prob then
      step.note = seq.markov_next(step.note)
      seq.last_note = step.note
    end

    -- velocity drift
    if math.random() < mut_prob * 0.5 then
      step.vel = math.max(0.2, math.min(1.0,
        step.vel + (math.random() * 0.2 - 0.1)))
    end

    -- occasionally toggle steps on/off
    if math.random() < mut_prob * 0.2 then
      step.on = not step.on
    end

    ::continue::
  end

  -- timbre evolution: occasionally add/remove p-locks
  for i = 1, seq.track_len[TRACK_TIMBRE] do
    local step = seq.timbre[i]
    if not step then goto continue_t end

    if math.random() < mut_prob * 0.3 then
      -- add a random p-lock
      local roll = math.random()
      if roll < 0.3 then
        step.config = math.random(0, 11)
      elseif roll < 0.5 then
        step.cutoff = math.random(200, 8000)
      elseif roll < 0.7 then
        step.master_index = math.random() * 1.5
      else
        step.wsa = math.random(0, 7)
      end
    end

    -- occasionally clear a p-lock (return to global)
    if math.random() < mut_prob * 0.15 then
      local params_list = {"config", "master_index", "cutoff", "resonance",
        "drive", "wsa", "wsb", "ratio2", "ratio3", "ratio4"}
      local key = params_list[math.random(#params_list)]
      step[key] = -1
    end

    ::continue_t::
  end

  -- rhythm evolution: occasionally change conditions
  for i = 1, seq.track_len[TRACK_RHYTHM] do
    local step = seq.rhythm[i]
    if not step then goto continue_r end

    if math.random() < mut_prob * 0.2 then
      step.condition = math.random(1, 10)
    end

    if math.random() < mut_prob * 0.1 then
      step.ratchet = math.random(1, 3)
    end

    ::continue_r::
  end
end

-- --------------------------------------------------------------------------
-- pattern operations
-- --------------------------------------------------------------------------

function seq.randomize_melody(root, scale_notes)
  root = root or 60
  for i = 1, seq.track_len[TRACK_MELODY] do
    if scale_notes and #scale_notes > 0 then
      seq.melody[i].note = scale_notes[math.random(#scale_notes)]
    else
      seq.melody[i].note = root + ({0,2,3,5,7,8,10,12})[math.random(8)]
    end
    seq.melody[i].vel = 0.4 + math.random() * 0.5
    seq.melody[i].on = math.random() > 0.2
  end
end

function seq.randomize_timbre()
  for i = 1, seq.track_len[TRACK_TIMBRE] do
    local step = seq.timbre[i]
    -- sparse p-locks: only 30% of steps get overrides
    if math.random() < 0.3 then
      step.config = math.random(0, 11)
    else
      step.config = -1
    end
    if math.random() < 0.2 then
      step.cutoff = math.random(200, 12000)
    else
      step.cutoff = -1
    end
    if math.random() < 0.15 then
      step.master_index = math.random() * 1.5
    else
      step.master_index = -1
    end
    step.wsa = math.random() < 0.1 and math.random(0, 7) or -1
    step.wsb = math.random() < 0.1 and math.random(0, 7) or -1
    step.drive = -1
    step.resonance = -1
    step.ratio2 = -1
    step.ratio3 = -1
    step.ratio4 = -1
  end
end

function seq.randomize_rhythm()
  for i = 1, seq.track_len[TRACK_RHYTHM] do
    local step = seq.rhythm[i]
    if math.random() < 0.7 then
      step.condition = COND_ALWAYS
    else
      step.condition = math.random(1, 10)
    end
    step.ratchet = math.random() < 0.15 and math.random(2, 3) or 1
    step.accent = math.random() < 0.2
  end
end

function seq.randomize_all(root, scale_notes)
  seq.randomize_melody(root, scale_notes)
  seq.randomize_timbre()
  seq.randomize_rhythm()
end

-- rotate a track's pattern
function seq.rotate(track, direction)
  local len = seq.track_len[track]
  local data
  if track == TRACK_MELODY then data = seq.melody
  elseif track == TRACK_TIMBRE then data = seq.timbre
  elseif track == TRACK_RHYTHM then data = seq.rhythm
  else return end

  if direction > 0 then
    local last = data[len]
    for i = len, 2, -1 do data[i] = data[i-1] end
    data[1] = last
  else
    local first = data[1]
    for i = 1, len - 1 do data[i] = data[i+1] end
    data[len] = first
  end
end

-- --------------------------------------------------------------------------
-- pattern chaining: save/recall/chain multiple patterns
-- --------------------------------------------------------------------------

seq.patterns = {}       -- saved pattern slots (up to 8)
seq.chain = {}          -- chain sequence (list of pattern indices)
seq.chain_pos = 0       -- current position in chain
seq.chain_active = false
seq.chain_passes = 0    -- passes through current pattern before advancing

function seq.save_pattern(slot)
  slot = slot or (#seq.patterns + 1)
  if slot > 8 then return end

  -- deep copy current state
  local p = {
    melody = {},
    timbre = {},
    rhythm = {},
    track_len = {seq.track_len[1], seq.track_len[2], seq.track_len[3]},
  }
  for i = 1, MAX_STEPS do
    p.melody[i] = {}
    for k, v in pairs(seq.melody[i]) do p.melody[i][k] = v end
    p.timbre[i] = {}
    for k, v in pairs(seq.timbre[i]) do p.timbre[i][k] = v end
    p.rhythm[i] = {}
    for k, v in pairs(seq.rhythm[i]) do p.rhythm[i][k] = v end
  end
  seq.patterns[slot] = p
end

function seq.load_pattern(slot)
  local p = seq.patterns[slot]
  if not p then return false end

  for i = 1, MAX_STEPS do
    if p.melody[i] then
      for k, v in pairs(p.melody[i]) do seq.melody[i][k] = v end
    end
    if p.timbre[i] then
      for k, v in pairs(p.timbre[i]) do seq.timbre[i][k] = v end
    end
    if p.rhythm[i] then
      for k, v in pairs(p.rhythm[i]) do seq.rhythm[i][k] = v end
    end
  end
  seq.track_len = {p.track_len[1], p.track_len[2], p.track_len[3]}
  return true
end

function seq.set_chain(chain_list)
  seq.chain = chain_list or {}
  seq.chain_pos = 1
  seq.chain_passes = 0
  seq.chain_active = #seq.chain > 0
  if seq.chain_active then
    seq.load_pattern(seq.chain[1])
  end
end

function seq.advance_chain()
  if not seq.chain_active then return end
  seq.chain_passes = seq.chain_passes + 1

  -- advance after 2 passes through the pattern
  if seq.chain_passes >= 2 then
    seq.chain_passes = 0
    seq.chain_pos = seq.chain_pos + 1
    if seq.chain_pos > #seq.chain then
      seq.chain_pos = 1
    end
    seq.load_pattern(seq.chain[seq.chain_pos])
  end
end

-- --------------------------------------------------------------------------
-- info for display
-- --------------------------------------------------------------------------

function seq.get_cond_name(cond)
  return COND_NAMES[cond] or "?"
end

seq.COND_NAMES = COND_NAMES
seq.TRACK_MELODY = TRACK_MELODY
seq.TRACK_TIMBRE = TRACK_TIMBRE
seq.TRACK_RHYTHM = TRACK_RHYTHM
seq.MAX_STEPS = MAX_STEPS

return seq
