// Run with Node.js: node Tests/test_preview.cjs. No browser or packages required.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const html=fs.readFileSync(require('node:path').join(__dirname,'../Preview.html'),'utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
function harness(){
 const elements=new Map(),cards=[],palettes=[],colors=[],sources=[],pending=[];
 const draw=new Proxy({createRadialGradient:()=>({addColorStop(){}}),createLinearGradient:()=>({addColorStop(){}})},{get:(o,k)=>o[k]||(()=>{})});
 function element(id=''){return {id,hidden:false,disabled:false,textContent:'',value:'',style:{setProperty(){}},dataset:{},attributes:{},width:264,height:156,classList:{items:new Set(),toggle(k,v){const yes=v??!this.items.has(k);yes?this.items.add(k):this.items.delete(k);return yes},remove(k){this.items.delete(k)}},setAttribute(k,v){this.attributes[k]=String(v)},getAttribute(k){return this.attributes[k]},getContext:()=>draw,getBoundingClientRect:()=>({width:600,height:400}),scrollIntoView(){},click(){this.onclick?.({target:this})},querySelector(){return element()},appendChild(e){if(id==='gallery'){const names=e.innerHTML.match(/<span>(.*?)<\/span>/);e.name=names?.[1];cards.push(e)}else if(id==='palettes')palettes.push(e)}}}
 for(const id of [...html.matchAll(/id="([^"]+)"/g)].map(x=>x[1]))elements.set(id,element(id));
 for(const color of ['Light blue','Orange','Red']){const e=element();e.dataset.tronColor=color;colors.push(e)}
 for(const source of ['ambient','local','mic','system','spotify','apple','other']){const e=element();e.dataset.source=source;sources.push(e)}
 const inspector=element(),body=element(),listeners={};
 class Audio{constructor(){this.paused=true;this.duration=20;this.currentTime=0;this.attrs={}}set src(v){this.attrs.src=v}get src(){return this.attrs.src}getAttribute(k){return this.attrs[k]}removeAttribute(k){delete this.attrs[k]}load(){}pause(){this.paused=true;this.onpause?.()}async play(){this.paused=false;this.onplay?.()}}
 function node(){return {connections:[],gain:{value:1},connect(n){this.connections.push(n)},disconnect(){this.connections=[]}}}
 class AudioContext{constructor(){this.destination={};this.sampleRate=48000}resume(){return Promise.resolve()}createGain(){return node()}createAnalyser(){return Object.assign(node(),{frequencyBinCount:1024,fftSize:2048,getFloatFrequencyData(a){a.fill(-20)},getFloatTimeDomainData(a){a.fill(.1)}})}createMediaElementSource(){return node()}createMediaStreamSource(){return node()}}
 const sandbox={console,Float32Array,Audio,AudioContext,URL:{createObjectURL:()=> 'blob:test',revokeObjectURL(){}},navigator:{mediaDevices:{getUserMedia:()=>new Promise((resolve,reject)=>pending.push({resolve,reject}))}},document:{hidden:false,body,documentElement:element(),getElementById:id=>elements.get(id),createElement:()=>element(),querySelector:()=>inspector,querySelectorAll:selector=>selector==='.card'?cards:selector==='.palette'?palettes:selector==='[data-tron-color]'?colors:selector==='[data-source]'?sources:[],addEventListener(k,f){listeners[k]=f}},localStorage:{getItem:()=>null,setItem(){}},matchMedia:()=>({matches:false,addEventListener(){}}),ResizeObserver:class{observe(){}},requestAnimationFrame(){},setTimeout:()=>1,clearTimeout(){},innerWidth:1400,devicePixelRatio:1};sandbox.window=sandbox;sandbox.addEventListener=(k,f)=>listeners[k]=f;sandbox.open=()=>{};vm.createContext(sandbox);vm.runInContext(script,sandbox);return {run:s=>vm.runInContext(s,sandbox),elements,cards,palettes,pending,listeners,inspector};
}
function stream(){const track={stopped:false,stop(){this.stopped=true}};return{track,getTracks:()=>[track],getAudioTracks:()=>[track]}}
const flush=()=>new Promise(r=>setImmediate(r));
(async()=>{
 const h=harness();assert.equal(h.cards.length,11);for(const card of h.cards){card.click();assert.equal(h.elements.get('visual-name').textContent,card.name==='Tron'?'Light cycles':card.name)}
 for(const p of h.palettes){p.click();assert(p.classList.items.has('active'))}
 h.elements.get('settings-button').click();assert(h.inspector.classList.items.has('mobile-open'));h.elements.get('close-settings').click();assert(!h.inspector.classList.items.has('mobile-open'));
 h.elements.get('expand').click();assert(h.run("document.body.classList.items.has('immersive')"));h.listeners.keydown({key:'Escape'});assert(!h.run("document.body.classList.items.has('immersive')"));
 const cancel=h.run("selectSource('mic')");await flush();assert.equal(h.elements.get('play').attributes['aria-label'],'Cancel microphone connection');await h.elements.get('play').onclick();const cancelledStream=stream();h.pending.shift().resolve(cancelledStream);await cancel;assert(cancelledStream.track.stopped);assert.equal(h.elements.get('mode').textContent,'AUDIO IDLE');
 const first=h.run("selectSource('mic')");await flush();const late=stream();await h.run("selectSource('ambient')");h.pending.shift().resolve(late);await first;assert(late.track.stopped);assert.equal(h.run('source'),'ambient');
 const staleFailure=h.run("selectSource('mic')");await flush();await h.run("selectSource('spotify')");h.pending.shift().reject(new Error('denied'));await staleFailure;assert.equal(h.run('source'),'spotify');
 const denied=h.run("selectSource('mic')");await flush();h.pending.shift().reject(new Error('denied'));await denied;assert.equal(h.elements.get('mode').textContent,'AUDIO IDLE');assert.equal(h.elements.get('play').attributes['aria-label'],'Start microphone');
 const connected=h.run("selectSource('mic')");await flush();const live=stream();h.pending.shift().resolve(live);await connected;assert.equal(h.elements.get('mode').textContent,'LIVE AUDIO');assert.equal(h.run('micSink.gain.value'),0);assert.equal(h.run('micSink.connections.length'),1);
 live.track.onended();assert.equal(h.elements.get('mode').textContent,'AUDIO IDLE');assert.equal(h.run('activeMic'),null);
 const resumed=h.run("selectSource('mic')");await flush();const live2=stream();h.pending.shift().resolve(live2);await resumed;await h.elements.get('play').onclick();assert(live2.track.stopped);assert.equal(h.run('source'),'mic');
 await h.elements.get('file').onchange({target:{files:[{name:'tone.wav'}],value:'tone.wav'}});assert.equal(h.run('source'),'local');assert.equal(h.elements.get('mode').textContent,'LIVE AUDIO');
 h.run('globalThis.analysisCalls=0;const originalRead=analyzer.getFloatFrequencyData.bind(analyzer);analyzer.getFloatFrequencyData=a=>{analysisCalls++;originalRead(a)}');
 h.elements.get('audio-reactive').onchange({target:{checked:false}});h.run('tick(40)');assert.equal(h.run('analysisCalls'),0);assert.equal(h.run('audio.paused'),false);assert.equal(h.elements.get('mode').textContent,'INDEPENDENT MOTION');
 h.elements.get('audio-reactive').onchange({target:{checked:true}});h.run('tick(60)');assert.equal(h.run('analysisCalls'),1);assert.equal(h.run('audio.paused'),false);
 h.run('document.hidden=true;tick(80)');assert.equal(h.run('analysisCalls'),1);h.run('document.hidden=false');
 assert(h.run('haloOrder(79)===haloOrder(79)'));assert.equal(h.run('frequencyRanges.length'),64);
 const gallery=h.elements.get('gallery'),scroll=h.elements.get('gallery-scroll');gallery.scrollWidth=1600;gallery.clientWidth=600;scroll.value=100;scroll.oninput();assert.equal(gallery.scrollLeft,1000);gallery.scrollLeft=500;gallery.onscroll();assert.equal(scroll.value,50);gallery.scrollWidth=600;gallery.onscroll();assert(scroll.disabled);
 h.run('tick(100)');assert(h.run('rms')>0);await h.elements.get('play').onclick();h.run('tick(200)');assert.equal(h.run('rms'),0);assert.equal(h.elements.get('mode').textContent,'AUDIO IDLE');
 h.elements.get('seek').oninput({target:{value:'.5'}});assert.equal(h.run('audio.currentTime'),10);h.elements.get('restart').click();assert.equal(h.run('audio.currentTime'),0);
 h.elements.get('volume').oninput({target:{value:'.2'}});assert.equal(h.run('audio.volume'),.2);await h.run("selectSource('ambient')");assert(h.elements.get('volume').disabled);
 console.log('PASS: 11 galleries, 5 palettes, settings/immersive close, microphone denial/retry/disconnect, stale permission success/failure, muted analysis graph, local playback/pause/seek/restart/volume.');
})().catch(e=>{console.error(e);process.exitCode=1});
