#!/usr/bin/env python3
"""Objective checks of the shipped original character/SFX pack and event map.
This is file/mix verification, not a claim of subjective listening review.
"""
from pathlib import Path
import hashlib,json,math,subprocess,wave
import numpy as np
from scipy.signal import correlate
from make_m23_character_audio import ROOT,OUT,RATE,VOICES

checks=0;failures=[]
def check(condition,message):
 global checks
 checks+=1
 if not condition:failures.append(message)
def db(value):return 20*math.log10(max(float(value),1e-12))
def read_wav(path):
 with wave.open(str(path),'rb') as stream:
  info={'channels':stream.getnchannels(),'sample_width':stream.getsampwidth(),'sample_rate':stream.getframerate(),'frames':stream.getnframes()}
  audio=np.frombuffer(stream.readframes(stream.getnframes()),'<i2').reshape(-1,info['channels']).astype(np.float64)/32768
 return audio,info
def periodicity(audio):
 mono=audio.mean(axis=1);size=min(len(mono),round(.12*RATE))
 starts=range(0,max(1,len(mono)-size+1),max(1,size//3))
 start=max(starts,key=lambda at:np.mean(mono[at:at+size]**2))
 segment=mono[start:start+size].copy();segment-=segment.mean()
 ac=correlate(segment,segment,mode='full',method='fft')[size-1:]
 left=round(RATE/500);right=min(len(ac),round(RATE/45))
 return float(np.max(ac[left:right])/max(ac[0],1e-12))
def decoded_music(name):
 raw=subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-i',str(OUT/name),'-f','f32le','-ac','2','-ar',str(RATE),'-'],check=True,capture_output=True).stdout
 return np.frombuffer(raw,'<f4').reshape(-1,2).astype(np.float64)
def add(mix,signal,time,gain):
 start=round(time*RATE);length=min(len(signal),len(mix)-start)
 mix[start:start+length]+=signal[:length]*10**(gain/20)

def main():
 manifest=json.loads((OUT/'character_audio_manifest.json').read_text())
 event_manifest=json.loads((OUT/'event_manifest.json').read_text())
 signals={};records=[]
 for expected in manifest['files']:
  path=ROOT/expected['file']
  check(path.exists(),'new file exists: '+path.name)
  audio,info=read_wav(path)
  check(info['channels']==2 and info['sample_width']==2 and info['sample_rate']==RATE,'native stereo PCM16/48k format: '+path.name)
  check(abs(info['frames']/RATE-expected['duration_seconds'])<1/RATE,'duration matches the cue contract: '+path.name)
  digest=hashlib.sha256(path.read_bytes()).hexdigest()
  check(digest==expected['sha256'],'file matches its manifest: '+path.name)
  peak=float(np.max(np.abs(audio)));rms=float(np.sqrt(np.mean(audio*audio)))
  clipped=int(np.sum(np.abs(audio)>=.99997))
  check(clipped==0 and peak<.85,'headroom and no clipped samples: '+path.name)
  check(-36<db(rms)<-7,'non-silent bounded cue energy: '+path.name)
  check(float(np.max(np.abs(audio[:16])))<.002 and float(np.max(np.abs(audio[-16:])))<.002,'soft sample boundaries: '+path.name)
  check(float(np.max(np.abs(audio.mean(axis=0))))<.012,'negligible DC: '+path.name)
  record={'file':expected['file'],'duration_seconds':info['frames']/RATE,'sample_peak_dbfs':db(peak),'rms_dbfs':db(rms),'clipped_samples':clipped,'sha256':digest}
  if path.stem in VOICES:
   score=periodicity(audio)
   check(score>.13,'voice includes a periodic glottal source, not only noise: '+path.name)
   record['voiced_periodicity_score']=score
  records.append(record);signals[path.stem]=audio
 events=event_manifest['events']
 for name,entry in events.items():
  check(entry.get('category') in ['hero_voice','boss_voice','effects','ui','environment'],'known event category: '+name)
  check(-42<=float(entry.get('volume_db',-100))<=0,'bounded runtime gain: '+name)
  check(float(entry.get('cooldown',-1))>=0,'nonnegative event cooldown: '+name)
  check(bool(entry.get('files')),'event has sample variants: '+name)
  for source in entry.get('files',[]):
   check((ROOT/source.removeprefix('res://')).exists(),'runtime event sample exists: '+name+' / '+source)
  for layer in entry.get('layers',[]):check(layer in events,'runtime layer exists: '+name+' / '+layer)
  if name.startswith('compiler_'):
   check(entry.get('category')!='hero_voice' and not any('hero' in layer for layer in entry.get('layers',[])),'boss cue cannot produce a hero voice: '+name)
 for key in ['swing','jump','dash','hit','hurt','pickup','save','parry_light','journal_open','journal_close','journal_page','bench','coin','room_transition','heal_start','heal_complete','heal_cancel','spell','footstep_stone','footstep_paper']:
  check(key in events,'world semantic event has a mapping: '+key)
 def no_cycles(name,trail):
  if name in trail:return False
  return all(no_cycles(layer,trail+[name]) for layer in events[name].get('layers',[]))
 check(all(no_cycles(name,[]) for name in events),'event layers cannot recurse in cycles')
 originals=[]
 for old in json.loads((OUT/'music_manifest.json').read_text())['tracks']+json.loads((OUT/'cues_manifest.json').read_text())['cues']+[json.loads((OUT/'cues_manifest.json').read_text())['victory']]:
  path=ROOT/old['file'];digest=hashlib.sha256(path.read_bytes()).hexdigest()
  check(digest==old['sha256'],'existing M23 music/warning audio remains byte-identical: '+path.name)
  originals.append({'file':old['file'],'sha256':digest})
 phase1=decoded_music('compiler_phase_1.ogg');phase2=decoded_music('compiler_phase_2.ogg')
 mixes=[]
 for offset in [1,8,18,36]:
  size=round(1.9*RATE);start=round(offset*RATE)
  mix=phase1[start:start+size].copy()*10**(-6/20)
  for cue,time,gain in [('hero_attack_1',0,-4),('hero_slash_1',0,-7),('combat_hit_1',.09,-6),('compiler_voice_hurt',.11,-4),('footstep_stone_1',.55,-10)]:add(mix,signals[cue],time,gain)
  peak=float(np.max(np.abs(mix)))
  check(peak<.97,'representative music/hero/boss/impact mix has headroom at offset '+str(offset))
  mixes.append({'kind':'melee exchange','music_offset_seconds':offset,'sample_peak_dbfs':db(peak),'clipped_samples':int(np.sum(np.abs(mix)>=1))})
 mix=phase2[:round(2.0*RATE)].copy()*10**((-6-3.5)/20)
 add(mix,signals['compiler_voice_phase'],0,-3)
 old,_=read_wav(OUT/'compiler_phase.wav');add(mix,old,.22,-6)
 peak=float(np.max(np.abs(mix)))
 check(peak<.97,'representative transformation music/voice/seal mix has headroom')
 mixes.append({'kind':'phase transformation with warning duck','sample_peak_dbfs':db(peak),'clipped_samples':int(np.sum(np.abs(mix)>=1))})
 report={'checks':checks,'failures':failures,'files':records,'event_count':len(events),'new_audio_files':len(records),'unchanged_originals':originals,'representative_mixes':mixes,'scope':'objective waveform, format, event-map and proposed-gain mix audit; native event timing/playback is verified separately','subjective_listening_claim':False,'no_reference_audio_used':True}
 (OUT/'character_audio_audit.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
 print(json.dumps({'checks':checks,'failures':failures,'new_files':len(records),'events':len(events),'mixes':mixes},indent=2))
 raise SystemExit(0 if not failures else 1)

if __name__=='__main__':main()
