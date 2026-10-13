// Real Canvas coverage of the block-world scene, with controlled clock/input.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {createCanvas}=require('@napi-rs/canvas');
const output=process.argv[2]||path.join(require('node:os').tmpdir(),'afterglow-minecraft');
fs.mkdirSync(output,{recursive:true});
const environment=vm.createContext({Math,Number,parseInt,rms:0,gain:1.25,glow:.6,detail:.65,
 palettes:{Glacier:['#55dcd9'],Ember:['#ff9760']},palette:'Glacier'});
vm.runInContext(fs.readFileSync(path.join(__dirname,'../Web/app.js'),'utf8').split('// BEGIN AUDIO RESPONSE')[1].split('// END AUDIO RESPONSE')[0],environment);
vm.runInContext(fs.readFileSync(path.join(__dirname,'../Web/minecraft.js'),'utf8'),environment);
const column=c=>vm.runInContext(`minecraftColumn(${c})`,environment);
const ore=(c,d)=>vm.runInContext(`minecraftOre(${c},${d})`,environment);
const heights=new Set(),ores=new Set();let trees=0,torches=0,creepers=0;
for(let c=-2000;c<20000;c++){
 const info=column(c);heights.add(info.height);
 assert(Number.isInteger(info.height)&&info.height>=1&&info.height<=6,'Surface stays within six blocks');
 assert(Math.abs(column(c+1).height-info.height)<=2,'Neighboring columns are walkable');
 assert(info.tree+info.torch+info.creeper<=1,'One feature per column');
 trees+=info.tree;torches+=info.torch;creepers+=info.creeper;
 assert.equal(ore(c,2),-1,'Dirt never contains ore');
 const kind=ore(c,6);if(kind>=0)ores.add(kind);
}
assert.equal(heights.size,6);assert.equal(ores.size,5,'All five ores appear');
assert(trees>1500&&torches>800&&creepers>300,'Trees, torches and creepers recur');
for(const c of [NaN,Infinity,-5,1e9])assert.doesNotThrow(()=>column(c));
const bands=Array.from({length:64},()=>.6),silent=Array(64).fill(0);
function draw(canvas,time,input=silent,small=false,hit=0){environment.canvas=canvas;environment.bands=input;vm.runInContext(`resetResponse();responseState.beat=${hit}`,environment);vm.runInContext(`renderMinecraft(canvas,${time},bands,${small})`,environment);return canvas.toBuffer('image/png')}
const desktop=createCanvas(1200,760),still=draw(desktop,4);
assert.deepEqual(draw(desktop,4),still,'Frozen clock produces identical pixels');
assert.notDeepEqual(draw(desktop,5),still,'Terrain scrolls and the miner walks');
assert.notDeepEqual(draw(desktop,4,bands),still,'Ore glow responds to bands with motion frozen');
environment.rms=.5;assert.notDeepEqual(draw(desktop,4),still,'Pickaxe, torches and orbs respond to level with motion frozen');environment.rms=0;
const attack=draw(desktop,4,bands,false,1);assert.notDeepEqual(attack,draw(desktop,4,bands),'Torches and pickaxe respond to attacks with motion frozen');
environment.palette='Ember';assert.notDeepEqual(draw(desktop,4),still,'Palette tints experience orbs');environment.palette='Glacier';
const brightness=time=>{draw(desktop,time);const data=desktop.getContext('2d').getImageData(0,0,1200,200).data;let sum=0;for(let i=0;i<data.length;i+=4)sum+=data[i]+data[i+1]+data[i+2];return sum/(data.length/4)};
assert(brightness(0)>brightness(60)*2,'Day sky is brighter than night sky');
fs.writeFileSync(path.join(output,'minecraft-night.png'),draw(desktop,60,bands));
for(const [name,w,h] of [['desktop',1200,760],['phone',390,520],['ultrawide',1600,680],['thumbnail',264,156]]){
 const canvas=createCanvas(w,h);fs.writeFileSync(path.join(output,`minecraft-${name}.png`),draw(canvas,4,bands,name==='thumbnail'));
 const pixels=canvas.getContext('2d').getImageData(0,0,w,h).data;
 let grass=0,stone=0;
 for(let i=0;i<pixels.length;i+=4){
  assert.equal(pixels[i+3],255,'Opaque scene');
  if(pixels[i+1]>pixels[i]*1.3&&pixels[i+1]>pixels[i+2]*1.3)grass++;
  if(Math.abs(pixels[i]-pixels[i+1])<6&&Math.abs(pixels[i+1]-pixels[i+2])<6&&pixels[i]>90&&pixels[i]<140)stone++;
 }
 assert(grass>w*h*.01,'Grass remains visible at '+name);assert(stone>w*h*.04,'Stone remains visible at '+name);
 for(const t of [0,59.99,120,1000000])draw(canvas,t,bands,name==='thumbnail');
}
console.log('PASS: Minecraft terrain bounds and walkability, all ores, trees/torches/creepers, deterministic pause, band and level response with motion frozen, day/night, palettes and responsive Canvas output.');
