s.quit;
(

//ServerOptions.devices;
//Server.default.options.inDevice_("H5"); // stereo input
//Server.default.options.inDevice_("H6"); // stereo input, check that this is the right name
//Server.default.options.inDevice_("MacBook Pro Microphone"); // mono input
//Server.default.options.outDevice_("External Headphones");
//Server.default.options.outDevice_("Scarlett 2i2 USB");
o = Server.default.options;
o.numInputBusChannels = 4;
o.numOutputBusChannels = 4;
//o.numOutputBusChannels;
o.sampleRate_(48000);
o.inDevice_("Scarlett 18i20 USB");
//o.inDevice_("Scarlett 2i2 USB");
//o.inDevice_("Soundflower (2ch)");
//o.outDevice_("External Headphones");
//o.outDevice_("Soundflower (2ch)");
o.outDevice_("Scarlett 18i20 USB");

Server.default.options.sampleRate_(48000);

s.waitForBoot( { // boot server
	// ADD SYNTHS TO SERVER
	s.freeAll;
	// Mic Synth for input only
	SynthDef.new( \micIn, {
		arg in1=0, in2=0, inputGain=1.0, out1=0, out2=0;
		var sig, out;
		sig = SoundIn.ar([in1, in2], inputGain);
		//sig = Mix.new(sig);
		out = Out.ar([out1, out2], sig);
	}).add;

	// sine bank synth
	SynthDef.new(\sinBank8, {
		arg iphase=0, width=0.5, pulse=0, pan=0, out=0;
		var size=8, env, sig, freqs, amps, phases;

		freqs = Array.fill(size, { 440 } );
		amps = Array.fill(size, { 1/size } );
		phases = Array.fill(size, { arg i; i.mod(2pi) } );
		// amp env
		env = EnvGen.kr( Env.new(
			[0, 1.0, 1.0, 0], // levels
			[\attack.kr(0.1), \sus.kr(1.0), \release.kr(5.0)], // times
			[5, 0, -5] // curves
		), \gate.tr(0)
		);

		// signal
		sig = DynKlang.ar( `[ \freqs.kr(freqs), \amps.kr(amps), \phases.kr(phases) ] );
		// EQ
		//sig = BLowShelf.ar(sig, 100, 1.0, 3);
		//sig = BHiShelf.ar(sig, 200, rs: 0.5, db: -2);
		//sig = BHiShelf.ar(sig, 300, rs: 0.1, db: -2);
		//sig = BHiShelf.ar(sig, 400, rs: 0.1, db: -1);
		sig = BHiShelf.ar(sig, 600, rs: 0.2, db: -3); // TRY?????
		sig = sig * env;
		//sig = Pan2.ar(sig, pan, \amp.kr(0.1)) * env;
		Out.ar(out, sig);
	}).add;

	s.sync;
	// allocate bus and instance of mic synth and sine synth
	~micBus1 = Bus.audio(s, 1);
	~micBus2 = Bus.audio(s, 1);
	~micIn = Synth.new(\micIn, [\in1, 2, \in2, 3, \out1, ~micBus1, \out2, ~micBus2]); //stereo input  RECORD THROUGH HC INPUTS (3+4)
	//~micIn = Synth.new(\micIn, [\in1, 0, \in2, 0, \out1, ~micBus1, \out2, ~micBus2]); // mono input
	~micBus1.scope;
	~micBus2.scope;
	~sines1 = Synth.new(\sinBank8, [\out, 0]); // OUTPUT THROUGH RESERVOIRS SPEAKERS (1+2)
	~sines2 = Synth.new(\sinBank8, [\out, 1]);
});
)