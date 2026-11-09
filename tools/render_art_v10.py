from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import build_cga_assets as art
root=Path(__file__).resolve().parents[1]
labels=['player_up','enemy_up','fast_up','power_up','armor_up','player_shield_up','brick','steel','water','forest','ice']+['bonus_'+x for x in art.BONUS_LETTERS]
pals=[('CGA palette 1 bright',[(0,0,0),(85,255,255),(255,85,255),(255,255,255)]),('CGA palette 0 bright',[(0,0,0),(85,255,85),(255,85,85),(255,255,85)]),('CGA palette 1 dim',[(0,0,0),(0,170,170),(170,0,170),(170,170,170)]),('CGA palette 0 dim',[(0,0,0),(0,170,0),(170,0,0),(170,85,0)])]
scale=5
w=720;h=740
im=Image.new('RGB',(w,h),(23,28,34));d=ImageDraw.Draw(im)
for k,(name,pal) in enumerate(pals):
 ybase=12+k*181
 d.text((14,ybase),name,fill=(240,241,243))
 for i,label in enumerate(labels):
  x=13+(i%9)*79;y=ybase+28+(i//9)*60
  tile=Image.new('RGB',(16,12),pal[0]);px=tile.load()
  for yy,row in enumerate(art.SPRITES[label]):
   for xx,c in enumerate(row):px[xx,yy]=pal[0 if c=='.' else int(c)]
  im.paste(tile.resize((64,48),Image.Resampling.NEAREST),(x,y))
  d.text((x,y+49),label.replace('bonus_','B:')[:12],fill=(210,213,218))
im.save(root/'docs'/'preview-art-v10.png')
# Real-scale sprite atlas as separate image, 1x pixel reading.
small=Image.new('RGB',(16*9,12*2),(0,0,0))
for i,label in enumerate(labels):
 x=(i%9)*16;y=(i//9)*12
 for yy,row in enumerate(art.SPRITES[label]):
  for xx,c in enumerate(row):small.putpixel((x+xx,y+yy),pals[0][1][0 if c=='.' else int(c)])
small.save(root/'docs'/'preview-art-v10-native.png')
print(root/'docs'/'preview-art-v10.png')
