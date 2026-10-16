import sys,pathlib,os,json,time
sys.stdout.reconfigure(encoding='utf-8')
prior=pathlib.Path(r'C:\Users\Administrator\Documents\Codex\2026-10-04\zon\work')
sys.path.insert(0,str(prior/'packages'))
dll_dirs=sorted(set(str(p.parent.resolve()) for p in pathlib.Path('work/meeting/gpu').rglob('*.dll')))
handles=[os.add_dll_directory(p) for p in dll_dirs]
os.environ['PATH']=os.pathsep.join(dll_dirs)+os.pathsep+os.environ['PATH']
from faster_whisper import WhisperModel
model=WhisperModel(str(prior/'models/whisper-small'),device='cuda',compute_type='float16')
start=float(sys.argv[1]) if len(sys.argv)>1 else 2280
end=float(sys.argv[2]) if len(sys.argv)>2 else 3407
segments,info=model.transcribe('work/meeting/audio.wav',language='zh',beam_size=5,clip_timestamps=[start,end],vad_filter=False,condition_on_previous_text=False,initial_prompt='人工神灵，游戏设计，UI，指令，路径点，关卡。')
with open(f'work/meeting/transcript_review_{int(start)}.jsonl','w',encoding='utf-8') as f:
 for s in segments:
  row={'start':round(s.start,2),'end':round(s.end,2),'text':s.text,'avg_logprob':s.avg_logprob,'no_speech_prob':s.no_speech_prob}
  f.write(json.dumps(row,ensure_ascii=False)+'\n');f.flush()
  print(f'{s.start/60:.2f} min | {s.text}',flush=True)
