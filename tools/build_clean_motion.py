#!/usr/bin/env python3
"""Original scalable SVG illustration and coherent 2D movement, exported to Godot.
    This is a controlled layered 2D animation, not individually hand-painted PNGs.
    Designed for no frame bleed, fixed heel baseline and real animated strides.
"""
import math, io, os, json, random
from pathlib import Path
from PIL import Image,ImageDraw
import cairosvg

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets'/'warden_clean'
SRC=ROOT/'art_source'/'warden_keyframes'
OUT.mkdir(parents=True,exist_ok=True);SRC.mkdir(parents=True,exist_ok=True)
SCALE=512
COUNTS={
'unarmed_idle':8,'unarmed_run':10,'unarmed_jump':5,'unarmed_fall':5,'unarmed_land':5,
'armed_idle':8,'armed_ready':8,'armed_run':10,'armed_jump':5,'armed_fall':5,'armed_land':5,'armed_dash':6,'armed_crouch':5,
'slash':8,'slash_follow':6,'slash_up':8,'slash_down':8,
'parry':7,'recoil':6,'death':9}
LOOPS={'unarmed_idle','unarmed_run','armed_idle','armed_ready','armed_run'}
FPS={k: (12 if 'run' in k else 9 if 'idle' in k or 'ready' in k else 15) for k in COUNTS}
FPS.update({'slash':23,'slash_up':23,'slash_down':23,'slash_follow':20,'parry':18,'armed_dash':18,'death':11})

D='''<defs>
<linearGradient id="cape" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3f4452"/><stop offset=".55" stop-color="#222a38"/><stop offset="1" stop-color="#131c27"/></linearGradient>
<linearGradient id="lining" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f1e5d1"/><stop offset="1" stop-color="#958d88"/></linearGradient>
<linearGradient id="lantern" x1="0" y1="0" x2=".85" y2="1"><stop offset="0" stop-color="#c6faff"/><stop offset=".52" stop-color="#6ad9f5"/><stop offset="1" stop-color="#1575a0"/></linearGradient>
<linearGradient id="bronze" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e1b47a"/><stop offset=".55" stop-color="#95704e"/><stop offset="1" stop-color="#554536"/></linearGradient>
<linearGradient id="blade" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff"/><stop offset=".35" stop-color="#c2faff"/><stop offset="1" stop-color="#2baed1"/></linearGradient>
<radialGradient id="flame"><stop offset="0" stop-color="#eaffff" stop-opacity=".96"/><stop offset=".45" stop-color="#7feafb" stop-opacity=".9"/><stop offset="1" stop-color="#0bd1f3" stop-opacity="0"/></radialGradient>
<filter id="glow" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="7" /></filter>
</defs>'''

def polyline_leg(hip,knee,ankle,front=False):
    a,b,c=hip,knee,ankle
    dark='#151d26' if not front else '#202733'; highlight='#58616a' if not front else '#727579'
    # parallel thick stroke for readable leg silhouette
    return f'''<g stroke-linejoin="round" stroke-linecap="round">
    <path d="M{a[0]},{a[1]} L{b[0]},{b[1]} L{c[0]},{c[1]}" fill="none" stroke="#0e1721" stroke-width="25"/>
    <path d="M{a[0]},{a[1]} L{b[0]},{b[1]} L{c[0]},{c[1]}" fill="none" stroke="{dark}" stroke-width="19"/>
    <path d="M{a[0]-3},{a[1]+2} L{b[0]-4},{b[1]} L{c[0]-4},{c[1]}" fill="none" stroke="{highlight}" stroke-width="3" opacity=".8"/>
    <path d="M{c[0]-10},{c[1]-4} L{c[0]+7},{c[1]-5} L{c[0]+15},{c[1]+4} Q{c[0]+17},{c[1]+8} {c[0]+11},{c[1]+9} L{c[0]-10},{c[1]+9} Z" fill="#1c222c" stroke="#0e1219" stroke-width="2.6"/>
    <path d="M{c[0]-6},{c[1]-1} L{c[0]+7},{c[1]-2}" stroke="#ad896b" stroke-width="2.2"/>
    <path d="M{c[0]-3},{c[1]+5} L{c[0]+10},{c[1]+5}" stroke="#626369" stroke-width="1.8"/></g>'''

def leg_pos(phase,index,kind):
    # Hip/heel positions are independent of cape silhouette; boots do NOT cross the ground line.
    jump=kind in ('jump','fall','dash','hurt','death')
    running=kind=='run'
    if running:
        swing=math.sin(phase + index*math.pi)
        footx=260+(-14 if index==0 else 14)+swing*28
        footy=443-max(0,math.cos(phase+index*math.pi))*20
        kneex=260+(-13 if index==0 else 13)+swing*17+(5 if index==0 else -5)
        kneey=390+max(0,-swing)*4
    elif kind in ('jump','fall'):
        swing= -1 if index==0 else 1
        footx=260+swing*35
        footy=(417 if kind=='jump' else 435)+index*5
        kneex=260+swing*(21 if kind=='jump' else 12)
        kneey=(380 if kind=='jump' else 392)+index*5
    elif kind=='dash':
        footx=247+index*40
        footy=435+index*5
        kneex=244+index*33
        kneey=395+index*3
    elif kind=='death':
        footx=232+index*31;footy=443
        kneex=236+index*22;kneey=419
    else:
        footx=244+index*29
        footy=443
        kneex=245+index*28
        kneey=393
    hip=(248+index*22, 351)
    return hip, (kneex,kneey), (footx,footy)

def art(pose,frame,total):
    t=frame/max(1,total-1); phase=2*math.pi*frame/total
    unarmed=pose.startswith('unarmed_')
    kind=('run' if 'run' in pose else 'jump' if 'jump' in pose else 'fall' if 'fall' in pose else 'dash' if 'dash' in pose else 'death' if pose=='death' else 'hurt' if pose=='recoil' else 'idle')
    attacking=pose in ('slash','slash_follow','slash_up','slash_down')
    if attacking: kind='idle'
    bounce=(1.5*(1-math.cos(phase*2))) if kind=='run' else (.8*math.sin(phase) if kind=='idle' else 0)
    tilt=(-7+3*math.sin(phase)) if kind in ('run','dash') else (-3 if attacking else 0)
    if kind=='death': tilt=55*t
    if pose=='recoil': tilt=-9*math.sin(t*math.pi)
    # All rendered frames have identical bounds and foot baseline.
    cape_sway=(2*math.sin(phase+.4)) if kind=='idle' else (3*math.sin(phase) if kind=='run' else -4)
    cape_tip_x=154+cape_sway
    cape_y=423-3*math.cos(phase) if kind=='run' else 429
    bg=f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">{D}'''
    if kind=='death':
        bg += f'<g transform="translate(0 {-65*t:.2f}) rotate({tilt:.2f} 261 432)">'
        tilt=0
    # rear cape under layers, gentle movement only, NO long physics ribbons
    bg+=f'''<path d="M255 272 Q218 291 201 314 Q175 360 {cape_tip_x:.1f} {cape_y:.1f} Q179 420 201 435 L215 419 Q218 447 242 444 Q257 418 262 371 Z" fill="url(#cape)" stroke="#111b25" stroke-width="4" />
    <path d="M246 283 Q215 322 193 356 Q182 380 168 403 L192 409 Q200 382 225 337 Z" fill="url(#lining)" stroke="#283040" stroke-width="2.8" />
    <path d="M210 333 Q195 383 174 407" fill="none" stroke="#ad8a67" stroke-width="2" opacity=".85" />
    <path d="M227 310 Q204 363 205 415" fill="none" stroke="#687380" stroke-width="2" opacity=".53" />
    <path d="M260 307 Q257 382 240 428" stroke="#ae8b68" stroke-width="2" fill="none" opacity=".58"/>'''
    # legs behind torso, genuine alternating foot placement
    for idx in [0,1]:
        hip,knee,ankle=leg_pos(phase,idx,kind)
        # body looks like running, feet relative to floor, not bouncing the entire sprite.
        bg+=polyline_leg(hip,knee,ankle,front=(idx==1))
    # mantle, coat torso sway min, head pivot none; lantern never swaps identity.
    bg+=f'<g transform="rotate({tilt:.2f} 259 325)">'
    bg+=f'''<path d="M239 285 Q253 277 275 283 L293 309 L302 379 Q298 424 292 433 L269 419 L252 438 L228 432 L230 368 Z" fill="#232b38" stroke="#0f1823" stroke-width="4" />
    <path d="M253 317 L249 424 L265 424 L271 317 Z" fill="url(#lining)" stroke="#524c49" stroke-width="1.6"/>
    <path d="M263 326 L257 417" stroke="#bb9771" stroke-width="2" opacity=".75"/>
    <path d="M244 335 L230 421 L237 429 L248 396 Z" fill="#343d4b" stroke="#101b27" stroke-width="2"/>
    <path d="M276 334 L292 427 L301 429 L289 341 Z" fill="#171e2b" stroke="#10151d" stroke-width="2"/>
    <path d="M247 319 L275 319 L274 334 L246 334 Z" fill="#201b23" stroke="#9f7752" stroke-width="2"/>
    <rect x="259" y="321" width="10" height="13" rx="2" fill="url(#bronze)" stroke="#1c1a1c" stroke-width="1.5"/>
    <path d="M232 287 L256 270 L269 271 Q286 274 301 300 L295 326 L281 326 L272 313 L261 316 L241 309 L233 325 L219 324 Z" fill="url(#cape)" stroke="#101824" stroke-width="4"/>
    <path d="M230 294 L245 294 L255 315 L246 326 L220 321" fill="#333945" stroke="#9b8069" stroke-width="2"/>
    <path d="M274 276 L292 291 L302 318 L285 321 L268 302" fill="#222a36" stroke="#af8560" stroke-width="2" />
    <path d="M227 307 L245 310 M283 302 L299 314" stroke="#e4b780" stroke-width="1.9"/>
    <path d="M251 296 L266 319 L282 294" fill="none" stroke="#997f5b" stroke-width="2.4"/>
    <circle cx="265" cy="313" r="7" fill="#3a3c40" stroke="#c29a62" stroke-width="2.3"/>
    <path d="M265 307 L267 314 L261 316 L265 320" fill="none" stroke="#d3aa76" stroke-width="1.3" />
    <!-- belt secondary memory lamp -->
    <path d="M280 340 L280 359" stroke="#bd9764" stroke-width="2"/>
    <rect x="275" y="355" width="16" height="28" rx="4" fill="#232c37" stroke="#b48c57" stroke-width="3" />
    <rect x="278.5" y="360" width="9" height="19" rx="2" fill="url(#lantern)" opacity=".90"/>
    <path d="M275 362 L291 362 M275 377 L291 377" stroke="#c4a37b" stroke-width="2"/>
    '''
    # arms, shoulder x 239 and 291, to elbow/wrist in degrees
    if attacking:
        # wrist follows a controlled arc, corresponding to sword blade and hit window.
        if pose=='slash_follow': angle=-65+50*t
        elif pose=='slash_up': angle=28-125*(min(1,(t+.05)*1.1))
        elif pose=='slash_down': angle=-85+155*(min(1,(t+.05)*1.1))
        else: angle=55-155*(min(1,(t+.05)*1.1))
        wrist=(303+20*math.cos(math.radians(angle)),324+36*math.sin(math.radians(angle)))
        elbow=(296,315)
    elif pose=='parry': wrist=(318,291);elbow=(298,307);angle=-65
    elif kind in ('run','dash'): wrist=(302+5*math.sin(phase),337+6*math.sin(phase));elbow=(294,316);angle=42
    elif kind in ('jump','fall'): wrist=(307,337);elbow=(294,310);angle=55
    else: wrist=(302,367);elbow=(293,320);angle=62
    # rear arm and front sleeve
    bg+='''<path d="M230 298 Q221 309 222 333 L230 361" fill="none" stroke="#0c1621" stroke-width="22" stroke-linecap="round"/>
    <path d="M230 298 Q221 309 222 333 L230 359" fill="none" stroke="#44434a" stroke-width="14" stroke-linecap="round"/>
    <path d="M222 336 L229 346" stroke="#d2c5ac" stroke-width="8" stroke-linecap="round"/>
    <path d="M230 350 L229 360" stroke="#242b32" stroke-width="10" stroke-linecap="round"/>'''
    bg+=f'''<path d="M288 301 Q{elbow[0]} {elbow[1]} {wrist[0]} {wrist[1]}" stroke="#0e1924" stroke-width="24" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    <path d="M288 302 Q{elbow[0]} {elbow[1]} {wrist[0]} {wrist[1]}" stroke="#d6cfbf" stroke-width="16" stroke-linecap="round" stroke-linejoin="round" fill="none" />
    <path d="M290 306 L{elbow[0]+3} {elbow[1]+3}" stroke="#66717b" stroke-width="5" stroke-linecap="round"/>
    <circle cx="{wrist[0]}" cy="{wrist[1]}" r="9" fill="#262b34" stroke="#a78458" stroke-width="2.5"/>'''
    # head: no alternative helmets between frames; distinctive 4-post bronze lantern.
    bg+='''<path d="M252 278 L250 257 L281 257 L279 280" fill="#1d2732" stroke="#a58b6e" stroke-width="2"/>
    <path d="M250 261 L239 268 L256 284 L269 280 L287 264 L280 258" fill="#17232e" stroke="#967351" stroke-width="2"/>
    <ellipse cx="265" cy="218" rx="29" ry="42" fill="#31d9f5" opacity=".26" filter="url(#glow)"/>
    <path d="M248 195 Q255 184 266 183 Q280 185 283 196 L284 250 L248 250 Z" fill="#101e2a" stroke="#101b24" stroke-width="5"/>
    <rect x="251" y="199" width="30" height="48" rx="5" fill="url(#lantern)" opacity=".95"/>
    <path d="M259 239 Q251 225 262 215 Q259 223 269 209 Q275 219 272 224 Q283 217 275 240 Z" fill="#f0ffff" opacity=".9"/>
    <path d="M255 238 Q250 225 260 220 Q259 231 264 233" stroke="#45b4db" stroke-width="2" fill="none"/>
    <path d="M249 199 L249 248 M283 198 L283 249" stroke="#bc9666" stroke-width="5"/>
    <path d="M250 199 L282 199 M250 249 L282 249" stroke="#ecc08e" stroke-width="5"/>
    <path d="M245 199 L287 199 L282 190 L250 190 Z" fill="url(#bronze)" stroke="#473527" stroke-width="2"/>
    <path d="M251 188 Q266 182 281 187" stroke="#c8a276" stroke-width="3.6" fill="none"/>
    <path d="M260 184 L263 178 L269 178 L272 184" fill="url(#bronze)" stroke="#6a4730" stroke-width="2"/>
    <circle cx="266" cy="176" r="4" fill="#cc9b62" stroke="#694a37" stroke-width="1.5"/>
    <path d="M247 211 L285 211 M247 238 L285 238" stroke="#ebc392" stroke-width="2" opacity=".5"/>
    '''
    # weapon first pickups only. Sword originates from hand in all sword animations.
    if not unarmed:
        # blade from hilt in direction angle degrees, fast but consistent.
        a=math.radians(angle)
        vx,vy=math.cos(a),math.sin(a)
        # handle anchor held at wrist; offsets define grip and tip
        hx,hy=wrist[0]+vx*9,wrist[1]+vy*9
        ex,ey=hx+vx*89,hy+vy*89
        ox,oy=-vy,vx
        def p(x,y):return f'{x:.2f},{y:.2f}'
        bg+=f'''<g stroke-linecap="round" stroke-linejoin="round">
        <path d="M{p(hx,hy)} L{p(ex,ey)}" stroke="#2ed9f9" stroke-width="10" opacity=".24" filter="url(#glow)" />
        <path d="M{p(hx,hy)} L{p(ex,ey)} L{p(hx+ox*5,hy+oy*5)} Z" fill="url(#blade)" stroke="#2a97bc" stroke-width="2"/>
        <path d="M{p(hx+vx*11,hy+vy*11)} L{p(ex,ey)}" stroke="#edffff" stroke-width="2.3"/>
        <path d="M{p(hx+ox*12,hy+oy*12)} L{p(hx-ox*12,hy-oy*12)}" stroke="#bb996c" stroke-width="7"/>
        <circle cx="{hx:.2f}" cy="{hy:.2f}" r="5" fill="#d6ac77" stroke="#442d23" stroke-width="2"/>
        <path d="M{p(hx-vx*9,hy-vy*9)} L{p(hx-vx*17,hy-vy*17)}" stroke="#7e654d" stroke-width="7"/>
        </g>'''
    # attack arc SVG is a short *tapered* instant on middle frames, not permanently attached
    if attacking and frame in (2,3,4):
        if pose=='slash_up':path='M314 396 Q405 363 392 265'
        elif pose=='slash_down':path='M338 272 Q413 343 350 428'
        else:path='M338 306 Q410 312 397 383'
        op=1 if frame==3 else .44
        bg+=f'''<path d="{path}" fill="none" stroke="#58ddf6" stroke-width="24" opacity="{.13*op:.2f}" filter="url(#glow)" stroke-linecap="round"/>
        <path d="{path}" fill="none" stroke="#c6faff" stroke-width="{5.0*op:.2f}" opacity="{.75*op:.2f}" stroke-linecap="round"/>'''
    if pose=='parry' and frame in (1,2,3):
        bg+='''<circle cx="326" cy="288" r="21" fill="none" stroke="#acf3ff" stroke-width="3.5" opacity=".72"/>
        <path d="M307 273 L343 306 M343 273 L307 306" stroke="#c6faff" stroke-width="2.2" opacity=".6"/>'''
    if kind=='death': bg+='</g>'
    bg+='</g></svg>'
    return bg

manifest={}
for pose,n in COUNTS.items():
    for i in range(n):
        svg=art(pose,i,n)
        if i==0:
            (SRC/f'{pose}_master.svg').write_text(svg)
        png=cairosvg.svg2png(bytestring=svg.encode(),output_width=SCALE,output_height=SCALE)
        im=Image.open(io.BytesIO(png)).convert('RGBA')
        # Clean consistent antialiased PNG export; never resample each frame's outline independently.
        im.save(OUT/f'{pose}_{i:02d}.png',optimize=True)
    manifest[pose]={'frames':n,'fps':FPS[pose], 'loop':pose in LOOPS}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
# soft light texture
im=Image.new('RGBA',(128,128),(0,0,0,0));d=ImageDraw.Draw(im)
for r in range(63,1,-1):d.ellipse((64-r,64-r,64+r,64+r),fill=(110,220,245,round(22*(1-r/64))))
im.save(OUT/'glow.png')
print('Wrote',sum(COUNTS.values()),'coherent clean art frames to',OUT)
