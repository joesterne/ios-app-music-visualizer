// DOM-level interaction tests; media, permissions, and RAF are controlled doubles.
// npm install --no-save jsdom; node Tests/test-controls.cjs
const {JSDOM}=require('jsdom');const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const html=fs.readFileSync(path.join(__dirname,'../Preview.html'),'utf8');
const key='afterglow.preferences.v1';let checks=0;
const check=(value,message)=>{assert.ok(value,message);checks++};
async function fixture(storage=new Map()){
 const raf=new Map(),opened=[],revoked=[],blobs=[],paints=[],media={pending:null,errors:[]};let id=0,now=0,blocked=false,resumeGate=null,reads=0;
 const dom=new JSDOM(html,{url:'https://afterglow.test',runScripts:'dangerously',pretendToBeVisual:true,beforeParse(w){
  w.HTMLElement.prototype.scrollIntoView=function(){};w.addEventListener('error',event=>media.errors.push(event.error));
  w.matchMedia=()=>({matches:false,addEventListener(type,fn){media.motion=fn}});
  w.Image=class{};w.Path2D=class{moveTo(){}lineTo(){}closePath(){}};
  w.ResizeObserver=class{constructor(fn){this.fn=fn}observe(){}};
  w.requestAnimationFrame=fn=>{raf.set(++id,fn);return id};w.cancelAnimationFrame=k=>raf.delete(k);
  w.open=(...args)=>{opened.push(args);return null};
  w.URL.createObjectURL=blob=>{blobs.push(blob);return 'blob:test/'+blobs.length};w.URL.revokeObjectURL=url=>revoked.push(url);
  w.HTMLAnchorElement.prototype.click=function(){opened.push([this.href,this.download||this.target])};
  Object.defineProperty(w,'localStorage',{value:{getItem(k){if(blocked)throw Error('blocked');return storage.get(k)||null},setItem(k,v){if(blocked)throw Error('blocked');storage.set(k,v)},removeItem(k){if(blocked)throw Error('blocked');storage.delete(k)}}});
  w.Audio=class{constructor(){this.paused=true;this.ended=false;this.duration=NaN;this.currentTime=0;this.volume=.8}pause(){this.paused=true;this.onpause?.()}async play(){this.paused=false;this.onplay?.()}};
  const node=()=>({connect(){},disconnect(){}});
  w.AudioContext=class{constructor(){this.sampleRate=48000;this.destination={}}resume(){return resumeGate||Promise.resolve()}createAnalyser(){return {...node(),fftSize:2048,frequencyBinCount:1024,getFloatFrequencyData(a){reads++;a.fill(-40)},getFloatTimeDomainData(a){a.fill(.1)}}}createGain(){return {...node(),gain:{value:1}}}createMediaElementSource(){return node()}createMediaStreamSource(){return node()}};
  Object.defineProperty(w.navigator,'mediaDevices',{value:{getUserMedia:()=>new Promise((resolve,reject)=>{media.pending={resolve,reject}})}});
 }});
 const w=dom.window,d=w.document;w.paints=paints;w.eval('render=(canvas,kind,time,bands,wave,small=false)=>window.paints.push({kind,time,small});');
 const run=code=>w.eval(code),click=selector=>d.querySelector(selector).click();
 const event=async(id,type,value)=>{const el=d.getElementById(id);if(value!==undefined)el.value=value;const fn=el['on'+type];await fn.call(el,{target:el})};
 const tick=()=>{now+=40;const f=[...raf.values()];raf.clear();f.forEach(fn=>fn(now))};
 const settle=async()=>{await Promise.resolve();await Promise.resolve();await Promise.resolve()};
 return {w,d,run,click,event,tick,settle,raf,opened,revoked,blobs,paints,storage,media,reads:()=>reads,block:v=>blocked=v,resume:v=>resumeGate=v,close:()=>w.close()};
}
(async()=>{
 const a=await fixture();const {w,d,run,click,event,tick,settle}=a;
 check([...d.querySelectorAll('button')].every(button=>typeof button.onclick==='function'),'every rendered button has a handler');
 check(d.querySelectorAll('.card').length===16,'all sixteen visualizer buttons exist');
 for(const card of d.querySelectorAll('.card')){card.click();check(run('style')===card.dataset.style,'visualizer '+card.dataset.style);check(card.getAttribute('aria-pressed')==='true','selected visualizer announced')}
 for(const button of d.querySelectorAll('.palette')){button.click();check(run('palette')===button.dataset.palette,'full palette '+button.dataset.palette)}
 for(const button of d.querySelectorAll('[data-duo-palette]')){button.click();check(run('palette')===button.dataset.duoPalette,'quick palette '+button.dataset.duoPalette)}
 const wasFavorite=run('favorites.has(style)');click('#favorite');check(run('favorites.has(style)')!==wasFavorite,'favorite toggles');click('#favorite');
 await event('gain','input',2.1);await event('speed','input',1.2);await event('glow','input',.8);await event('detail','input',.9);await event('fps','change','30');await event('volume','input',.42);
 await event('duo-speed','input',.85);check(run('speed')===.85&&Number(d.getElementById('speed').value)===.85,'quick/full speed stay in sync');
 await event('duo-glow','input',.4);check(run('glow')===.4&&Number(d.getElementById('glow').value)===.4,'quick/full glow stay in sync');
 click('#pause-motion');check(run('paused')===true,'pause motion');click('#play');check(run('paused')===false,'ambient play resumes');
 click('#expand');check(d.body.classList.contains('immersive'),'expand');d.dispatchEvent(new w.KeyboardEvent('keydown',{key:'Escape'}));check(!d.body.classList.contains('immersive'),'escape exits');
 for(const width of [390,890,1150,1440]){w.innerWidth=width;click('#settings-button');check(width>1200||d.querySelector('.inspector').classList.contains('mobile-open'),'settings opens at '+width);click('#close-settings');check(!d.querySelector('.inspector').classList.contains('mobile-open'),'settings closes at '+width);if(width>1200)check(d.body.classList.contains('settings-hidden'),'desktop inspector actually hides')}
 // Preserve repository Tron controls in the integrated preference snapshot.
 click('[data-style=tron]');await event('tron-mode','change','identityDiscs');click('[data-tron-color=Orange]');
 check(run('tronMode')==='identityDiscs'&&run('tronColor')==='Orange','Tron controls change mode and color');
 // Explicit persistence and complete round-trip across a new document.
 d.getElementById('audio-reactive').checked=false;await event('audio-reactive','change');
 click('#save-preferences');const saved=JSON.parse(a.storage.get(key));check(saved.audioReactive===false,'response preference is saved');check(saved.volume===.42&&saved.fps===30&&saved.speed===.85,'save includes playback and render preferences');
 click('#reset-preferences');check(run('gain')===1.25&&run('fps')===60,'reset defaults');click('#restore-preferences');check(run('gain')===2.1&&run('speed')===.85,'restore snapshot');
 const b=await fixture(a.storage);check(b.run('audioReactive')===false,'response preference restores without autoplay');check(b.run('gain')===2.1&&b.run('style')===saved.style&&b.run('audio.volume')===.42,'startup restore');check(b.run('tronMode')==='identityDiscs'&&b.run('tronColor')==='Orange','Tron preferences restore');check(b.run('source')==='ambient'&&b.run('audio.paused'),'no source or media autoplay on restore');b.close();
 let preferencePicker=0;d.getElementById('preference-file').click=()=>preferencePicker++;click('#import-preferences');check(preferencePicker===1,'import preferences opens JSON picker');
 click('#export-preferences');check(a.blobs.at(-1).type==='application/json','export JSON');check(a.opened.at(-1)[1]==='Afterglow-preferences.json','export filename');
 const importInput={files:[{size:120,text:async()=>JSON.stringify({version:1,style:'orbit',palette:'Glacier',gain:999,speed:-1,volume:99,favorites:['orbit','orbit','bad']})}],value:'x'};
 await d.getElementById('preference-file').onchange({target:importInput});check(run('style')==='orbit'&&run('gain')===3&&run('speed')===.1&&run('audio.volume')===1,'import clamps limits');check(run('favorites.size')===1,'import sanitizes favorites');
 await d.getElementById('preference-file').onchange({target:{files:[{size:10,text:async()=>'{bad json'}],value:'x'}});check(run('style')==='orbit'&&d.getElementById('preference-status').textContent.includes('Could not import'),'malformed import leaves state intact');
 a.block(true);click('#save-preferences');check(d.getElementById('preference-status').textContent.includes('Export'),'blocked storage suggests backup');a.block(false);
 let readPreferences;const lateImport=d.getElementById('preference-file').onchange({target:{files:[{size:120,text:()=>new Promise(resolve=>readPreferences=resolve)}],value:'x'}});click('#reset-preferences');readPreferences(JSON.stringify({version:1,style:'bloom'}));await lateImport;check(run('style')==='yosemite','new reset wins over an older file import');
 click('#forget-preferences');check(!a.storage.has(key)&&d.getElementById('restore-preferences').disabled,'forget only local snapshot');
 // File picker controls, local playback, seeking, source launchers.
 let picker=0;d.getElementById('file').click=()=>picker++;click('#import');check(picker===1,'import opens picker');
 await d.getElementById('file').onchange({target:{files:[{name:'Test.wav'}],value:'x'}});check(run('source')==='local'&&!run('audio.paused'),'local file plays');run('audio.duration=120;audio.onloadedmetadata()');
 await event('seek','input',.25);check(run('audio.currentTime')===30,'seek');click('#restart');check(run('audio.currentTime')===0,'restart');await d.getElementById('play').onclick();check(run('audio.paused'),'pause playback');await d.getElementById('play').onclick();check(!run('audio.paused'),'resume playback');
 for(const source of ['spotify','apple','other']){click('[data-source="'+source+'"]');check(run('source')===source,'source '+source);check(a.opened.at(-1)[0].startsWith('https://'),'launcher opens URL');check(d.querySelector('#toast a'),'launcher has fallback link')}
 const prior=run('source');click('[data-source=system]');check(run('source')===prior&&d.getElementById('toast').textContent.includes('native Mac'),'system button explains native-only capability');
 // Integrated styles and audio controls retain explicit snapshots and playback.
 for(const visual of ['superMario','spaceFlight','yosemite','fallout','forestWalk']){
  run(`pickStyle('${visual}');audioReactive=false;savePreferences();resetPreferences();restorePreferences()`);
  check(run('style')===visual&&!run('audioReactive'),'new scene and response survive save/restore: '+visual);
 }
 run("source='local';audio.paused=false;audioReactive=false;updatePlay();requestRender()");
 const independentReads=a.reads();tick();check(a.reads()===independentReads&&!run('audio.paused'),'independent mode skips analysis without pausing playback');
 d.getElementById('audio-reactive').checked=true;await event('audio-reactive','change');tick();check(a.reads()>independentReads&&!run('audio.paused'),'response resumes analysis without interrupting playback');
 const gallery=d.getElementById('gallery'),scroll=d.getElementById('gallery-scroll');
 Object.defineProperties(gallery,{scrollWidth:{value:1600,configurable:true},clientWidth:{value:600,configurable:true}});
 await event('gallery-scroll','input',100);check(gallery.scrollLeft===1000,'gallery slider reaches final cards');gallery.scrollLeft=500;gallery.onscroll();check(Number(scroll.value)===50,'manual gallery scroll syncs slider');
 // Latest source wins when permission or AudioContext resume resolves late.
 const pending=w.selectSource('mic');await settle();const old=a.media.pending;click('[data-source=ambient]');old.reject(Error('old rejection'));await pending;check(run('source')==='ambient','late permission error does not overwrite newer source');
 let stops=0;const track={stop(){stops++}};const pending2=w.selectSource('mic');await settle();click('[data-source=spotify]');a.media.pending.resolve({getTracks:()=>[track]});await pending2;check(stops===1&&run('source')==='spotify','stale microphone stream is stopped');
 const pending3=w.selectSource('mic');await settle();a.media.pending.resolve({getTracks:()=>[track]});await pending3;check(run('source')==='mic'&&run('activeMic')!==null,'microphone capture starts');await d.getElementById('play').onclick();check(run('source')==='mic'&&run('activeMic')===null,'microphone stop keeps its mode for restart');
 let resume; a.resume(new Promise(resolve=>resume=resolve));const pendingFile=d.getElementById('file').onchange({target:{files:[{name:'Late.wav'}],value:'x'}});click('[data-source=ambient]');resume();await pendingFile;check(run('source')==='ambient','late file resume cannot take over source');a.resume(null);
 // Count expensive thumbnail passes rather than claiming a wall-clock benchmark.
 run("fps=60;paused=false;source='ambient';pickPalette('Ultraviolet');gain=1.25;glow=.6;requestThumbnails()");tick();a.paints.length=0;
 for(let i=0;i<50;i++)await event('speed','input',.2+i*.02);tick();check(a.paints.filter(p=>p.small).length===0,'50 speed events do not redraw static thumbnails');
 a.paints.length=0;for(let i=0;i<50;i++)await event('gain','input',.2+i*.04);tick();check(a.paints.filter(p=>p.small).length===16,'50 sensitivity events coalesce into one sixteen-card pass');
 a.media.motion({matches:true});tick();check(d.getElementById('pause-motion').disabled&&a.raf.size===0,'Reduce Motion change suspends ambient animation');
 run("source='local';audio.pause();paused=true;clearSignal();requestRender()");const readsBefore=a.reads();tick();check(a.reads()===readsBefore&&a.raf.size===0,'paused audio and motion perform no analysis or idle redraw');
 check(a.media.errors.length===0,'no uncaught UI event errors');a.close();
 const corrupt=await fixture(new Map([[key,'not json']]));check(corrupt.run('style')==='yosemite','corrupt storage recovers defaults');corrupt.close();
 console.log('PASS:',checks,'DOM interaction assertions; controls, local persistence, corruption/blocking, async races, coalesced thumbnails, idle/Reduce Motion.');
})().catch(error=>{console.error(error);process.exitCode=1});
