#!/usr/bin/env python3
"""Original LAST LECTURE boss score: The Unfinished Proof (two 24-bar loops).

Render with libfluidsynth + the MIT-licensed FluidR3 GM soundfont; no game or
commercial recording is sampled. The MIDI, deterministic score and mastering
chain are original and supplied under CC0-1.0. See assets/audio/m23/LICENSE.txt.

python3 tools/audio/compose_m23_boss.py --soundfont /path/FluidR3_GM.sf2
Requires Python3, numpy, scipy, libfluidsynth.so.3 and ffmpeg. The soundfont is a
rendering dependency only, not a runtime dependency. Its exact source/SHA/license
are recorded alongside the Ogg assets. Intermediate WAVs stay outside the repo.
"""
from __future__ import annotations
import argparse, ctypes as C, hashlib, json, math, struct, subprocess, wave
from pathlib import Path
import numpy as np
from scipy.signal import butter, sosfilt

RATE = 48000
PPQ = 480
BARS = 24
BEATS = BARS * 4
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/m23'
INSTRUMENTS = {
    0: ('Measured strings', 48, 86, 35),
    1: ('Cello pulse', 42, 83, 73),
    2: ('Double bass', 43, 82, 62),
    3: ('Horn countertheme', 60, 78, 86),
    4: ('Scholars choir', 52, 56, 49),
    5: ('Archive organ', 19, 53, 64),
    6: ('Violin theme', 40, 92, 76),
    7: ('Harpsichord margins', 6, 47, 99),
    8: ('Brass proclamation', 61, 70, 42),
    9: ('Orchestral cymbals and snare', 0, 67, 67),
    10: ('Low taiko', 116, 91, 57),
    11: ('Timpani', 47, 88, 80),
    12: ('Oboe question', 68, 72, 48),
    13: ('Bell punctuation', 14, 47, 100),
}
CHORDS = {
    'Dm': (38, [50, 57, 62, 65], [62, 65, 69]),
    'Bb': (34, [46, 53, 58, 62], [58, 62, 65]),
    'Gm': (31, [43, 50, 55, 58], [55, 58, 62]),
    'C': (36, [48, 55, 60, 64], [60, 64, 67]),
    'A': (33, [45, 52, 57, 61], [57, 61, 64]),
    'Eo': (40, [52, 58, 62, 67], [58, 62, 67]),
}
HARMONY = ['Dm','Dm','Bb','Gm','Dm','C','Bb','A',
           'Dm','Gm','Bb','A','Dm','Bb','Gm','A',
           'Bb','C','Dm','Dm','Gm','Eo','A','A']
# Each authored melodic cell has its own breath and long notes. Rhythm values
# are beats, not an arpeggiator substituting for a melody.
THEME = [
    [(0,74,.70),(1,69,.34),(1.5,74,.34),(2,77,.66),(3,76,.32),(3.5,73,.36)],
    [(0,69,.72),(1,77,.34),(1.5,76,.34),(2,74,1.42)],
    [(0,70,.58),(.75,74,.52),(1.5,77,.72),(2.5,81,.50),(3.25,77,.48)],
    [(0,67,.54),(.75,70,.50),(1.5,74,.70),(2.5,72,.44),(3.25,69,.50)],
    [(0,77,.70),(1,76,.34),(1.5,74,.34),(2,69,.66),(3,73,.32),(3.5,74,.34)],
    [(0,76,.58),(.75,79,.56),(1.5,84,.72),(2.5,79,.44),(3.25,76,.50)],
    [(0,77,.54),(.75,74,.50),(1.5,70,.72),(2.5,74,.44),(3.25,77,.50)],
    [(0,76,.54),(.75,73,.50),(1.5,69,.72),(2.5,67,.44),(3.25,73,.50)],
    [(0,74,.48),(.75,77,.48),(1.5,81,.72),(2.5,77,.45),(3.25,76,.48)],
    [(0,79,.48),(.75,77,.48),(1.5,74,.72),(2.5,70,.45),(3.25,74,.48)],
    [(0,77,.72),(1,74,.35),(1.5,70,.35),(2,74,1.35)],
    [(0,76,.72),(1,73,.35),(1.5,69,.35),(2,73,1.35)],
    [(0,81,.52),(.75,77,.52),(1.5,74,.72),(2.5,76,.46),(3.25,77,.48)],
    [(0,82,.54),(.75,81,.50),(1.5,77,.70),(2.5,74,.44),(3.25,77,.50)],
    [(0,79,.54),(.75,77,.50),(1.5,74,.70),(2.5,70,.44),(3.25,74,.50)],
    [(0,76,.54),(.75,73,.50),(1.5,69,.70),(2.5,67,.44),(3.25,73,.50)],
    [(0,77,1.35),(1.5,82,.60),(2.5,81,.55),(3.25,77,.50)],
    [(0,79,1.35),(1.5,84,.60),(2.5,83,.55),(3.25,79,.50)],
    [(0,81,1.25),(1.5,77,.50),(2.25,76,.45),(3,74,.72)],
    [(0,77,.65),(1,76,.35),(1.5,74,.35),(2,69,1.40)],
    [(0,79,.55),(.75,77,.50),(1.5,74,.70),(2.5,70,.44),(3.25,74,.50)],
    [(0,79,.55),(.75,77,.50),(1.5,74,.70),(2.5,70,.44),(3.25,76,.50)],
    [(0,76,.55),(.75,73,.50),(1.5,69,.70),(2.5,67,.44),(3.25,73,.50)],
    [(0,76,.55),(.75,73,.50),(1.5,69,.70),(2.5,73,.44),(3.25,76,.50)],
]

def score(phase: int):
    events = []
    def note(ch, pitch, start, length, vel):
        if 0 <= start < BEATS:
            on = int(round(start * PPQ))
            off = min(BEATS*PPQ-1, int(round((start+length)*PPQ)))
            events.extend([(on, 1, ch, int(pitch), int(np.clip(vel, 1, 120))),
                           (off, 0, ch, int(pitch), 0)])
    for bar, name in enumerate(HARMONY):
        t = bar*4
        root, broken, triad = CHORDS[name]
        intense = phase == 2
        strength = [0,3,6][bar//8] + (9 if intense else 0)
        # Persistent running string figure, with phrased accents and breathing
        # gaps before cadences. The second phase adds low sixteenth answers.
        pattern = [0,2,1,3,2,1,3,2]
        for j, degree in enumerate(pattern):
            length = .29 if intense else .34
            note(0, broken[degree], t+j*.5, length,
                 78+strength+(8 if j in [0,4] else (-3 if j%2 else 1)))
            if intense and j not in [3,7]:
                note(1, broken[(degree+1)%4]-12, t+j*.5+.25, .14, 64+strength)
        for beat in [0,1,2,3]:
            note(1, root+12+(12 if beat%2 else 0), t+beat, .48 if intense else .62, 73+strength)
        note(2, root-12, t, 1.72, 78+strength)
        note(2, root-12, t+2, 1.65, 74+strength)
        for pitch in [root,root+7,root+12]: note(5,pitch,t,3.83,48+strength//2)
        for pitch in triad:
            note(4,pitch,t+.04,3.70,47+strength//2+(5 if bar>=16 else 0))
        # French-horn punctuations follow the harmonic sentence rather than
        # doubling every sixteenth, leaving the 2–5k attack-cue region room.
        for offset, length in [(0,1.25),(2.5,.64)]:
            if bar%4 == 3 and offset == 2.5: length = 1.1
            for pitch in triad:
                note(3,pitch-12,t+offset,length,61+strength)
        if intense or bar>=16:
            for pitch in triad: note(8,pitch,t, .68,62+strength)
        for start,pitch,length in THEME[bar]:
            lead = 12 if bar<4 and not intense else 6
            note(lead,pitch,t+start,length,84+strength//2+(3 if start==0 else -3))
            if intense and (start==0 or bar>=16):
                note(3,pitch-12,t+start,min(length,.70),61+strength//2)
        # A sparse harpsichord line gives the score an academic identity without
        # becoming a constant sharp click beneath combat telegraphs.
        if bar%2 == 1 or intense:
            for j in range(4):
                note(7,broken[(j+bar)%4]+12,t+j+.25,.20,44+strength//2)
        # Low ensemble drums, timpani and restrained cymbals. The final two
        # bars of each sentence have a short snare/timpani lift, not a pop beat.
        hits = [(0,95),(1.5,72),(2,89),(3.5,73)] if intense else [(0,88),(2,79)]
        for offset,vel in hits:
            note(10,38 if bar%2==0 else 36,t+offset,.52,vel+strength//2)
        if bar%4 in [0,3] or intense:
            note(11,root if root>=36 else root+12,t,.62,80+strength)
        if bar in [0,8,16] or (intense and bar in [4,12,20]):
            note(9,49,t,.30,66+(7 if intense else 0))
            note(13,74 if name=='Dm' else triad[-1]+12,t,.90,42)
        if bar%8==7:
            for j in range(8):
                note(9,38,t+3+j*.125,.09,40+j*4+(5 if intense else 0))
                if j%2==0: note(11,45,t+3+j*.125,.17,54+j*3)
        elif intense and bar%4==3:
            for j in range(4): note(9,38,t+3+j*.25,.10,52+j*5)
    return sorted(events, key=lambda event:(event[0],event[1]))

def vlq(value):
    data = [value & 127]
    while value >> 7:
        value >>= 7
        data.insert(0,(value & 127)|128)
    return bytes(data)

def write_midi(path, events, bpm):
    tracks=[]
    tempo=round(60000000/bpm)
    meta=b'\0\xff\x51\x03'+tempo.to_bytes(3,'big')
    meta+=b'\0\xff\x58\x04\x04\x02\x18\x08'
    name=b'The Unfinished Proof - original LAST LECTURE score'
    meta+=b'\0\xff\x03'+vlq(len(name))+name+b'\0\xff\x2f\0'
    tracks.append(meta)
    for channel,(name,program,volume,pan) in INSTRUMENTS.items():
        encoded=name.encode()
        data=b'\0\xff\x03'+vlq(len(encoded))+encoded
        data+=b'\0'+bytes([0xC0+channel,program])
        for cc,val in [(7,volume),(10,pan),(91,36),(93,9)]:
            data+=b'\0'+bytes([0xB0+channel,cc,val])
        last=0
        for tick,on,ch,pitch,velocity in events:
            if ch!=channel: continue
            data+=vlq(tick-last)+bytes([(0x90 if on else 0x80)+channel,pitch,velocity])
            last=tick
        data+=vlq(max(0,BEATS*PPQ-last))+b'\xff\x2f\0'
        tracks.append(data)
    path.write_bytes(b'MThd'+struct.pack('>IHHH',6,1,len(tracks),PPQ)+b''.join(b'MTrk'+struct.pack('>I',len(t))+t for t in tracks))

class Synth:
    def __init__(self,soundfont):
        self.lib=C.CDLL('libfluidsynth.so.3')
        api={
            'new_fluid_settings':([],C.c_void_p),
            'fluid_settings_setnum':([C.c_void_p,C.c_char_p,C.c_double],C.c_int),
            'fluid_settings_setint':([C.c_void_p,C.c_char_p,C.c_int],C.c_int),
            'new_fluid_synth':([C.c_void_p],C.c_void_p),
            'fluid_synth_sfload':([C.c_void_p,C.c_char_p,C.c_int],C.c_int),
            'fluid_synth_program_change':([C.c_void_p,C.c_int,C.c_int],C.c_int),
            'fluid_synth_cc':([C.c_void_p,C.c_int,C.c_int,C.c_int],C.c_int),
            'fluid_synth_noteon':([C.c_void_p,C.c_int,C.c_int,C.c_int],C.c_int),
            'fluid_synth_noteoff':([C.c_void_p,C.c_int,C.c_int],C.c_int),
            'fluid_synth_write_float':([C.c_void_p,C.c_int,C.c_void_p,C.c_int,C.c_int,C.c_void_p,C.c_int,C.c_int],C.c_int),
            'fluid_synth_set_reverb':([C.c_void_p,C.c_double,C.c_double,C.c_double,C.c_double],C.c_int),
            'fluid_synth_set_chorus':([C.c_void_p,C.c_int,C.c_double,C.c_double,C.c_double,C.c_int],C.c_int),
            'fluid_synth_set_gen':([C.c_void_p,C.c_int,C.c_int,C.c_float],C.c_int),
            'delete_fluid_synth':([C.c_void_p],None),
            'delete_fluid_settings':([C.c_void_p],None),
        }
        for name,(args,result) in api.items():
            fn=getattr(self.lib,name);fn.argtypes=args;fn.restype=result
        self.settings=self.lib.new_fluid_settings()
        for key,value in [('synth.sample-rate',RATE),('synth.gain',.40)]:
            self.lib.fluid_settings_setnum(self.settings,key.encode(),value)
        for key,value in [('synth.polyphony',256),('synth.cpu-cores',1),('synth.reverb.active',1),('synth.chorus.active',1)]:
            self.lib.fluid_settings_setint(self.settings,key.encode(),value)
        self.synth=self.lib.new_fluid_synth(self.settings)
        if self.lib.fluid_synth_sfload(self.synth,str(soundfont).encode(),1)<0: raise RuntimeError('Soundfont load failed')
        self.lib.fluid_synth_set_reverb(self.synth,.77,.42,80,.24)
        self.lib.fluid_synth_set_chorus(self.synth,3,.65,.25,2.8,0)
        for channel,(_,program,volume,pan) in INSTRUMENTS.items():
            self.lib.fluid_synth_program_change(self.synth,channel,program)
            for cc,value in [(7,volume),(10,pan),(91,36),(93,9)]: self.lib.fluid_synth_cc(self.synth,channel,cc,value)
        for ch in [0,1]:
            self.lib.fluid_synth_set_gen(self.synth,ch,34,-8000)
            self.lib.fluid_synth_set_gen(self.synth,ch,38,-2500)
    def render(self,events,bpm):
        frames=round(BEATS*60/bpm*RATE)
        timeline=[]
        for cycle in range(3):
            timeline.extend((cycle*frames+round(tick/(PPQ*BEATS)*frames),on,ch,pitch,velocity) for tick,on,ch,pitch,velocity in events)
        audio=np.zeros((frames*3,2),dtype=np.float32)
        cursor=0
        def block(end):
            nonlocal cursor
            while cursor<end:
                count=min(end-cursor,8192)
                left=np.zeros(count,np.float32);right=np.zeros(count,np.float32)
                self.lib.fluid_synth_write_float(self.synth,count,left.ctypes.data,0,1,right.ctypes.data,0,1)
                audio[cursor:cursor+count,0]=left;audio[cursor:cursor+count,1]=right
                cursor+=count
        for at,on,ch,pitch,velocity in sorted(timeline,key=lambda x:(x[0],x[1])):
            block(at)
            if on:self.lib.fluid_synth_noteon(self.synth,ch,pitch,velocity)
            else:self.lib.fluid_synth_noteoff(self.synth,ch,pitch)
        block(len(audio))
        # The second pass has full natural room tails. Blend its last 50ms into
        # the previous cycle's equivalent tail; the wrap then shares an actual
        # adjacent sample boundary from the continuous render, not a fade to 0.
        audio=sosfilt(butter(2,34,fs=RATE,btype='highpass',output='sos'),audio,axis=0)
        loop=audio[frames:frames*2].copy()
        count=round(.05*RATE)
        weight=(.5-.5*np.cos(np.linspace(0,np.pi,count)))[:,None]
        loop[-count:]=loop[-count:]*(1-weight)+audio[frames-count:frames]*weight
        self.lib.delete_fluid_synth(self.synth);self.lib.delete_fluid_settings(self.settings)
        return loop.astype(np.float32)

def write_wav(path,audio):
    with wave.open(str(path),'wb') as stream:
        stream.setnchannels(2);stream.setsampwidth(2);stream.setframerate(RATE)
        stream.writeframes((np.clip(audio,-.9999,.9999)*32767).astype('<i2').tobytes())

def ffmpeg(*args):
    return subprocess.run(['ffmpeg','-hide_banner','-nostdin','-y',*map(str,args)],capture_output=True,text=True,check=True)

def loudness(path):
    log=ffmpeg('-i',path,'-af','loudnorm=I=-17:TP=-2:LRA=9:print_format=json','-f','null','-').stderr
    begin=log.rfind('{');end=log.rfind('}')
    return json.loads(log[begin:end+1])

def master(audio,stem,work):
    raw=work/(stem+'_raw.wav')
    audio*=.62/max(float(np.max(np.abs(audio))),1e-9)
    write_wav(raw,audio)
    measured=loudness(raw)
    # A single constant gain preserves a periodic boundary and orchestral
    # dynamics. Reserve headroom for Vorbis reconstruction and combat cues.
    gain_db=min(-17-float(measured['input_i']),-2.3-float(measured['input_tp']))
    audio*=10**(gain_db/20)
    mastered=work/(stem+'_master.wav');write_wav(mastered,audio)
    ogg=OUT/(stem+'.ogg')
    ffmpeg('-i',mastered,'-c:a','libvorbis','-q:a','6','-ar',RATE,'-ac',2,'-metadata','title='+stem.replace('_',' ').title(),'-metadata','artist=LAST LECTURE original score','-metadata','license=CC0-1.0 composition; FluidR3 MIT sample attribution in LICENSE.txt',ogg)
    decoded=work/(stem+'_decoded.wav')
    ffmpeg('-i',ogg,'-c:a','pcm_s16le',decoded)
    with wave.open(str(decoded),'rb') as stream:
        decoded_audio=np.frombuffer(stream.readframes(stream.getnframes()),'<i2').reshape(-1,2)/32768
    stats=loudness(ogg)
    diff=np.diff(decoded_audio,axis=0)
    seam=float(np.max(np.abs(decoded_audio[0]-decoded_audio[-1])))
    return {'file':str(ogg.relative_to(ROOT)),'sample_rate':RATE,'channels':2,'frames':len(decoded_audio),'duration_seconds':len(decoded_audio)/RATE,'codec':'Vorbis quality 6','integrated_lufs':float(stats['input_i']),'true_peak_dbtp':float(stats['input_tp']),'loudness_range_lu':float(stats['input_lra']),'sample_peak_dbfs':20*math.log10(max(float(np.max(np.abs(decoded_audio))),1e-12)),'clipped_samples':int(np.sum(np.abs(decoded_audio)>=.99997)),'wrap_step_dbfs':20*math.log10(max(seam,1e-12)),'wrap_step_relative_to_99_9_percentile_derivative':seam/max(float(np.quantile(np.abs(diff),.999)),1e-12),'recommended_runtime_gain_db':-6,'loop':True,'loop_offset_seconds':0,'sha256':hashlib.sha256(ogg.read_bytes()).hexdigest()}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--soundfont',required=True,type=Path)
    parser.add_argument('--work-dir',default=Path('/workspace/work/m23_music/render'),type=Path)
    args=parser.parse_args();args.work_dir.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    results=[]
    for phase,bpm in [(1,110),(2,132)]:
        stem=f'compiler_phase_{phase}'
        events=score(phase)
        write_midi(OUT/(stem+'.mid'),events,bpm)
        print(f'Rendering phase {phase}: {len(events)//2} original notes, {bpm} BPM',flush=True)
        audio=Synth(args.soundfont).render(events,bpm)
        result=master(audio,stem,args.work_dir)
        result.update({'bpm':bpm,'bars':BARS,'beats':BEATS,'key':'D harmonic minor / D minor','note_count':len(events)//2,'composition':'The Unfinished Proof','phase':phase})
        results.append(result);print(json.dumps(result),flush=True)
    metadata={'title':'The Unfinished Proof / البرهان غير المكتمل','original_composition':True,'composition_license':'CC0-1.0','sample_library':'FluidR3 GM, MIT license; attribution in LICENSE.txt','soundfont_sha256':hashlib.sha256(args.soundfont.read_bytes()).hexdigest(),'renderer':'libfluidsynth, deterministic MIDI scheduling; SciPy high-pass; static loudness gain; FFmpeg Vorbis','loop_method':'three consecutive score cycles rendered; middle cycle retained; last50ms blend toward equivalent previous-cycle tail, preserving continuous wrap','runtime':{'battle_gain_db':-6,'written_intro_or_pause_additional_duck_db':-12,'phase_crossfade_seconds':1.2,'keep_attack_cues_on_separate_bus':True},'tracks':results}
    metadata['sample_library_provenance']={
        'license_file':'assets/audio/m23/LICENSE.txt','license':'MIT',
        'source_url':'https://deb.debian.org/debian/pool/main/f/fluid-soundfont/fluid-soundfont-gm_3.1-5.3_all.deb',
        'source_package_sha256':'6f531493ac4e4d9772fd96b2488ea1790af81c196135fbdd25997da0781fc60e',
        'license_source_url':'https://deb.debian.org/debian/pool/main/f/fluid-soundfont/fluid-soundfont_3.1-5.3.debian.tar.xz',
        'soundfont_bundled':False}
    (OUT/'music_manifest.json').write_text(json.dumps(metadata,indent=2,ensure_ascii=False)+'\n')

if __name__=='__main__': main()
