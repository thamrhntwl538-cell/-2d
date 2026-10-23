#!/usr/bin/env python3
"""Original textured paper/brass combat cues and an orchestral victory sting.
Pure procedural cues use no samples. Victory uses the same MIT FluidR3 sample
library as the original boss score. Run from any directory with --soundfont.
This tool does not regenerate or alter either existing phase loop.
"""
import argparse, ctypes as C, hashlib, json, math, subprocess, wave
from pathlib import Path
import numpy as np
from scipy.signal import butter, sosfilt
from compose_m23_boss import Synth, RATE, ROOT, OUT, PPQ, INSTRUMENTS, ffmpeg, loudness, write_wav

def noise_band(rng,count,lo,hi):
    data=rng.standard_normal(count)
    data=sosfilt(butter(2,[lo,hi],fs=RATE,btype='bandpass',output='sos'),data)
    return data/max(np.sqrt(np.mean(data*data)),1e-9)

def stereo(signal,pan=0):
    return signal[:,None]*np.array([math.sqrt((1-pan)/2),math.sqrt((1+pan)/2)])[None,:]

def add_at(output,signal,time):
    start=round(time*RATE);end=min(len(output),start+len(signal))
    output[start:end]+=signal[:end-start]

def modal(t,freq,decay=.10):
    result=np.zeros_like(t)
    for ratio,level,tail in [(1,1,1),(2.76,.32,.55),(5.4,.14,.27)]:
        result+=level*np.sin(2*np.pi*freq*ratio*t)*np.exp(-t/(decay*tail))
    return result*np.minimum(t/.004,1)

def attack_cues():
    rng=np.random.default_rng(230110)
    result={}
    output=np.zeros((round(.38*RATE),2))
    for when,freq,pan in [(0,554.365,-.30),(.075,659.255,0),(.15,783.991,.30)]:
        t=np.arange(round(.23*RATE))/RATE
        tone=.38*modal(t,freq,.075)
        paper=.10*noise_band(rng,len(t),1700,8500)*np.exp(-t/.022)*np.minimum(t/.002,1)
        add_at(output,stereo(tone+paper,pan),when)
    result['compiler_bolts']=(output,'Three dry ascending brass/pen ticks; the projectile volley warning.')
    t=np.arange(round(.52*RATE))/RATE
    low=noise_band(rng,len(t),180,1300)
    air=noise_band(rng,len(t),1300,7500)
    rise=np.clip(t/.40,0,1)
    envelope=np.sin(np.pi*np.minimum(t/.52,1))**1.6
    # The noise changes from low page scrape to bright page edge; a low
    # resonant pressure layer gives a bodily swish rather than a sine beep.
    mono=(.32*low*(1-rise)+.38*air*rise)*envelope
    mono+=.17*np.sin(2*np.pi*(100*t+95*t*t))*np.exp(-t/.19)*np.minimum(t/.014,1)
    result['compiler_sweep']=(stereo(mono,-.08),'A broad rising paper scrape and low pressure swish; the sweeping-page warning.')
    output=np.zeros((round(.60*RATE),2))
    for i,when in enumerate([0,.15,.30]):
        t=np.arange(round(.30*RATE))/RATE
        wood=.30*noise_band(rng,len(t),440,2900)*np.exp(-t/.018)*np.minimum(t/.001,1)
        body=.30*np.sin(2*np.pi*(146.83+24*i)*t)*np.exp(-t/.075)
        body+=.14*np.sin(2*np.pi*311.13*t)*np.exp(-t/.045)
        ring=.08*modal(t,587.33,.14)
        add_at(output,stereo((wood+body+ring)*np.minimum(t/.002,1),-.18+.18*i),when)
    result['compiler_pillars']=(output,'Three resonant wooden press knocks; the ink-column warning.')
    t=np.arange(round(1.30*RATE))/RATE
    rev=noise_band(rng,len(t),500,10000)*(np.minimum(t/.48,1)**2)*np.exp(-np.maximum(t-.48,0)/.17)*.20
    impact=np.zeros_like(t)
    d=np.maximum(0,t-.48)
    impact[t>=.48]=(.43*np.sin(2*np.pi*(73.416*d[t>=.48]+18*d[t>=.48]**2))*np.exp(-d[t>=.48]/.29)+.12*modal(d[t>=.48],293.665,.33))
    result['compiler_phase']=(stereo(rev+impact,0),'A reverse paper/cymbal breath into a low resonant seal; phase change only.')
    return result

def write_cue(stem,audio,description):
    audio=sosfilt(butter(2,55,fs=RATE,btype='highpass',output='sos'),audio,axis=0)
    fade=min(len(audio)//4,round(.014*RATE))
    audio[:fade]*=np.linspace(0,1,fade)[:,None]
    audio[-fade:]*=np.linspace(1,0,fade)[:,None]
    target=10**(-3.8/20)
    audio*=target/max(float(np.max(np.abs(audio))),1e-9)
    path=OUT/(stem+'.wav');write_wav(path,audio)
    return {'file':str(path.relative_to(ROOT)),'description':description,'original_procedural_audio':True,
            'duration_seconds':len(audio)/RATE,'sample_rate':RATE,'channels':2,'format':'PCM16 WAV',
            'sample_peak_dbfs':20*math.log10(float(np.max(np.abs(audio)))),
            'rms_dbfs':20*math.log10(float(np.sqrt(np.mean(audio*audio)))),
            'clipped_samples':0,'loop':False,'recommended_runtime_gain_db':-6 if stem=='compiler_phase' else -4,
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

def victory(soundfont,work):
    synth=Synth(soundfont)
    bpm=90
    length=7.8
    events=[]
    def note(ch,pitch,beat,duration,velocity):
        for when,on,vel in [(beat,True,velocity),(beat+duration,False,0)]:
            events.append((round(when*60/bpm*RATE),on,ch,pitch,vel))
    for beat,chord in [(0,[50,53,57]),(2,[46,50,53]),(4,[45,49,52]),(6,[50,54,57])]:
        for pitch in chord:
            note(0,pitch+12,beat,1.9,70)
            note(4,pitch+12,beat,2.1,58)
            note(3,pitch,beat,1.6,70)
        note(2,chord[0]-12,beat,1.8,79)
        note(10,38,beat,.45,82 if beat==6 else 63)
    for beat,pitch,dur in [(0,74,.6),(.75,69,.4),(1.25,77,.55),(2,74,1.2),(3.5,76,.4),(4,73,1.3),(5.5,76,.4),(6,78,.6),(6.75,81,.5),(7.5,86,.9)]:
        note(6,pitch,beat,dur,82)
    note(13,86,6,1.8,66)
    output=np.zeros((round(length*RATE),2),np.float32)
    cursor=0
    def render(until):
        nonlocal cursor
        until=min(until,len(output))
        while cursor<until:
            count=min(8192,until-cursor)
            left=np.zeros(count,np.float32);right=np.zeros(count,np.float32)
            synth.lib.fluid_synth_write_float(synth.synth,count,left.ctypes.data,0,1,right.ctypes.data,0,1)
            output[cursor:cursor+count,0]=left;output[cursor:cursor+count,1]=right
            cursor+=count
    for when,on,ch,pitch,vel in sorted(events,key=lambda x:(x[0],x[1])):
        render(when)
        if on:synth.lib.fluid_synth_noteon(synth.synth,ch,pitch,vel)
        else:synth.lib.fluid_synth_noteoff(synth.synth,ch,pitch)
    render(len(output))
    synth.lib.delete_fluid_synth(synth.synth);synth.lib.delete_fluid_settings(synth.settings)
    output=sosfilt(butter(2,34,fs=RATE,btype='highpass',output='sos'),output,axis=0)
    output[:240]*=np.linspace(0,1,240)[:,None]
    output[-round(1.1*RATE):]*=np.linspace(1,0,round(1.1*RATE))[:,None]**1.3
    output*=.62/max(float(np.max(np.abs(output))),1e-9)
    raw=work/'victory_raw.wav';write_wav(raw,output)
    stats=loudness(raw)
    gain=min(-18-float(stats['input_i']),-2.6-float(stats['input_tp']))
    output*=10**(gain/20)
    mastered=work/'victory_master.wav';write_wav(mastered,output)
    path=OUT/'compiler_victory.ogg'
    ffmpeg('-i',mastered,'-c:a','libvorbis','-q:a',6,'-metadata','title=The Unfinished Proof - A Page Turned','-metadata','artist=LAST LECTURE original score',path)
    stats=loudness(path)
    return {'file':str(path.relative_to(ROOT)),'description':'Original motif resolves from D minor to a restrained D major, with strings, horn, choir and one bell. One-shot victory sting.',
            'duration_seconds':length,'sample_rate':RATE,'channels':2,'loop':False,
            'integrated_lufs':float(stats['input_i']),'true_peak_dbtp':float(stats['input_tp']),
            'recommended_runtime_gain_db':-6,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--soundfont',required=True,type=Path)
    parser.add_argument('--work-dir',default=Path('/workspace/work/m23_music/cues'),type=Path)
    args=parser.parse_args();args.work_dir.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    cues=[write_cue(stem,audio,description) for stem,(audio,description) in attack_cues().items()]
    sting=victory(args.soundfont,args.work_dir)
    report={'original_audio':True,'original_procedural_cues_license':'CC0-1.0','victory_composition_license':'CC0-1.0; FluidR3 samples MIT','cues':cues,'victory':sting}
    (OUT/'cues_manifest.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
