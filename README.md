# bucha

*ghosts of the 700 — FM synthesis as living instrument*

## about

a norns adaptation of the Buchla 700's synthesis architecture: four operators routed through twelve topologies, waveshaping, and an OTA ladder filter with drive. the sound moves from glassy overtone clouds to gritty industrial mutation. an autonomous octopus system inhabits the engine, riding parameters across eight dimensions with nine compositional souls, turning the instrument into a collaborator.

## requirements

- norns
- grid (optional — index faders and isomorphic keyboard)
- MIDI device (optional — OP-XY integration, full CC control)

## controls

| control | function |
|---|---|
| E1 | page select |
| E2 / E3 | context-dependent per page |
| K2 hold | secondary encoder functions |
| K3 short | randomize current page params |
| K3 long | toggle autonomous systems (octopus + explorer + bandmate) |

## pages

**TOPOLOGY** — FM routing configuration (12 topologies) and master index

**RATIOS** — operator frequency ratios

**SHAPE** — waveshape A/B preset selection (8 presets per slot)

**FILTER** — cutoff, resonance, drive

**EFFECTS** — phaser, exciter, delay, reverb, chorus, tilt EQ

**OCTOPUS** — soul selection, bandmate voice

## the octopus

eight tentacles reach into the synthesis engine — TOPOLOGY, SPECTRUM, FILTER, RHYTHM, MELODY, SPACE, FORM, CHAOS — each moving at its own rate through its own territory.

nine souls shape how the octopus thinks:

| soul | character |
|---|---|
| SUBOTNICK | sparse, electric, insectoid |
| OLIVEROS | slow deep listening, long tones |
| BUCHLA | wild voltage, unpredictable beauty |
| XENAKIS | stochastic density, mass motion |
| ENO | ambient patience, gradual drift |
| COLTRANE | modal intensity, harmonic searching |
| MILES | cool space, implied harmony |
| APHEX | microtonal precision, controlled chaos |
| FUNK | groove-locked, rhythmic inevitability |

## features

- 12 FM topologies from simple carrier/modulator pairs to circular feedback networks
- 8 waveshape presets per slot (A and B with morph)
- 4-pole OTA ladder filter with drive
- polymetric sequencer with p-locks, ratchets, and conditional triggers
- scale lock, scale progression, and chord mode
- softcut tape loop
- full MIDI out — notes, clock, transport, 13+ CCs
- grid: index faders and isomorphic keyboard mode
- audio input processing through filter and effects chain

## install

```
;install https://github.com/jamminstein/bucha
```
