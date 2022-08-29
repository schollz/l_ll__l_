// Engine_EmissionSpectrum

// Inherit methods from CroneEngine
Engine_EmissionSpectrum : CroneEngine {

    // EmissionSpectrum specific v0.1.0
    var synMixer;
    var busMixer;
    var synNoise;
    var busNoise;
    var busSidechain;
    var oscAmplitude;
    // EmissionSpectrum ^

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    alloc {
        // EmissionSpectrum specific v0.0.1

        oscAmplitude = OSCFunc({ |msg| 
            NetAddr("127.0.0.1", 10111).sendMsg("amplitude",msg[3],msg[4]);
        }, '/oscAmplitude');


        SynthDef("mixer",{
            arg out,in,insc,sidechain_mult=2,compress_thresh=0.1,compress_level=0.1,compress_attack=0.01,compress_release=0.15;
            var snd=In.ar(in,2);
            var sndSC=In.ar(insc,2);
            // snd = Compander.ar(snd, sndSC*sidechain_mult, 
            //     compress_thresh, 1, compress_level, 
            //     compress_attack, compress_release);
            snd = HPF.ar(snd, 50);
            snd = LPF.ar(snd,2000);
            6.do{snd = DelayL.ar(snd, 0.8, [0.8.rand,0.8.rand], 1/8, snd) };

            Out.ar(out,snd*0.5);
        }).add;

        SynthDef("noise",{
            arg out;
            Out.ar(out,PinkNoise.ar([0.1,0.1]));
        }).add;

        SynthDef("kick", { |basefreq = 40, ratio = 6, sweeptime = 0.05, preamp = 1, amp = 1,
            decay1 = 0.3, decay1L = 0.8, decay2 = 0.15, clicky=0.0, out|
            var    fcurve = EnvGen.kr(Env([basefreq * ratio, basefreq], [sweeptime], \exp)),
            env = EnvGen.kr(Env([clicky,1, decay1L, 0], [0.0,decay1, decay2], -4), doneAction: Done.freeSelf),
            sig = SinOsc.ar(fcurve, 0.5pi, preamp).distort * env * amp;
            sig = sig !2;
            Out.ar(0,sig);
            Out.ar(out, sig);
        }).add;

        SynthDef("klank",{
            arg out=0,in,attack=0.5,decay=0.5,note=60,note_ind=0,ring=0.5;
            var snd;
            var start=Impulse.kr(0);
            var numvoices = 10;
            var freq=note.midicps;
            var env_main = EnvGen.ar(Env.perc(attack,decay),doneAction:2);
            var duration=attack+decay;

            var env = EnvGen.kr(Env.linen(
                rrand(0,duration*100)/100,
                rrand(0,duration*100)/100, 
                (rrand(0,duration*100)/100*10), 
                rrand(0,100)/100 ));
 
            snd = DynKlank.ar(`[[freq],[env],[ring]], In.ar(in,2) );
            snd = SelectX.ar(VarLag.kr(LFNoise0.kr(1/4),4,warp:\sine).range(0.2,0.7),[snd,LPF.ar(SinOsc.ar(freq*2)*env,1000,4)]);
            
            snd=Pan2.ar(snd,VarLag.kr(LFNoise0.kr(1/5),5,warp:\sine).range(-0.5,0.5));
            snd=snd/20;
            snd=snd.tanh*env_main;

            SendReply.kr(Impulse.kr(10),"/oscAmplitude",[
                note_ind,
                env_main
            ]);

            DetectSilence.ar(snd,0.01,2,doneAction:2);
            Out.ar(out,snd);
        }).add;

        context.server.sync;

        busMixer=Bus.audio(context.server,2);
        busNoise=Bus.audio(context.server,2);
        busSidechain=Bus.audio(context.server,2);

        context.server.sync;

        synNoise=Synth.head(context.server,"noise",[\out,busNoise]);
        synMixer=Synth.tail(context.server,"mixer",[\out,0,\in,busMixer,\insc,busSidechain]);

        // metronome
        this.addCommand("emit","iffff",{arg msg;
            var note_ind=msg[1];
            var note=msg[2];
            var attack=msg[3];
            var decay=msg[4];
            var ring=msg[5];
            Synth.before(synMixer,"klank",[
                \out,busMixer,
                \in,busNoise,
                \note_ind,note_ind,
                \note,note,
                \attack,attack,
                \decay,decay,
                \ring,ring
            ]).onFree({"freed!"});
        });

        this.addCommand("kick","fffffffff",{arg msg;
            var basefreq=msg[1];
            var ratio=msg[2];
            var sweeptime=msg[3];
            var preamp=msg[4];
            var amp=msg[5];
            var decay1=msg[6];
            var decay1L=msg[7];
            var decay2=msg[8];
            var clicky=msg[9];
            Synth.before(synMixer,"kick",[
                \out,busSidechain,
                \basefreq,basefreq,
                \ratio,ratio,
                \sweeptime,sweeptime,
                \preamp,preamp,
                \amp,amp,
                \decay1,decay1,
                \decay1L,decay1L,
                \decay2,decay2,
                \clicky,clicky,
            ]).onFree({"freed!"});
        });

        // ^ EmissionSpectrum specific

    }

    free {
        // EmissionSpectrum Specific v0.0.1
        synMixer.free;
        synNoise.free;
        busNoise.free;
        busMixer.free;
        oscAmplitude.free;
        // ^ EmissionSpectrum specific
    }
}
