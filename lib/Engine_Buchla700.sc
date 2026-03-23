// Engine_Buchla700
// Norns port of the Buchla 700 DSP engine
// 4-voice FM + waveshaping + OTA ladder filter
// 12 FM routing topologies, aural exciter, 8-stage phase shifter
//
// Original DSP by The Contributors (GPL v3)
// Norns adaptation 2026

Engine_Buchla700 : CroneEngine {
	var <voices;       // Dictionary of active voice synths
	var <params;       // global parameter state
	var <fxBus;        // effects send bus
	var <fxSynth;      // effects chain synth
	var <fxGroup;      // group for effects
	var <voiceGroup;   // group for voices
	var <wsaBufs;      // waveshape A buffer array (8 presets)
	var <wsbBufs;      // waveshape B buffer array (8 presets)
	var <wsaIdx;       // current WSA preset index
	var <wsbIdx;       // current WSB preset index

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		var server = context.server;

		voices = Dictionary.new;
		params = Dictionary.new;

		// defaults
		params[\config] = 0;
		params[\ratio2] = 2.0;
		params[\ratio3] = 3.0;
		params[\ratio4] = 4.0;
		params[\index1] = 0.5;
		params[\index2] = 0.3;
		params[\index3] = 0.2;
		params[\index4] = 0.1;
		params[\index5] = 0.1;
		params[\index6] = 0.1;
		params[\masterIndex] = 1.0;
		params[\cutoff] = 2000.0;
		params[\resonance] = 0.3;
		params[\drive] = 0.0;
		params[\wsaPreset] = 0;
		params[\wsbPreset] = 0;
		params[\phaserIntensity] = 0.0;
		params[\phaserRate] = 1.0;
		params[\phaserDepth] = 0.5;
		params[\exciterAmount] = 0.3;
		params[\tilt] = 0.0;

		wsaIdx = 0;
		wsbIdx = 0;

		// ---- waveshape buffers ----
		// 8 presets x 2 (WSA + WSB), 1024 samples each
		wsaBufs = Array.fill(8, { Buffer.alloc(server, 1024, 1) });
		wsbBufs = Array.fill(8, { Buffer.alloc(server, 1024, 1) });

		server.sync;

		// fill waveshape presets
		this.fillWaveshapePresets(wsaBufs);
		this.fillWaveshapePresets(wsbBufs);

		server.sync;

		// ---- buses and groups ----
		fxBus = Bus.audio(server, 2);
		voiceGroup = ParGroup.new(context.xg);
		fxGroup = Group.after(voiceGroup);

		// ---- SynthDefs ----

		// -- Voice SynthDef with all 12 FM topologies --
		SynthDef(\b700voice, { arg out, freq=440, vel=0.8, gate=1,
			config=0,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			masterIdx=1.0,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf,
			pan=0;

			var f1, f2, f3, f4;
			var p1, p2, p3, p4;
			var s0, s1, s2, s3;
			var idx, wsaIn, wsbIn;
			var wsaOut, wsbOut, mixed, filtered, sig;
			var env, dynEnv;

			// oscillator frequencies
			f1 = freq;
			f2 = freq * ratio2;
			f3 = freq * ratio3;
			f4 = freq * ratio4;

			// phase accumulators (Phasor for continuous phase)
			p1 = Phasor.ar(0, f1 * SampleDur.ir * 2pi, 0, 2pi);
			p2 = Phasor.ar(0, f2 * SampleDur.ir * 2pi, 0, 2pi);
			p3 = Phasor.ar(0, f3 * SampleDur.ir * 2pi, 0, 2pi);
			p4 = Phasor.ar(0, f4 * SampleDur.ir * 2pi, 0, 2pi);

			// base oscillator signals
			s0 = sin(p1);
			s1 = sin(p2);
			s2 = sin(p3);
			s3 = sin(p4);

			// scale indices by master
			idx = [idx1, idx2, idx3, idx4, idx5, idx6] * masterIdx;

			// FM routing: Select topology
			// Each config produces [wsaIn, wsbIn]
			// We implement all 12 and crossfade-select

			wsaIn = Select.ar(config, [
				// config 00: symmetric dual-path
				(sin(p1 + (s1 * idx[0])) + (s3 * idx[1])) * idx[2],
				// config 01: split modulators
				(sin(p1 + (s1 * idx[0])) + (s1 * idx[1])) * idx[2],
				// config 02: cascaded FM with feedback
				sin(p1 + (sin(p2 + (s2 * idx[1])) * idx[0])) * idx[2],
				// config 03: shared carrier
				(s3 + (sin(p1 + (s2 * idx[1])) * idx[0])) * idx[2],
				// config 04: minimal FM + direct envelope
				sin(p1 + (sin(p2) * idx[1])) * idx[2],
				// config 05: cross-coupled
				(sin(p2) + (sin(p1 + (s3 * idx[1])) * idx[0])) * idx[2],
				// config 06: three-osc cascade
				sin(p1 + (sin(p2 + (s2 * idx[0])) * idx[1]) + (s3 * idx[3])) * idx[2],
				// config 07: osc4-centric
				sin(p1 + (s3 * idx[3])) * idx[2],
				// config 08: dual-path with feedback
				(sin(p1 + (sin(p2) * idx[1])) + (s2 * idx[0])) * idx[2],
				// config 09: circular feedback (chaos)
				sin(p1 + (s3 * idx[0])) * idx[2],
				// config 10: shared modulator
				(sin(p1 + (s1 * idx[1])) + (s2 * idx[0])) * idx[2],
				// config 11: multi-output
				(sin(p1 + (sin(p3) * idx[4])) + (s0 * idx[0]) + (s3 * idx[3])) * idx[2]
			]);

			wsbIn = Select.ar(config, [
				// config 00
				(sin(p3 + (s1 * idx[3])) + (s3 * idx[4])) * idx[5],
				// config 01
				(sin(p3 + (s3 * idx[3])) + (s3 * idx[4])) * idx[5],
				// config 02
				sin(p3 + (s3 * idx[3])) * idx[5],
				// config 03
				(s3 + (sin(p2 + (s2 * idx[4])) * idx[3])) * idx[5],
				// config 04: direct envelope
				idx[5],
				// config 05
				(s3 + (sin(p3 + (sin(p2) * idx[4])) * idx[3])) * idx[5],
				// config 06: same signal both paths
				sin(p1 + (sin(p2 + (s2 * idx[0])) * idx[1]) + (s3 * idx[3])) * idx[5],
				// config 07: osc4 self-mod
				(s3 + (s3 * idx[4])) * idx[5],
				// config 08
				(s3 + (s0 * idx[4])) * idx[5],
				// config 09: circular feedback
				sin(p3 + (s1 * idx[3])) * idx[5],
				// config 10
				(sin(p3 + (s1 * idx[4])) + (s0 * idx[3])) * idx[5],
				// config 11
				(sin(p1 + (sin(p3) * idx[4])) + (s1 * idx[1])) * idx[5]
			]);

			// waveshaper lookup
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1, 1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1, 1));

			// mix waveshapers
			mixed = (wsaOut + wsbOut) * 0.2;

			// pre-filter drive (tanh saturation, Buchla OTA character)
			mixed = (mixed * (1 + (drive * 4))).tanh;

			// OTA ladder filter (MoogFF approximation)
			filtered = MoogFF.ar(mixed, cutoff.clip(20, 18000), resonance.clip(0, 3.5));

			// DC blocker
			filtered = LeakDC.ar(filtered);

			// envelope
			env = EnvGen.kr(Env.adsr(0.005, 0.2, 0.8, 0.3), gate, doneAction: Done.freeSelf);
			dynEnv = env * vel;

			// anti-click ramp
			sig = filtered * dynEnv;

			// pan and output
			sig = Pan2.ar(sig, pan);
			Out.ar(out, sig);
		}).add;

		// -- Effects chain --
		SynthDef(\b700fx, { arg in, out,
			phaserIntensity=0.0, phaserRate=1.0, phaserDepth=0.5,
			exciterAmount=0.3,
			tilt=0.0;

			var sig, left, right;
			var lhf, rhf, lHarm, rHarm, lExc, rExc;
			var lfo, lfoSoft, lfoTri, lfoBlend;
			var allpassFreqs, apL, apR;
			var tiltLo, tiltHi;
			var excAmt;

			sig = In.ar(in, 2);
			left = sig[0];
			right = sig[1];

			// ---- AURAL EXCITER ----
			// extract HF band 1-12kHz
			excAmt = exciterAmount.lag(0.1);
			lhf = BPF.ar(left, 3000, 1.5);
			rhf = BPF.ar(right, 3000, 1.5);

			// generate 2nd + 3rd order harmonics
			lHarm = ((lhf * lhf * lhf.sign * 2) + (lhf * lhf * lhf * 0.5)).softclip;
			rHarm = ((rhf * rhf * rhf.sign * 2) + (rhf * rhf * rhf * 0.5)).softclip;

			// mix back
			lExc = left + (lHarm * excAmt) + (left * 0.3 * excAmt);
			rExc = right + (rHarm * excAmt) + (right * 0.3 * excAmt);
			left = lExc.softclip;
			right = rExc.softclip;

			// ---- 8-STAGE PHASE SHIFTER ----
			// LFO: 70% soft sine + 30% triangle
			lfo = SinOsc.kr(phaserRate);
			lfoSoft = lfo * (1.5 - (0.5 * lfo * lfo));
			lfoTri = LFTri.kr(phaserRate);
			lfoBlend = (lfoSoft * 0.7) + (lfoTri * 0.3);

			// modulated allpass frequencies: 300-3500 Hz range
			allpassFreqs = Array.fill(8, { |i|
				var ratio = i / 7.0;
				var baseFreq = 300 + ((1 - (phaserIntensity * phaserIntensity)) * 3200);
				var freqL = (baseFreq * (0.5 + (ratio * 0.5)).pow(1.5)).clip(250, 6000);
				freqL
			});

			// cascade of 8 allpass stages per channel
			apL = left;
			apR = right;
			8.do { |i|
				var freq = allpassFreqs[i];
				var modFreq = freq * (1 + (lfoBlend * phaserDepth * 0.3));
				var delay = (1.0 / modFreq).clip(0.00001, 0.01);
				apL = AllpassC.ar(apL, 0.01, delay, 0.0);
				apR = AllpassC.ar(apR, 0.01, delay * 0.8, 0.0);
			};

			// mix: 80% shifted + 20% dry, scaled by intensity
			left = (apL * 0.8 * phaserIntensity) + (left * (1 - (phaserIntensity * 0.8)));
			right = (apR * 0.8 * phaserIntensity) + (right * (1 - (phaserIntensity * 0.8)));

			// ---- TILT EQ ----
			// tilt < 0 = dark (boost low, cut high)
			// tilt > 0 = bright (cut low, boost high)
			tiltLo = BLowShelf.ar(left, 300, 1, tilt.neg * 6, [left, right]);
			tiltHi = BHiShelf.ar(tiltLo, 3000, 1, tilt * 6);
			left = tiltHi[0];
			right = tiltHi[1];

			// soft clamp
			left = left.clip(-1, 1);
			right = right.clip(-1, 1);

			Out.ar(out, [left, right]);
		}).add;

		server.sync;

		// ---- start effects ----
		fxSynth = Synth(\b700fx, [
			\in, fxBus,
			\out, context.out_b,
			\phaserIntensity, params[\phaserIntensity],
			\phaserRate, params[\phaserRate],
			\phaserDepth, params[\phaserDepth],
			\exciterAmount, params[\exciterAmount],
			\tilt, params[\tilt]
		], fxGroup);

		// ---- commands ----

		this.addCommand("note_on", "if", { arg msg;
			var note = msg[1].asInteger;
			var vel = msg[2].asFloat;
			var freq = note.midicps;

			// kill existing voice on same note
			if (voices[note].notNil) {
				voices[note].set(\gate, 0);
				voices[note] = nil;
			};

			voices[note] = Synth(\b700voice, [
				\out, fxBus,
				\freq, freq,
				\vel, vel,
				\gate, 1,
				\config, params[\config],
				\ratio2, params[\ratio2],
				\ratio3, params[\ratio3],
				\ratio4, params[\ratio4],
				\idx1, params[\index1] * params[\masterIndex],
				\idx2, params[\index2] * params[\masterIndex],
				\idx3, params[\index3] * params[\masterIndex],
				\idx4, params[\index4] * params[\masterIndex],
				\idx5, params[\index5] * params[\masterIndex],
				\idx6, params[\index6] * params[\masterIndex],
				\masterIdx, params[\masterIndex],
				\cutoff, params[\cutoff],
				\resonance, params[\resonance],
				\drive, params[\drive],
				\wsaBuf, wsaBufs[params[\wsaPreset].asInteger],
				\wsbBuf, wsbBufs[params[\wsbPreset].asInteger]
			], voiceGroup);
		});

		this.addCommand("note_off", "i", { arg msg;
			var note = msg[1].asInteger;
			if (voices[note].notNil) {
				voices[note].set(\gate, 0);
				voices[note] = nil;
			};
		});

		this.addCommand("config", "i", { arg msg;
			params[\config] = msg[1].asInteger.clip(0, 11);
			voices.do({ arg s; s.set(\config, params[\config]) });
		});

		this.addCommand("ratio2", "f", { arg msg;
			params[\ratio2] = msg[1].asFloat;
			voices.do({ arg s; s.set(\ratio2, params[\ratio2]) });
		});

		this.addCommand("ratio3", "f", { arg msg;
			params[\ratio3] = msg[1].asFloat;
			voices.do({ arg s; s.set(\ratio3, params[\ratio3]) });
		});

		this.addCommand("ratio4", "f", { arg msg;
			params[\ratio4] = msg[1].asFloat;
			voices.do({ arg s; s.set(\ratio4, params[\ratio4]) });
		});

		this.addCommand("index1", "f", { arg msg;
			params[\index1] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx1, params[\index1] * params[\masterIndex]) });
		});

		this.addCommand("index2", "f", { arg msg;
			params[\index2] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx2, params[\index2] * params[\masterIndex]) });
		});

		this.addCommand("index3", "f", { arg msg;
			params[\index3] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx3, params[\index3] * params[\masterIndex]) });
		});

		this.addCommand("index4", "f", { arg msg;
			params[\index4] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx4, params[\index4] * params[\masterIndex]) });
		});

		this.addCommand("index5", "f", { arg msg;
			params[\index5] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx5, params[\index5] * params[\masterIndex]) });
		});

		this.addCommand("index6", "f", { arg msg;
			params[\index6] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx6, params[\index6] * params[\masterIndex]) });
		});

		this.addCommand("master_index", "f", { arg msg;
			params[\masterIndex] = msg[1].asFloat;
			voices.do({ arg s;
				s.set(\idx1, params[\index1] * params[\masterIndex]);
				s.set(\idx2, params[\index2] * params[\masterIndex]);
				s.set(\idx3, params[\index3] * params[\masterIndex]);
				s.set(\idx4, params[\index4] * params[\masterIndex]);
				s.set(\idx5, params[\index5] * params[\masterIndex]);
				s.set(\idx6, params[\index6] * params[\masterIndex]);
			});
		});

		this.addCommand("cutoff", "f", { arg msg;
			params[\cutoff] = msg[1].asFloat;
			voices.do({ arg s; s.set(\cutoff, params[\cutoff]) });
		});

		this.addCommand("resonance", "f", { arg msg;
			params[\resonance] = msg[1].asFloat;
			voices.do({ arg s; s.set(\resonance, params[\resonance]) });
		});

		this.addCommand("drive", "f", { arg msg;
			params[\drive] = msg[1].asFloat;
			voices.do({ arg s; s.set(\drive, params[\drive]) });
		});

		this.addCommand("wsa", "i", { arg msg;
			var idx = msg[1].asInteger.clip(0, 7);
			params[\wsaPreset] = idx;
			wsaIdx = idx;
			// waveshape buffer swap requires new notes to pick up
		});

		this.addCommand("wsb", "i", { arg msg;
			var idx = msg[1].asInteger.clip(0, 7);
			params[\wsbPreset] = idx;
			wsbIdx = idx;
		});

		this.addCommand("phaser_intensity", "f", { arg msg;
			params[\phaserIntensity] = msg[1].asFloat;
			fxSynth.set(\phaserIntensity, params[\phaserIntensity]);
		});

		this.addCommand("phaser_rate", "f", { arg msg;
			params[\phaserRate] = msg[1].asFloat;
			fxSynth.set(\phaserRate, params[\phaserRate]);
		});

		this.addCommand("phaser_depth", "f", { arg msg;
			params[\phaserDepth] = msg[1].asFloat;
			fxSynth.set(\phaserDepth, params[\phaserDepth]);
		});

		this.addCommand("exciter_amount", "f", { arg msg;
			params[\exciterAmount] = msg[1].asFloat;
			fxSynth.set(\exciterAmount, params[\exciterAmount]);
		});

		this.addCommand("tilt", "f", { arg msg;
			params[\tilt] = msg[1].asFloat;
			fxSynth.set(\tilt, params[\tilt]);
		});

		this.addCommand("pan", "if", { arg msg;
			var note = msg[1].asInteger;
			var panVal = msg[2].asFloat;
			if (voices[note].notNil) {
				voices[note].set(\pan, panVal);
			};
		});
	}

	fillWaveshapePresets { arg bufs;
		var server = context.server;

		// preset 0: linear (pass-through)
		bufs[0].sine1([1.0]);

		// preset 1: soft clip (gentle saturation)
		bufs[1].cheby([1.0, 0.0, -0.1, 0.0, 0.02]);

		// preset 2: hard clip
		bufs[2].sendCollection(
			Signal.fill(1024, { |i|
				var x = (i / 512.0) - 1.0;
				x.clip(-0.6, 0.6) / 0.6
			}).asWavetable
		);

		// preset 3: wavefolder
		bufs[3].sendCollection(
			Signal.fill(1024, { |i|
				var x = (i / 512.0) - 1.0;
				(x * 2).fold(-1, 1)
			}).asWavetable
		);

		// preset 4: sine fold (Buchla-style)
		bufs[4].sendCollection(
			Signal.fill(1024, { |i|
				var x = (i / 512.0) - 1.0;
				sin(x * 2pi)
			}).asWavetable
		);

		// preset 5: asymmetric (even harmonics)
		bufs[5].cheby([0.8, 0.5, 0.0, 0.3, 0.0, 0.1]);

		// preset 6: staircase
		bufs[6].sendCollection(
			Signal.fill(1024, { |i|
				var x = (i / 512.0) - 1.0;
				(x * 6).round / 6
			}).asWavetable
		);

		// preset 7: chebyshev 3rd harmonic
		bufs[7].cheby([0.0, 0.0, 1.0]);
	}

	free {
		voices.do({ arg s; s.free });
		fxSynth.free;
		fxBus.free;
		wsaBufs.do({ arg b; b.free });
		wsbBufs.do({ arg b; b.free });
	}
}
