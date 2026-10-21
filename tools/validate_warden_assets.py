#!/usr/bin/env python3
"""Asset QA for Stage-1 Lantern Warden (runs without Godot)."""
from pathlib import Path
from PIL import Image, ImageChops
import json, math, re, sys
p=Path(__file__).resolve().parents[1]
m=json.loads((p/'assets/warden_clean/manifest.json').read_text())
errors=[]
for state,opts in m.items():
 prev=None
 for i in range(opts['frames']):
  f=p/f'assets/warden_clean/{state}_{i:02d}.png'
  if not f.is_file():errors.append(f'missing {f}');continue
  a=Image.open(f).convert('RGBA')
  if a.size!=(512,512):errors.append(f'wrong size {f}')
  bbox=a.getbbox()
  if not bbox or bbox[0]<12 or bbox[2]>501 or bbox[1]<15 or bbox[3]>495:
   errors.append(f'clipped or empty {f}: {bbox}')
  if prev is not None and state.endswith('_run') and ImageChops.difference(a,prev).getbbox() is None:
   errors.append(f'consecutive duplicate run {f}')
  prev=a
for n in ['scripts/player.gd','scripts/lantern_animation_lab.gd']:
 txt=(p/n).read_text()
 counts={a:int(b) for a,b in re.findall(r'"([a-z_]+)":\s*(\d+)',txt.split('const COUNTS := {')[1].split('}')[0])}
 if counts!={s:v['frames'] for s,v in m.items()}: errors.append(f'count mismatch in {n}')
 if 'res://assets/warden_smooth' in txt:errors.append(f'old asset ref in {n}')
 if any(('/'+s+'_00.png') not in ' res://assets/warden_clean/'+s+'_00.png' for s in []):pass
if errors:
 for e in errors:print('ERROR',e)
 sys.exit(1)
print('PASS:',len(m),'animations,',sum(v['frames'] for v in m.values()),'frames, alpha bounds, image size, script counts and paths')
