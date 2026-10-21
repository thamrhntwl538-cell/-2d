from PIL import Image,ImageDraw,ImageFont,ImageEnhance,ImageFilter
from pathlib import Path
p=Path(__file__).resolve().parents[1]
out=Path('/mnt/data')
bg=Image.open(p/'assets/backgrounds/university_hall.webp').convert('RGB')
W,H=900,506
# game-style background, resize/crop to preview
ratio=max(W/bg.width,H/bg.height)
bg=bg.resize((round(bg.width*ratio),round(bg.height*ratio)),Image.Resampling.LANCZOS)
left=(bg.width-W)//2;top=(bg.height-H)//2
bg=bg.crop((left,top,left+W,top+H)).convert('RGBA')
bg=ImageEnhance.Brightness(bg).enhance(.6)
layer=Image.new('RGBA',(W,H),(1,9,16,45));bg=Image.alpha_composite(bg,layer)
try:font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',17)
except:font=None
try:headerfont=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',28)
except:headerfont=None
phases=[('unarmed_run',10, 'BEFORE DEBUG BLADE · RUN'),('armed_run',10,'AFTER DEBUG BLADE · RUN'),('armed_jump',5,'JUMP'),('armed_fall',5,'FALL'),('slash',8,'SWORD SLASH'),('parry',7,'PERFECT PARRY')]
frames=[]
for name,n,label in phases:
 for i in range(n):
  scene=bg.copy()
  d=ImageDraw.Draw(scene,'RGBA')
  d.rectangle((0,448,W,506),fill=(5,12,21,230))
  d.line((0,448,W,448),fill=(121,179,188,255),width=3)
  d.text((25,22),'LAST LECTURE  |  THE LANTERN WARDEN',fill=(238,241,241,255),font=headerfont)
  d.text((28,60),label,fill=(136,237,251,255),font=font)
  d.text((28,475),'ART PREVIEW — COMPOSITED FROM EXPORTED GAME SPRITES (NOT GODOT CAPTURE)',fill=(164,182,196,255),font=font)
  im=Image.open(p/f'assets/warden_clean/{name}_{i:02d}.png').convert('RGBA')
  # fixed sprite scale 0.73 and same baseline as in actual game
  sw=sh=round(512*.73)
  im=im.resize((sw,sh),Image.Resampling.LANCZOS)
  feet=452*.73
  x=450-round(256*.73)
  y=448-round(feet)
  scene.alpha_composite(im,(x,y))
  frames.append(scene.convert('RGB').quantize(colors=128,method=Image.Quantize.FASTOCTREE))
frames[0].save(out/'LastLecture_Warden_V4_Preview.gif',save_all=True,append_images=frames[1:],duration=90,loop=0,optimize=True,disposal=2)
frames[0].convert('RGB').save(out/'LastLecture_Warden_V4_Preview.png')
print('Rendered preview',len(frames),'frames')
