(
SynthDef.new(\sinBank8, {
	arg iphase=0, width=0.5, pulse=0;
	var size=8, env, sig, freqs, amps, phases, time=0.05;
	freqs = Array.fill(size, { 440 } );
	amps = Array.fill(size, { 1/size } );
	phases = Array.fill(size, { arg i; i.mod(2pi) } );
	// amp env
	env = EnvGen.kr( Env.asr(0.01, 1.0, 0.01), \gate.kr(0));
	// signal
	sig = DynKlang.ar( `[ \freqs.kr(freqs), \amps.kr(amps), \phases.kr(phases) ] );
	// EQ
	//sig = BLowShelf.ar(sig, 100, 1.0, 3);
	//sig = BHiShelf.ar(sig, 200, rs: 0.5, db: -2);
	//sig = BHiShelf.ar(sig, 300, rs: 0.1, db: -2);
	//sig = BHiShelf.ar(sig, 400, rs: 0.1, db: -1);
	//sig = BHiShelf.ar(sig, 600, rs: 0.2, db: -3);

	sig = Pan2.ar(sig, \pan.kr(0), \amp.kr(0.1)) * env;
	Out.ar(\out.kr(0), sig);
}).add;
)

x = Synth.new(\sinBank8, [\gate, 1]);
a = Array.fill(8, {arg i; (i+1.0) * 100;});
b = Array.fill(8, {0.11});

x.set(\freqs, a);
x.set(\amps, b);
x.set(\gate, 1);
x.set(\gate, 0);
x.free;

(
~makeLocalHost = {
	arg hostname = "127.0.0.1", port=10000;
	var host;
	host = NetAddr.new( hostname, port);
	host;

};
)
(
OSCdef.freeAll;
OSCdef.new(
	\recvFreqs,
	// function to be evaluated upon receiving qualifying OSC message
	{
		arg msg, time, addr, port; // these are the messages passed on
		var rawRcvd, amps, freqs;
		[msg, time, addr, port].postln; // action to be executed
		msg.removeAt(0);
		// make separate lists for amp vals and freq vals
		amps = Array.new(msg.size/2);
		freqs = Array.new(msg.size/2);
		// separate msg into the two lists
		msg.do( {
			arg val, i;
			[val, i].postln;
			if( i % 2 == 0, { amps.add(val) }, { freqs.add(val) });
		});
		amps = amps.normalizeSum();

		// SO AT THIS POINT I HAVE THE TWO LISTS THAT I NEED
		// NOW THEY NEED TO BE SENT TO A SYNTH



		["RECEIVED", msg.size].postln;
		amps.postln;
		freqs.postln;
		amps.sum.postln;
	},
	'/freqs',
	recvPort: 10001
);
)
4 % 2;
3 % 2;
a = [56, 23, 456, 243, 345];
a.collect( {arg val, i; val.postln; i.postln;});

~localHost.sendMsg('/ping');
~localHost.sendMsg('/shutdown');

~localHost = ~makeLocalHost.();
// start up python server
(
var cwd, pyFile="analyzeSample.py", command;
cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
pyFile = cwd ++ pyFile;
command = "python3" + pyFile;
command.runInTerminal;
//command = "python3" + cwd ++ "../library/thinkdsp.py";
//command.runInTerminal;
)



(
// Mic Synth
SynthDef.new( \micIn, {
	arg in=0, inputGain=1.0, out=0;
	var sig;
	sig = SoundIn.ar(in, inputGain);
	out = Out.ar(out, sig);
}).add;
)

// allocate bus and instance of mic synth
b = Bus.audio(s, 1);
x = Synth.new(\micIn, [\out, b]);
b.scope;
// functions
(
~getPeaks = {
	// run python program analyzeSample.py and return array of peakFreq tuples ([amp, freq]...)
	var p, l, cwd, pyFile="analyzeSample.py", wavFile="temp.wav", totalPeaks=8, returnList;
	cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
	pyFile = cwd ++ pyFile;
	wavFile = cwd ++ wavFile;
	pyFile.postln;
	wavFile.postln;
	["python3", pyFile, wavFile, totalPeaks].postln;
	p = Pipe.argv(["python3", pyFile, wavFile, totalPeaks.asString], "r");
	//p = Pipe.new("python3 analyzeSample.py temp.wav 8", "r");
	returnList = Array.new(8); // rename this
	l = p.getLine;
	while(
		{ l.notNil },
		{
			["GETTING:", l].postln;
			returnList.add(l);
			l = p.getLine;

	});
	p.close;
	returnList.postln;
	returnList;
}
)


(
// MAIN
var cwd, tempWav, sampleDur=2.0, recBufTime=1.0, pingBufTime=1.0, cycleRemainder, cycleDur=10, totalCycles=100;

cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
tempWav = cwd ++ "temp.wav";
r = Recorder(s);
r.recHeaderFormat_('wav');
r.recSampleFormat_("int16");
//~sig = { SoundIn.ar(0) }.play;

t = TempoClock.new();


Task{
	totalCycles.do{
		var freqs;
		// 1. START RECORDING
		r.record(tempWav, b, numChannels:1); // record for sampleDur seconds
		sampleDur.do{ format("RECORDING, TIME:\t\t\t\t %", t.beats).postln; 1.wait};
		// 2. STOP RECORDING
		r.stopRecording;
		recBufTime.do{ format("STOPPED RECORDING, TIME:\t\t %", t.beats).postln; 1.wait};
		// 3. PING PYTHON PROGRAM FOR FREQS
		freqs = ~getPeaks.();
		//freqs.postln;
		pingBufTime.do{ format("GETTING SAMPLE FREQS, TIME:\t\t %", t.beats).postln; 1.wait}; // is this necessary?
		// 4. UPDATE SYNTH
		cycleRemainder = cycleDur - sampleDur - recBufTime - pingBufTime;
		cycleRemainder.do{ format("UPDATING SYNTH, TIME:\t\t\t %", t.beats).postln; 1.wait};

	};
}.start;
)
