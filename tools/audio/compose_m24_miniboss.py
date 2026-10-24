#!/usr/bin/env python3
"""Original Bell Warden miniature: The Weight Between Chimes.

Render: python3 tools/audio/compose_m24_miniboss.py --soundfont /path/FluidR3_GM.sf2
Requires NumPy, SciPy, libfluidsynth.so.3 and FFmpeg. No network, no copied score,
no external recordings, no packaged soundfont. Source and MIDI: CC0-1.0.
The MIT FluidR3 sample attribution is supplied in assets/audio/m24/music/LICENSE.txt.
"""
from __future__ import annotations
import argparse
import ctypes as C
import hashlib
import json
import math
import struct
import subprocess
import wave
from pathlib import Path
import numpy as np
from scipy.signal import butter, sosfilt

RATE = 48000
PPQ = 480
BPM = 96
BARS = 16
BEATS = BARS * 4
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/audio/m24/music'
TITLE = 'The Weight Between Chimes / الثقل بين الرنّات'
EXPECTED_SF_SHA = '74594e8f4250680adf590507a306655a299935343583256f3b722c48a1bc1cb0'
# Zero-based GM programs. Deliberately no tubular-bell, warning beep, snare roll,
# cymbal crash, full brass section or main-boss orchestral climax.
INSTRUMENTS = {
    0: ('Pizzicato clockwork', 45, 77, 40),
    1: ('Contrabass feet', 43, 77, 59),
    2: ('Bassoon question', 70, 80, 49),
    3: ('Viola answering line', 41, 66, 84),
    4: ('Dust organ', 19, 42, 66),
    5: ('Damped wooden mallet', 12, 43, 97),
    6: ('Soft low frame drum', 116, 62, 58),
}
# Harmonic sentences of four bars: D minor with a brief leading tone at A7.
HARMONY = ['Dm9', 'DmC', 'Bb7', 'A7', 'Gm9', 'DmF', 'Eh', 'A7',
           'Dm9', 'Bb7', 'Gm9', 'A7', 'Bb7', 'DmF', 'Eh', 'A7']
CHORDS = {
    'Dm9': (38, [50, 57, 62, 65], [57, 62, 65, 76]),
    'DmC': (36, [48, 57, 62, 65], [57, 62, 65, 72]),
    'Bb7': (34, [46, 53, 58, 62], [57, 62, 65, 70]),
    'A7': (33, [45, 52, 57, 61], [55, 61, 64, 69]),
    'Gm9': (31, [43, 50, 55, 58], [57, 62, 65, 70]),
    'DmF': (29, [41, 50, 57, 62], [57, 62, 65, 69]),
    'Eh': (28, [40, 50, 55, 58], [55, 58, 62, 64]),
}
# A compact descending-fifth question recurs with changed answers. All timings
# are authored in beats; held notes and rests make room for metal contact SFX.
THEME = [
    [(0,62,.70),(1.25,57,.40),(2,62,.65),(3,64,.35),(3.5,65,.35)],
    [(0,64,1.05),(1.5,62,.65),(2.75,57,.65)],
    [(0,62,.65),(1,65,.65),(2,69,1.15),(3.5,65,.30)],
    [(0,64,.70),(1.25,61,.45),(2,57,1.10)],
    [(0,62,.70),(1.25,58,.40),(2,62,.65),(3,65,.65)],
    [(0,64,1.10),(1.5,62,.75),(3,57,.60)],
    [(0,58,.70),(1.25,62,.40),(2,64,.65),(3,67,.65)],
    [(0,64,1.05),(1.5,61,.50),(2.5,57,.60),(3.5,61,.30)],
    [(0,74,.70),(1.25,69,.40),(2,74,.65),(3,76,.35),(3.5,77,.35)],
    [(0,77,.95),(1.5,74,.65),(2.75,70,.65)],
    [(0,74,.65),(1,70,.65),(2,67,1.10),(3.5,65,.30)],
    [(0,64,.70),(1.25,61,.45),(2,57,1.10)],
    [(0,65,.70),(1.25,62,.40),(2,58,.65),(3,62,.65)],
    [(0,64,.95),(1.5,62,1.20)],
    [(0,58,.65),(1,62,.65),(2,64,.85),(3.25,62,.40)],
    [(0,61,.80),(1.5,57,.70),(3,61,.55)],
]

def note(events, ch, pitch, start, length, velocity, total_beats):
    if not 0 <= start < total_beats:
        return
    on = round(start * PPQ)
    off = min(round(total_beats * PPQ) - 1, round((start + length) * PPQ))
    events.extend([(on, 1, ch, int(pitch), int(np.clip(velocity, 1, 120))),
                   (off, 0, ch, int(pitch), 0)])

def fight_score():
    events = []
    def n(ch, pitch, start, length, velocity):
        note(events, ch, pitch, start, length, velocity, BEATS)
    for bar, chord in enumerate(HARMONY):
        root, broken, held = CHORDS[chord]
        t = bar * 4
        arch = [0, 3, 6, -1][bar // 4]
        # The eight-note clock has a 3+3+2 accent but no attack-state coupling.
        # The final eighth of each fourth bar rests before the next sentence.
        order = [0, 2, 1, 3, 1, 2, 3, 1]
        for step, degree in enumerate(order):
            if bar % 4 == 3 and step >= 6:
                continue
            n(0, broken[degree], t + step*.5, .25 if step % 3 else .34,
              64 + arch + (10 if step in (0,3,6) else -3))
        n(1, root, t, 1.30, 72 + arch)
        n(1, root, t + 2, 1.15, 65 + arch)
        # Soft held colours are placed below bright clang harmonics.
        if bar % 2 == 0:
            for pitch in held[:3]:
                n(4, pitch - 12, t + .04, 7.70, 41 + arch // 2)
        # The lead changes from low bassoon to a viola answer halfway through;
        # the reprise is an arrangement variation, not a second combat phase.
        for start, pitch, duration in THEME[bar]:
            lead = 2 if bar < 8 or bar >= 12 else 3
            n(lead, pitch, t + start, duration, 78 + arch + (3 if start == 0 else -4))
        if bar in (1,5,9,13):
            for off, pitch in ((0.5,held[1]), (2.5,held[2])):
                n(3, pitch, t + off, 1.10, 48 + arch)
        # Tiny marimba replies occur only at written phrase endings. This is
        # muted wood, not a bell or a high electronic combat indicator.
        if bar in (2,6,10,14):
            for off, pitch in ((2.5,held[1]),(3.25,held[2])):
                n(5, pitch, t + off, .22, 44 + arch)
        # Half-note footfalls rather than a cinematic percussion battery.
        n(6, 36, t, .32, 57 + arch)
        if bar % 4 != 3:
            n(6, 36 if bar % 2 else 38, t + 2, .26, 47 + arch)
        if bar in (6,10):
            n(6, 36, t + 3.25, .16, 39)
    return sorted(events, key=lambda x: (x[0], x[1]))

def victory_score():
    events = []
    def n(ch, pitch, start, length, velocity):
        note(events, ch, pitch, start, length, velocity, 8)
    for pitch in (43,50,58): n(4,pitch,0,1.6,42)
    for pitch in (45,52,61): n(4,pitch,1.75,1.75,40)
    for pitch in (38,50,57,62,65): n(4,pitch,3.5,3.7,38)
    for start,pitch,length in [(0,64,.55),(.75,65,.55),(1.5,61,.65),
                               (2.5,62,.65),(3.5,69,.70),(4.5,65,.65),(5.5,62,1.8)]:
        n(3,pitch,start,length,70 if start < 3.5 else 62)
    for start,pitch in [(0,43),(1.75,45),(3.5,38)]: n(1,pitch,start,1.5,57)
    for start,pitch in [(3.5,62),(4.5,65),(5.5,69)]: n(5,pitch,start,.42,38)
    return sorted(events, key=lambda x: (x[0], x[1]))

def vlq(value):
    data = [value & 127]
    while value >> 7:
        value >>= 7
        data.insert(0, (value & 127) | 128)
    return bytes(data)

def write_midi(path, events, bpm, total_beats, title):
    tempo = round(60000000/bpm)
    encoded = title.encode()
    meta = b'\0\xff\x51\x03' + tempo.to_bytes(3,'big')
    meta += b'\0\xff\x58\x04\x04\x02\x18\x08'
    meta += b'\0\xff\x03' + vlq(len(encoded)) + encoded + b'\0\xff\x2f\0'
    tracks = [meta]
    for channel, (name,program,volume,pan) in INSTRUMENTS.items():
        encoded = name.encode()
        data = b'\0\xff\x03' + vlq(len(encoded)) + encoded
        data += b'\0' + bytes([0xC0+channel,program])
        for cc,val in [(7,volume),(10,pan),(91,28),(93,0)]:
            data += b'\0'+bytes([0xB0+channel,cc,val])
        last = 0
        for tick,on,ch,pitch,velocity in events:
            if ch != channel: continue
            data += vlq(tick-last)+bytes([(0x90 if on else 0x80)+channel,pitch,velocity])
            last = tick
        data += vlq(max(0,round(total_beats*PPQ)-last))+b'\xff\x2f\0'
        tracks.append(data)
    path.write_bytes(b'MThd'+struct.pack('>IHHH',6,1,len(tracks),PPQ)+b''.join(
        b'MTrk'+struct.pack('>I',len(track))+track for track in tracks))

class Synth:
    def __init__(self, soundfont):
        self.lib = C.CDLL('libfluidsynth.so.3')
        api = {
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
            fn=getattr(self.lib,name); fn.argtypes=args; fn.restype=result
        self.settings = self.lib.new_fluid_settings()
        for key,value in [('synth.sample-rate',RATE),('synth.gain',.40)]:
            self.lib.fluid_settings_setnum(self.settings,key.encode(),value)
        for key,value in [('synth.polyphony',192),('synth.cpu-cores',1),
                          ('synth.reverb.active',1),('synth.chorus.active',0)]:
            self.lib.fluid_settings_setint(self.settings,key.encode(),value)
        self.synth = self.lib.new_fluid_synth(self.settings)
        if self.lib.fluid_synth_sfload(self.synth,str(soundfont).encode(),1) < 0:
            raise RuntimeError('Soundfont load failed')
        self.lib.fluid_synth_set_reverb(self.synth,.64,.52,65,.20)
        self.lib.fluid_synth_set_chorus(self.synth,0,0.,.25,2.8,0)
        for channel,(_,program,volume,pan) in INSTRUMENTS.items():
            self.lib.fluid_synth_program_change(self.synth,channel,program)
            for cc,value in [(7,volume),(10,pan),(91,28),(93,0)]:
                self.lib.fluid_synth_cc(self.synth,channel,cc,value)
        # Quicker wood/string releases preserve gaps around actual bell hits.
        self.lib.fluid_synth_set_gen(self.synth,0,38,-2800)

    def render(self, events, bpm, total_beats, loop):
        frames = round(total_beats*60/bpm*RATE)
        copies = 3 if loop else 1
        total = frames*copies if loop else frames+round(1.8*RATE)
        audio = np.zeros((total,2),dtype=np.float32)
        timeline = [(cycle*frames+round(tick/(PPQ*total_beats)*frames),on,ch,pitch,velocity)
                    for cycle in range(copies) for tick,on,ch,pitch,velocity in events]
        cursor = 0
        def block(end):
            nonlocal cursor
            while cursor < end:
                count = min(end-cursor,8192)
                left=np.zeros(count,np.float32); right=np.zeros(count,np.float32)
                self.lib.fluid_synth_write_float(self.synth,count,left.ctypes.data,0,1,
                                                 right.ctypes.data,0,1)
                audio[cursor:cursor+count,0]=left
                audio[cursor:cursor+count,1]=right
                cursor+=count
        for at,on,ch,pitch,velocity in sorted(timeline,key=lambda x:(x[0],x[1])):
            block(at)
            if on: self.lib.fluid_synth_noteon(self.synth,ch,pitch,velocity)
            else: self.lib.fluid_synth_noteoff(self.synth,ch,pitch)
        block(total)
        self.lib.delete_fluid_synth(self.synth)
        self.lib.delete_fluid_settings(self.settings)
        audio = sosfilt(butter(2,36,fs=RATE,btype='highpass',output='sos'),audio,axis=0)
        # A broad -2 dB shelf above 2 kHz gives metal hit/voice transients room.
        low = sosfilt(butter(1,2100,fs=RATE,btype='lowpass',output='sos'),audio,axis=0)
        audio = low + (audio-low)*10**(-2/20)
        if loop:
            result = audio[frames:frames*2].copy()
            count = round(.08*RATE)
            weight=(.5-.5*np.cos(np.linspace(0,np.pi,count)))[:,None]
            # Match an adjacent boundary in the same continuous render. There
            # is no end silence or fade-to-zero hole in the repeating score.
            result[-count:] = result[-count:]*(1-weight)+audio[frames-count:frames]*weight
        else:
            result = audio
            count = round(.7*RATE)
            result[-count:] *= (.5+.5*np.cos(np.linspace(0,np.pi,count)))[:,None]
            result[:round(.025*RATE)] *= np.linspace(0,1,round(.025*RATE))[:,None]
        return result.astype(np.float32)

def write_wav(path,audio):
    with wave.open(str(path),'wb') as stream:
        stream.setnchannels(2); stream.setsampwidth(2); stream.setframerate(RATE)
        stream.writeframes((np.clip(audio,-.9999,.9999)*32767).astype('<i2').tobytes())

def ffmpeg(*args):
    return subprocess.run(['ffmpeg','-hide_banner','-nostdin','-y',*map(str,args)],
                          capture_output=True,text=True,check=True)

def loudness(path):
    log = ffmpeg('-i',path,'-af','loudnorm=I=-17:TP=-3.3:LRA=9:print_format=json',
                 '-f','null','-').stderr
    return json.loads(log[log.rfind('{'):log.rfind('}')+1])

def master(audio,stem,work,loop):
    # Static, memoryless gentle peak shaping preserves the exact loop period.
    # No lookahead gate, time-varying limiter or normalization across loop ends.
    audio /= max(float(np.max(np.abs(audio))),1e-12)
    audio = np.tanh(audio*1.25)
    audio *= .62/max(float(np.max(np.abs(audio))),1e-12)
    raw = work/(stem+'_raw.wav')
    write_wav(raw,audio)
    initial=loudness(raw)
    gain=min(-17.0-float(initial['input_i']),-3.7-float(initial['input_tp']))
    audio*=10**(gain/20)
    mastered=work/(stem+'_master.wav')
    write_wav(mastered,audio)
    ogg=OUT/(stem+'.ogg')
    ffmpeg('-i',mastered,'-c:a','libvorbis','-q:a','6','-ar',RATE,'-ac',2,
           '-metadata','title='+TITLE.split(' / ')[0]+(' - miniature' if loop else ' - release'),
           '-metadata','artist=LAST LECTURE original score',
           '-metadata','license=CC0-1.0 composition; FluidR3 MIT sample attribution in LICENSE.txt',ogg)
    decoded=work/(stem+'_decoded.wav')
    ffmpeg('-i',ogg,'-c:a','pcm_s16le',decoded)
    with wave.open(str(decoded),'rb') as stream:
        data=np.frombuffer(stream.readframes(stream.getnframes()),'<i2').reshape(-1,2)/32768
    stats=loudness(ogg)
    seam=float(np.max(np.abs(data[0]-data[-1])))
    derivative=float(np.quantile(np.abs(np.diff(data,axis=0)),.999))
    rms=lambda x: float(np.sqrt(np.mean(np.square(x))))
    def db(value): return 20*math.log10(max(value,1e-12))
    result={
        'file':str(ogg.relative_to(ROOT)), 'sample_rate':RATE, 'channels':2,
        'frames':len(data), 'duration_seconds':len(data)/RATE, 'codec':'Vorbis quality 6',
        'integrated_lufs':float(stats['input_i']), 'true_peak_dbtp':float(stats['input_tp']),
        'loudness_range_lu':float(stats['input_lra']),
        'sample_peak_dbfs':db(float(np.max(np.abs(data)))),
        'clipped_samples':int(np.sum(np.abs(data)>=.99997)),
        'recommended_runtime_gain_db':-8, 'loop':loop, 'loop_offset_seconds':0,
        'sha256':hashlib.sha256(ogg.read_bytes()).hexdigest(),
        'master_constant_gain_db':gain, 'peak_shaping':'static tanh drive 1.25 before gain',
        'first_50ms_rms_dbfs':db(rms(data[:2400])),
        'last_50ms_rms_dbfs':db(rms(data[-2400:])),
        'stereo_correlation':float(np.corrcoef(data[:,0],data[:,1])[0,1]),
        'final_sample_abs':float(np.max(np.abs(data[-1]))),
    }
    if loop:
        result.update({'wrap_step_dbfs':db(seam),
                       'wrap_step_relative_to_99_9_percentile_derivative':seam/max(derivative,1e-12)})
    assert result['clipped_samples']==0
    assert result['true_peak_dbtp']<=-3.0, result
    if loop:
        assert 30<=result['duration_seconds']<=50
        assert result['wrap_step_relative_to_99_9_percentile_derivative']<1.0, result
    return result

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--soundfont',required=True,type=Path)
    parser.add_argument('--work-dir',default=Path('/workspace/work/m24_music/render'),type=Path)
    args=parser.parse_args()
    sf_sha=hashlib.sha256(args.soundfont.read_bytes()).hexdigest()
    if sf_sha != EXPECTED_SF_SHA:
        raise SystemExit('Use the documented MIT FluidR3 soundfont or update provenance explicitly.')
    OUT.mkdir(parents=True,exist_ok=True); args.work_dir.mkdir(parents=True,exist_ok=True)
    results=[]
    for stem,events,bpm,total,loop in [
        ('bell_warden_clockwork',fight_score(),BPM,BEATS,True),
        ('bell_warden_release',victory_score(),112,8,False),
    ]:
        print(f'Rendering {stem}: {len(events)//2} original notes, {bpm} BPM',flush=True)
        midi=OUT/(stem+'.mid')
        write_midi(midi,events,bpm,total,TITLE.split(' / ')[0])
        audio=Synth(args.soundfont).render(events,bpm,total,loop)
        result=master(audio,stem,args.work_dir,loop)
        result.update({'bpm':bpm,'bars':total/4,'beats':total,
                       'key':'D minor with A7 leading tone', 'note_count':len(events)//2,
                       'midi_file':str(midi.relative_to(ROOT)),
                       'midi_sha256':hashlib.sha256(midi.read_bytes()).hexdigest()})
        results.append(result); print(json.dumps(result),flush=True)
    metadata={
        'title':TITLE,'original_composition':True,'composition_license':'CC0-1.0',
        'purpose':'Compact Bell Warden miniboss score, smaller in scale than the M23 main boss',
        'original_sources':'Authored note events in tools/audio/compose_m24_miniboss.py and supplied MIDI',
        'external_game_music_or_recordings_used':False,
        'renderer':'libfluidsynth + MIT FluidR3; 36Hz high-pass; broad -2dB upper shelf; static peak shaping/gain; FFmpeg Vorbis',
        'loop_method':'Three continuous score cycles, middle retained; final80ms blends to equivalent previous-cycle tail; no silence/fade-to-zero',
        'instrument_programs':{str(ch):{'name':spec[0],'gm_zero_based_program':spec[1]} for ch,spec in INSTRUMENTS.items()},
        'runtime':{'battle_gain_db':-8,'victory_gain_db':-8,
                   'pause_or_cinematic_additional_duck_db':-12,
                   'warning_additional_duck_db':0,
                   'attack_preparation_audio_changes':False,
                   'fade_in_seconds':.85,'fade_out_seconds':.65,
                   'sections':1,'phase2_requests_continue_same_score':True},
        'tracks':results,
        'sample_library_provenance':{
            'name':'FluidR3 GM','license':'MIT','soundfont_sha256':sf_sha,
            'license_file':'assets/audio/m24/music/LICENSE.txt',
            'source_url':'https://deb.debian.org/debian/pool/main/f/fluid-soundfont/fluid-soundfont-gm_3.1-5.3_all.deb',
            'source_package_sha256':'6f531493ac4e4d9772fd96b2488ea1790af81c196135fbdd25997da0781fc60e',
            'license_source_url':'https://deb.debian.org/debian/pool/main/f/fluid-soundfont/fluid-soundfont_3.1-5.3.debian.tar.xz',
            'soundfont_bundled':False},
        'listening_review':'No human listening review claimed; objective measurements and runtime checks supplied.',
    }
    (OUT/'music_manifest.json').write_text(json.dumps(metadata,indent=2,ensure_ascii=False)+'\n')
    qa={'asset_checks_pass':True,'measured_after_vorbis_decode':True,'tracks':results,
        'soundfont_external_to_project':not args.soundfont.resolve().is_relative_to(ROOT),
        'm23_audio_check':'Compare recorded baseline in runtime QA; this script writes m24/music only.',
        'human_listening_claimed':False}
    (OUT/'music_audio_qa.json').write_text(json.dumps(qa,indent=2,ensure_ascii=False)+'\n')

if __name__=='__main__': main()
