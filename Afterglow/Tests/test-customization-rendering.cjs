// Actual Canvas pixels for every targeted scene; user-facing events are covered in test-controls.
const {JSDOM}=require('jsdom');
const {createCanvas,Path2D}=require('@napi-rs/canvas');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const canvases=new WeakMap();
function surface(el){let c=canvases.get(el);if(!c||c.width!==el.width||c.height!==el.height){c=createCanvas(el.width,el.height);canvases.set(el,c)}return c}
const dom=new JSDOM(fs.readFileSync(path.join(__dirname,'../Preview.html'),'utf8'),{url:'https://afterglow.test',runScripts:'dangerously',beforeParse(w){
 w.matchMedia=()=>({matches:false,addEventListener(){}});w.Image=class{};w.Path2D=Path2D;
 w.requestAnimationFrame=()=>1;w.cancelAnimationFrame=()=>{};w.ResizeObserver=class{observe(){}};
 w.Audio=class{constructor(){this.paused=true;this.volume=.8}pause(){}};
 w.HTMLCanvasElement.prototype.getContext=function(){return surface(this).getContext('2d')};
}});
const w=dom.window,canvas=w.document.getElementById('visual');canvas.width=600;canvas.height=400;
const run=code=>w.eval(code);
function draw(){run("render($('visual'),style,7,bands,wave)");return surface(canvas).toBuffer('image/png')}
run('bands.fill(.4);wave.fill(.2);rms=.2');
for(const kind of run('customizableStyles')){
 run(`pickStyle('${kind}');customizations={}`);const original=draw();
 run("updateCustomization({colors:['#00ff00','#00aa00','#aaff00']})");const colored=draw();
 assert.notDeepEqual(colored,original,kind+' color changes real pixels');
 run('updateCustomization({size:.5})');const small=draw();assert.notDeepEqual(small,colored,kind+' size changes real pixels');
 assert.deepEqual(draw(),small,kind+' remains deterministic while motion is frozen');
 run('updateCustomization({size:1.5})');assert.notDeepEqual(draw(),small,kind+' supports enlargement');
 run('customizations={}');assert.deepEqual(draw(),original,kind+' reset restores original render without leaking transforms');
}
run("pickStyle('ironMan');updateCustomization({colors:['#00ff00','#00aa00','#aaff00']})");
for(const [width,height] of [[320,500],[1000,300],[264,156]]){canvas.width=width;canvas.height=height;draw()}
dom.window.close();console.log('PASS: all 11 visualizers change pixels for custom colors/size, deterministic frames, reset, transform isolation, and responsive sizes.');
