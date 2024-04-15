(
// Mic Synth
SynthDef.new( \micIn, {
	arg in=0, inputGain=1.0, out=0;
	var sig;
	sig = SoundIn.ar(in, inputGain);
	out = Out.ar(out, sig);
}).add;
)
b = Bus.audio(s, 1);
x = Synth.new(\micIn, [\out, b]);

b.scope;
(
var p, l, cwd, pyFile;
cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
pyFile = cwd ++ "scPipe.py";

p = Pipe.new("python3", pyFile,"r");
l = p.getLine;
while( {l.notNil}, {l.postln; l = p.getLine; });
p.close;
)
b.server;

~someString = "python3 simpleString.py".runInTerminal;

(
Task{
	"STARTING".postln;
	5.wait;
}.start;
"DONE".postln;
)

"cd Users; pwd".unixCmd;
"pwd".unixCmd;

"ls".unixCmdGetStdOut;

(
// runs python program and puts stdout into an array
var p, l, cwd, pyFile, command;
cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
pyFile = cwd ++ "analyzeSample.py";


//pyFile = cwd ++ "scPipe.py";
//pyFile = cwd ++ "simpleString.py";
//("python3" + pyFile).runInTerminal;

p = Pipe.argv(["python3", pyFile], "r");
//p = Pipe.new(("python3" + pyFile), "r");
//p = Pipe.callSync("python3" + pyFile, {"SUCCESS".postln;}, {"FAILURE".postln;});
//~myList = Array.new(20);
//p.isOpen.postln;
l = p.getLine(maxSize: 44100);
l.postln;
while(
	{l.notNil},
	{
		"NEW LINE".postln;
		l.postln;
		//~myList.add(l);
		l = p.getLine; }
);
p.close;
~myList.postln;
)

p.getLine;
p.close;

~myList.postln;

(
Routine.new( {
	"START".postln;
	1.wait;
	"HEY".postln;
}).play;
)

(
~getPeaks = {
	// run python program analyzeSample.py and return array of peakFreq tuples ([amp, freq]...)
	var p, l, cwd, pyFile="analyzeSample.py", wavFile="temp.wav", totalPeaks=8;
	cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
	p = Pipe.argv(["python3", pyFile, wavFile, totalPeaks], "r");
	~myData = Array.new(8); // rename this
	l = p.getLine;
	while(
		{l.notNil},
		{~myList.add(l); l = p.getLine; });
	p.close;
}
)

~getPeaks.();

(
var cwd, tempWav;

cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
tempWav = cwd ++ "temp.wav";
r = Recorder(s);
r.recHeaderFormat_('wav');
r.recSampleFormat_("int16");
//~sig = { SoundIn.ar(0) }.play;

Task{
	5.do{
		r.record(tempWav, b, numChannels:1);
		// record for 2 seconds
		2.wait;
		r.stopRecording;
		//~getPeaks.();
		//~myData.postln;

		8.wait;
		// wait 9 seconds before recording next sample
	};
}.start;
)
