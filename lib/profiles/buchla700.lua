-- buchla700 robot profile
--
-- the robot is a topology explorer, not a parameter randomizer.
-- it rides FM indices like a buchla operator rides a complex oscillator:
-- subtle shifts in modulation depth create vast timbral journeys.
-- topology switching is the dramatic gesture — used sparingly,
-- like changing a patch cable on a modular.

return {
  name = "buchla700",
  description = "FM topology explorer — rides indices, drifts ratios, shifts routing",
  phrase_len = 8,
  recommended_modes = {1, 2, 3},  -- DRIFT, MORPH, CHAOS

  never_touch = {
    "midi_in_ch",
    "midi_out_ch",
    "seq_steps",
  },

  params = {
    -- TIMBRAL: the core expression
    config = {
      group = "timbral",
      weight = 0.15,
      sensitivity = 1.0,
      direction = "both",
      description = "FM routing topology — the character of the sound. rare but dramatic."
    },
    master_index = {
      group = "timbral",
      weight = 0.85,
      sensitivity = 0.6,
      direction = "both",
      range_lo = 0.05,
      range_hi = 1.8,
      description = "scales all 6 FM indices — the primary expressivity control"
    },
    index1 = {
      group = "timbral",
      weight = 0.7,
      sensitivity = 0.5,
      direction = "both",
      range_lo = 0.0,
      range_hi = 1.5,
      description = "FM index 1 — primary modulation depth"
    },
    index2 = {
      group = "timbral",
      weight = 0.6,
      sensitivity = 0.5,
      direction = "both",
      range_lo = 0.0,
      range_hi = 1.5,
      description = "FM index 2 — secondary modulation"
    },
    index3 = {
      group = "timbral",
      weight = 0.5,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0.0,
      range_hi = 1.2,
      description = "FM index 3 — output scaling / tertiary mod"
    },
    index4 = {
      group = "timbral",
      weight = 0.4,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0.0,
      range_hi = 1.2,
      description = "FM index 4"
    },
    index5 = {
      group = "timbral",
      weight = 0.35,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 0.0,
      range_hi = 1.0,
      description = "FM index 5 — often feedback path"
    },
    index6 = {
      group = "timbral",
      weight = 0.35,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 0.0,
      range_hi = 1.0,
      description = "FM index 6 — often WSB output scaling"
    },
    cutoff = {
      group = "timbral",
      weight = 0.8,
      sensitivity = 0.7,
      direction = "both",
      range_lo = 80,
      range_hi = 14000,
      description = "OTA ladder filter cutoff — the breath of the instrument"
    },
    resonance = {
      group = "timbral",
      weight = 0.5,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0.0,
      range_hi = 2.8,
      description = "filter resonance — careful above 2.5"
    },
    drive = {
      group = "timbral",
      weight = 0.3,
      sensitivity = 0.3,
      direction = "up",
      range_lo = 0.0,
      range_hi = 0.7,
      description = "pre-filter tanh saturation — buchla OTA warmth"
    },

    -- MELODIC: spectral character
    ratio2 = {
      group = "melodic",
      weight = 0.35,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 0.5,
      range_hi = 6.0,
      description = "osc 2 frequency ratio — harmonic drift"
    },
    ratio3 = {
      group = "melodic",
      weight = 0.3,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 0.5,
      range_hi = 6.0,
      description = "osc 3 frequency ratio"
    },
    ratio4 = {
      group = "melodic",
      weight = 0.25,
      sensitivity = 0.25,
      direction = "both",
      range_lo = 0.5,
      range_hi = 6.0,
      description = "osc 4 frequency ratio"
    },

    -- STRUCTURAL: waveshape and sequencer
    wsa_preset = {
      group = "structural",
      weight = 0.12,
      sensitivity = 1.0,
      direction = "both",
      description = "waveshape A transfer function — rare but total character change"
    },
    wsb_preset = {
      group = "structural",
      weight = 0.12,
      sensitivity = 1.0,
      direction = "both",
      description = "waveshape B transfer function"
    },
    seq_probability = {
      group = "structural",
      weight = 0.2,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 40,
      range_hi = 100,
      description = "sequencer probability — thinning creates space"
    },
    seq_swing = {
      group = "structural",
      weight = 0.15,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 50,
      range_hi = 70,
      description = "swing amount"
    },

    -- SPATIAL: effects and space
    phaser_intensity = {
      group = "spatial",
      weight = 0.5,
      sensitivity = 0.5,
      direction = "both",
      range_lo = 0.0,
      range_hi = 0.85,
      description = "8-stage phase shifter — buchla spatial movement"
    },
    phaser_rate = {
      group = "spatial",
      weight = 0.25,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 0.2,
      range_hi = 3.5,
      description = "phaser LFO rate"
    },
    phaser_depth = {
      group = "spatial",
      weight = 0.2,
      sensitivity = 0.3,
      direction = "both",
      range_lo = 0.1,
      range_hi = 0.9,
      description = "phaser modulation depth"
    },
    exciter_amount = {
      group = "spatial",
      weight = 0.4,
      sensitivity = 0.4,
      direction = "both",
      range_lo = 0.0,
      range_hi = 0.7,
      description = "aural exciter — harmonic presence and air"
    },
    tilt_eq = {
      group = "spatial",
      weight = 0.3,
      sensitivity = 0.3,
      direction = "both",
      range_lo = -0.7,
      range_hi = 0.7,
      description = "spectral tilt: dark (-) to bright (+)"
    },
  }
}
