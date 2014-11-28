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
480.0 => float bpm;

// maj scale frequencies
float freqs[7];
middleC => freqs[0];
freqs[0]*9/8 => freqs[1];
freqs[0]*5/4 => freqs[2];
freqs[0]*4/3 => freqs[3];
freqs[0]*3/2 => freqs[4];
freqs[0]*5/3 => freqs[5];
freqs[0]*30/16 => freqs[6];

// env.
ADSR e;
e.set( 0::ms, 0.1::ms, 0, 0.001::ms );
.0001 => e.decayRate;

SinOsc oscillators[7];

int i;
for (0 => int i; i < 7; i++) {
    .2 => oscillators[i].gain;
    freqs[i] => oscillators[i].freq;
}

//oscillators[0] => e => dac;
//oscillators[1] => e => dac;
//oscillators[5] => e => dac;
bpmToms(bpm) => float beatDur;

-1 => int beatCounter;
int seqState[16][8][1];
clear_all();

// loop state variables
int x, y, s;

while (true) {
    
    while (oe.nextMsg() != 0) {
        oe.getInt() => x;
        oe.getInt() => y;
        oe.getInt() => s;
        
        if (s == 1 && x < width && y < height) {
            if (seqState[x][y+1][0] == 0) {
                1 => seqState[x][y+1][0];
                led_set(x, y, 1);
                
            } else {
                0 => seqState[x][y+1][0];
                led_set(x, y, 0);
                
            }
        } 
    }
    
    (beatCounter + 1) %16 => beatCounter;
    <<<beatCounter>>>;
    led_set(beatCounter, 0, 1);
    led_set(16- (16 - (beatCounter - 1)%16)%16, 0, 0);
    for (0 => int i; i < 7; i++) {
        if (seqState[beatCounter][i+1][0] == 1) {
            oscillators[i] => e => dac;
        } else {
        }
    }
    e.keyOn(); 
    beatDur::ms => now;
    e.keyOff();
    disconnect();
}





// fun void go(float bpm, OscEvent oe, int ss[][][]) {} 
//fun void buttonListen(OscEvent oe,int ss[][][]) {}

// funcs
fun float bpmToms(float bpm) {
    return 1/(bpm/60/1000);
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

fun void disconnect() {
    for (0 => int i; i < 7; i++) {
        oscillators[i] =< e;
        e =< dac;
    }
}