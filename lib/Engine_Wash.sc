// Engine_Wash

// Inherit methods from CroneEngine
Engine_Wash : CroneEngine {

    // Wash specific v0.1.0

    // Wash ^

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // Wash specific v0.0.1
        SynthDef.new("wash",{
            arg timescale=8,attack=0.5,
            wflo=1, wfhi=10, decay=0, gate=1, wfmax=850;
            var sound, freqs, envs, rings, numvoices, env, freqind;
            var iphase=1;
            var time=timescale;
            var start=Impulse.kr(0);
            numvoices =10;
            freqs ={
                Demand.kr(start,0,Drand([ 0, 2, 4, 5, 7, 9, 11 ]))+26+Demand.kr(start,0,Drand([ 0, 12, 24, 36, 48 ]))
            }!numvoices;
            freqs=freqs.midicps;
            rings = {1.0.rand}.dup(numvoices);
            envs = { EnvGen.kr(Env.linen( rrand(0,timescale*100)/100,
                rrand(0,timescale*100)/100, (rrand(0,timescale*100)/100*10), rrand(0,100)/100 ) ) }.dup(numvoices);
            
            sound = PinkNoise.ar([0.1,0.1]);
            sound = DynKlank.ar(`[freqs,envs,rings], sound );
            sound = SelectX.ar(VarLag.kr(LFNoise0.kr(1/4),4,warp:\sine).range(0.2,0.7),[sound,LPF.ar(Splay.ar(SinOsc.ar(freqs*2)*envs),1000,4)]);
            // freqind=ArrayMin.kr(freqs).poll;
            // //sound=sound+RLPF.ar(Saw.ar(freqind[0]*0.99,freqind[0]*1.005/2),freqind[0]*1.5,0.707,0.05);
            sound = HPF.ar(sound, 50);
            
            6.do{sound = DelayC.ar(sound, 0.8, [0.8.rand,0.8.rand], 1/8, sound) };
            
            sound=Pan2.ar(sound,VarLag.kr(LFNoise0.kr(1/5),5,warp:\sine).range(-0.5,0.5));
            sound=sound*0.1;
            
            DetectSilence.ar(sound,0.01,2,doneAction:2);
            Out.ar(0,sound.tanh*EnvGen.ar(Env.perc(attack*timescale,(1-attack)*timescale),doneAction:2));
        }).add(context.server);

        // metronome
        this.addCommand("wash","ff",{arg msg;
            Synth.new("wash",[\timescale,msg[1],\attack,msg[2]])
        });

        // ^ Wash specific

    }

    free {
        // Wash Specific v0.0.1

        // ^ Wash specific
    }
}
