from PIL import Image,ImageDraw,ImageFont
import pathlib,json
root=pathlib.Path(__file__).resolve().parents[2]
out=root/'work/meeting/background_audit';out.mkdir(exist_ok=True)
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',24)
records=[]
for kind,folder in [('source',root/'godot/assets/backgrounds'),('existing_game',root/'docs/screenshots')]:
 for first in [1,5]:
  sheet=Image.new('RGB',(1800,1260),'#eeeeee');d=ImageDraw.Draw(sheet)
  for n in range(first,first+4):
   path=folder/f'level_{n:02d}.png';im=Image.open(path).convert('RGB')
   if kind=='source':records.append({'level':n,'file':str(path),'size':im.size})
   im.thumbnail((890,590));x=(n-first)%2*900;y=(n-first)//2*630
   sheet.paste(im,(x,y+35));d.text((x+8,y+3),f'{kind} - level {n:02d}',font=font,fill='black')
  sheet.save(out/f'{kind}_{first}.jpg',quality=95)
(out/'inventory.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
