import sys,pathlib,os,json,time
sys.stdout.reconfigure(encoding='utf-8')
prior=pathlib.Path(r'C:\Users\Administrator\Documents\Codex\2026-10-04\zon\work')
sys.path.insert(0,str(prior/'packages'))
dll_dirs=sorted(set(str(p.parent.resolve()) for p in pathlib.Path('work/meeting/gpu').rglob('*.dll')))
handles=[os.add_dll_directory(p) for p in dll_dirs]
os.environ['PATH']=os.pathsep.join(dll_dirs)+os.pathsep+os.environ['PATH']
from faster_whisper import WhisperModel,BatchedInferencePipeline
model=WhisperModel(str(prior/'models/whisper-small'),device='cuda',compute_type='float16')
pipeline=BatchedInferencePipeline(model)
started=time.time()
segments,info=pipeline.transcribe('work/meeting/audio.wav',language='zh',beam_size=5,batch_size=8,vad_filter=True,initial_prompt='游戏设计会议，人工神灵，Godot，UI，Cost，地图编辑器，主角，人偶，魔女，攻击形态，承伤形态，快速形态，远射形态，指令，部署，射程，视野，追击，撤离，巡逻，路径点，循环，往复，哨兵，侦察兵，猎犬，狙击手，重装兵，护送目标，腐土平原，灰棘林，圣钟城，肉巢沼泽，骨花母体，关卡，战斗原型。')
print('DURATION',info.duration,flush=True)
with open('work/meeting/transcript_gpu.jsonl','w',encoding='utf-8') as f:
 for s in segments:
  row={'start':round(s.start,2),'end':round(s.end,2),'text':s.text,'avg_logprob':s.avg_logprob,'no_speech_prob':s.no_speech_prob}
  f.write(json.dumps(row,ensure_ascii=False)+'\n');f.flush()
  print(f'{s.start/60:.1f} min | {s.text}',flush=True)
print('Complete in',round(time.time()-started),'seconds',flush=True)
