#!/usr/bin/env python3
"""Create an original 24-second ambient score; NumPy is development-only."""
from pathlib import Path
import numpy as np
import wave
root=Path(__file__).resolve().parents[1]
rate=48000;duration=24;n=rate*duration;t=np.arange(n)/rate
signal=np.zeros(n)
def hz(note):return 440*2**((note-69)/12)
for bar,notes in enumerate([[50,57,61,66],[47,54,57,62],[43,50,54,59],[45,52,57,62]]):
 start=bar*6;local=t-start
 env=np.where((local>=0)&(local<6.8),np.minimum(np.maximum(local,0)/1.2,1)*np.minimum(np.maximum(6.8-local,0)/1.5,1),0)
 for j,note in enumerate(notes):
  phase=2*np.pi*hz(note)*local
  pad=np.sin(phase+.004*np.sin(local*.8))+.16*np.sin(phase*2)+.04*np.sin(phase*3)
  signal+=pad*env*.026
for k in range(32):
 start=.375+k*.75;local=t-start;note=[74,69,66,73,78,73,71,69][k%8]
 env=np.where((local>=0)&(local<2),np.exp(-np.maximum(local,0)*3.2)*(1-np.exp(-np.maximum(local,0)*60)),0)
 signal+=(np.sin(2*np.pi*hz(note)*local)+.23*np.sin(2*np.pi*hz(note)*2.002*local))*env*.042
for k in range(32):
 local=t-k*.75;env=np.where((local>=0)&(local<.3),np.exp(-np.maximum(local,0)*18),0)
 signal+=np.sin(2*np.pi*(48*local+2.3*(1-np.exp(-np.maximum(local,0)*25))))*env*.065
# A quiet stereo echo; a gentle fade keeps the demo start/end clean.
delay=int(.28*rate);right=signal.copy();right[delay:]+=signal[:-delay]*.19
fade=np.minimum(t/1.3,1)*np.minimum((duration-t)/2.2,1)
audio=np.stack([signal,right],axis=1)*fade[:,None]
audio*=.74/max(np.max(np.abs(audio)),1e-6)
out=root/'Demo/Open-Sky.wav'
with wave.open(str(out),'wb') as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(rate);w.writeframes((audio*32767).astype('<i2').tobytes())
# Analysis for the rendered walkthrough uses this actual score, not random bands.
frames=[]
for frame in range(duration*24):
 mid=int(frame/24*rate);block=audio[max(0,mid-1024):mid+1024].mean(axis=1)
 block=np.pad(block,(0,max(0,2048-len(block))))[:2048]
 spectrum=np.abs(np.fft.rfft(block*np.hanning(2048)))/1024
 bands=[]
 for i in range(64):
  lo=max(1,int(40*(16000/40)**(i/64)/rate*2048));hi=min(1024,int(np.ceil(40*(16000/40)**((i+1)/64)/rate*2048)))
  db=20*np.log10(max(spectrum[lo:hi+1].max(),1e-8));bands.append(float(np.clip((db+80)/70,0,1)))
 frames.append({'rms':float(np.sqrt(np.mean(block*block))),'bands':bands,'wave':block[::8].tolist()})
import json
(root/'Demo/score-analysis.json').write_text(json.dumps(frames,separators=(',',':')))
print('Created original ambient score:',out,'24 seconds, stereo 48 kHz; measured per-frame audio analysis.')
