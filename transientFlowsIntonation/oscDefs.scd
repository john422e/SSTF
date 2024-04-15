(
/*PORTS:
to/from local host: 9998/9999
to pis: 10000 (on/off), 10001 (control messages: /freq, /gain, /distance)
TO PHONES: 10002
FROM PHONES: 10003
*/

OSCdef.freeAll;

// set up local host
~localHost = ~localHost.free;
~localHost = ~makeHost.(port: 9998);

~hostnames = ["pitwo.local", "pifive.local"];
try { ~hostsMaster = ~makeHosts.(~hostnames, 10000) } { "PIS NOT ONLINE".postln}; // for adding/removing synths from remote servers
try { ~hostsParams = ~makeHosts.(~hostnames, 10001) } { "PIS NOT ONLINE".postln}; // for setting params on remote synths
~phoneHostnames = ["Johns-iPhone.local", "Emily.local"];
//~phoneHostnames = ["127.0.0.1", "Johns-iPhone.local"];
//~phoneHostnames = ["127.0.0.1", "Emily.local"]; // do this one for performance
try { ~phones = ~makeHosts.(~phoneHostnames, 10002) } { "PHONES NOT ONLINE".postln};
//~phones = ~makeHost.("Johns-iPhone.local", 10002);
//~phoneHostnames.size;

// ----------------------------------------------------------------------------

// receive freqs and amps from sample analysis program
OSCdef.new(
	\recvFreqs,
	// function to be evaluated upon receiving qualifying OSC message
	{
		arg msg, time, addr, port; // these are the messages passed on
		var cleaned, midpoint, l1, l2;
		[msg, time, addr, port].postln; // action to be executed
		msg.removeAt(0); // get rid of tag beginning
		["RCVD:", msg].postln;
		// clean list of strings
		cleaned = msg.select( { arg i; i.isNumber });
		// cut list in two
		midpoint = (cleaned.size/2).asInteger;
		l1 = cleaned[..(midpoint-1)];
		l2 = cleaned[midpoint..cleaned.size];
		// now we have 2 lists of [amp, freq, amp, freq...]
		// make separate lists for amp vals and freq vals\

		// L1
		~amps1 = Array.new(l1.size/2);
		~freqs1 = Array.new(l1.size/2);
		l1.do( {
			arg val, i;
			[val, i].postln;
			if( i % 2 == 0, { ~amps1.add(val) }, { ~freqs1.add(val) });
		});
		~amps1 = ~amps1.normalizeSum();
		//~amps1 = Array.fill(8, {1.0/8});

		// L2
		~amps2 = Array.new(l2.size/2);
		~freqs2 = Array.new(l2.size/2);
		l2.do( {
			arg val, i;
			[val, i].postln;
			if( i % 2 == 0, { ~amps2.add(val) }, { ~freqs2.add(val) });
		});
		~amps2 = ~amps2.normalizeSum();
		//~amps2 = Array.fill(8, {1.0/8});

		//~amps1.sum.postln;
	},
	'/freqs',
	recvPort: 9999
);

// button from phones to reset sensor programs
OSCdef.new(
	\sensorResetDef,
	{
		Task {
			"RESETTING SENSOR".postln;
			// start up sensor programs
			~sensorInit.(~hostsMaster, ~hostsParams);  // TO RESET SENSOR DO THIS AND ~pingSensors block

			3.wait;
			"NOW PINGING".postln;
			// initiate synth settings and start pinging
			~pingSensors.(~hostsParams);
			~setSensorOffset.(~hostsParams, vals: [18.0, 12.0]);
			~setSensorRange.(~hostsParams, val: 15.0);

		}.start;

	},
	"/sensorReset",
	recvPort: 10003
);

)