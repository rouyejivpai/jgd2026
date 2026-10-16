import sys, pathlib, importlib.util, zipfile, json
sys.stdout.reconfigure(encoding='utf-8')
root=pathlib.Path(r'H:\其他\人工神灵')
prior=pathlib.Path(r'C:\Users\Administrator\Documents\Codex\2026-10-04\zon\work\packages')
sys.path.insert(0,str(prior))
print('PACKAGES', {m:bool(importlib.util.find_spec(m)) for m in ['faster_whisper','imageio_ffmpeg','reportlab','fitz','PIL','ctranslate2']},flush=True)
import imageio_ffmpeg
print('FFMPEG',imageio_ffmpeg.get_ffmpeg_exe(),flush=True)
cache=pathlib.Path.home()/'.cache/huggingface/hub/models--Systran--faster-whisper-small/snapshots'
print('MODELS', list(map(str,cache.glob('*'))),flush=True)
target=root/'work/meeting/recording'
target.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(r'C:\Users\Administrator\Downloads\2026-10-04 20-59-14.zip') as z:
 for entry in z.infolist():
  if pathlib.PurePosixPath(entry.filename).name==entry.filename:
   dest=target/entry.filename
   if not dest.exists(): z.extract(entry,target)
   print('EXTRACTED',str(dest),dest.stat().st_size,flush=True)
video=next(target.glob('*.mp4'))
import subprocess
r=subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-i',str(video)],capture_output=True,text=True)
print(r.stderr,flush=True)
audio=root/'work/meeting/audio.wav'
if not audio.exists():
 subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-i',str(video),'-vn','-ac','1','-ar','16000',str(audio)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
print('AUDIO',str(audio),flush=True)
