import zipfile,pathlib,xml.etree.ElementTree as ET,json
from PIL import Image,ImageDraw,ImageFont
root=pathlib.Path('work/meeting/ppt');root.mkdir(exist_ok=True)
ns={'a':'http://schemas.openxmlformats.org/drawingml/2006/main','p':'http://schemas.openxmlformats.org/presentationml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
with zipfile.ZipFile('docs/UI设计.pptx') as z:
 for name in z.namelist():
  if name.startswith('ppt/media/'):
   (root/pathlib.PurePosixPath(name).name).write_bytes(z.read(name))
 for i in [1,2,3]:
  slide=ET.fromstring(z.read(f'ppt/slides/slide{i}.xml'))
  rel=ET.fromstring(z.read(f'ppt/slides/_rels/slide{i}.xml.rels'))
  rels={r.get('Id'):r.get('Target') for r in rel}
  pics=[]
  for pic in slide.findall('.//p:pic',ns):
   b=pic.find('.//a:blip',ns); x=pic.find('.//a:xfrm',ns)
   pics.append({'media':rels.get(b.get('{'+ns['r']+'}embed')),'position':ET.tostring(x,encoding='unicode') if x is not None else ''})
  (root/f'slide{i}_pictures.json').write_text(json.dumps(pics,ensure_ascii=False,indent=2),encoding='utf-8')
files=[p for p in root.iterdir() if p.suffix.lower() in ['.png','.jpg','.jpeg']]
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
sheet=Image.new('RGB',(1500,330*((len(files)+2)//3)),'#dddddd');d=ImageDraw.Draw(sheet)
for i,p in enumerate(files):
 im=Image.open(p).convert('RGB');im.thumbnail((490,300));x=i%3*500;y=i//3*330
 sheet.paste(im,(x,y+25));d.text((x+5,y),p.name,fill='black',font=font)
sheet.save(root/'media_contact.jpg')
print('media',[(p.name,Image.open(p).size) for p in files])
