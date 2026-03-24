// Engine_Bucha
// Norns port of the Bucha DSP engine
// 4-voice FM + waveshaping + OTA ladder filter
// 12 FM routing topologies, aural exciter, 8-stage phase shifter
//
// Original DSP by The Contributors (GPL v3)
// Norns adaptation 2026

Engine_Bucha : CroneEngine {
	var <voices;       // Dictionary of active voice synths
	var <voiceOrder;   // Array tracking voice creation order for stealing
	var <maxVoices;    // max simultaneous voices (CPU protection)
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
		voiceOrder = List.new;
		maxVoices = 6;
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
		// This is faithful to the original Bucha which set config per-voice

		SynthDef(\b700v00, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 00: symmetric dual-path
			wsaIn = (SinOsc.ar(freq, s1*idx1) + (s3*idx2)) * idx3;
			wsbIn = (SinOsc.ar(freq*ratio3, s1*idx4) + (s3*idx5)) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v01, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 01: split modulators
			wsaIn = (SinOsc.ar(freq, s1*idx1) + (s1*idx2)) * idx3;
			wsbIn = (SinOsc.ar(freq*ratio3, s3*idx4) + (s3*idx5)) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v02, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 02: cascaded FM with feedback
			wsaIn = SinOsc.ar(freq, SinOsc.ar(freq*ratio2, s2*idx2)*idx1) * idx3;
			wsbIn = SinOsc.ar(freq*ratio3, s3*idx4) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v03, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 03: shared carrier
			wsaIn = (s3 + (SinOsc.ar(freq, s2*idx2)*idx1)) * idx3;
			wsbIn = (s3 + (SinOsc.ar(freq*ratio2, s2*idx5)*idx4)) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v04, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 04: minimal FM + direct envelope
			wsaIn = SinOsc.ar(freq, SinOsc.ar(freq*ratio2)*idx2) * idx3;
			wsbIn = DC.ar(idx6);
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v05, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 05: cross-coupled
			wsaIn = (s1 + (SinOsc.ar(freq, s3*idx2)*idx1)) * idx3;
			wsbIn = (s3 + (SinOsc.ar(freq*ratio3, s1*idx5)*idx4)) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v06, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 06: three-osc cascade
			wsaIn = SinOsc.ar(freq, (SinOsc.ar(freq*ratio2, s2*idx1)*idx2) + (s3*idx4)) * idx3;
			wsbIn = wsaIn * (idx6/idx3.max(0.001));
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v07, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 07: osc4-centric
			wsaIn = SinOsc.ar(freq, s3*idx4) * idx3;
			wsbIn = (s3 + (s3*idx5)) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v08, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 08: dual-path with feedback
			wsaIn = (SinOsc.ar(freq, SinOsc.ar(freq*ratio2)*idx2) + (s2*idx1)) * idx3;
			wsbIn = (s3 + (s0*idx5)) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v09, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 09: circular feedback (chaos)
			wsaIn = SinOsc.ar(freq, s3*idx1) * idx3;
			wsbIn = SinOsc.ar(freq*ratio3, s1*idx4) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v10, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 10: shared modulator
			wsaIn = (SinOsc.ar(freq, s1*idx2) + (s2*idx1)) * idx3;
			wsbIn = (SinOsc.ar(freq*ratio3, s1*idx5) + (s0*idx4)) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		SynthDef(\b700v11, { arg out, freq=440, vel=0.8, gate=1,
			ratio2=2.0, ratio3=3.0, ratio4=4.0,
			idx1=1.0, idx2=0.8, idx3=0.8, idx4=0.6, idx5=0.5, idx6=0.6,
			cutoff=2000, resonance=0.3, drive=0.0,
			atk=0.005, dec=0.2, sus=0.8, rel=0.3,
			noise=0.0, trem_rate=0.0, trem_depth=0.0, amp=1.0,
			sub=0.0, lfo_filter=0.0, lfo_filter_rate=2.0,
			wsaBuf, wsbBuf, pan=0;
			var s0,s1,s2,s3,wsaIn,wsbIn,wsaOut,wsbOut,mixed,filtered,sig,env,subOsc,noiseSig,tremLfo,filterLfo;
			// smooth all FM indices to prevent artifacts on parameter changes
			idx1=idx1.lag(0.05); idx2=idx2.lag(0.05); idx3=idx3.lag(0.05);
			idx4=idx4.lag(0.05); idx5=idx5.lag(0.05); idx6=idx6.lag(0.05);
			s0 = SinOsc.ar(freq); s1 = SinOsc.ar(freq*ratio2.lag(0.08));
			s2 = SinOsc.ar(freq*ratio3.lag(0.08)); s3 = SinOsc.ar(freq*ratio4.lag(0.08));
			// config 11: multi-output
			wsaIn = (SinOsc.ar(freq, SinOsc.ar(freq*ratio3)*idx5) + (s0*idx1) + (s3*idx4)) * idx3;
			wsbIn = (SinOsc.ar(freq, SinOsc.ar(freq*ratio3)*idx5) + (s1*idx2)) * idx6;
			// waveshaping: gentle softclip (no tanh — warmer)
			wsaOut = (wsaIn * 0.9).softclip;
			wsbOut = (wsbIn * 0.9).softclip;
			// sub oscillator (one octave below)
			subOsc = SinOsc.ar(freq * 0.5) * sub.lag(0.05);
			// noise layer
			noiseSig = PinkNoise.ar * noise.lag(0.05);
			// mix FM + sub + noise
			mixed = ((wsaOut + wsbOut) * 0.4 + subOsc + noiseSig);
			// frequency-tracking LPF: tames metallic partials at the SOURCE
			// higher notes get filtered more aggressively
			mixed = LPF.ar(mixed, (freq * 14).clip(1200, 18000));
			mixed = (mixed * (1 + (drive.lag(0.05) * 1.5))).softclip;
			// filter (smoothed, conservative limits)
			filterLfo = SinOsc.kr(lfo_filter_rate.lag(0.08)) * lfo_filter.lag(0.05) * cutoff.lag(0.05) * 0.4;
			filtered = MoogFF.ar(mixed, (cutoff.lag(0.05) + filterLfo).clip(30,10000), resonance.lag(0.05).clip(0,2.0));
			filtered = LeakDC.ar(filtered);
			// tremolo
			tremLfo = 1 - (SinOsc.kr(trem_rate).range(0,1) * trem_depth);
			// envelope
			env = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate, doneAction:2);
			sig = filtered * env * vel * amp.lag(0.02) * tremLfo;
			// frequency-dependent gain: tame higher notes
			sig = sig * freq.explin(1500, 8000, 1.0, 0.3);
			// anti-click: 2ms fade-in on note start
			sig = sig * EnvGen.kr(Env([0, 1], [0.002]));
			sig = Pan2.ar(sig, pan.lag(0.03));
			Out.ar(out, sig);
		}).add;

		// -- Drum SynthDefs (creative metronome) --
		// Kick: sine body + pitch sweep + click transient
		// Kick: sine body + pitch env + click + drive + filter
		SynthDef(\b700_kick, { arg out, amp=0.5, tone=0.4, decay=0.3,
			pitch=1.0, click=0.3, drive=0.5, lpf=8000;
			var body, clk, env, sig, pitchHz;
			pitchHz = 55 * pitch;
			env = EnvGen.kr(Env.perc(0.001, decay, 1, -8), doneAction: Done.freeSelf);
			body = SinOsc.ar(
				EnvGen.kr(Env([pitchHz * 2.2, pitchHz, pitchHz * 0.72],
					[0.01, decay], [-8, -4])),
				0, env
			);
			// sub harmonic for weight
			body = body + (SinOsc.ar(pitchHz * 0.5) * env * 0.3);
			clk = LPF.ar(WhiteNoise.ar(1), 1500 + (tone * 3000)) *
				EnvGen.kr(Env.perc(0.001, 0.008 + (tone * 0.01)));
			sig = body + (clk * click);
			// drive: from clean to crunchy
			sig = (sig * (1 + (drive * 4))).tanh * (1 / (1 + (drive * 1.5)));
			sig = LPF.ar(sig, lpf);
			sig = sig * amp * 0.8;
			Out.ar(out, sig ! 2);
		}).add;

		// Hat: noise source + filter + character
		SynthDef(\b700_hat, { arg out, amp=0.3, tone=0.5, decay=0.08,
			pitch=1.0, drive=0.0, lpf=16000, ring=0.0;
			var sig, env, metallic;
			env = EnvGen.kr(Env.perc(0.001, decay, 1, -12), doneAction: Done.freeSelf);
			// noise body
			sig = HPF.ar(WhiteNoise.ar(1), 3000 + (tone * 7000));
			sig = BPF.ar(sig, (6000 + (tone * 5000)) * pitch, 0.5);
			// metallic ring: pair of detuned square waves for shimmer
			metallic = Pulse.ar(6430 * pitch, 0.5, 0.2) +
				Pulse.ar(7210 * pitch, 0.5, 0.15) +
				Pulse.ar(8530 * pitch, 0.3, 0.12);
			metallic = HPF.ar(metallic, 4000);
			sig = sig + (metallic * ring);
			sig = sig * env;
			// drive
			sig = Select.ar((drive > 0.01).asInteger, [sig, (sig * (1 + (drive * 6))).tanh * 0.7]);
			sig = LPF.ar(sig, lpf);
			sig = sig * amp;
			Out.ar(out, sig ! 2);
		}).add;

		// Rim/Snare: body + noise + ring + filter
		SynthDef(\b700_rim, { arg out, amp=0.4, tone=0.5, decay=0.06,
			pitch=1.0, drive=0.0, lpf=12000, snappy=0.5;
			var sig, env, body, noise;
			env = EnvGen.kr(Env.perc(0.0005, decay, 1, -10), doneAction: Done.freeSelf);
			// tuned body
			body = SinOsc.ar(
				EnvGen.kr(Env([(800 * pitch), (400 * pitch)], [0.005], [-6])),
				0, env * 0.5
			);
			// additional ring partial
			body = body + (SinOsc.ar(580 * pitch) * env * 0.2);
			// noise burst (snare wires)
			noise = BPF.ar(WhiteNoise.ar(1), (1800 + (tone * 2000)) * pitch, 0.15) *
				EnvGen.kr(Env.perc(0.0005, 0.01 + (snappy * 0.04)));
			// noise tail (longer = more snare, shorter = more rim)
			noise = noise + (HPF.ar(WhiteNoise.ar(1), 2000) *
				EnvGen.kr(Env.perc(0.001, decay * snappy * 0.8)) * snappy * 0.3);
			sig = body + noise;
			// drive
			sig = Select.ar((drive > 0.01).asInteger, [sig, (sig * (1 + (drive * 5))).tanh * 0.7]);
			sig = LPF.ar(sig, lpf);
			sig = sig * amp;
			Out.ar(out, sig ! 2);
		}).add;

		// -- Effects chain --
		SynthDef(\b700fx, { arg in, out,
			phaserIntensity=0.0, phaserRate=1.0, phaserDepth=0.5,
			exciterAmount=0.3, tilt=0.0,
			delayTime=0.3, delayFeedback=0.4, delayMix=0.0,
			reverbSize=0.6, reverbDamp=0.5, reverbMix=0.0,
			chorusRate=0.5, chorusMix=0.0,
			audioIn=0.0;

			var sig, left, right;
			var lhf, rhf, lHarm, rHarm, lExc, rExc;
			var lfo, lfoSoft, lfoTri, lfoBlend;
			var allpassFreqs, apL, apR;
			var delL, delR, revSig, chorusL, chorusR;
			var excAmt;
			// multiband compressor vars
			var mbLoL, mbLoR, mbMidL, mbMidR, mbHiL, mbHiR;

			sig = In.ar(in, 2);
			// mix in external audio input
			sig = sig + (SoundIn.ar([0,1]) * audioIn.lag(0.1));
			left = sig[0];
			right = sig[1];

			// ---- HF ROLLOFF ----
			left = LPF.ar(left, 11000);
			right = LPF.ar(right, 11000);

			// ---- MULTIBAND DYNAMICS (the key to taming FM) ----
			// Split into 3 bands: low (<800), mid (800-4k), high (>4k)
			// Compress the mid+high bands to tame metallic bells

			// LOW: untouched (warmth, body)
			mbLoL = LPF.ar(left, 800);
			mbLoR = LPF.ar(right, 800);

			// MID (800-4kHz): the metallic bell zone — compress it
			mbMidL = BPF.ar(left, 2000, 1.2);
			mbMidR = BPF.ar(right, 2000, 1.2);
			mbMidL = Compander.ar(mbMidL, mbMidL, 0.15, 1, 0.4, 0.003, 0.06);
			mbMidR = Compander.ar(mbMidR, mbMidR, 0.15, 1, 0.4, 0.003, 0.06);

			// HIGH (>4kHz): presence/air — compress harder
			mbHiL = HPF.ar(left, 4000);
			mbHiR = HPF.ar(right, 4000);
			mbHiL = Compander.ar(mbHiL, mbHiL, 0.1, 1, 0.3, 0.002, 0.04);
			mbHiR = Compander.ar(mbHiR, mbHiR, 0.1, 1, 0.3, 0.002, 0.04);

			// Recombine bands
			left = mbLoL + mbMidL + mbHiL;
			right = mbLoR + mbMidR + mbHiR;

			// ---- AURAL EXCITER (subtle) ----
			excAmt = exciterAmount.lag(0.1) * 0.4;
			lhf = BPF.ar(left, 4000, 0.8);
			rhf = BPF.ar(right, 4000, 0.8);
			lHarm = (lhf * lhf * lhf.sign).softclip;
			rHarm = (rhf * rhf * rhf.sign).softclip;
			left = left + (lHarm * excAmt);
			right = right + (rHarm * excAmt);
			left = left.softclip;
			right = right.softclip;

			// ---- 8-STAGE PHASE SHIFTER ----
			lfo = SinOsc.kr(phaserRate.lag(0.05));
			lfoSoft = lfo * (1.5 - (0.5 * lfo * lfo));
			lfoTri = LFTri.kr(phaserRate.lag(0.05));
			lfoBlend = (lfoSoft * 0.7) + (lfoTri * 0.3);

			apL = left;
			apR = right;
			[400, 600, 900, 1300, 1800, 2400, 3100, 3900].do { |baseFreq, i|
				var modAmt = lfoBlend * phaserDepth.lag(0.05) * 0.3 * phaserIntensity.lag(0.05);
				var delayL = (1.0 / (baseFreq * (1 + modAmt))).clip(0.00002, 0.01);
				var delayR = (1.0 / (baseFreq * 0.85 * (1 + modAmt))).clip(0.00002, 0.01);
				apL = AllpassC.ar(apL, 0.01, delayL, 0.0);
				apR = AllpassC.ar(apR, 0.01, delayR, 0.0);
			};

			left = (apL * 0.8 * phaserIntensity.lag(0.05)) + (left * (1 - (phaserIntensity.lag(0.05) * 0.8)));
			right = (apR * 0.8 * phaserIntensity.lag(0.05)) + (right * (1 - (phaserIntensity.lag(0.05) * 0.8)));

			// ---- TILT EQ ----
			left = BLowShelf.ar(left, 300, 1, tilt.lag(0.05).neg * 6);
			left = BHiShelf.ar(left, 3000, 1, tilt.lag(0.05) * 5);
			right = BLowShelf.ar(right, 300, 1, tilt.lag(0.05).neg * 6);
			right = BHiShelf.ar(right, 3000, 1, tilt.lag(0.05) * 5);

			// ---- STEREO DELAY ----
			delL = CombC.ar(left, 1.0, delayTime.lag(0.05).clip(0.01, 1.0), delayFeedback.lag(0.03).clip(0, 0.8) * 2.5);
			delR = CombC.ar(right, 1.0, (delayTime.lag(0.05) * 0.75).clip(0.01, 1.0), delayFeedback.lag(0.03).clip(0, 0.8) * 2.5);
			// filter the delay returns to prevent metallic buildup
			delL = LPF.ar(delL, 6000);
			delR = LPF.ar(delR, 6000);
			left = left + (delL * delayMix.lag(0.03));
			right = right + (delR * delayMix.lag(0.03));

			// ---- CHORUS ----
			chorusL = DelayC.ar(left, 0.05,
				SinOsc.kr(chorusRate.lag(0.1), 0).range(0.005, 0.02));
			chorusR = DelayC.ar(right, 0.05,
				SinOsc.kr(chorusRate.lag(0.1) * 1.1, 0.5pi).range(0.005, 0.02));
			left = left + (chorusL * chorusMix.lag(0.03));
			right = right + (chorusR * chorusMix.lag(0.03));

			// ---- REVERB ----
			revSig = FreeVerb2.ar(left, right, reverbMix.lag(0.05), reverbSize.lag(0.05), reverbDamp.lag(0.05));
			left = revSig[0];
			right = revSig[1];

			// ---- FINAL: soft saturation + brick wall ----
			left = (left * 0.9).softclip;
			right = (right * 0.9).softclip;
			sig = Limiter.ar([left, right], 0.85, 0.04);

			Out.ar(out, sig);
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

			// kill existing voice on same note (quick fade to avoid click)
			if (voices[note].notNil) {
				var old = voices[note];
				old.set(\gate, 0, \rel, 0.008);
				voices[note] = nil;
				voiceOrder.remove(note);
			};

			// voice stealing: if at max, kill oldest voice
			while ({voices.size >= maxVoices}, {
				var oldest = voiceOrder.removeAt(0);
				if (oldest.notNil and: {voices[oldest].notNil}) {
					voices[oldest].set(\gate, 0, \rel, 0.008);
					voices[oldest] = nil;
				};
			});

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
				\idx1, (params[\index1] * params[\masterIndex]).clip(0, 1.8),
				\idx2, (params[\index2] * params[\masterIndex]).clip(0, 1.8),
				\idx3, (params[\index3] * params[\masterIndex]).clip(0, 1.8),
				\idx4, (params[\index4] * params[\masterIndex]).clip(0, 1.8),
				\idx5, (params[\index5] * params[\masterIndex]).clip(0, 1.8),
				\idx6, (params[\index6] * params[\masterIndex]).clip(0, 1.8),
				\cutoff, params[\cutoff],
				\resonance, params[\resonance],
				\drive, params[\drive],
				\atk, params[\atk] ? 0.005,
				\dec, params[\dec] ? 0.2,
				\sus, params[\sus] ? 0.8,
				\rel, params[\rel] ? 0.3,
				\noise, params[\noise] ? 0.0,
				\sub, params[\sub] ? 0.0,
				\trem_rate, params[\tremRate] ? 0.0,
				\trem_depth, params[\tremDepth] ? 0.0,
				\lfo_filter, params[\lfoFilter] ? 0.0,
				\lfo_filter_rate, params[\lfoFilterRate] ? 2.0,
				\amp, params[\amp] ? 1.0,
				\wsaBuf, wsaBufs[params[\wsaPreset].asInteger],
				\wsbBuf, wsbBufs[params[\wsbPreset].asInteger]
			], voiceGroup);

			voiceOrder.add(note);
		});

		this.addCommand("note_off", "i", { arg msg;
			var note = msg[1].asInteger;
			if (voices[note].notNil) {
				voices[note].set(\gate, 0);
				voices[note] = nil;
				voiceOrder.remove(note);
			};
		});

		this.addCommand("max_voices", "i", { arg msg;
			maxVoices = msg[1].asInteger.clip(2, 12);
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
			voices.do({ arg s; s.set(\idx1, (params[\index1] * params[\masterIndex]).clip(0, 1.8)) });
		});

		this.addCommand("index2", "f", { arg msg;
			params[\index2] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx2, (params[\index2] * params[\masterIndex]).clip(0, 1.8)) });
		});

		this.addCommand("index3", "f", { arg msg;
			params[\index3] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx3, (params[\index3] * params[\masterIndex]).clip(0, 1.8)) });
		});

		this.addCommand("index4", "f", { arg msg;
			params[\index4] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx4, (params[\index4] * params[\masterIndex]).clip(0, 1.8)) });
		});

		this.addCommand("index5", "f", { arg msg;
			params[\index5] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx5, (params[\index5] * params[\masterIndex]).clip(0, 1.8)) });
		});

		this.addCommand("index6", "f", { arg msg;
			params[\index6] = msg[1].asFloat;
			voices.do({ arg s; s.set(\idx6, (params[\index6] * params[\masterIndex]).clip(0, 1.8)) });
		});

		this.addCommand("master_index", "f", { arg msg;
			params[\masterIndex] = msg[1].asFloat;
			voices.do({ arg s;
				s.set(\idx1, (params[\index1] * params[\masterIndex]).clip(0, 1.8));
				s.set(\idx2, (params[\index2] * params[\masterIndex]).clip(0, 1.8));
				s.set(\idx3, (params[\index3] * params[\masterIndex]).clip(0, 1.8));
				s.set(\idx4, (params[\index4] * params[\masterIndex]).clip(0, 1.8));
				s.set(\idx5, (params[\index5] * params[\masterIndex]).clip(0, 1.8));
				s.set(\idx6, (params[\index6] * params[\masterIndex]).clip(0, 1.8));
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

		// ---- voice shaping commands ----
		this.addCommand("attack", "f", { arg msg;
			params[\atk] = msg[1].asFloat;
			voices.do({ arg s; s.set(\atk, params[\atk]) });
		});
		this.addCommand("decay", "f", { arg msg;
			params[\dec] = msg[1].asFloat;
			voices.do({ arg s; s.set(\dec, params[\dec]) });
		});
		this.addCommand("sustain", "f", { arg msg;
			params[\sus] = msg[1].asFloat;
			voices.do({ arg s; s.set(\sus, params[\sus]) });
		});
		this.addCommand("release", "f", { arg msg;
			params[\rel] = msg[1].asFloat;
			voices.do({ arg s; s.set(\rel, params[\rel]) });
		});
		this.addCommand("noise", "f", { arg msg;
			params[\noise] = msg[1].asFloat;
			voices.do({ arg s; s.set(\noise, params[\noise]) });
		});
		this.addCommand("sub", "f", { arg msg;
			params[\sub] = msg[1].asFloat;
			voices.do({ arg s; s.set(\sub, params[\sub]) });
		});
		this.addCommand("trem_rate", "f", { arg msg;
			params[\tremRate] = msg[1].asFloat;
			voices.do({ arg s; s.set(\trem_rate, params[\tremRate]) });
		});
		this.addCommand("trem_depth", "f", { arg msg;
			params[\tremDepth] = msg[1].asFloat;
			voices.do({ arg s; s.set(\trem_depth, params[\tremDepth]) });
		});
		this.addCommand("lfo_filter", "f", { arg msg;
			params[\lfoFilter] = msg[1].asFloat;
			voices.do({ arg s; s.set(\lfo_filter, params[\lfoFilter]) });
		});
		this.addCommand("lfo_filter_rate", "f", { arg msg;
			params[\lfoFilterRate] = msg[1].asFloat;
			voices.do({ arg s; s.set(\lfo_filter_rate, params[\lfoFilterRate]) });
		});
		this.addCommand("amp", "f", { arg msg;
			params[\amp] = msg[1].asFloat;
			voices.do({ arg s; s.set(\amp, params[\amp]) });
		});

		// ---- FX commands ----
		this.addCommand("delay_time", "f", { arg msg;
			fxSynth.set(\delayTime, msg[1].asFloat);
		});
		this.addCommand("delay_feedback", "f", { arg msg;
			fxSynth.set(\delayFeedback, msg[1].asFloat);
		});
		this.addCommand("delay_mix", "f", { arg msg;
			fxSynth.set(\delayMix, msg[1].asFloat);
		});
		this.addCommand("reverb_size", "f", { arg msg;
			fxSynth.set(\reverbSize, msg[1].asFloat);
		});
		this.addCommand("reverb_damp", "f", { arg msg;
			fxSynth.set(\reverbDamp, msg[1].asFloat);
		});
		this.addCommand("reverb_mix", "f", { arg msg;
			fxSynth.set(\reverbMix, msg[1].asFloat);
		});
		this.addCommand("chorus_rate", "f", { arg msg;
			fxSynth.set(\chorusRate, msg[1].asFloat);
		});
		this.addCommand("chorus_mix", "f", { arg msg;
			fxSynth.set(\chorusMix, msg[1].asFloat);
		});
		this.addCommand("audio_in", "f", { arg msg;
			fxSynth.set(\audioIn, msg[1].asFloat);
		});

		// ---- drum commands (creative metronome) ----
		// each takes: amp, tone, pitch, decay, drive, lpf, extra
		this.addCommand("drum_kick", "fffffff", { arg msg;
			Synth(\b700_kick, [
				\out, context.out_b,
				\amp, msg[1].asFloat,
				\tone, msg[2].asFloat,
				\pitch, msg[3].asFloat,
				\decay, msg[4].asFloat,
				\drive, msg[5].asFloat,
				\lpf, msg[6].asFloat,
				\click, msg[7].asFloat
			], voiceGroup);
		});
		this.addCommand("drum_hat", "fffffff", { arg msg;
			Synth(\b700_hat, [
				\out, context.out_b,
				\amp, msg[1].asFloat,
				\tone, msg[2].asFloat,
				\pitch, msg[3].asFloat,
				\decay, msg[4].asFloat,
				\drive, msg[5].asFloat,
				\lpf, msg[6].asFloat,
				\ring, msg[7].asFloat
			], voiceGroup);
		});
		this.addCommand("drum_rim", "fffffff", { arg msg;
			Synth(\b700_rim, [
				\out, context.out_b,
				\amp, msg[1].asFloat,
				\tone, msg[2].asFloat,
				\pitch, msg[3].asFloat,
				\decay, msg[4].asFloat,
				\drive, msg[5].asFloat,
				\lpf, msg[6].asFloat,
				\snappy, msg[7].asFloat
			], voiceGroup);
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
