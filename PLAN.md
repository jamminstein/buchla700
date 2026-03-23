# buchla700 — Norns Port Plan

## The Instrument

A faithful port of the Buchla 700's DSP engine to norns/SuperCollider. The Buchla 700 was Don Buchla's last major instrument (1989) — a 12-voice FM+waveshaping+subtractive hybrid with 12 FM routing topologies that fundamentally change the character of the sound. The magic is in the **topology switching**: same notes, same indices, completely different timbre.

## Architecture

### SuperCollider Engine: `Engine_Buchla700.sc`

**Voice structure** (4 voices, polyphonic):
```
4 SinOsc phase accumulators
  → FM routing (1 of 12 configs, 6 modulation indices)
  → Waveshape A + Waveshape B (Shaper UGen with Buffer)
  → Mix (x0.2)
  → OTA Ladder Filter (MoogFF + tanh pre-drive for saturation character)
  → DC Blocker (LeakDC)
  → Equal-power pan (Pan2)
  → Level × Dynamics
```

**Global effects chain** (post voice mix):
1. **Aural Exciter** — BPF 1-12kHz → harmonic generation (squared + cubed) → soft clip → mix back. Always on, controllable amount.
2. **Phase Shifter** — 8-stage AllpassC chain per channel, LFO-modulated (70% soft sine + 30% tri blend), independent L/R tuning for stereo width. Faithful port of the original.
3. **Tilt EQ** — Simplified from the 7-band. Single knob: dark ↔ bright. More appropriate for norns than 7 faders.

**FM Topologies** — All 12 configs ported directly from `dsp.c`:
- 00: Symmetric dual-path (Osc2+Osc4 modulate both paths)
- 01: Split modulators (dedicated mod per path)
- 02: Cascaded FM with feedback loop
- 03: Shared carrier (Osc3 mods both Osc1+Osc2)
- 04: Minimal FM + direct envelope
- 05: Cross-coupled paths
- 06: Three-oscillator cascade
- 07: Osc4-centric with self-modulation
- 08: Dual-path with feedback
- 09: Circular feedback (two feedback loops — chaos)
- 10: Shared modulator, no feedback
- 11: Multi-output with three side-chains

Each topology is a separate function in SC, selected via an integer command. The topology names will be shown on screen with short evocative labels.

**Waveshape presets** (loaded into Buffers):
1. Linear (pass-through, default)
2. Soft clip (gentle saturation)
3. Hard clip (aggressive)
4. Fold (wavefolder character)
5. Sine fold (Buchla-style sine wavefolder)
6. Asymmetric (even harmonics emphasis)
7. Staircase (bit-reduction feel)
8. Chebyshev 3rd (3rd harmonic emphasis)

**Engine commands:**
- `note_on(note, vel)` / `note_off(note)`
- `config(i)` — FM topology 0-11
- `ratio2(r)`, `ratio3(r)`, `ratio4(r)` — oscillator freq ratios relative to fundamental
- `index1..6(v)` — FM modulation depths (0.0-1.0 normalized, bipolar internally)
- `master_index(v)` — scales all 6 indices proportionally
- `cutoff(hz)`, `resonance(v)`, `drive(v)` — filter
- `wsa(preset)`, `wsb(preset)` — waveshape selection
- `phaser_intensity(v)`, `phaser_rate(hz)`, `phaser_depth(v)`
- `exciter_amount(v)` — 0=off, 1=full
- `tilt(v)` — -1 dark, 0 flat, +1 bright

### Lua Script: `buchla700.lua`

**5 pages**, E1 always selects page:

#### Page 1: TOPOLOGY
- E2: FM config (0-11) with name display
- E3: Master index (scales all 6 FM indices proportionally)
- Screen: FM routing diagram — shows the 4 oscillators and their connections for current config. Animated signal flow.
- K3: Random topology + random ratios (instant timbral exploration)

#### Page 2: RATIOS
- E2: Select oscillator (2/3/4) — highlighted on screen
- E3: Adjust selected ratio (harmonic series: 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 5, 6, 7, 8 — snaps to harmonics with fine-tune between)
- Screen: Shows all 4 oscillators with their frequency ratios, selected one highlighted
- K3: Randomize all ratios within harmonic constraints

#### Page 3: SHAPE
- E2: Waveshape A preset (1-8)
- E3: Waveshape B preset (1-8)
- Screen: Visual representation of both waveshape transfer functions (the classic Buchla waveshape display — input on X, output on Y)
- K3: Randomize both waveshapes

#### Page 4: FILTER
- E2: Cutoff frequency (20-20000 Hz, exponential)
- E3: Resonance (0-0.95)
- Screen: Filter response visualization with cutoff/res indicators. Shows the warm Buchla curve.
- K2+E3 (shift): Drive amount (pre-filter tanh saturation)

#### Page 5: EFFECTS
- E2: Phaser intensity (0-1)
- E3: Exciter amount (0-1)
- Screen: Phaser LFO visualization + exciter harmonic spectrum
- K2+E2 (shift): Phaser rate
- K2+E3 (shift): Tilt EQ

**Keys:**
- K2: Play/stop sequencer (or hold for shift layer)
- K3: Page-specific action (randomize on most pages)

**Sequencer** (8 steps, like jamcoast pattern):
- Steps hold note, velocity, gate length
- Per-step FM config override (optional — the killer feature: different topology per step)
- Clock-synced via lattice
- Probability per step

**MIDI:**
- MIDI in: Note on/off for playing
- MIDI out: To external gear (OP-XY channel support)
- All params MIDI-mappable via norns params system

**Params menu** (deep access to everything):
- All 6 FM indices individually
- All oscillator ratios with fine tune
- Filter cutoff, resonance, drive
- Phaser rate, depth, intensity
- Exciter amount
- Tilt EQ
- Level, pan
- Sequencer settings (steps, probability, swing)
- MIDI in/out channels

### Robot Profile: `lib/profiles/buchla700.lua`

```
timbral: config (weight 0.3, sensitivity 1.0 — rare but dramatic)
timbral: master_index (weight 0.8, sensitivity 0.6)
timbral: cutoff (weight 0.9, sensitivity 0.7)
timbral: resonance (weight 0.5, sensitivity 0.4)
timbral: wsa/wsb (weight 0.2, sensitivity 1.0 — rare, full change)
melodic: ratio2/3/4 (weight 0.4, sensitivity 0.3 — gentle harmonic drift)
spatial: phaser_intensity (weight 0.6, sensitivity 0.5)
spatial: exciter_amount (weight 0.3, sensitivity 0.3)
spatial: tilt (weight 0.4, sensitivity 0.4)
never_touch: ["note", "velocity", "gate_length"]
```

## Screen Design

128x64 OLED. Each page has a distinct visual identity:

- **TOPOLOGY**: Minimal node graph — 4 circles (oscillators) with animated connection lines showing signal flow. Current config number large in corner.
- **RATIOS**: Horizontal frequency bars, selected oscillator bright, ratios displayed numerically.
- **SHAPE**: Two small XY transfer function plots side by side (WSA left, WSB right).
- **FILTER**: Classic filter curve with peak at resonance, cutoff marker.
- **EFFECTS**: Split screen — phaser LFO waveform top, exciter spectrum bottom.

## File Structure

```
buchla700/
├── buchla700.lua              -- main script
├── lib/
│   ├── Engine_Buchla700.sc    -- SuperCollider engine
│   ├── sequencer.lua          -- 8-step sequencer
│   ├── topology_display.lua   -- FM routing visualizations
│   └── profiles/
│       └── buchla700.lua      -- robot profile
└── README.md                  -- (only if requested)
```

## Implementation Order

1. **Engine_Buchla700.sc** — Core synthesis: oscillators, all 12 FM topologies, waveshaping, filter, effects chain. Test with simple note_on/off.
2. **buchla700.lua** — Main script with params, 5-page UI, encoder/key handling. Wire up to engine.
3. **Screen visualizations** — Topology diagrams, waveshape plots, filter curves.
4. **Sequencer** — 8-step with per-step topology override.
5. **MIDI** — In/out, OP-XY support.
6. **Robot profile** — Explorer integration.
