/*
a template for live intonation pieces.
runs with python server analyzeSample.py with Allen Downey's thinkdsp modules.
it's essentially just a pitch tracker for now without further spectral processing.
--john eagle, august 2022

TO RUN: add code blocks 1-4, then run analyzeSample.py from terminal (5), serverMaster.ck from terminal on each pi (6), then run code block 7
*/

// 1. run setup.scd

// 2. run functions.scd

// 3. run soundServer.scd ( builds arrays for ~micBusses, ~micSynths, and ~sines )

// 4. run oscDefs.scd (builds ~localHost )

// 5. START PYTHON SERVER IN TERMINAL reservoirs_analyzeSample.py

// 8. START PROGRAM
(
// MAIN
var cwd, temps, recs, r3, sampleDur=1.0, recBufTime=1.0, pingBufTime=0.0, extraLag=0.0, cycleRemainder, totalFreqs=~numSines;

// ----------------------------------------------------------------------------

cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
// build arrays for filenames and recorders
temps = Array.fill( ~numSources, { arg i; cwd ++ "temp" ++ i.asString ++ ".wav"});
recs = Array.fill( ~numSources, {

	arg recorder;
	recorder = Recorder(s);
	recorder.recHeaderFormat_('wav');
	recorder.recSampleFormat_("int16");
	recorder;
});

// DOCUMENTATION
r3 = Recorder(s);
r3.recHeaderFormat_('wav');
r3.recSampleFormat_("int16");


// for display
t = TempoClock.new();

// MAIN LOOP, DETERMINED BY totalCycles
x = Task{

	// START DOCUMENTATION RECORDER
	//UNCOMMENT THIS LATER TO RECORD
	r3.record(cwd ++ Date.getDate.stamp ++ "performance.wav", s, 2);

	~sections.do{
		arg dur, i;

		"TOP".postln;
		[dur, i].postln;

		2.do ( // alternate going between the 2 channels
			{
				arg chan; // 0 or 1
				var nextSection, freqs, fillPct, attack, sus, release, cycleDur, minutes, seconds;

				cycleDur = dur * 60;
				nextSection = t.beats + cycleDur;

				format("LENGTH OF SECTION: % seconds", cycleDur).postln;
				// 1. START RECORDING SAMPLE
				// update button on phone to indicate recording
				try { ~phones[chan].sendMsg("/recordingLight", "1")} {"MESSAGE ERROR".postln };

				recs[chan].record(temps[chan], ~micBusses[chan], numChannels: 1);
				/*
				recs.do( {
					arg rec, i;
					var fileName = temps[i];
					rec.record(fileName, ~micBusses[i], numChannels: 1);
				});
				*/
				//["SAMPLE DUR:", sampleDur].postln;
				// record for sampleDur seconds
				//~updateTime.();
				// update sampleDur
				cycleDur = cycleDur - 0.11; // to compensate for release time later
				sampleDur = cycleDur * 0.5; // or keep default???
				1.do{ format("RECORDING, TIME:\t\t\t\t % minutes, % seconds", (t.beats/60).asInteger, (t.beats%60).asInteger).postln; sampleDur.wait};

				// 2. STOP RECORDING
				// update button on phone (off) to indicate recording stopped
				try { ~phones[chan].sendMsg("/recordingLight", "0")} {"MESSAGE ERROR".postln; };

				recs[chan].stopRecording;
				//recs.do( { arg rec; rec.stopRecording});
				//~updateTime.();
				// update recBufTime
				recBufTime = cycleDur * 0.25; // or keep default?
				1.do{ format("STOPPED RECORDING, TIME:\t\t % minutes, % seconds", (t.beats/60).asInteger, (t.beats%60).asInteger).postln; recBufTime.wait};


				// 3. PING PYTHON PROGRAM FOR FREQS
				~localHost.sendMsg('/ping', chan);

				//~updateTime.();
				// update pingBufTime
				pingBufTime = cycleDur * 0.125; // or keep default?
				format("GETTING SAMPLE FREQS, TIME:\t\t % minutes, % seconds", (t.beats/60).asInteger, (t.beats%60).asInteger).postln; pingBufTime.wait; // is this necessary?

				// 4. UPDATE LOCAL SYNTHS

				// calculate remaining time left in cycle
				cycleRemainder = cycleDur - sampleDur - recBufTime - pingBufTime;
				["CYLCE REM:", cycleRemainder].postln;

				// determine envelope based on ~fills value (determined at top), value 0.5 - 1.0
				fillPct = ~fills[i];
				//sus = cycleRemainder * fillPct + sampleDur;
				//release = (cycleRemainder - sus);

				//if( cycleDur > 50.0, {fillPct = 0.5}, {fillPct = 0.9});
				//if( fillPct < 1.0, {release = 10.0}, {release=0.1});


				format( "sus %, release %, cycleDur %", sus, release, cycleDur).postln;

				// this gate off is added. was it better before?
				~sines[chan].set(\gate, 0); // turn off
				["OFF"].postln;
				0.11.wait; // for release

				~sines[chan].set(\freqs, ~currentData[chan][1]);
				~sines[chan].set(\amps, ~currentData[chan][0]); // set
				~sines[chan].set(\gate, 1); // turn back on

				// at this point, sampleDur (2) + recBufTime (1) + pingBufTime (1) seconds have passed
				//~updateTime.();
				format("TUNING TIME, TIME:\t %:% , NEXT CHANGE: %:%", (t.beats/60).asInteger, (t.beats%60).asInteger, (nextSection/60).asInteger, (nextSection%60).asInteger).postln; cycleRemainder.wait;
		});

	};

	// shutdown python server when finished
	~localHost.sendMsg('/shutdown');

	// kill synth with fade out
	~sines.do( {
		arg synth;
		synth.set(\release, 30);
		synth.set(\gate, 0);
	});

	// stop recording
	// but wait 60 seconds first
	60.do({ arg i; format("COUNT DOWN: %", (60-i)).postln; 1.wait;});
	r3.stopRecording;


};

y = Task {
	(~seconds+60).do{
		~updateTime.();
		1.wait;
	}
};

x.start;
y.start;

)



(
// USE THIS FOR STOPPING
x.stop;
y.stop;
~sines.do{
	arg synth;
	synth.set(\gate,  0);
}
)



~localHost.sendMsg('/shutdown');
~localHost.sendMsg('/ping', 1);





~currentData[0][0];
~currentData[0][1];
~currentData[1][1];
~currentData[0][0].size;

s.quit;


s.scope;

s.freqscope;

~localHost;