#!/usr/bin/env python3
"""Original wordless character voices and tactile LAST LECTURE sound effects.

No recordings, reference-video clips, actor voice models or TTS voices are used.
Vocalizations use a Rosenberg glottal-flow source, changing vowel formants,
aspiration, pitch jitter and short room reflections. All source and new audio
are CC0, consistent with the original M23 procedural audio notice.

python3 tools/audio/make_m23_character_audio.py [--manifest-only]
Requires NumPy and SciPy. Does not alter the existing M23 score or cues.
"""
from pathlib import Path
import argparse,hashlib,json,math,wave
import numpy as np
from scipy.signal import butter,sosfilt,iirpeak,lfilter

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/audio/m23'
RATE=48000
VOWELS={'a':[720,1220,2600,3550],'u':[350,850,2200,3350],
        'e':[490,1750,2500,3500],'o':[460,900,2350,3350],
        'i':[310,2150,3000,3850]}
VOICES={
 'hero_attack_1':(.20,'hero',[285,325,245],['u','a','u'],1.0),
 'hero_attack_2':(.23,'hero',[310,285,250],['e','a','u'],1.0),
 'hero_attack_3':(.19,'hero',[270,320,280],['u','e','u'],.9),
 'hero_jump_1':(.27,'hero',[265,335,315],['u','a','u'],.8),
 'hero_jump_2':(.25,'hero',[300,355,280],['u','e','u'],.8),
 'hero_hurt_1':(.34,'hero',[345,300,215],['a','e','u'],1.2),
 'hero_hurt_2':(.31,'hero',[310,275,205],['e','a','u'],1.2),
 'hero_death':(.96,'hero',[275,220,125],['a','o','u'],1.1),
 'hero_dash_voice':(.24,'hero',[275,320,240],['u','a','u'],.85),
 'hero_focus':(.60,'hero',[240,270,285],['u','i','u'],.45),
 'compiler_voice_intro':(.88,'boss',[91,107,83],['u','o','a'],.6),
 'compiler_voice_attack_1':(.42,'boss',[88,132,92],['u','a','u'],1.2),
 'compiler_voice_attack_2':(.39,'boss',[110,145,98],['e','a','o'],1.1),
 'compiler_voice_attack_3':(.46,'boss',[81,119,87],['o','a','u'],1.25),
 'compiler_voice_hurt':(.40,'boss',[113,97,74],['a','o','u'],1.1),
 'compiler_voice_hurt_2':(.44,'boss',[123,104,79],['e','a','u'],1.2),
 'compiler_voice_phase':(1.72,'boss',[73,92,158,112],['u','a','o'],1.5),
 'compiler_voice_death':(1.58,'boss',[105,90,54],['a','o','u'],1.25),
 'hero_spell_voice':(.32,'hero',[280,345,295],['u','e','a'],1.0),
}

def event(files,category='effects',db=-7,cooldown=.08,layers=(),pitch=(.98,1.02)):
 return {'files':['res://assets/audio/m23/'+name+'.wav' for name in files],
         'volume_db':db,'category':category,'cooldown':cooldown,
         'max_instances':1 if category.endswith('_voice') else 3,
         'pitch_min':pitch[0],'pitch_max':pitch[1],'layers':list(layers)}

def event_definitions():
 events={
  'hero_attack':event(['hero_attack_1','hero_attack_2','hero_attack_3'],'hero_voice',-4,.52),
  'hero_jump':event(['hero_jump_1','hero_jump_2'],'hero_voice',-4,.38),
  'hero_hurt':event(['hero_hurt_1','hero_hurt_2'],'hero_voice',-3.5,.65),
  'hero_death':event(['hero_death'],'hero_voice',-3,.5,pitch=(1,1)),
  'hero_dash_voice':event(['hero_dash_voice'],'hero_voice',-5,.7),
  'hero_focus':event(['hero_focus'],'hero_voice',-7,1.2),
  'swing':event(['hero_slash_1','hero_slash_2'],db=-7,cooldown=.07,layers=['hero_attack']),
  'jump':event(['hero_jump_1','hero_jump_2'],'hero_voice',-4,.38),
  'dash':event(['hero_dash'],db=-7,cooldown=.15,layers=['hero_dash_voice']),
  'hit':event(['combat_hit_1','combat_hit_2'],db=-6,cooldown=.055),
  'hurt':event(['combat_hurt'],db=-7,cooldown=.20,layers=['hero_hurt']),
  'parry_light':event(['combat_parry'],db=-6,cooldown=.10),
  'footstep':event(['footstep_1','footstep_2','footstep_3','footstep_4'],db=-10,cooldown=.125),
  'land':event(['hero_land'],db=-8,cooldown=.20),
  'pickup':event(['coin_pickup_1','coin_pickup_2'],'ui',-7,.035),
  'save':event(['bench_rest'],'ui',-7,1.0),
  'book_open':event(['book_open'],'ui',-8,.18),
  'book_page':event(['book_page'],'ui',-8,.12),
  'book_close':event(['book_close'],'ui',-8,.18),
  'puzzle_success':event(['puzzle_success'],'ui',-7,.6),
  'puzzle_error':event(['puzzle_error'],'ui',-10,.35),
  'paper_rustle':event(['paper_rustle'],'environment',-12,2.0),
  'chain_tink':event(['chain_tink'],'environment',-12,3.0),
  'lamp_flicker':event(['lamp_flicker'],'environment',-13,2.5),
  'room_enter':event(['door_transition'],'environment',-10,.7),
  'compiler_release':event(['compiler_release'],db=-6,cooldown=.07),
  'compiler_bolts':event(['compiler_bolts'],db=-4,cooldown=.15,pitch=(1,1)),
  'compiler_sweep':event(['compiler_sweep'],db=-4,cooldown=.15,pitch=(1,1)),
  'compiler_pillars':event(['compiler_pillars'],db=-4,cooldown=.15,pitch=(1,1)),
  'compiler_phase':event(['compiler_phase'],db=-6,cooldown=1.0,pitch=(1,1)),
  'footstep_stone':event(['footstep_stone_1','footstep_stone_2'],db=-10,cooldown=.125),
  'footstep_paper':event(['footstep_paper_1','footstep_paper_2'],db=-10,cooldown=.125),
  'heal_start':event(['hero_focus'],'hero_voice',-7,1.2),
  'heal_complete':event(['heal_complete'],db=-7,cooldown=.45),
  'heal_cancel':event(['heal_cancel'],db=-9,cooldown=.25),
  'hero_spell_voice':event(['hero_spell_voice'],'hero_voice',-4,.65),
  'spell':event(['spell_cast'],db=-6,cooldown=.12,layers=['hero_spell_voice']),
 }
 for name in [key for key in VOICES if key.startswith('compiler_voice')]:
  important=name in ['compiler_voice_intro','compiler_voice_phase','compiler_voice_death']
  events[name]=event([name],'boss_voice',-3 if important else -4,.3 if important else 1.1,pitch=(1,1) if important else (.98,1.02))
  if important:events[name]['preempt_category']=True
 events['hero_death']['preempt_category']=True
 for alias,target in {'journal_open':'book_open','journal_close':'book_close','journal_page':'book_page',
                      'bench':'save','coin':'pickup','room_transition':'room_enter'}.items():
  events[alias]=dict(events[target])
 return events

def smooth(value):
 value=np.clip(value,0,1)
 return value*value*(3-2*value)

def band_noise(rng,count,lo=250,hi=7000):
 noise=sosfilt(butter(2,[lo,hi],fs=RATE,btype='bandpass',output='sos'),rng.standard_normal(count))
 return noise/max(np.sqrt(np.mean(noise*noise)),1e-8)

def room(signal,depth=.07):
 output=np.stack([signal,signal],axis=1)*.7071
 for channel,delays in [(0,[(.023,depth),(.069,depth*.40)]),(1,[(.037,depth),(.083,depth*.38)])]:
  for delay,gain in delays:
   count=round(delay*RATE)
   output[count:,channel]+=signal[:-count]*gain
 return output

def voice(profile,seed):
 duration,kind,pitches,vowels,effort=profile
 rng=np.random.default_rng(seed)
 count=round(duration*RATE);t=np.arange(count)/RATE;u=t/duration
 f0=np.interp(u,np.linspace(0,1,len(pitches)),pitches)
 jitter=np.interp(t,np.linspace(0,duration,max(5,round(duration*52))),rng.normal(0,.012 if kind=='boss' else .008,max(5,round(duration*52))))
 f0*=1+jitter+.009*np.sin(2*np.pi*(4.8 if kind=='boss' else 6.3)*t)
 phase=np.cumsum(f0/RATE);p=phase%1
 flow=np.zeros(count)
 opening=p<.62;closing=(p>=.62)&(p<.84)
 flow[opening]=.5*(1-np.cos(np.pi*p[opening]/.62))
 flow[closing]=np.cos(np.pi*.5*(p[closing]-.62)/.22)
 excitation=np.gradient(flow)
 excitation/=max(np.sqrt(np.mean(excitation*excitation)),1e-8)
 if kind=='boss':excitation*=1+.25*np.sin(np.pi*phase)+.05*np.sin(2*np.pi*37*t)
 breath=band_noise(rng,count,240,7500)
 excitation+=breath*(.10 if kind=='boss' else .065)*effort
 formant_scale=.82 if kind=='boss' else 1.19
 filtered=[]
 for vowel in vowels:
  value=np.zeros(count)
  for freq,bw,level in zip(VOWELS[vowel],[85,110,175,240],[1,.65,.38,.19]):
   freq*=formant_scale;bw*=formant_scale
   b,a=iirpeak(freq,freq/bw,fs=RATE)
   value+=lfilter(b,a,excitation)*level
  filtered.append(value)
 coordinate=np.clip(u*(len(vowels)-1),0,len(vowels)-1)
 combined=np.zeros(count)
 for index,value in enumerate(filtered):combined+=value*np.maximum(0,1-np.abs(coordinate-index))
 combined/=max(np.sqrt(np.mean(combined*combined)),1e-8)
 onset=.055 if kind=='boss' else .025
 voiced_envelope=smooth((t-onset)/(.055 if kind=='boss' else .025))*smooth((duration-.018-t)/(.18 if duration>.8 else .07))
 voiced_envelope*=.94+.06*np.sin(2*np.pi*3.7*t+.4)
 combined=np.tanh(combined*.75)*(voiced_envelope*.68)
 # A real source-filter breath onset and release make these exertions, not
 # pure pitched alarms. Pitch and vowel trajectories remain original.
 breath_envelope=.18*np.exp(-t/.06)+.065*smooth((u-.65)/.30)
 combined+=breath*breath_envelope*effort
 if kind=='boss':
  combined+=.045*np.sin(2*np.pi*phase*.5)*voiced_envelope
 if duration>1.2:
  combined+=.09*band_noise(rng,count,500,6500)*np.sin(np.pi*u)**2*effort
 return room(combined,.09 if kind=='boss' else .055)

def modal(t,freq,decay):
 output=np.zeros(len(t))
 for ratio,gain,tail in [(1,1,1),(2.71,.40,.6),(4.83,.21,.3)]:
  output+=np.sin(2*np.pi*freq*ratio*t)*np.exp(-t/(decay*tail))*gain
 return output*smooth(t/.002)

def effects():
 rng=np.random.default_rng(231024)
 results={}
 def noise(duration,lo,hi):
  t=np.arange(round(duration*RATE))/RATE
  return t,band_noise(rng,len(t),lo,hi)
 for variant in [1,2]:
  t,n=noise(.23 if variant==1 else .26,350,10500)
  env=np.sin(np.pi*t/t[-1])**1.5
  ember=band_noise(rng,len(t),2500,11000)*np.exp(-t/.07)*.13
  metal=.15*modal(t,740+95*variant,.038)
  results[f'hero_slash_{variant}']=room(n*env*.42+ember+metal,.03)
 t,n=noise(.29,180,9000)
 results['hero_dash']=room(n*np.sin(np.pi*t/t[-1])**1.8*.55,.045)
 t,n=noise(.30,120,8000)
 results['compiler_release']=room(n*np.sin(np.pi*t/t[-1])**1.5*.50+.16*modal(t,196,.10),.06)
 for variant in [1,2]:
  t,n=noise(.20 if variant==1 else .23,650,10000)
  body=.40*np.sin(2*np.pi*(92+21*variant)*t)*np.exp(-t/.055)
  results[f'combat_hit_{variant}']=room(n*np.exp(-t/.030)*.35+body+.13*modal(t,570+110*variant,.065),.06)
 t,n=noise(.27,180,5200)
 results['combat_hurt']=room(.30*n*np.exp(-t/.055)+.40*np.sin(2*np.pi*98*t)*np.exp(-t/.082),.04)
 t,n=noise(.33,1800,11000)
 results['combat_parry']=room(.11*n*np.exp(-t/.018)+.42*modal(t,1174.66,.11),.11)
 for variant in range(1,5):
  t,n=noise(.12+variant*.007,320,6500)
  stone=.22*modal(t,175+variant*33,.024)
  paper=.24*n*np.exp(-t/.028)
  dust=.05*band_noise(rng,len(t),2200,10000)*np.exp(-t/.055)
  results[f'footstep_{variant}']=room(stone+paper+dust,.025)
 t,n=noise(.28,150,8000)
 results['hero_land']=room(.42*n*np.exp(-t/.055)+.30*np.sin(2*np.pi*110*t)*np.exp(-t/.075),.05)
 for name,duration in [('book_open',.48),('book_page',.27),('book_close',.29),('paper_rustle',.78)]:
  t,n=noise(duration,350,9000)
  env=np.sin(np.pi*t/duration)**1.2
  flutter=.55+.45*np.sin(2*np.pi*(14*t+9*t*t))**2
  paper=n*env*flutter*.40
  if name!='book_page':paper+=.12*modal(t,185,.035)
  results[name]=room(paper,.04)
 for name,duration in [('coin_pickup_1',.22),('coin_pickup_2',.25),('chain_tink',.64)]:
  t=np.arange(round(duration*RATE))/RATE
  freq=1396.9 if name=='coin_pickup_1' else 1567.98 if name=='coin_pickup_2' else 1108.73
  signal=.32*modal(t,freq,.075 if name!='chain_tink' else .12)
  if name=='chain_tink':
   for at,f in [(.13,1661.22),(.29,987.77)]:
    start=round(at*RATE);signal[start:]+=.18*modal(t[:-start],f,.09)
  results[name]=room(signal,.12)
 for name,duration,tones in [('bench_rest',.78,[587.33,880.0]),('puzzle_success',1.02,[587.33,698.46,880.0]),('puzzle_error',.39,[220.0,196.0])]:
  t=np.arange(round(duration*RATE))/RATE;signal=np.zeros(len(t))
  for index,freq in enumerate(tones):
   start=round(index*.11*RATE)
   signal[start:]+=.22*modal(t[:len(t)-start],freq,.16 if name!='puzzle_error' else .055)
  if name=='puzzle_error':signal+=band_noise(rng,len(t),600,4200)*np.exp(-t/.10)*.08
  results[name]=room(signal,.10)
 t,n=noise(.62,800,11000)
 sparks=np.zeros(len(t))
 for at,gain in [(.02,.19),(.09,.10),(.18,.12),(.32,.08),(.42,.06)]:
  sparks+=gain*np.exp(-np.maximum(t-at,0)/.012)*(t>=at)
 results['lamp_flicker']=room(n*sparks,.04)
 t,n=noise(.76,150,6000)
 results['door_transition']=room(n*np.sin(np.pi*t/.76)**2*.35+.12*modal(t,146.83,.16),.11)
 for variant in [1,2]:
  t,n=noise(.13+variant*.008,240,5600)
  signal=.28*n*np.exp(-t/.019)+.27*modal(t,160+variant*38,.027)
  results[f'footstep_stone_{variant}']=room(signal,.025)
  t,n=noise(.16+variant*.009,650,9500)
  signal=.25*n*np.exp(-t/.039)*(.60+.40*np.sin(2*np.pi*27*t)**2)
  signal+=.13*modal(t,265+variant*31,.019)
  results[f'footstep_paper_{variant}']=room(signal,.03)
 t,n=noise(.66,900,9000)
 results['heal_complete']=room(.18*modal(t,1174.66,.16)+.12*modal(t,1760,.14)+n*.035*np.exp(-t/.15),.09)
 t,n=noise(.19,700,7000)
 results['heal_cancel']=room(.25*n*np.sin(np.pi*t/.19)**1.5,.02)
 t,n=noise(.48,220,11000)
 envelope=np.sin(np.pi*t/.48)**1.2
 sparks=band_noise(rng,len(t),2200,10500)*np.exp(-t/.12)*.12
 results['spell_cast']=room(.38*n*envelope+.20*modal(t,293.665,.12)+sparks,.08)
 return results

def write_audio(stem,audio):
 audio=sosfilt(butter(2,45,fs=RATE,btype='highpass',output='sos'),audio,axis=0)
 fade=min(round(.010*RATE),len(audio)//8)
 audio[:fade]*=smooth(np.linspace(0,1,fade))[:,None]
 audio[-fade:]*=smooth(np.linspace(1,0,fade))[:,None]
 target_db=-4.8 if stem in VOICES else -4.0
 audio*=10**(target_db/20)/max(float(np.max(np.abs(audio))),1e-9)
 path=OUT/(stem+'.wav')
 with wave.open(str(path),'wb') as stream:
  stream.setnchannels(2);stream.setsampwidth(2);stream.setframerate(RATE)
  stream.writeframes((np.clip(audio,-.9999,.9999)*32767).astype('<i2').tobytes())
 category='boss_voice' if stem.startswith('compiler_voice') else 'hero_voice' if stem in VOICES else 'effects'
 metadata={'file':str(path.relative_to(ROOT)),'duration_seconds':len(audio)/RATE,'sample_rate':RATE,'channels':2,
           'category':category,'original_audio':True,'source_type':'original glottal source/filter synthesis; no recordings or actor model' if stem in VOICES else 'original procedural paper/stone/brass/ember synthesis',
           'sample_peak_dbfs':target_db,'rms_dbfs':20*math.log10(max(float(np.sqrt(np.mean(audio*audio))),1e-12)),
           'clipped_samples':0,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 if stem in VOICES:
  profile=VOICES[stem]
  metadata.update({'pitch_contour_hz':profile[2],'vowel_trajectory':profile[3],'formant_scale':.82 if profile[1]=='boss' else 1.19})
 return metadata

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--manifest-only',action='store_true');args=parser.parse_args()
 OUT.mkdir(parents=True,exist_ok=True)
 manifest={'version':1,'sample_rate':RATE,'original_audio':True,
           'category_rules':{'hero_voice':{'cooldown':.18,'max_instances':1},'boss_voice':{'cooldown':1.1,'max_instances':1}},
           'events':event_definitions()}
 (OUT/'event_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
 if args.manifest_only:
  print('Event manifest ready:',len(manifest['events']),'events');return
 records=[]
 for index,(stem,profile) in enumerate(VOICES.items()):records.append(write_audio(stem,voice(profile,231024+index*43)))
 for stem,audio in effects().items():records.append(write_audio(stem,audio))
 (OUT/'character_audio_manifest.json').write_text(json.dumps({'version':1,'original_audio':True,'license':'CC0-1.0 original synthesis; no third-party samples','reference_media_usage':'visual/timing reference only; no audio extracted or cloned','files':records},indent=2,ensure_ascii=False)+'\n')
 print(json.dumps({'new_files':len(records),'events':len(manifest['events']),'seconds':sum(item['duration_seconds'] for item in records)},indent=2))

if __name__=='__main__':main()
