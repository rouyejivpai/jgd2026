import sys,pathlib,subprocess,wave,zipfile,xml.etree.ElementTree as ET
sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0,r'C:\Users\Administrator\Documents\Codex\2026-10-04\zon\work\packages')
import imageio_ffmpeg
from PIL import Image,ImageDraw,ImageFont
root=pathlib.Path('work/meeting'); frames=root/'frames';frames.mkdir(exist_ok=True)
video=next((root/'recording').glob('*.mp4'));ff=imageio_ffmpeg.get_ffmpeg_exe()
with wave.open(str(root/'audio.wav')) as w: duration=w.getnframes()/w.getframerate()
print('duration',duration,flush=True)
r=subprocess.run([ff,'-i',str(video)],capture_output=True,encoding='utf-8',errors='replace')
(root/'metadata.txt').write_text(r.stderr,encoding='utf-8')
times=list(range(0,int(duration),120))
if len(sys.argv)>1: times=[int(t) for t in sys.argv[1:]]
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
for t in times:
 dest=frames/f'{t:05d}.jpg'
 if not dest.exists(): subprocess.run([ff,'-y','-ss',str(t),'-i',str(video),'-frames:v','1','-q:v','2',str(dest)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
for n in range(0,len(times),12):
 chunk=times[n:n+12];sheet=Image.new('RGB',(1600,310*((len(chunk)+2)//3)), '#eeeeee');d=ImageDraw.Draw(sheet)
 for i,t in enumerate(chunk):
  im=Image.open(frames/f'{t:05d}.jpg');im.thumbnail((520,275));x=(i%3)*533;y=(i//3)*310
  sheet.paste(im,(x,y+30));d.text((x+8,y+2),f'{t//60:02d}:{t%60:02d}',fill='#111111',font=font)
 sheet.save(root/f'contact_{n//12}.jpg')
print('frames',len(times),flush=True)
ns={'a':'http://schemas.openxmlformats.org/drawingml/2006/main'}
with zipfile.ZipFile('docs/UI设计.pptx') as z:
 slides=sorted([name for name in z.namelist() if name.startswith('ppt/slides/slide') and name.endswith('.xml')],key=lambda s:int(s.split('slide')[-1].split('.')[0]))
 text=[]
 for i,name in enumerate(slides,1):
  tree=ET.fromstring(z.read(name));text.append(f'SLIDE {i}\n'+'\n'.join(e.text or '' for e in tree.findall('.//a:t',ns)))
 (root/'ui_slides.txt').write_text('\n\n'.join(text),encoding='utf-8')
