#!/usr/bin/env python3
"""Offline master-proportions QA. Requires Pillow: pip install pillow."""
from pathlib import Path
from PIL import Image
import json, sys
root=Path(__file__).resolve().parents[1]
spec=json.loads((root/'WARDEN_MASTER_PROPORTIONS.json').read_text('utf-8'))
paths=(list((root/'assets/warden_m09_whole_body').glob('*idle.png'))+
       list((root/'assets/warden_run_m02').glob('run_??.png'))+
       list((root/'assets/warden_jump_m10').glob('jump_??.png')))
fail=[]
for path in sorted(paths):
 im=Image.open(path).convert('RGBA')
 mask=im.getchannel('A').point(lambda q: 255 if q>100 else 0)
 bb=mask.getbbox()
 if im.size != tuple(spec['source_canvas_px']): fail.append(f'{path.name}: invalid canvas {im.size}')
 if bb is None: fail.append(f'{path.name}: empty silhouette')
 print(f'{path.parent.name}/{path.name}  bounding_box={bb}')
print('PASS: Canvas and nonempty silhouette' if not fail else 'FAIL: '+str(fail))
print('NOTE: Anatomy, face scale, disconnected body parts and jump poses require visual QA.')
sys.exit(1 if fail else 0)
