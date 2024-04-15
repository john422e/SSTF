(
// start up sensor programs
~sensorInit.(~hostsMaster, ~hostsParams);  // TO RESET SENSOR DO THIS AND ~pingSensors block
)

(
// start up synth programs
~stdSynthSwitch.(~hostsMaster);


// initiate synth settings and start pinging
~pingSensors.(~hostsParams);
~setSensorOffset.(~hostsParams, vals: [18.0, 12.0]);
~setSensorRange.(~hostsParams, val: 15.0);
)

(
~setStdSynth.(~hostsParams, "/stdSynthState", 0, 1); // turn on chan 1

~setStdSynth.(~hostsParams, "/synthFreq1", 0, 440.0);
~setStdSynth.(~hostsParams, "/synthFreq2", 0, 330.0);
)

// SHUT IT DOWN
(
~unpingSensors.(~hostsParams);
~stdSynthSwitch.(~hostsMaster, state: 0);
~sensorShutdown.(~hostsMaster, ~hostsParams);
)
~shutdownRemoteServer.(~hostsMaster);
