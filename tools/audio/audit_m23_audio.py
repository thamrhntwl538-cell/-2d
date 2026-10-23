#!/usr/bin/env python3
"""Decode the shipped M23 audio and check formats, peaks, boundaries and cues.
No music is generated or modified by this audit.
"""
import hashlib,json,math,subprocess
from pathlib import Path
import numpy as np
from compose_m23_boss import ROOT,OUT,RATE,loudness

checks=0
failures=[]
def check(condition,message):
    global checks
    checks+=1
    if not condition:failures.append(message)

def db(value):return 20*math.log10(max(float(value),1e-12))

def decode(path):
    command=['ffmpeg','-hide_banner','-loglevel','error','-i',str(path),'-f','f32le','-acodec','pcm_f32le','-ac','2','-ar',str(RATE),'-']
    raw=subprocess.run(command,check=True,capture_output=True).stdout
    return np.frombuffer(raw,'<f4').reshape(-1,2)

def main():
    music=json.loads((OUT/'music_manifest.json').read_text())
    cues=json.loads((OUT/'cues_manifest.json').read_text())
    records=[];cue_signals=[]
    for expected in music['tracks']+cues['cues']+[cues['victory']]:
        path=ROOT/expected['file']
        check(path.exists(),'file exists: '+str(path.relative_to(ROOT)))
        actual_hash=hashlib.sha256(path.read_bytes()).hexdigest()
        check(actual_hash==expected['sha256'],'rendered bytes match manifest: '+path.name)
        info=json.loads(subprocess.run(['ffprobe','-v','error','-select_streams','a:0','-show_entries','stream=codec_name,sample_rate,channels','-of','json',str(path)],check=True,capture_output=True,text=True).stdout)['streams'][0]
        check(int(info['sample_rate'])==RATE and int(info['channels'])==2,'stereo 48k format: '+path.name)
        audio=decode(path)
        duration=len(audio)/RATE
        check(abs(duration-expected['duration_seconds'])<1/RATE+.00001,'decoded duration matches the authored score: '+path.name)
        check(np.isfinite(audio).all(),'decoded samples are finite: '+path.name)
        clipped=int(np.sum(np.abs(audio)>=.99997))
        peak=float(np.max(np.abs(audio)))
        rms=float(np.sqrt(np.mean(audio.astype(np.float64)**2)))
        check(clipped==0 and peak<.90,'render has headroom and no clipped samples: '+path.name)
        check(rms>.005,'render contains non-silent audio: '+path.name)
        record={'file':expected['file'],'duration_seconds':duration,'decoded_frames':len(audio),'sample_peak_dbfs':db(peak),'rms_dbfs':db(rms),'clipped_samples':clipped,'sha256':actual_hash}
        if expected.get('loop',False):
            imported=path.with_suffix(path.suffix+'.import').read_text()
            check('loop=true' in imported and 'beat_count=96' in imported,'Godot imports the complete musical loop: '+path.name)
            check(f"bpm={expected['bpm']}" in imported,'Godot tempo metadata matches the score: '+path.name)
            derivative=np.abs(np.diff(audio,axis=0))
            boundary=float(np.max(np.abs(audio[0]-audio[-1])))
            normal=float(np.quantile(derivative,.999))
            ratio=boundary/max(normal,1e-12)
            check(ratio<1.0,'wrap discontinuity stays below the normal 99.9th waveform derivative: '+path.name)
            stats=loudness(path)
            check(-19<float(stats['input_i'])<-15,'battle loudness remains in the intended range: '+path.name)
            check(float(stats['input_tp'])<=-1.5,'decoded true peak leaves combat mix headroom: '+path.name)
            check(float(np.sqrt(np.mean((audio[:,0]-audio[:,1])**2)))>.002,'orchestral mix has actual stereo content: '+path.name)
            record.update({'integrated_lufs':float(stats['input_i']),'true_peak_dbtp':float(stats['input_tp']),'wrap_step_dbfs':db(boundary),'wrap_step_to_99_9_derivative_ratio':ratio})
        else:
            check(float(np.max(np.abs(audio[-64:])))<.003,'one-shot ends without a hard audio edge: '+path.name)
            if path.suffix=='.wav':cue_signals.append((path.name,audio.mean(axis=1)))
        records.append(record)
    similarities=[]
    for i,(left,a) in enumerate(cue_signals):
        for right,b in cue_signals[i+1:]:
            size=max(len(a),len(b))
            padded_a=np.pad(a,(0,size-len(a)));padded_b=np.pad(b,(0,size-len(b)))
            correlation=float(abs(np.dot(padded_a,padded_b))/max(np.linalg.norm(padded_a)*np.linalg.norm(padded_b),1e-12))
            check(correlation<.80,'warning cues are distinct waveforms: '+left+' / '+right)
            similarities.append({'a':left,'b':right,'absolute_waveform_correlation':correlation})
    license_text=(OUT/'LICENSE.txt').read_text()
    check('Permission is hereby granted, free of charge' in license_text and music['soundfont_sha256'] in license_text,'sample license and exact source provenance are shipped')
    for path in [OUT/'compiler_phase_1.mid',OUT/'compiler_phase_2.mid']:
        data=path.read_bytes()
        check(data[:4]==b'MThd' and int.from_bytes(data[10:12],'big')==15,'editable original multitrack MIDI is present: '+path.name)
    report={'checks':checks,'failures':failures,'decode_tool':'FFmpeg','sample_metrics_tool':'NumPy; FFmpeg loudnorm input measurement','scope':'independent decoding and objective mix/loop/format checks; native playback/crossfade/duck verified by the M23 game QA','listening_claim':False,'files':records,'warning_cue_correlations':similarities}
    (OUT/'audio_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({'checks':checks,'failures':failures,'files':len(records)},indent=2))
    raise SystemExit(0 if not failures else 1)

if __name__=='__main__':main()
