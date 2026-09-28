// Real Canvas renderer coverage; no browser or native runtime claim.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {createCanvas}=require('@napi-rs/canvas');
const output=process.argv[2]||path.join(require('node:os').tmpdir(),'afterglow-fallout');
const source=fs.readFileSync(path.join(__dirname,'../Web/app.js'),'utf8').split('// BEGIN FALLOUT RENDERER')[1].split('// END FALLOUT RENDERER')[0];
const environment=vm.createContext({Math,rms:0,gain:1.25,glow:.6,detail:.65});vm.runInContext(source,environment);
const bands=new Float32Array(64);environment.bands=bands;
function draw(canvas,time,small=false){environment.canvas=canvas;vm.runInContext(`renderFallout(canvas,${time},bands,${small})`,environment);return canvas.toBuffer('image/png')}
fs.mkdirSync(output,{recursive:true});
const desktop=createCanvas(1200,760),first=draw(desktop,7);
assert.deepEqual(draw(desktop,7),first,'A frozen clock produces an identical scene');
assert.notDeepEqual(draw(desktop,15),first,'Vault doors and code animate');
fs.writeFileSync(path.join(output,'fallout-desktop.png'),first);
const silent=draw(desktop,7);environment.rms=.6;bands.fill(.7);
assert.notDeepEqual(draw(desktop,7),silent,'CRT luminance, indicators, and traces respond with motion frozen');
for(const [name,w,h] of [['phone',390,520],['ultrawide',1600,680],['thumbnail',264,156]]){
 const canvas=createCanvas(w,h);fs.writeFileSync(path.join(output,`fallout-${name}.png`),draw(canvas,7,name==='thumbnail'));
 const pixels=canvas.getContext('2d').getImageData(0,0,w,h).data;let green=0;
 for(let i=0;i<pixels.length;i+=4)if(pixels[i+1]>pixels[i]*1.2&&pixels[i+1]>pixels[i+2]*1.2&&pixels[i+1]>80)green++;
 assert(green>w*h*.001,'Green CRT content remains visible at '+name+' size');
 for(const time of [0,39.2698,240,1000000])draw(canvas,time,name==='thumbnail');
}
// Both doors move horizontally and rotate in step with traveled distance.
const canvas=createCanvas(800,500),ctx=canvas.getContext('2d'),translations=[],rotations=[];
const translate=ctx.translate.bind(ctx),rotate=ctx.rotate.bind(ctx);
ctx.translate=(x,y)=>{translations.push([x,y]);translate(x,y)};ctx.rotate=a=>{rotations.push(a);rotate(a)};
draw(canvas,0);draw(canvas,10);
assert.equal(translations.length,4);assert.notEqual(translations[0][0],translations[2][0]);assert.notEqual(translations[1][0],translations[3][0]);
assert(Math.abs(rotations[3]-rotations[1]-(translations[3][0]-translations[1][0])/Math.min(800*.24,500*.23))<1e-9);
console.log('PASS: Fallout rolling-door geometry, deterministic pause, live CRT response, desktop/portrait/thumbnail rendering and long-running timestamps.');
