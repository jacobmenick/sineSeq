// set up OSC communication.  
    "/sinseq" => string prefix;
    
    // Initial send and reveive
    OscSend xmit; 
    xmit.setHost("localhost", 12002);
    
    OscRecv recv;
    8000 => recv.port;
    recv.listen();
    
    // list devices
    xmit.startMsg("/serialosc/list", "si");
    "localhost" => xmit.addString;
    8000 => xmit.addInt;
    
        <<<"looking for a monome...", "">>>;
    
    recv.event("/serialosc/device", "ssi") @=> OscEvent discover;
    discover => now;
    
    string serial; string devicetype; int port;

    while(discover.nextMsg() != 0){
    
        discover.getString() => serial;
        discover.getString() => devicetype;
        discover.getInt() => port;
    
        <<<"found", devicetype, "(", serial, ") on port", port>>>;
    }
    
    // connect to device.
    xmit.setHost("localhost", port);
	xmit.startMsg("/sys/port", "i");
	8000 => xmit.addInt;
    
    // get size (of monome)? 
    recv.event("/sys/size", "ii") @=> OscEvent getsize;
    
    xmit.startMsg("/sys/info", "si");
    "localhost" => xmit.addString;	
    8000 => xmit.addInt;
    
    getsize => now;
    
    int width; int height;
    
    while(getsize.nextMsg() != 0){
        
        getsize.getInt() => width;
        getsize.getInt() => height;
        
        //	<<<"size is", width, "by", height>>>;
    }
    //set prefix
	xmit.startMsg("/sys/prefix", "s");
	prefix => xmit.addString;

        recv.event( prefix+"/grid/key", "iii") @=> OscEvent oe;

// Set up parameters of application.
261.6 => float middleC;
120.0 => float bpm;

// maj scale frequencies
float freqs[7];
middleC => freqs[0];
freqs[0]*9/8 => freqs[1];
freqs[0]*5/4 => freqs[2];
freqs[0]*4/3 => freqs[3];
freqs[0]*3/2 => freqs[4];
freqs[0]*5/3 => freqs[5];
freqs[0]*30/16 => freqs[6];

// envelopes.
ADSR synthEnv;
synthEnv.set( 0::ms, 0.1::ms, 0, 0.001::ms );
.0001 => synthEnv.decayRate;



SinOsc oscillators[7];
string samplefns[7]; 
SndBuf buffers[7];

me.sourceDir()+"/samples/808BD1.aif" => samplefns[0];
me.sourceDir()+"/samples/ddClP18.wav" => samplefns[1];
me.sourceDir()+"/samples/ddHH3.wav" => samplefns[2];
me.sourceDir()+"/samples/808oh.aif" => samplefns[3];
me.sourceDir()+"/samples/v1SH3.wav" => samplefns[4];
me.sourceDir()+"/samples/wvRM11.wav" => samplefns[5];
me.sourceDir()+"/samples/v1BNG3.wav" => samplefns[6];
// Assign sample names to buffers.
for (0 => int i; i < 7; i++) {
    samplefns[i] => buffers[i].read;
    .5 => buffers[i].gain;
    if (i == 4) {
        .05 => buffers[i].gain;
    }
}

// 7 Oscillators indexed 0-6
// Assign frequencies to each oscillator. 
for (0 => int i; i < 7; i++) {
    .2 => oscillators[i].gain;
    freqs[i] => oscillators[i].freq;
}

// Beat duration is according to bpm. 
bpmToms(bpm) => float beatDur;

// initialize beatCounter at 0. 
0 => int beatCounter;

// The sequence state is a 3D array. 
// First component (0 - 15): Column (beat) number
// Second component (0 - 7): Scale position
// Third component (0 or 1): Off or on. 
int seqState[16][8][1];

// Tells whether we are editing (displaying, resp.) drum or synth mode. 
int mode; // 0 - synth, 1 - drums

// If we are in drum mode, we are editing drum mode. 
int drumState[16][8][1];
clear_leds();

// event state variables
// ‘x’ holds the column number of a button event.
// ‘y’ holds the row number.
// ’s’ holds whether or not it is a depression or release. 
int x, y, s;

while (true) {
    while (oe.nextMsg() != 0) {
        oe.getInt() => x;
        oe.getInt() => y;
        oe.getInt() => s;
        // Switch mode. 
        if (x == 14 && y == 0 && s == 1) {
            if (mode == 0) {
                1 => mode;
                showSynth();
                led_set(14, 0, 1);
            } else if (mode == 1) {
                0 => mode;
                showDrums();
                led_set(14, 0, 0);
            }
        }
        // Increment BPM
        if (x == 13 && y == 0 && s == 1) {
            bpm + 10 => bpm;
            bpmToms(bpm) => beatDur;
        }

        // Decrement BPM
        if (x == 12 && y == 0 && s == 1) {
            bpm - 10 => bpm;
            bpmToms(bpm) => beatDur;
        }

        if (s == 1 && x < width && y < height) {
            if (mode == 0 || y == 0) {
                if (seqState[x][y][0] == 0) {
                    1 => seqState[x][y][0];
                    led_set(x, y, 1);
                } else if (seqState[x][y][0] == 1) {
                    0 => seqState[x][y][0];
                    led_set(x, y, 0);
                }
            } else if (mode == 1) {
                if (drumState[x][y][0] == 0) {
                    1 => drumState[x][y][0];
                    led_set(x, y, 1);
                } else if (drumState[x][y][0] == 1) {
                    0 => drumState[x][y][0];
                    led_set(x, y, 0);
                }

            }
        }
    }
    // Include play/restart button. 
    if (seqState[15][0][0] == 1) {
        led_set(15, 0, 1);
        while (true) {
            // Illuminate the led of the beatcounter position in the current row. 
            led_set(beatCounter, 0, 1);
            <<<beatCounter>>>;
            <<<mode>>>;
            // Take any button push events and alter the state accordingly. 
            while (oe.nextMsg() != 0) {
                oe.getInt() => x;
                oe.getInt() => y;
                oe.getInt() => s;
                if (x == 14 && y == 0 && s == 1) {
                    if (mode == 0) {
                        1 => mode;
                        showDrums();
                        led_set(14, 0, 1);
                    } else if (mode == 1) {
                        0 => mode;
                        showSynth();
                        led_set(14, 0, 0);
                    }
                }
                if (x == 13 && y == 0 && s == 1) {
                    bpm + 10 => bpm;
                    bpmToms(bpm) => beatDur;
                }
                
                // Decrement BPM
                if (x == 12 && y == 0 && s == 1) {
                    bpm - 10 => bpm;
                    bpmToms(bpm) => beatDur;
                }
                if (s == 1 && x < width && y < height) {
                    if (mode == 0 || y == 0) {
                        if (seqState[x][y][0] == 0) {
                            1 => seqState[x][y][0];
                            led_set(x, y, 1);
                        } else if (seqState[x][y][0] == 1) {
                            0 => seqState[x][y][0];
                            led_set(x, y, 0);
                        }
                    } else if (mode == 1) {
                        if (drumState[x][y][0] == 0) {
                            1 => drumState[x][y][0];
                            led_set(x, y, 1);
                        } else if (drumState[x][y][0] == 1) {
                            0 => drumState[x][y][0];
                            led_set(x, y, 0);
                        }
                        
                    }
                }
            }
            
            for (1 => int i; i <= 7; i++) {
                // If a note is triggered, send it to the dac (through the envelope). 
                if (seqState[beatCounter][i][0] == 1) {
                    oscillators[i -1] => synthEnv => dac;
                }
                if (drumState[beatCounter][i][0] == 1) {
                    0 => buffers[i - 1].pos;
                    buffers[i - 1] => dac; 
                }
            }
            synthEnv.keyOn(); 

            beatDur::ms => now;
            synthEnv.keyOff();
            disconnect();
            if (seqState[15][0][0] == 0) {
                led_set(beatCounter, 0, 0);
                0 => beatCounter;
                int seqState[15][8][1];
                break;
            }
            // Kill the led of the previous beatcounter position if it has zero state. 
            if (seqState[beatCounter][0][0] == 0) {
                led_set(beatCounter, 0, 0);
            }
            // Increment the beatcounter mod 16.
            (beatCounter + 1) %16 => beatCounter;
        }
    }
}






fun void showSynth() {
    clear_leds();
    for (0 => int i; i < 16; i++) {
        for (0 => int j; j <= 7; j++) {
            if (seqState[i][j][0] == 1) {
                led_set(i, j, 1);
            }
        }
    }
}

fun void showDrums() {
    clear_leds();
    for (0 => int i; i < 16; i++) {
        for (0 => int j; j <= 7; j++) {
            if (drumState[i][j][0] == 1) {
                led_set(i, j, 1);
            }
        }
    }
}

// funcs
fun float bpmToms(float bpm) {
    return 1/(bpm/60/1000)/4;
}

fun void led_set(int x, int y, int s) {
    xmit.startMsg("/sinseq/grid/led/set", "iii");
	x => xmit.addInt;
	y => xmit.addInt;
	s => xmit.addInt;
}

fun void clear_all() {
    xmit.startMsg("/sinseq/grid/led/all", "i");
    0 => xmit.addInt;
}

fun void clear_leds() {
    for (0 => int i; i < 15; i++) {
        for (0 => int j; j <= 7; j++) {
            led_set(i, j, 0);
        }
    }
}

fun void disconnect() {
    for (0 => int i; i < 7; i++) {
        oscillators[i] =< synthEnv;
        buffers[i] =< dac;
        synthEnv =< dac;
    }
}