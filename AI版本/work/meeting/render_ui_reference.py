import zipfile,xml.etree.ElementTree as E,pathlib
from PIL import Image,ImageDraw,ImageFont
N={'a':'http://schemas.openxmlformats.org/drawingml/2006/main','p':'http://schemas.openxmlformats.org/presentationml/2006/main','r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
out=pathlib.Path('work/meeting/ppt'); W=1600;H=900
z=zipfile.ZipFile('docs/UI设计.pptx')
pres=E.fromstring(z.read('ppt/presentation.xml'));sz=pres.find('p:sldSz',N);SX=W/int(sz.get('cx'));SY=H/int(sz.get('cy'))
theme=E.fromstring(z.read('ppt/theme/theme1.xml'));scheme={}
cs=theme.find('.//a:clrScheme',N)
for c in cs:
 cc=list(c)[0];scheme[c.tag.split('}')[-1]]=cc.get('val') if cc.tag.endswith('srgbClr') else cc.get('lastClr','#000000')
scheme.update({'tx1':scheme.get('dk1','000000'),'bg1':scheme.get('lt1','FFFFFF'),'bg2':scheme.get('lt2','EEEEEE'),'tx2':scheme.get('dk2','333333')})
def color(fill,default=None):
 if fill is None:return default
 c=fill.find('a:srgbClr',N)
 if c is not None:v=c.get('val')
 else:
  c=fill.find('a:schemeClr',N)
  if c is None:return default
  v=scheme.get(c.get('val'),'888888')
 vals=[int(v[i:i+2],16) for i in (0,2,4)];lm=c.find('a:lumMod',N)
 if lm is not None:vals=[round(t*int(lm.get('val'))/100000) for t in vals]
 return tuple(vals)
for si in [1,2,3]:
 s=E.fromstring(z.read(f'ppt/slides/slide{si}.xml'));rr=E.fromstring(z.read(f'ppt/slides/_rels/slide{si}.xml.rels'));rels={r.get('Id'):r.get('Target') for r in rr}
 im=Image.new('RGB',(W,H),color(s.find('p:cSld/p:bg/p:bgPr/a:solidFill',N),(0,0,0)));d=ImageDraw.Draw(im)
 def walk(node,sx=SX,sy=SY,ox=0,oy=0):
  for e in node:
   typ=e.tag.split('}')[-1]
   if typ=='grpSp':
    x=e.find('p:grpSpPr/a:xfrm',N);o=x.find('a:off',N);ex=x.find('a:ext',N);co=x.find('a:chOff',N);ce=x.find('a:chExt',N)
    rx=int(ex.get('cx'))/max(int(ce.get('cx')),1);ry=int(ex.get('cy'))/max(int(ce.get('cy')),1)
    walk(e,sx*rx,sy*ry,ox+sx*(int(o.get('x'))-rx*int(co.get('x'))),oy+sy*(int(o.get('y'))-ry*int(co.get('y'))))
   elif typ in ['pic','sp']:
    x=e.find('p:spPr/a:xfrm',N)
    if x is None:continue
    o=x.find('a:off',N);ex=x.find('a:ext',N);left=ox+sx*int(o.get('x'));top=oy+sy*int(o.get('y'));ww=sx*int(ex.get('cx'));hh=sy*int(ex.get('cy'));box=(round(left),round(top),round(left+ww),round(top+hh))
    if typ=='pic':
     b=e.find('p:blipFill/a:blip',N);file=pathlib.PurePosixPath(rels[b.get('{'+N['r']+'}embed')]).name
     p=Image.open(out/file).convert('RGB');cr=e.find('p:blipFill/a:srcRect',N)
     if cr is not None:
      l,t,r,b=[int(cr.get(k,'0'))/100000 for k in ['l','t','r','b']];p=p.crop((round(p.width*l),round(p.height*t),round(p.width*(1-r)),round(p.height*(1-b))))
     p=p.resize((max(1,box[2]-box[0]),max(1,box[3]-box[1])),Image.Resampling.LANCZOS);im.paste(p,box[:2])
    else:
     fill=color(e.find('p:spPr/a:solidFill',N))
     if fill:d.rectangle(box,fill=fill)
     runs=e.findall('.//a:r',N);text=''.join(r.find('a:t',N).text or '' for r in runs if r.find('a:t',N) is not None)
     if text:
      rp=runs[0].find('a:rPr',N);fs=round((int(rp.get('sz','1800'))/100)*W/(int(sz.get('cx'))/914400*72)) if rp is not None else 24
      font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',max(10,fs));tc=color(rp.find('a:solidFill',N) if rp is not None else None,(255,255,255));tb=d.textbbox((0,0),text,font=font);d.text((left+(ww-(tb[2]-tb[0]))/2,top+(hh-(tb[3]-tb[1]))/2-tb[1]),text,font=font,fill=tc)
 walk(s.find('p:cSld/p:spTree',N));im.save(out/f'slide_{si}.png')
print('Rendered 3 layout reference previews; fonts may differ from PowerPoint.')
