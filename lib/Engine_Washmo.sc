// Engine_Washmo

// Inherit methods from CroneEngine
Engine_Washmo : CroneEngine {

    // Washmo specific v0.1.0
    var synMixer;
    var busMixer;
    var synNoise;
    var busNoise;
    // Washmo ^

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Washmo specific v0.0.1
        SynthDef("mixer",{
            arg out,in;
            var snd=In.ar(in,2);
            snd = HPF.ar(snd, 50);
            6.do{snd = DelayL.ar(snd, 0.8, [0.8.rand,0.8.rand], 1/8, snd) };
            Out.ar(out,snd);
        }).add;

        SynthDef("noise",{
            arg out;
            Out.ar(out,PinkNoise.ar([0.1,0.1]));
        }).add;


        SynthDef("klank",{
            arg out=0,in,timescale=8,attack=0.5,decay=0.5,note=60,ring=0.5;
            var snd;
            var start=Impulse.kr(0);
            var numvoices = 10;
            var freq=note.midicps;

            var env = EnvGen.kr(Env.linen(
                rrand(0,timescale*100)/100,
                rrand(0,timescale*100)/100, 
                (rrand(0,timescale*100)/100*10), 
                rrand(0,100)/100 ));

            
            snd = DynKlank.ar(`[[freq],[env],[ring]], In.ar(in,2) );
            snd = SelectX.ar(VarLag.kr(LFNoise0.kr(1/4),4,warp:\sine).range(0.2,0.7),[snd,LPF.ar(SinOsc.ar(freq*2)*env,1000,4)]);
            
            snd=Pan2.ar(snd,VarLag.kr(LFNoise0.kr(1/5),5,warp:\sine).range(-0.5,0.5));
            snd=snd/20;
            snd=snd.tanh*EnvGen.ar(Env.perc(attack*timescale,decay*timescale),doneAction:2);

            DetectSilence.ar(snd,0.01,2,doneAction:2);
            Out.ar(out,snd);
        }).add;

        context.server.sync;

        busMixer=Bus.audio(context.server,2);
        busNoise=Bus.audio(context.server,2);

        context.server.sync;

        synNoise=Synth.head(context.server,"noise",[\out,busNoise]);
        synMixer=Synth.tail(context.server,"mixer",[\out,0,\in,busMixer]);

        // metronome
        this.addCommand("washmo","ffff",{arg msg;
            var note=msg[1];
            var timescale=msg[2];
            var attack=msg[3];
            var decay=msg[4];
            Synth.before(synMixer,"klank",[
                \out,busMixer,
                \in,busNoise,
                \note,note,
                \timescale,timescale,
                \attack,attack,
                \decay,decay
            ]).onFree({"freed!"});
        });

        // ^ Washmo specific

    }

    free {
        // Washmo Specific v0.0.1
        synMixer.free;
        synNoise.free;
        busNoise.free;
        busMixer.free;
        // ^ Washmo specific
    }
}
