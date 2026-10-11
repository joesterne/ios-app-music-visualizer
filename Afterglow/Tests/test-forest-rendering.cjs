// Real Canvas coverage of the standalone scene, with controlled clock/input.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const {createCanvas}=require('@napi-rs/canvas');
const output=process.argv[2]||path.join(require('node:os').tmpdir(),'afterglow-forest');
fs.mkdirSync(output,{recursive:true});
const environment=vm.createContext({Math,rms:0,gain:1.25,glow:.6,detail:.65,
 palettes:{Glacier:['#55dcd9'],Ember:['#ff9760']},palette:'Glacier'});
vm.runInContext(fs.readFileSync(path.join(__dirname,'../Web/forest-walk.js'),'utf8'),environment);
const encounter=time=>vm.runInContext(`forestEncounter(${time})`,environment);
const kinds=new Set(),sides=new Set();let quiet=0,visible=0;
for(let i=0;i<10000;i++){
 const e=encounter(i*.1);
 if(!e){quiet++;continue}visible++;kinds.add(e.kind);sides.add(e.side);
 assert(e.progress>=0&&e.progress<1&&e.opacity>=0&&e.opacity<=1);
 assert(e.depth>=.48&&e.depth<=.66);
 assert.deepEqual(encounter(i*.1),e,'Frozen time keeps the same animal and pose');
}
assert.equal(kinds.size,4);assert.equal(sides.size,2);assert(quiet>1000&&visible>4000,'Encounters have visible windows and quiet gaps');
for(const t of [0,10,1000000,NaN,Infinity,-5])assert.doesNotThrow(()=>encounter(t));
function draw(canvas,time,small=false){environment.canvas=canvas;vm.runInContext(`renderForestWalk(canvas,${time},[],${small})`,environment);return canvas.toBuffer('image/png')}
const desktop=createCanvas(1200,760),still=draw(desktop,4);
assert.deepEqual(draw(desktop,4),still,'Frozen clock produces identical pixels');
assert.notDeepEqual(draw(desktop,5),still,'Walking and parallax animate');
environment.rms=.5;assert.notDeepEqual(draw(desktop,4),still,'Light and foliage respond to input with motion frozen');
environment.rms=0;environment.palette='Ember';assert.notDeepEqual(draw(desktop,4),still,'Palette changes firefly accents');environment.palette='Glacier';
for(const [name,w,h] of [['desktop',1200,760],['phone',390,520],['ultrawide',1600,680],['thumbnail',264,156]]){
 const canvas=createCanvas(w,h);fs.writeFileSync(path.join(output,`forest-${name}.png`),draw(canvas,4,name==='thumbnail'));
 const pixels=canvas.getContext('2d').getImageData(0,0,w,h).data;
 let green=0,gold=0;
 for(let i=0;i<pixels.length;i+=4){assert.equal(pixels[i+3],255,'Opaque scene');if(pixels[i+1]>pixels[i]*1.2)green++;if(pixels[i]>150&&pixels[i+1]>110&&pixels[i+2]<130)gold++}
 assert(green>w*h*.1,'Forest remains visible at '+name);assert(gold>w*h*.0005,'Walker remains visible at '+name);
 for(const t of [0,9.99,10,240,1000000])draw(canvas,t,name==='thumbnail');
}
for(let kind=0;kind<4;kind++){
 let time=4;while(encounter(time)?.kind!==kind)time+=10;
 fs.writeFileSync(path.join(output,`forest-animal-${kind}.png`),draw(desktop,time));
}
console.log('PASS: Forest encounters include all four species, both trail sides, quiet gaps, bounded fades, deterministic pause, frozen-motion audio response, palettes and responsive Canvas output.');
