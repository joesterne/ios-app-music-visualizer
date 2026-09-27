// Optional development-only Canvas verification. Install @napi-rs/canvas to run.
// This executes the real preview renderer in Skia, not a browser or native SwiftUI.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const output=process.argv[2]||path.join(require('node:os').tmpdir(),'afterglow-yosemite-validation');
const {createCanvas,loadImage,Path2D}=require('@napi-rs/canvas');
(async()=>{
const html=fs.readFileSync(path.join(root,'Preview.html'),'utf8');
const code=html.split('// BEGIN YOSEMITE RENDERER')[1].split('// END YOSEMITE RENDERER')[0];
const palettes={Ultraviolet:['#91a1ff','#cb79ff','#f3b0e6'],Glacier:['#55dcd9','#68b2ff','#c6fff2'],Ember:['#ff9760','#f25d86','#ffe0a3'],Candy:['#ff80c7','#868bff','#57eee0'],Monochrome:['#d1d7e6','#ffffff','#737f99']};
let caches=0;
const context=vm.createContext({Path2D,Math,palettes,palette:'Ultraviolet',rms:.12,gain:1.25,detail:.65,glow:.6,yosemiteAssetsReady:true,
 yosemiteLandscape:await loadImage(path.join(root,'Assets.xcassets/YosemiteLandscape.imageset/YosemiteLandscape.png')),
 yosemiteCloud:await loadImage(path.join(root,'Assets.xcassets/YosemiteCloud.imageset/YosemiteCloud.png')),
 document:{createElement(){caches++;return createCanvas(1,1)}}});
vm.runInContext(code,context);
const draw=(canvas,t,small=false)=>{context.target=canvas;vm.runInContext(`renderYosemite(target,${t},${small})`,context);return canvas.toBuffer('image/png')};
fs.mkdirSync(output,{recursive:true});
const wide=createCanvas(1440,810);const first=draw(wide,7);fs.writeFileSync(path.join(output,'desktop-t7.png'),first);
assert.equal(caches,1);assert.deepEqual(draw(wide,7),first,'Paused frame must remain identical');assert.equal(caches,1,'Reuse static background');
const later=draw(wide,32);assert.notDeepEqual(later,first,'Clouds and birds must move');assert.equal(caches,1);fs.writeFileSync(path.join(output,'desktop-t32.png'),later);
for(const [name,W,H] of [['phone',390,520],['wide',1600,680],['thumbnail',264,156]]){fs.writeFileSync(path.join(output,`${name}.png`),draw(createCanvas(W,H),7,name==='thumbnail'))}
let before=caches;context.palette='Glacier';draw(wide,7);assert.equal(caches,before+1,'Palette invalidates cache once');draw(wide,8);assert.equal(caches,before+1);
wide.width=1024;draw(wide,7);assert.equal(caches,before+2,'Resize invalidates cache once');
context.palette='Ember';context.detail=1;context.glow=1;fs.writeFileSync(path.join(output,'ember.png'),draw(wide,22));
const silent=draw(wide,7);context.rms=.6;assert.notDeepEqual(draw(wide,7),silent,'Audio changes sunlight');
context.yosemiteAssetsReady=false;draw(wide,7);
console.log('PASS: renderer draws landscape/phone/thumbnail frames; motion, frozen frame, light response, background cache, palette/resize invalidation, loading fallback.');
})().catch(error=>{console.error(error);process.exitCode=1});
