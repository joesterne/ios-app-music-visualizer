// Actual Skia Canvas rendering plus deterministic signal tests; no live-device claim.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {createCanvas,loadImage,Path2D}=require('@napi-rs/canvas');
const root=path.resolve(__dirname,'..'),source=fs.readFileSync(path.join(root,'Web/app.js'),'utf8');
const section=name=>source.split('// BEGIN '+name)[1].split('// END '+name)[0];
const response=vm.createContext({rms:0,gain:1.25});vm.runInContext(section('AUDIO RESPONSE'),response);
const run=code=>vm.runInContext(code,response);
for(const fps of [30,60,120]){
 run('resetResponse()');
 for(let hit=0;hit<3;hit++){
  run(`updateResponse(.18,1/${fps})`);assert(run('responseState.beat')>.9);
  for(let i=0;i<Math.ceil(fps*.7);i++)run(`updateResponse(0,1/${fps})`);
  assert(run('responseState.beat')<.01);
 }
 for(let i=0;i<fps*2;i++)run(`updateResponse(.18,1/${fps})`);
 assert(run('responseState.beat')<.001,'Sustained note settles at '+fps+' fps');
 run('resetResponse();updateResponse(.002,1/60)');assert.equal(run('responseState.beat'),0);
 run('updateResponse(NaN,1/60);updateResponse(Infinity,1/60)');assert.equal(run('responseState.beat'),0);
}
assert(run('bandSignal(.9,3)>bandSignal(.8,3)'),'High gain retains loud-track dynamics');
assert.equal(run('compressSignal(NaN,1)'),0);
for(const gain of [.2,1.25,3])for(let i=0;i<=100;i++){
 const value=run(`bandSignal(${i/100},${gain})`);assert(value>=0&&value<1);
}
(async()=>{
 const ctx=vm.createContext({Path2D,devicePixelRatio:1,palette:'Ultraviolet',rms:0,gain:1.25,detail:.65,glow:.6,
  tronMode:'lightCycles',tronColor:'Light blue',tronColors:{'Light blue':'#66deff'},yosemiteAssetsReady:true,
  document:{createElement:()=>createCanvas(1,1)},
  yosemiteLandscape:await loadImage(path.join(root,'Assets.xcassets/YosemiteLandscape.imageset/YosemiteLandscape.png')),
  yosemiteCloud:await loadImage(path.join(root,'Assets.xcassets/YosemiteCloud.imageset/YosemiteCloud.png'))});
 const evaluate=code=>vm.runInContext(code,ctx);
 evaluate(fs.readFileSync(path.join(root,'Web/forest-walk.js'),'utf8'));
 evaluate(fs.readFileSync(path.join(root,'Web/minecraft.js'),'utf8'));
 evaluate(source.match(/^const styles=.*$/m)[0]);evaluate(source.match(/^const palettes=.*$/m)[0]);
 evaluate(source.slice(source.indexOf('const haloOrders='),source.indexOf("let style='")));
 evaluate(section('AUDIO RESPONSE'));
 evaluate(source.slice(source.indexOf('const tronWrap='),source.indexOf('const bandStarts=')));
 evaluate(section('YOSEMITE RENDERER'));evaluate(section('FALLOUT RENDERER'));
 evaluate(source.slice(source.indexOf('function renderSpace('),source.indexOf('function drawThumbnails(')));
 ctx.b=new Float32Array(64);ctx.w=new Float32Array(256);
 function signal(kind){
  ctx.b.fill(0);ctx.w.fill(0);ctx.rms=kind==='silence'?0:.16;
  if(kind!=='silence'){
   for(let i=0;i<64;i++){const zone=i<19?'bass':i<49?'mid':'treble';ctx.b[i]=kind==='music'?.45:(kind===zone?.7:.02)}
   for(let i=0;i<256;i++)ctx.w[i]=Math.sin(i/256*Math.PI*12)*.22;
  }
  evaluate('resetResponse()');
 }
 function draw(kind,small=false,t=7){ctx.kind=kind;evaluate(`render(target,kind,${t},b,w,${small})`);return ctx.target.toBuffer('image/png')}
 const names=Array.from(evaluate('styles.map(s=>s[0])'));
 const output=process.argv[2];if(output)fs.mkdirSync(output,{recursive:true});
 const sheet=createCanvas(800,Math.ceil(names.length/2)*156),sc=sheet.getContext('2d');
 for(const [index,kind] of names.entries()){
  ctx.target=createCanvas(600,360);
  signal('silence');const silent=draw(kind);assert.deepEqual(draw(kind),silent,kind+' frozen frame');
  signal('music');const held=draw(kind);assert.notDeepEqual(held,silent,kind+' responds to music');
  evaluate('responseState.beat=1');const hit=draw(kind);assert.notDeepEqual(hit,held,kind+' responds to attacks with frozen time');
  assert.deepEqual(draw(kind),hit,kind+' attack render is deterministic');
  const thumbnail=draw(kind,true);ctx.rms=.9;evaluate('responseState.beat=0');
  assert.deepEqual(draw(kind,true),thumbnail,kind+' thumbnail ignores live amplitude/attack');
  if(['orbit','bloom','halo','ironMan','constellation','yosemite','tron','spaceFlight','forestWalk','minecraft'].includes(kind)){
   signal('bass');const bass=draw(kind);signal('treble');assert.notDeepEqual(draw(kind),bass,kind+' distinguishes bass and treble');
  }
  for(const [width,height] of [[390,520],[1600,680],[264,156]]){
   ctx.target=createCanvas(width,height);signal('music');evaluate('responseState.beat=1');
   for(const t of [0,7,1000000])draw(kind,width===264,t);
  }
  ctx.target=createCanvas(400,156);signal('music');evaluate('responseState.beat=1');draw(kind);
  sc.drawImage(ctx.target,(index%2)*400,Math.floor(index/2)*156);
  sc.fillStyle='#fff';sc.font='12px sans-serif';sc.fillText(kind,(index%2)*400+10,Math.floor(index/2)*156+18);
 }
 for(const mode of ['identityDiscs','circuitExpansion']){
  ctx.tronMode=mode;signal('music');const held=draw('tron');evaluate('responseState.beat=1');assert.notDeepEqual(draw('tron'),held,mode+' attack response');
 }
 // Geometry must still respond when the user turns glow all the way down.
 ctx.glow=0;for(const kind of names){signal('music');const held=draw(kind);evaluate('responseState.beat=1');assert.notDeepEqual(draw(kind),held,kind+' responds with glow off')}
 if(output)fs.writeFileSync(path.join(output,'music-reactivity.png'),sheet.toBuffer('image/png'));
 console.log('PASS: onset/decay/noise gate at 30/60/120 fps; all 17 scenes and 3 Tron modes respond with frozen motion; band separation, static thumbnails, glow off, portrait/wide/long-time rendering.');
})().catch(error=>{console.error(error);process.exitCode=1});
