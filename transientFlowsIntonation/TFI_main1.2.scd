/*
a template for live intonation pieces.
runs with python server analyzeSample.py with Allen Downey's thinkdsp modules.
it's essentially just a pitch tracker for now without further spectral processing.
--john eagle, august 2022

TO RUN: add code blocks 1-4, then run analyzeSample.py from terminal (5), serverMaster.ck from terminal on each pi (6), then run code block 7
*/

// 1. LOAD FUNCTIONS (functions.scd)


// 2. GET DURATIONS FROM PYTHON SCRIPT form_functions.py
(
var p, l, cwd, pyFile, numSections=20, duration=9.5, power=0.6;  // ADJUST VARS HERE FOR FORM
//var p, l, cwd, pyFile, numSections=10, duration=1, power=0.6; // for testing

cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
pyFile = cwd ++ "form_functions.py";
p = Pipe.argv(["python3", pyFile, numSections.asString, duration.asString, power.asString], "r");
~sections = p.getLine;
p.close;
~sections = ~sections.interpret;
~fills = Array.fill(~sections.size, { arg i; (i+1)/~sections.size});
~fills = ~fills.normalize(0.5, 1.0);
// make the last 5 fills full
5.do( {
	arg i; // 0 1 2 3 4
	i = i + 1; // 1 2 3 4 5
	i = ~fills.size - i;
	~fills[i] = 1.0;
});
)

// 3. SET UP SOUND STUFF
// run soundServer.scd
s.quit;

// 4. SET UP OSC STUFF
// run oscDefs.scd

// 5. START PYTHON SERVER IN TERMINAL TFI_analyzeSample.py

// 6. START PI SERVERS IN TERMINAL serverMaster.ck

// 7. START UP PIs: sensorSender.ck and stdSynth.ck
// run each block in piStartup.scd, one at a time

~sections;

// 8. START PROGRAM
(
// MAIN
var cwd, tempWav1, tempWav2, r1, r2, r3, sampleDur=2.0, recBufTime=1.0, pingBufTime=1.0, cycleRemainder, totalFreqs=8;




// ----------------------------------------------------------------------------

cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
tempWav1 = cwd ++ "temp1.wav";
tempWav2 = cwd ++ "temp2.wav";
r1 = Recorder(s);
r1.recHeaderFormat_('wav');
r1.recSampleFormat_("int16");
r2 = Recorder(s);
r2.recHeaderFormat_('wav');
r2.recSampleFormat_("int16");

// DOCUMENTATION
r3 = Recorder(s);
r3.recHeaderFormat_('wav');
r3.recSampleFormat_("int16");


// MAIN LOOP, DETERMINED BY totalCycles
x = Task{

	// START DOCUMENTATION RECORDER
	//r3.record(cwd++"performance.wav", [~micBusses[0], ~micBusses[1]], 2);

	// 10 second countdown to start
	10.do({ arg i; format("COUNT DOWN: %", (10-i)).postln; 1.wait;});
	// for display
	t = TempoClock.new();

	~sections.do{
		arg dur, i;
		var nextSection, freqs, fillPct, attack, sus, release, cycleDur, minutes, seconds;

		format("THIS SECTION: % of % sections", i, ~sections.size).postln;
		cycleDur = dur * 60;
		nextSection = t.beats + cycleDur;

		format("LENGTH OF SECTION: % seconds", cycleDur).postln;
		// 1. START RECORDING
		r1.record(tempWav1, ~micBus1, numChannels:1); // record for sampleDur seconds
		r2.record(tempWav2, ~micBus2, numChannels:1); // record second channel
		1.do{
			format("RECORDING, TIME:\t\t\t\t % : % ", (t.beats/60).asInteger, (t.beats%60).asInteger).postln;
			// update phone
			~phones.do( {
				arg phone;
				try { phone.sendMsg("/nowTime", format("%:%", (t.beats/60).asInteger, (t.beats%60).asInteger)) } { "PHONE OFFLINE".postln };
			});
			sampleDur.wait;
		};

		// 2. STOP RECORDING
		r1.stopRecording;
		r2.stopRecording;
		recBufTime.do{
			format("STOPPED RECORDING, TIME:\t\t % : % ", (t.beats/60).asInteger, (t.beats%60).asInteger).postln;
			// update phone
			~phones.do( {
				arg phone;
				try { phone.sendMsg("/nowTime", format("%:%", (t.beats/60).asInteger, (t.beats%60).asInteger)) } { "PHONE OFFLINE".postln };
			});
			1.wait;
		};

		// 3. PING PYTHON PROGRAM FOR FREQS
		~localHost.sendMsg('/ping');
		//freqs.postln;
		pingBufTime.do{
			format("GETTING SAMPLE FREQS, TIME:\t\t % : % ", (t.beats/60).asInteger, (t.beats%60).asInteger).postln;
			// update phone
			~phones.do( {
				arg phone;
				try { phone.sendMsg("/nowTime", format("%:%", (t.beats/60).asInteger, (t.beats%60).asInteger)) } { "PHONE OFFLINE".postln };
			});
			1.wait;
		}; // is this necessary?

		// 4. UPDATE LOCAL SYNTH
		~sines1.set(\freqs, ~freqs1);
		~sines1.set(\amps, ~amps1);
		~sines2.set(\freqs, ~freqs2);
		~sines2.set(\amps, ~amps2);
		// calculate envelope based on length of cycle

		// calculate remaining time left in cycle
		cycleRemainder = cycleDur - sampleDur - recBufTime - pingBufTime;

		// determine envelope based on ~fills value (determined at top), value 0.5 - 1.0
		fillPct = ~fills[i];
		sus = cycleRemainder * fillPct;
		release = (cycleRemainder - sus + sampleDur + recBufTime + pingBufTime); // * 0.8; TRY ADJUSTING THIS VALUE
		//if( i < 10, { release = release * 0.7 });
		//if( ( i >= 10 && i < 15 ), { release = release * 0.9 }, { release = release * 1.2 });

		format("BEFORE: %", release).postln;
		release = case
		{ i < 5 } {release * 0.5}
		{ (i >= 5) && (i < 10) } { release * 0.7}
		{ (i >= 10) && (i < 16) } { release * 0.9}
		{ i >= 16 } { release * 1.1 };
		format("AFTER: %", release).postln;


		// make the last one a 30 second fade out
		if(i == (~sections.size-1), { "LAST SECTION".postln; release = 30 });
		format("RELEASE: %", release).postln;

		//if( cycleDur > 50.0, {fillPct = 0.5}, {fillPct = 0.9});
		//if( fillPct < 1.0, {release = 10.0}, {release=0.1});


		format( "sus %, release %, cycleDur %", sus, release, cycleDur).postln;
		~sines1.set(\sus, sus);
		~sines1.set(\release, release);
		~sines1.set(\gate, 1);
		~sines2.set(\sus, sus);
		~sines2.set(\release, release);
		~sines2.set(\gate, 1);

		// at this point, sampleDur (2) + recBufTime (1) + pingBufTime (1) seconds have passed

		// ----------------------------------------------------------------------------
		// NOW UPDATE PIS

		// COME BACK AND TEST THIS STUFF


		// pi 1, freqs 1 and 2
		f = ~freqs1.choose;

		if( f < 60.midicps, { f = f*2 }); // transpose up an octave if it's below middle c

		// update pione
		~hostsParams[0].sendMsg('/synthFreq1', 0, f);
		~hostsParams[0].sendMsg('/synthFreq2', 0, ~freqs1.takeAt(rand(~freqs1.size)));

		// update first phone
		~updatePitchDisplay.(~phones[0], ~getNoteAndCentsFromHz.(f)[0], ~getNoteAndCentsFromHz.(f)[1]);

		// pi 2, freqs 1 and 2
		f = ~freqs2.choose;

		// update pitwo
		if( f < 60.midicps, { f = f*2 }); // transpose up an octave if it's below middle c
		~hostsParams[1].sendMsg('/synthFreq1', 0, f);
		~hostsParams[1].sendMsg('/synthFreq2', 0, ~freqs2.takeAt(rand(~freqs2.size)));

		// update second phone
		~updatePitchDisplay.(~phones[1], ~getNoteAndCentsFromHz.(f)[0], ~getNoteAndCentsFromHz.(f)[1]);
		//~updatePitchDisplay.(~phones[1], ~getNoteAndCentsFromHz.(440.0)[0], ~getNoteAndCentsFromHz.(440.0)[1]);

		// make a button for resetting sensors
		// figure out cable situation for having laptop by me for performance

		// update next change time:
		~phones.do( {
			arg phone;
			try { phone.sendMsg("/nextCycle", format("%:%", (nextSection/60).asInteger, (nextSection%60).asInteger)) } { "PHONE OFFLINE".postln };
			//phone.sendMsg("/nextCycle", format("NEXT: %:%", (294/60).asInteger, (294%60).asInteger));
		});


		cycleRemainder.do{
			format("TUNING TIME, TIME:\t %:% , NEXT CHANGE: %:%", (t.beats/60).asInteger, (t.beats%60).asInteger, (nextSection/60).asInteger, (nextSection%60).asInteger).postln;
			// update phones
			~phones.do( {
				arg phone;
				try { phone.sendMsg("/nowTime", format("%:%", (t.beats/60).asInteger, (t.beats%60).asInteger)) } { "PHONE OFFLINE".postln };
			});
			1.wait;
		};

	};
	// shutdown python server when finished
	~localHost.sendMsg('/shutdown');
	// stop pis
	~setStdSynth.(~hostsParams, "/stdSynthState", 0, 0); // turn on chan 1


	~hostsParams[0].sendMsg('/synthFreq1', 0, f);
	~hostsParams[0].sendMsg('/synthFreq2', 0, f);
	~hostsParams[1].sendMsg('/synthFreq1', 0, f);
	~hostsParams[1].sendMsg('/synthFreq2', 0, f);
	// kill synth
	//~sines1.set(\gate, 0);
	//~sines2.set(\gate, 0);
	// stop recording
	// but wait 60 seconds first
	60.do({ arg i; format("COUNT DOWN: %", (60-i)).postln; 1.wait;});
	r3.stopRecording;
}.start;
)
~fills;



// USE THIS FOR STOPPING
(
x.stop;
~sines1.set(\sus, 1);
~sines1.set(\release, 1);
~sines1.set(\gate, 1);
~sines2.set(\sus, 1);
~sines2.set(\release, 1);
~sines2.set(\gate, 1);

//r3.stopRecording;
)
s.quit;


s.scope;
s.freqscope;

~freqs1;
~freqs2;