-- buchla700
-- norns port of the buchla 700
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

engine.name = "Buchla700"

local musicutil = require "musicutil"
local lattice_lib = require "lattice"

local seq = include "lib/sequencer"
local explorer = include "lib/explorer"
local bandmate = include "lib/bandmate"

-- pages
local PAGES = {"TOPOLOGY", "RATIOS", "SHAPE", "FILTER", "EFFECTS"}
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
local BANDMATE_STYLES = {"DRIFT", "PULSE", "BELLS", "VOICE", "CHAOS"}

-- state
local config = 0
local master_index = 0.5
local ratio_select = 1
local ratios = {2.0, 3.0, 4.0}
local ratio_idx = {6, 8, 10}
local wsa_preset = 0
local wsb_preset = 0
local cutoff = 2000
local resonance = 0.3
local drive = 0.0
local phaser_intensity = 0.0
local phaser_rate = 1.0
local phaser_depth = 0.5
local exciter_amount = 0.3
local tilt_eq = 0.0
local shift_held = false

-- MIDI
local midi_in_device
local midi_out_device
local current_note = nil

-- lattice
local my_lattice
local seq_sprocket
local explorer_sprocket
local bandmate_sprocket

-- grid
local g = grid.connect()
local grid_dirty = true
local grid_held = {}  -- track held keys for gestures
local index_values = {0.5, 0.3, 0.2, 0.1, 0.1, 0.1}  -- local tracking for grid display

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
-- init
-- --------------------------------------------------------------------------

function init()
  params:add_separator("BUCHLA 700")

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
    controlspec.new(0, 2, 'lin', 0.01, 0.5, ""))
  params:set_action("master_index", function(v)
    master_index = v
    engine.master_index(v)
    screen_dirty = true
  end)

  for i = 1, 6 do
    params:add_control("index" .. i, "index " .. i,
      controlspec.new(0, 2, 'lin', 0.01, ({0.5,0.3,0.2,0.1,0.1,0.1})[i], ""))
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
    controlspec.new(20, 18000, 'exp', 0, 2000, "hz"))
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
  params:set_action("drive", function(v)
    drive = v
    engine.drive(v)
  end)

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

  -- BANDMATE
  params:add_group("BANDMATE", 2)
  params:add_option("bandmate_style", "bandmate style",
    BANDMATE_STYLES, 1)
  params:set_action("bandmate_style", function(v)
    bandmate.set_style(BANDMATE_STYLES[v])
  end)

  params:add_number("bandmate_root", "bandmate root", 24, 72, 48)

  -- MIDI
  params:add_group("MIDI", 3)
  params:add_number("midi_in_ch", "midi in ch", 1, 16, 1)
  params:add_number("midi_out_ch", "midi out ch", 1, 16, 1)
  params:add_number("midi_out_device", "midi out device", 1, 16, 2)

  -- connect MIDI
  midi_in_device = midi.connect(1)
  midi_in_device.event = midi_event
  midi_out_device = midi.connect(params:get("midi_out_device"))

  -- init modules
  seq.init()

  -- bandmate note callback
  bandmate.note_on_fn = function(note, vel, gate)
    note_on(note, vel)
    clock.run(function()
      clock.sleep(gate * clock.get_beat_sec())
      note_off(note)
    end)
  end

  -- lattice: sequencer, explorer, bandmate on separate sprockets
  my_lattice = lattice_lib:new()

  seq_sprocket = my_lattice:new_sprocket{
    action = function(t)
      if seq.playing then seq_step() end
    end,
    division = 1/4,
    enabled = true
  }

  explorer_sprocket = my_lattice:new_sprocket{
    action = function(t)
      explorer.tick()
      grid_dirty = true
    end,
    division = 1/4,
    enabled = true
  }

  bandmate_sprocket = my_lattice:new_sprocket{
    action = function(t)
      bandmate.advance()
      grid_dirty = true
    end,
    division = 1/4,
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

function note_on(note, vel)
  engine.note_on(note, vel)
  local ch = params:get("midi_out_ch")
  midi_out_device:note_on(note, math.floor(vel * 127), ch)
  current_note = note
  screen_dirty = true
end

function note_off(note)
  engine.note_off(note)
  local ch = params:get("midi_out_ch")
  midi_out_device:note_off(note, 0, ch)
  if current_note == note then current_note = nil end
  screen_dirty = true
end

-- --------------------------------------------------------------------------
-- sequencer step
-- --------------------------------------------------------------------------

function seq_step()
  if current_note then note_off(current_note) end

  local swing_delay = seq.get_swing_delay()
  if swing_delay > 0 then
    clock.sleep(swing_delay * clock.get_beat_sec())
  end

  if seq.should_play() then
    local step = seq.get_step()

    -- per-step topology override
    if step.config >= 0 then
      engine.config(step.config)
    elseif step.config == -1 then
      engine.config(config)
    end

    local vel = step.vel / 127
    note_on(step.note, vel)

    local gate = seq.get_gate_length()
    clock.run(function()
      clock.sleep(gate * clock.get_beat_sec())
      note_off(step.note)
    end)
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
      if shift_held then
        params:delta("drive", d)
      else
        params:delta("cutoff", d)
      end
    elseif n == 3 then
      params:delta("resonance", d)
    end
  elseif page == 5 then
    if n == 2 then
      if shift_held then
        params:delta("phaser_rate", d)
      else
        params:delta("phaser_intensity", d)
      end
    elseif n == 3 then
      if shift_held then
        params:delta("tilt_eq", d)
      else
        params:delta("exciter_amount", d)
      end
    end
  end
  screen_dirty = true
end

function key(n, z)
  if n == 2 then
    shift_held = (z == 1)
    if z == 0 then
      -- short press: toggle sequencer
      seq.playing = not seq.playing
      if not seq.playing and current_note then note_off(current_note) end
      if seq.playing then seq.reset() end
    end
  elseif n == 3 and z == 1 then
    if shift_held then
      -- K2+K3: toggle bandmate + explorer (the autonomous systems)
      if bandmate.active then
        bandmate.stop()
        explorer.stop()
      else
        bandmate.start(
          params:get("bandmate_root"),
          BANDMATE_STYLES[params:get("bandmate_style")]
        )
        explorer.start()
      end
    else
      -- K3 alone: page-specific randomize
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

  -- sequencer dots
  if seq.playing then
    screen.level(6)
    screen.rect(60, 1, 2, 2)
    screen.fill()
    for i = 1, seq.num_steps do
      screen.level(i == seq.current_step and 15 or 3)
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

  screen.level(2)
  screen.move(1, 63)
  screen.text("E2:config E3:idx K2+K3:auto")
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
  screen.text(shift_held and "E2:drive  E3:res" or "E2:cutoff  E3:res  K2+E2:drive")
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

  -- bandmate info (bottom right when active)
  if bandmate.active then
    local info = bandmate.get_info()
    screen.level(4)
    screen.move(70, 54)
    screen.text(info.style .. " " .. info.breath)
    screen.level(math.floor(info.energy * 12) + 2)
    screen.rect(70, 56, info.energy * 56, 2)
    screen.fill()
  end

  screen.level(2)
  screen.move(1, 63)
  screen.text(shift_held and "E2:rate  E3:tilt" or "E2:phaser  E3:exciter  K2=shift")
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
            BANDMATE_STYLES[params:get("bandmate_style")]
          )
        end
      elseif x == 15 then
        -- toggle explorer
        if explorer.active then
          explorer.stop()
        else
          explorer.start()
        end
      elseif x == 16 then
        -- play/stop sequencer
        seq.playing = not seq.playing
        if not seq.playing and current_note then note_off(current_note) end
        if seq.playing then seq.reset() end
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

    -- ROW 3: sequencer step toggle
    elseif y == 3 then
      if x >= 1 and x <= 16 then
        local step = seq.steps[x]
        if step then
          step.on = not step.on
        end
      end

    -- ROW 4: per-step topology override
    elseif y == 4 then
      if x >= 1 and x <= 16 then
        local step = seq.steps[x]
        if step then
          -- cycle: -1 (global) -> 0 -> 1 -> ... -> 11 -> -1
          step.config = step.config + 1
          if step.config > 11 then step.config = -1 end
        end
      end

    -- ROWS 5-8: index faders + controls
    elseif y >= 5 and y <= 8 then
      -- cols 1-6: FM index faders (vertical, 4 rows = 4 levels per index)
      if x >= 1 and x <= 6 then
        -- map row 5-8 to value: row 5 = high (1.5), row 8 = low (0.0)
        local val = util.linlin(8, 5, 0, 1.5, y)
        params:set("index" .. x, val)
      -- col 8-16, row 5: master index horizontal fader
      elseif x >= 8 and x <= 16 and y == 5 then
        local val = util.linlin(8, 16, 0, 2.0, x)
        params:set("master_index", val)
      -- col 8-12, row 6: bandmate style
      elseif x >= 8 and x <= 12 and y == 6 then
        local style_idx = x - 7
        if style_idx >= 1 and style_idx <= #BANDMATE_STYLES then
          params:set("bandmate_style", style_idx)
        end
      -- col 8-11, row 7: force explorer phase
      elseif x >= 8 and x <= 11 and y == 7 then
        if explorer.active then
          explorer.enter_phase(x - 7)
        end
      -- col 13-16, row 7: randomize actions
      elseif y == 7 then
        if x == 13 then
          -- random topology
          config = math.random(0, 11)
          params:set("config", config + 1)
        elseif x == 14 then
          -- random ratios
          for i = 1, 3 do
            ratio_idx[i] = math.random(1, #RATIOS)
            params:set("ratio" .. (i + 1), RATIOS[ratio_idx[i]])
          end
        elseif x == 15 then
          -- random indices
          for i = 1, 6 do
            params:set("index" .. i, math.random() * 1.5)
          end
        elseif x == 16 then
          -- random waveshapes
          wsa_preset = math.random(0, 7)
          wsb_preset = math.random(0, 7)
          params:set("wsa_preset", wsa_preset + 1)
          params:set("wsb_preset", wsb_preset + 1)
        end
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

  -- ROW 3: sequencer steps
  for x = 1, seq.num_steps do
    local step = seq.steps[x]
    local bright = 0
    if step and step.on then
      bright = 6
      if seq.playing and x == seq.current_step then
        bright = 15
      end
    else
      if seq.playing and x == seq.current_step then
        bright = 4
      end
    end
    g:led(x, 3, bright)
  end

  -- ROW 4: per-step topology override
  for x = 1, seq.num_steps do
    local step = seq.steps[x]
    if step then
      if step.config >= 0 then
        -- brightness maps to config number (1-12 -> 2-13)
        g:led(x, 4, math.floor(2 + step.config * 11 / 11))
      else
        g:led(x, 4, 1)  -- global = very dim
      end
    end
  end

  -- ROWS 5-8: FM index faders (cols 1-6, vertical)
  for idx = 1, 6 do
    local val = index_values[idx]
    -- map 0-1.5 to rows 8 (bottom) to 5 (top)
    local fill_rows = math.floor(util.linlin(0, 1.5, 0, 4, val) + 0.5)
    for row = 8, 5, -1 do
      local row_from_bottom = 8 - row  -- 0,1,2,3
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
    local col_from_left = x - 7  -- 1-9
    if col_from_left <= master_fill then
      g:led(x, 5, 10)
    else
      g:led(x, 5, 1)
    end
  end

  -- ROW 6, cols 8-12: bandmate style
  for i = 1, #BANDMATE_STYLES do
    local x = i + 7
    local is_current = (BANDMATE_STYLES[i] == bandmate.style)
    g:led(x, 6, is_current and 12 or 3)
  end

  -- ROW 7, cols 8-11: explorer phase
  if explorer.active then
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

  -- STATUS METERS (col 15-16, rows 5-8)
  -- col 15: explorer intensity (bottom to top)
  if explorer.active then
    local exp_fill = math.floor(explorer.intensity * 4 + 0.5)
    for row = 8, 5, -1 do
      local from_bottom = 8 - row
      -- don't overwrite index faders in cols 1-6, these are cols 15-16
      g:led(15, row, from_bottom < exp_fill and 8 or 0)
    end
  end

  -- col 16: bandmate energy (bottom to top)
  if bandmate.active then
    local bm_fill = math.floor(bandmate.energy * 4 + 0.5)
    for row = 8, 5, -1 do
      local from_bottom = 8 - row
      g:led(16, row, from_bottom < bm_fill and 8 or 0)
    end
  end

  g:refresh()
end

-- --------------------------------------------------------------------------
-- cleanup
-- --------------------------------------------------------------------------

function cleanup()
  if current_note then note_off(current_note) end
  bandmate.stop()
  explorer.stop()
  if my_lattice then my_lattice:destroy() end
end
