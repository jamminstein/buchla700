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
		// Use SinOsc directly for FM — avoids Select.ar rate issues
		// Config selects topology at note-on time (not modulatable per-sample)
		// This is faithful to the original Buchla 700 which set config per-voice

		SynthDef(\b700v00, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 00: symmetric dual-path
			wsaIn = (SinOsc.ar(freq, s1*idx1) + (s3*idx2)) * idx3;
			wsbIn = (SinOsc.ar(freq*ratio3, s1*idx4) + (s3*idx5)) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v01, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 01: split modulators
			wsaIn = (SinOsc.ar(freq, s1*idx1) + (s1*idx2)) * idx3;
			wsbIn = (SinOsc.ar(freq*ratio3, s3*idx4) + (s3*idx5)) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v02, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 02: cascaded FM with feedback
			wsaIn = SinOsc.ar(freq, SinOsc.ar(freq*ratio2, s2*idx2)*idx1) * idx3;
			wsbIn = SinOsc.ar(freq*ratio3, s3*idx4) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v03, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 03: shared carrier
			wsaIn = (s3 + (SinOsc.ar(freq, s2*idx2)*idx1)) * idx3;
			wsbIn = (s3 + (SinOsc.ar(freq*ratio2, s2*idx5)*idx4)) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v04, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 04: minimal FM + direct envelope
			wsaIn = SinOsc.ar(freq, SinOsc.ar(freq*ratio2)*idx2) * idx3;
			wsbIn = DC.ar(idx6);
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v05, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 05: cross-coupled
			wsaIn = (s1 + (SinOsc.ar(freq, s3*idx2)*idx1)) * idx3;
			wsbIn = (s3 + (SinOsc.ar(freq*ratio3, s1*idx5)*idx4)) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v06, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 06: three-osc cascade
			wsaIn = SinOsc.ar(freq, (SinOsc.ar(freq*ratio2, s2*idx1)*idx2) + (s3*idx4)) * idx3;
			wsbIn = wsaIn * (idx6/idx3.max(0.001));
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v07, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 07: osc4-centric
			wsaIn = SinOsc.ar(freq, s3*idx4) * idx3;
			wsbIn = (s3 + (s3*idx5)) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v08, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 08: dual-path with feedback
			wsaIn = (SinOsc.ar(freq, SinOsc.ar(freq*ratio2)*idx2) + (s2*idx1)) * idx3;
			wsbIn = (s3 + (s0*idx5)) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v09, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 09: circular feedback (chaos)
			wsaIn = SinOsc.ar(freq, s3*idx1) * idx3;
			wsbIn = SinOsc.ar(freq*ratio3, s1*idx4) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v10, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 10: shared modulator
			wsaIn = (SinOsc.ar(freq, s1*idx2) + (s2*idx1)) * idx3;
			wsbIn = (SinOsc.ar(freq*ratio3, s1*idx5) + (s0*idx4)) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v11, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=0.5, idx2=0.3, idx3=0.2, idx4=0.1, idx5=0.1, idx6=0.1,
			cutoff=2000, resonance=0.3, drive=0.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env;
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2);
			s2 = SinOsc.ar(freq*ratio3); s3 = SinOsc.ar(freq*ratio4);
			// config 11: multi-output
			wsaIn = (SinOsc.ar(freq, SinOsc.ar(freq*ratio3)*idx5) + (s0*idx1) + (s3*idx4)) * idx3;
			wsbIn = (SinOsc.ar(freq, SinOsc.ar(freq*ratio3)*idx5) + (s1*idx2)) * idx6;
			wsaOut = Shaper.ar(wsaBuf, wsaIn.clip(-1,1));
			wsbOut = Shaper.ar(wsbBuf, wsbIn.clip(-1,1));
			mixed = ((wsaOut + wsbOut) * 0.2 * (1+(drive*4))).tanh;
			filtered = MoogFF.ar(mixed, cutoff.clip(20,18000), resonance.clip(0,3.5));
			filtered = LeakDC.ar(filtered);
			env = EnvGen.kr(Env.adsr(0.005,0.2,0.8,0.3), gate, doneAction:2);
			sig = Pan2.ar(filtered * env * vel, pan);
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

			// 8 cascaded allpass stages with fixed base frequencies
			// modulated by LFO for phasing effect
			apL = left;
			apR = right;
			[400, 600, 900, 1300, 1800, 2400, 3100, 3900].do { |baseFreq, i|
				var modAmt = lfoBlend * phaserDepth * 0.3 * phaserIntensity;
				var delayL = (1.0 / (baseFreq * (1 + modAmt))).clip(0.00002, 0.01);
				var delayR = (1.0 / (baseFreq * 0.85 * (1 + modAmt))).clip(0.00002, 0.01);
				apL = AllpassL.ar(apL, 0.01, delayL, 0.0);
				apR = AllpassL.ar(apR, 0.01, delayR, 0.0);
			};

			// mix: shifted + dry, scaled by intensity
			left = (apL * 0.8 * phaserIntensity) + (left * (1 - (phaserIntensity * 0.8)));
			right = (apR * 0.8 * phaserIntensity) + (right * (1 - (phaserIntensity * 0.8)));

			// ---- TILT EQ ----
			// tilt < 0 = dark (boost low, cut high)
			// tilt > 0 = bright (cut low, boost high)
			left = BLowShelf.ar(left, 300, 1, tilt.neg * 6);
			left = BHiShelf.ar(left, 3000, 1, tilt * 6);
			right = BLowShelf.ar(right, 300, 1, tilt.neg * 6);
			right = BHiShelf.ar(right, 3000, 1, tilt * 6);

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
			var synthName;

			// kill existing voice on same note
			if (voices[note].notNil) {
				voices[note].set(\gate, 0);
				voices[note] = nil;
			};

			// select SynthDef by config (b700v00 through b700v11)
			synthName = [\b700v00, \b700v01, \b700v02, \b700v03,
				\b700v04, \b700v05, \b700v06, \b700v07,
				\b700v08, \b700v09, \b700v10, \b700v11
			][params[\config].asInteger.clip(0,11)];

			voices[note] = Synth(synthName, [
				\out, fxBus,
				\freq, freq,
				\vel, vel,
				\gate, 1,
				\ratio2, params[\ratio2],
				\ratio3, params[\ratio3],
				\ratio4, params[\ratio4],
				\idx1, params[\index1] * params[\masterIndex],
				\idx2, params[\index2] * params[\masterIndex],
				\idx3, params[\index3] * params[\masterIndex],
				\idx4, params[\index4] * params[\masterIndex],
				\idx5, params[\index5] * params[\masterIndex],
				\idx6, params[\index6] * params[\masterIndex],
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
			// topology is set per-note (different SynthDef per config)
			// existing voices keep their topology until note-off
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
		// all use cheby() which handles wavetable format correctly

		// preset 0: linear (pass-through) — 1st chebyshev = identity
		bufs[0].cheby([1.0]);

		// preset 1: soft clip — mild odd harmonics
		bufs[1].cheby([1.0, 0.0, -0.1, 0.0, 0.02]);

		// preset 2: hard clip — strong odd harmonics (square-ish)
		bufs[2].cheby([1.0, 0.0, 0.33, 0.0, 0.2, 0.0, 0.14, 0.0, 0.1]);

		// preset 3: wavefolder — alternating sign chebyshevs
		bufs[3].cheby([0.5, 0.0, 0.8, 0.0, -0.5, 0.0, 0.3, 0.0, -0.2]);

		// preset 4: sine fold (Buchla-style) — strong 3rd+5th
		bufs[4].cheby([0.3, 0.0, 1.0, 0.0, 0.6, 0.0, 0.3]);

		// preset 5: asymmetric (even harmonics)
		bufs[5].cheby([0.8, 0.5, 0.0, 0.3, 0.0, 0.1]);

		// preset 6: staircase — many harmonics, quantized feel
		bufs[6].cheby([1.0, 0.0, 0.5, 0.0, 0.33, 0.0, 0.25, 0.0, 0.2, 0.0, 0.16, 0.0, 0.14]);

		// preset 7: chebyshev 3rd harmonic emphasis
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
