// Development-only: @napi-rs/canvas + ffmpeg. Frames use the actual preview renderers.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),{spawn}=require('node:child_process');
const {createCanvas,loadImage,Path2D,GlobalFonts}=require('@napi-rs/canvas');
const root=path.resolve(__dirname,'..'),out=process.argv[2]||path.join(root,'Demo/Afterglow-Duo-Demo.mp4');
const W=1280,H=800,FPS=24,DURATION=24;
const font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';if(fs.existsSync(font))GlobalFonts.registerFromPath(font,'Demo Sans');
const smooth=v=>{v=Math.max(0,Math.min(1,v));return v*v*(3-2*v)};
(async()=>{
 const html=fs.readFileSync(path.join(root,'Preview.html'),'utf8');
 const renderer=html.split('// BEGIN YOSEMITE RENDERER')[1].split('function drawThumbnails()')[0];
 const palettes={Ultraviolet:['#91a1ff','#cb79ff','#f3b0e6'],Glacier:['#55dcd9','#68b2ff','#c6fff2'],Ember:['#ff9760','#f25d86','#ffe0a3'],Candy:['#ff80c7','#868bff','#57eee0'],Monochrome:['#d1d7e6','#ffffff','#737f99']};
 const context=vm.createContext({Path2D,Math,palettes,palette:'Ultraviolet',rms:.12,gain:1.25,detail:.65,glow:.6,devicePixelRatio:1,yosemiteAssetsReady:true,
  yosemiteLandscape:await loadImage(path.join(root,'Assets.xcassets/YosemiteLandscape.imageset/YosemiteLandscape.png')),
  yosemiteCloud:await loadImage(path.join(root,'Assets.xcassets/YosemiteCloud.imageset/YosemiteCloud.png')),
  document:{createElement:()=>createCanvas(1,1)}});
 vm.runInContext(renderer,context);const render=context.render;
 const analysis=JSON.parse(fs.readFileSync(path.join(root,'Demo/score-analysis.json'),'utf8'));
 const canvas=createCanvas(W,H),c=canvas.getContext('2d'),scene=createCanvas(1,1);
 const thumbnails={};for(const kind of ['yosemite','aurora','orbit']){let thumb=createCanvas(180,108);render(thumb,kind,7,Array(64).fill(.4),Array(256).fill(0),true);thumbnails[kind]=thumb}
 function box(x,y,w,h,r,color){c.beginPath();c.roundRect(x,y,w,h,r);c.fillStyle=color;c.fill()}
 function text(value,x,y,size=16,color='#edf1ff',weight='400'){c.font=`${weight} ${size}px "Demo Sans", sans-serif`;c.fillStyle=color;c.fillText(value,x,y)}
 function line(x,y,x2,y2,color='#ffffff14',width=1){c.beginPath();c.moveTo(x,y);c.lineTo(x2,y2);c.strokeStyle=color;c.lineWidth=width;c.stroke()}
 function clipBox(x,y,w,h,r,draw){c.save();c.beginPath();c.roundRect(x,y,w,h,r);c.clip();draw();c.restore()}
 function miniSlider(x,y,w,label,value){text(label,x,y,13,'#c1cadc');text(label==='MOTION'?'0.7×':'60%',x+w-32,y,11,'#75839c');box(x,y+15,w,3,2,'#293249');box(x,y+15,w*value,3,2,'#b6c3ff');box(x+w*value-5,y+11,11,11,6,'#d0daff')}
 function deck(x,y,w,h,kind,table){
  text('YOUR CONTROL DECK',x,y+15,10,'#8794ae');text('Find your atmosphere.',x,y+49,21);
  const cw=(w-18)/3,ch=cw*.6;
  ['yosemite','aurora','orbit'].forEach((id,i)=>{const tx=x+i*(cw+9);clipBox(tx,y+68,cw,ch,8,()=>c.drawImage(thumbnails[id],tx,y+68,cw,ch));if(id===kind){c.strokeStyle='#c3ccff';c.lineWidth=1.6;c.beginPath();c.roundRect(tx,y+68,cw,ch,8);c.stroke()}text(id[0].toUpperCase()+id.slice(1),tx,y+ch+88,11,id===kind?'#eef1ff':'#7886a2')});
  if(table)return;
  Object.values(palettes).forEach((p,i)=>{box(x+i*42,y+ch+117,32,32,16,i===0?'#303b5c':'#192236');box(x+i*42+7,y+ch+124,18,18,9,p[0])});
  miniSlider(x,y+ch+184,w,'MOTION',.34);miniSlider(x,y+ch+245,w,'GLOW',.6);
  box(x,y+h-55,w,43,10,'#1b2740');text('Choose music  +',x+16,y+h-27,12,'#c3ceeb');
 }
 function drawScreen(x,y,w,h,pose,kind,t,index){
  const narrow=pose==='closed',table=pose==='tabletop',pad=narrow?14:18,headerH=65,footerH=72;
  box(x,y,w,h,20,'#090e19');text('≋',x+pad,y+43,32,'#b1bfff');text('afterglow',x+pad+36,y+39,23,'#eff2fc');text('☷',x+w-45,y+39,22,'#aebbd7');
  line(x+pad,y+headerH,x+w-pad,y+headerH);
  let sx=x+pad,sy=y+headerH+14,sw,sh;
  if(narrow){sw=w-2*pad;sh=h-255}
  else if(table){sw=w-2*pad;sh=(h-headerH-footerH)*.50-15}
  else{sw=(w-3*pad)*.61;sh=h-headerH-footerH-28}
  const rw=Math.round(sw),rh=Math.round(sh);if(scene.width!==rw||scene.height!==rh){scene.width=rw;scene.height=rh}
  context.rms=analysis[index].rms;render(scene,kind,t*1.5+7,analysis[index].bands,analysis[index].wave);
  clipBox(sx,sy,sw,sh,16,()=>c.drawImage(scene,sx,sy,sw,sh));
  box(sx+12,sy+12,106,25,13,'#09121de6');box(sx+22,sy+22,5,5,3,'#a7f1c7');text('DEMO AUDIO',sx+35,sy+29,8,'#d7e1f7');
  const shade=c.createLinearGradient(0,sy+sh*.55,0,sy+sh);shade.addColorStop(0,'#050a1200');shade.addColorStop(1,'#050a12b0');clipBox(sx,sy,sw,sh,16,()=>{c.fillStyle=shade;c.fillRect(sx,sy,sw,sh)});
  text(kind==='yosemite'?'Yosemite':'Aurora',sx+18,sy+sh-38,29);text(kind==='yosemite'?'Clouds over the valley':'Ribbons of light',sx+18,sy+sh-17,10,'#b4c0d5');
  if(narrow){const dy=sy+sh+23;['yosemite','aurora','orbit'].forEach((id,i)=>{const cw=(w-pad*2-16)/3;clipBox(sx+i*(cw+8),dy,cw,56,8,()=>c.drawImage(thumbnails[id],sx+i*(cw+8),dy,cw,56));text(id[0].toUpperCase()+id.slice(1),sx+i*(cw+8),dy+72,11,'#a7b6d0')})}
  else if(table){const dy=sy+sh+24;line(x+8,dy-12,x+w-8,dy-12,'#0a101b',9);deck(sx,dy,sw*.49,155,kind,true);miniSlider(sx+sw*.55,dy+35,sw*.43,'MOTION',.34);miniSlider(sx+sw*.55,dy+101,sw*.43,'GLOW',.6)}
  else deck(sx+sw+pad,sy+4,w-sw-3*pad,sh,kind,false);
  const fy=y+h-footerH;box(x+8,fy,w-16,footerH-8,14,'#111b2d');box(x+20,fy+13,40,40,10,'#293855');text('♪',x+33,fy+40,22,'#b9c8ee');text('Open Sky',x+72,fy+30,13);text('Original demo soundtrack',x+72,fy+48,9,'#7e8fab');box(x+w-65,fy+13,40,40,20,'#c3d0ff');text('Ⅱ',x+w-51,fy+40,17,'#14213b');
 }
 const ff=spawn('ffmpeg',['-y','-f','rawvideo','-pixel_format','rgba','-video_size',`${W}x${H}`,'-framerate',String(FPS),'-i','pipe:0','-i',path.join(root,'Demo/Open-Sky.wav'),'-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-shortest','-movflags','+faststart',out],{stdio:['pipe','ignore','pipe']});
 let error='';ff.stderr.on('data',b=>{error=(error+b.toString()).slice(-5000)});
 const result=new Promise((resolve,reject)=>{ff.on('error',reject);ff.on('exit',code=>code===0?resolve():reject(new Error(error)))});
 const layouts=[{w:326,h:475},{w:668,h:470},{w:668,h:470},{w:668,h:470}];
 for(let i=0;i<DURATION*FPS;i++){
  const t=i/FPS,phase=Math.min(3,Math.floor(t/6)),pose=['closed','open','tabletop','open'][phase],kind=phase===3?'aurora':'yosemite';
  const bg=c.createLinearGradient(0,0,W,H);bg.addColorStop(0,'#060a12');bg.addColorStop(1,'#172339');c.fillStyle=bg;c.fillRect(0,0,W,H);
  const halo=c.createRadialGradient(940,400,10,940,400,480);halo.addColorStop(0,phase===3?'#64519a36':'#536f9333');halo.addColorStop(1,'#1f294000');c.fillStyle=halo;c.fillRect(0,0,W,H);
  text('≋',55,68,40,'#b5c4ff');text('afterglow',106,62,26);text('IPHONE DUO  /  ADAPTIVE STUDIO',W-368,57,10,'#8192ae');line(55,95,W-55,95);
  text(['01  /  CLOSED','02  /  OPEN','03  /  TABLETOP','04  /  YOUR ATMOSPHERE'][phase],60,218,11,'#95a8cb');
  const titles=[['Pocket-sized.','World-opening.'],['More view.','More control.'],['Set it down.','Sink into it.'],['Find your','frequency.']][phase];
  titles.forEach((s,k)=>text(s,55,310+k*70,49,k===1?'#b7caff':'#f0f3fb'));
  const body=[['A Yosemite escape,','wherever the music takes you.'],['A larger scene. A dedicated deck.','Your session stays with you.'],['Scenery above. Controls below.','A listening room, anywhere.'],['Nine ways to see your sound.','Make the atmosphere your own.']][phase];body.forEach((s,k)=>text(s,60,455+k*29,15,'#92a2bd'));
  ['CLOSED','OPEN','TABLETOP'].forEach((label,k)=>{box(60+k*134,540,119,40,10,(phase===3?1:phase)===k?'#2a3c60':'#131e30');text(label,76+k*134,566,10,(phase===3?1:phase)===k?'#dce5ff':'#7586a6')});
  let dims=layouts[phase];if(phase>0){const f=smooth((t-phase*6)/.8);dims={w:layouts[phase-1].w+(dims.w-layouts[phase-1].w)*f,h:layouts[phase-1].h+(dims.h-layouts[phase-1].h)*f}}
  const x=890-dims.w/2,y=394-dims.h/2;
  c.save();c.shadowColor='#000a';c.shadowBlur=45;c.shadowOffsetY=26;box(x-11,y-11,dims.w+22,dims.h+22,30,'#313e52');c.restore();
  const logical=pose==='closed'?{w:466,h:678}:{w:890,h:626};c.save();c.translate(x,y);c.scale(dims.w/logical.w,dims.h/logical.h);drawScreen(0,0,logical.w,logical.h,pose,kind,t,i);c.restore();
  line(55,716,W-55,716);text('Yosemite • drifting clouds • valley mist • audio-reactive light',60,752,11,'#8094b6');text('RENDERED LAYOUT DEMO · NOT A DEVICE RECORDING',W-397,752,8,'#637692');
  box(0,H-3,W*(t/DURATION),3,0,'#b5c9ff');
  if([0,8*FPS,14*FPS,20*FPS].includes(i))fs.writeFileSync(path.join(root,`Demo/frame-${i/FPS}.png`),canvas.toBuffer('image/png'));
  const raw=c.getImageData(0,0,W,H).data;
  if(!ff.stdin.write(Buffer.from(raw.buffer,raw.byteOffset,raw.byteLength)))await new Promise(resolve=>ff.stdin.once('drain',resolve));
  if(i%144===0)console.log(`Rendered ${i/FPS}/${DURATION} seconds`);
 }
 ff.stdin.end();await result;console.log('Saved',out);
})().catch(e=>{console.error(e);process.exitCode=1});
