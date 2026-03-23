-- buchla700 sequencer
-- 8-step with per-step topology override

local seq = {}

seq.steps = {}
seq.num_steps = 8
seq.current_step = 1
seq.playing = false
seq.probability = 100
seq.swing = 50
seq.gate_length = 0.5

function seq.init()
  for i = 1, 16 do
    seq.steps[i] = {
      note = 60,
      vel = 100,
      gate_len = -1,    -- -1 = use global
      config = -1,      -- -1 = use global, 0-11 = per-step topology
      on = true
    }
  end
  -- default chromatic ascending
  seq.steps[1].note = 60
  seq.steps[2].note = 63
  seq.steps[3].note = 65
  seq.steps[4].note = 67
  seq.steps[5].note = 70
  seq.steps[6].note = 72
  seq.steps[7].note = 67
  seq.steps[8].note = 65
end

function seq.advance()
  seq.current_step = seq.current_step + 1
  if seq.current_step > seq.num_steps then
    seq.current_step = 1
  end
end

function seq.get_step()
  return seq.steps[seq.current_step]
end

function seq.set_step(idx, key, value)
  if seq.steps[idx] then
    seq.steps[idx][key] = value
  end
end

function seq.reset()
  seq.current_step = 1
end

function seq.should_play()
  if not seq.steps[seq.current_step].on then return false end
  if seq.probability >= 100 then return true end
  return math.random(100) <= seq.probability
end

function seq.get_gate_length()
  local step = seq.steps[seq.current_step]
  if step.gate_len >= 0 then
    return step.gate_len
  end
  return seq.gate_length
end

function seq.get_swing_delay()
  if seq.current_step % 2 == 0 then
    local swing_amt = (seq.swing - 50) / 100
    return swing_amt * 0.5
  end
  return 0
end

function seq.randomize_notes(scale_notes)
  if scale_notes and #scale_notes > 0 then
    for i = 1, seq.num_steps do
      seq.steps[i].note = scale_notes[math.random(#scale_notes)]
    end
  end
end

function seq.randomize_configs()
  for i = 1, seq.num_steps do
    if math.random() > 0.5 then
      seq.steps[i].config = math.random(0, 11)
    else
      seq.steps[i].config = -1  -- use global
    end
  end
end

return seq
