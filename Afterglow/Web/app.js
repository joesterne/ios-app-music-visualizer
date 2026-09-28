
"use strict";
const $=id=>document.getElementById(id);
const styles=[['yosemite','Yosemite','Clouds over the valley'],['aurora','Aurora','Ribbons of light'],['spectrum','Spectrum','Every frequency, in color'],['orbit','Orbit','Sound in circular motion'],['waveform','Waveform','The shape of a moment'],['tunnel','Tunnel','An infinite escape'],['constellation','Constellation','A sky of connections'],['terrain','Terrain','Ride the frequency landscape'],['bloom','Bloom','Let the sound unfold'],['tron','Tron','Enter the grid'],['halo','Halo','Beyond the ringworld'],['ironMan','Iron Man','Power the arc reactor'],['superMario','Super Mario','Run, jump, and follow the music'],['spaceFlight','Space Flight','Bank past planets. Slip between starships.']];
const palettes={Ultraviolet:['#91a1ff','#cb79ff','#f3b0e6'],Glacier:['#55dcd9','#68b2ff','#c6fff2'],Ember:['#ff9760','#f25d86','#ffe0a3'],Candy:['#ff80c7','#868bff','#57eee0'],Monochrome:['#d1d7e6','#ffffff','#737f99']};
const motionPreference=matchMedia('(prefers-reduced-motion: reduce)');let reducedMotion=motionPreference.matches;
function motionStopped(){return paused||reducedMotion}
let fps=60;
let audioReactive=true;
try{audioReactive=localStorage.getItem('afterglow.audioReactive')!=='false'}catch{}
const haloOrders=new Map();
function haloOrder(n){if(!haloOrders.has(n))haloOrders.set(n,Array.from({length:n},(_,i)=>i).sort((a,b)=>Math.sin(a/n*Math.PI*2)-Math.sin(b/n*Math.PI*2)));return haloOrders.get(n)}
let style='yosemite',palette='Ultraviolet',source='ambient',paused=false,gain=1.25,speed=.65,glow=.6,detail=.65,time=7,last=0,activeMic=null,audioContext=null,analyzer=null,playerNode=null,micNode=null,objectURL=null;
let favorites=new Set(['aurora','orbit']);const audio=new Audio();audio.volume=.8;audio.preload='auto';
const bands=new Float32Array(64),wave=new Float32Array(256);let rms=.12;
let rawFrequency=null,rawWave=null,toastTimer=null;
const tronModes = [['lightCycles','Light cycles','Neon riders. Endless trails.'],['identityDiscs','Identity discs','Spin. Rebound. Repeat.'],['circuitExpansion','Circuit expansion','A circuit that never stops growing.']];
const tronColors = {'Light blue':'#66deff',Orange:'#ff8c30',Red:'#ff3347'};
let tronMode='lightCycles',tronColor='Light blue';
try { const saved=JSON.parse(localStorage.getItem('afterglow.tron')||'{}'); if(tronModes.some(m=>m[0]===saved.mode))tronMode=saved.mode; if(Object.hasOwn(tronColors,saved.color))tronColor=saved.color; } catch {}
function syncTron(){
  const active=style==='tron';$('tron-controls').hidden=!active;$('palettes').hidden=active;$('tron-palette-note').hidden=!active;$('palette-heading').textContent=active?'TRON COLOR':'COLOR PALETTE';
  document.documentElement.style.setProperty('--accent',active?tronColors[tronColor]:palettes[palette][0]);
  $('tron-mode').value=tronMode;
  document.querySelectorAll('[data-tron-color]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.tronColor===tronColor));
  if(active){const m=tronModes.find(m=>m[0]===tronMode);$('visual-name').textContent=m[1];$('visual-subtitle').textContent='TRON · '+tronColor+' · '+m[2];}
}
const tronWrap=(value,period)=>((value%period)+period)%period;
function tronReflect(value,lo,hi){const span=hi-lo;if(span<=0)return lo;const phase=tronWrap(value-lo,span*2);return lo+(phase<=span?phase:span*2-phase)}
const cycleRoutes=[
  [[.12,.19],[.74,.19],[.74,.43],[.88,.43],[.88,.79],[.39,.79],[.39,.57],[.12,.57]],
  [[.23,.87],[.23,.34],[.53,.34],[.53,.12],[.85,.12],[.85,.64],[.66,.64],[.66,.87]],
  [[.09,.70],[.09,.09],[.36,.09],[.36,.47],[.62,.47],[.62,.92],[.45,.92],[.45,.70]],
  [[.94,.92],[.77,.92],[.77,.54],[.47,.54],[.47,.26],[.94,.26]]
].map(r=>[...r,r[0]]);
function tronLength(points){return points.slice(1).reduce((sum,p,i)=>sum+Math.hypot(p[0]-points[i][0],p[1]-points[i][1]),0)}
function tronPose(points,distance){let d=Math.max(0,distance);for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i],dx=b[0]-a[0],dy=b[1]-a[1],length=Math.hypot(dx,dy);if(!length)continue;if(d<=length)return{x:a[0]+dx*d/length,y:a[1]+dy*d/length,angle:Math.atan2(dy,dx)};d-=length;}return{x:points.at(-1)[0],y:points.at(-1)[1],angle:0}}
function tronPrefix(points,progress){const d=tronLength(points)*Math.max(0,Math.min(1,progress)),out=[points[0]];let traveled=0;for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i],length=Math.hypot(b[0]-a[0],b[1]-a[1]);if(traveled+length>d){const p=tronPose([a,b],d-traveled);out.push([p.x,p.y]);return out}out.push(b);traveled+=length}return out}
function tronTrail(index,t){const route=cycleRoutes[index],perimeter=tronLength(route),head=tronWrap(t*(.11+index*.012)+index*.61,perimeter),start=head-.68,p=tronPose(route,tronWrap(start,perimeter)),out=[[p.x,p.y]];for(let lap=-1;lap<=0;lap++){let d=lap*perimeter;for(let i=1;i<route.length;i++){d+=Math.hypot(route[i][0]-route[i-1][0],route[i][1]-route[i-1][1]);if(d>start&&d<head)out.push(route[i])}}const q=tronPose(route,head);out.push([q.x,q.y]);return out}
function tronDisc(index,t,aspect){const W=Math.max(1,aspect),H=Math.max(1,1/aspect),speeds=[[.17,.13],[-.14,.19],[.21,-.12],[-.12,-.16]],v=speeds[index];return[tronReflect(W*(.2+index*.19)+t*v[0],.1,W-.1),tronReflect(H*(.22+index*.17)+t*v[1],.1,H-.1)]}
function tronCircuits(t){const growth=Math.max(0,t)/4.8+2.5,newest=Math.floor(growth),out=[];for(let ring=Math.max(0,newest-7);ring<=newest;ring++){const outer=.62*1.52**(ring-growth),inner=outer/1.52,p=Math.min(1,(growth-ring)*1.7);for(let arm=0;arm<8;arm++){const angle=arm*Math.PI/4,u=[Math.cos(angle),Math.sin(angle)],v=[-Math.sin(angle),Math.cos(angle)],at=(r,d=0)=>[u[0]*r+v[0]*d,u[1]*r+v[1]*d],mid=inner+(outer-inner)*.45,offset=(outer-inner)*(arm%2?-.34:.34),spur=(outer-inner)*.55;out.push({points:[at(inner),at(mid),at(mid,offset),at(outer,offset),at(outer)],progress:p});out.push({points:[at(mid,offset),at(mid,offset+spur),at(mid+(outer-inner)*.23,offset+spur)],progress:Math.max(0,(p-.45)/.55)})}}return out}
function renderTron(canvas,t,b,small){
  const ctx=canvas.getContext('2d'),W=canvas.width,H=canvas.height,D=Math.min(W,H),C=tronColors[tronColor],E=small?.35:Math.min(1,rms*gain*3),scale=Math.max(.5,D/350);
  ctx.save();ctx.globalCompositeOperation='source-over';ctx.globalAlpha=1;ctx.shadowBlur=0;ctx.fillStyle='#030910';ctx.fillRect(0,0,W,H);
  const wash=ctx.createRadialGradient(W/2,H/2,0,W/2,H/2,Math.max(W,H)*.65);wash.addColorStop(0,C+'19');wash.addColorStop(1,C+'00');ctx.fillStyle=wash;ctx.fillRect(0,0,W,H);ctx.globalCompositeOperation='lighter';
  function stroke(points,opacity=.8,width=1.4,haze=true){ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.strokeStyle=C;ctx.globalAlpha=opacity;ctx.lineWidth=width;ctx.lineCap='round';ctx.lineJoin='round';ctx.shadowColor=C;ctx.shadowBlur=haze&&!small?glow*12*scale:0;ctx.stroke();ctx.shadowBlur=0;}
  function ring(x,y,r,opacity,width){ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.strokeStyle=C;ctx.globalAlpha=opacity;ctx.lineWidth=width;ctx.shadowColor=C;ctx.shadowBlur=small?0:glow*10*scale;ctx.stroke();ctx.shadowBlur=0;}
  const spacing=Math.max(18,D/14);for(let x=0;x<=W;x+=spacing)stroke([[x,0],[x,H]],.055,.7,false);for(let y=0;y<=H;y+=spacing)stroke([[0,y],[W,y]],.055,.7,false);
  if(tronMode==='lightCycles')for(let index=0;index<(detail>.55&&!small?4:3);index++){
    stroke(tronTrail(index,t).map(p=>[p[0]*W,p[1]*H]),.65+index*.08,(2+E*2.2)*scale);
    const route=cycleRoutes[index],pose=tronPose(route,tronWrap(t*(.11+index*.012)+index*.61,tronLength(route)));
    ctx.save();ctx.translate(pose.x*W,pose.y*H);ctx.rotate(pose.angle);ctx.scale(scale,scale);ctx.globalCompositeOperation='source-over';ctx.globalAlpha=1;ctx.fillStyle='#06131b';ctx.fillRect(-12,-4,24,8);ctx.globalCompositeOperation='lighter';
    stroke([[-12,-4],[12,-4],[12,4],[-12,4],[-12,-4]],1,1.5);for(const x of [-8,8])stroke([[x-3,-6],[x+3,-6],[x+3,6],[x-3,6],[x-3,-6]],1,1.7);ctx.fillStyle='#eaffff';ctx.fillRect(-3,-2,8,4);ctx.restore();
  }
  if(tronMode==='identityDiscs')for(let index=0;index<(detail>.55&&!small?4:3);index++){
    const p=tronDisc(index,t,W/H),x=p[0]*D,y=p[1]*D,r=D*(.065+E*.014);
    for(let ghost=6;ghost>=1;ghost--){const q=tronDisc(index,t-ghost*.08,W/H);ring(q[0]*D,q[1]*D,r,(7-ghost)*.025,1.2)}
    ctx.save();ctx.translate(x,y);ctx.rotate(t*(index%2?-1.5:1.2)+index);ctx.globalCompositeOperation='source-over';ctx.globalAlpha=.96;ctx.fillStyle='#071018';ctx.beginPath();ctx.arc(0,0,r,0,Math.PI*2);ctx.fill();ctx.globalCompositeOperation='lighter';ring(0,0,r,1,Math.max(1.5,D*.006));ring(0,0,r*.58,.7,Math.max(1,D*.003));
    for(let mark=0;mark<3;mark++){const a=(mark*120+12)*Math.PI/180;ctx.beginPath();ctx.arc(0,0,r*.81,a,a+72*Math.PI/180);ctx.strokeStyle=C;ctx.globalAlpha=.85;ctx.lineWidth=Math.max(1.2,D*.005);ctx.stroke()}ctx.restore();
  }
  if(tronMode==='circuitExpansion'){
    const unit=Math.max(W,H)*1.9,map=p=>[W/2+p[0]*unit,H/2+p[1]*unit],traces=tronCircuits(t),terminals=[],dots=[];
    // Draw all paths with a single shadow pass, keeping long-running costs bounded.
    ctx.beginPath();traces.forEach((trace,i)=>{if(trace.progress<=0)return;const points=tronPrefix(trace.points,trace.progress);points.map(map).forEach(([x,y],j)=>j?ctx.lineTo(x,y):ctx.moveTo(x,y));terminals.push(map(points.at(-1)));const q=tronPose(points,tronLength(points)*tronWrap(t*.24+i*.19,1));dots.push(map([q.x,q.y]));});
    ctx.globalAlpha=.75;ctx.strokeStyle=C;ctx.lineWidth=(.9+E*.8)*scale;ctx.shadowColor=C;ctx.shadowBlur=small?0:glow*10*scale;ctx.stroke();ctx.shadowBlur=0;
    ctx.globalAlpha=.65;ctx.lineWidth=scale;ctx.beginPath();for(const [x,y] of terminals){ctx.moveTo(x+2.5*scale,y);ctx.arc(x,y,2.5*scale,0,Math.PI*2)}ctx.stroke();ctx.fillStyle='#eaffff';ctx.globalAlpha=.55+E*.4;ctx.beginPath();for(const [x,y] of dots){ctx.moveTo(x+1.5*scale,y);ctx.arc(x,y,1.5*scale,0,Math.PI*2)}ctx.fill();
    const r=D*.075;ctx.globalCompositeOperation='source-over';ctx.globalAlpha=1;ctx.fillStyle='#030910';ctx.fillRect(W/2-r,H/2-r,2*r,2*r);ctx.globalCompositeOperation='lighter';stroke([[W/2-r,H/2-r],[W/2+r,H/2-r],[W/2+r,H/2+r],[W/2-r,H/2+r],[W/2-r,H/2-r]],1,1.4*scale);ctx.fillStyle=C;ctx.font=Math.max(6,r*.4)+'px monospace';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText('GRID',W/2,H/2);
  }
  ctx.restore();
}


const bandStarts=new Uint16Array(64),bandEnds=new Uint16Array(64);
let animationRequest=null,lastDraw=null,needsRedraw=true,thumbnailsDirty=true,thumbnailKey=null;
const thumbnailBands=new Float32Array(64),thumbnailWave=new Float32Array(256);
ambient(7,thumbnailBands,thumbnailWave);
function requestThumbnails(){thumbnailsDirty=true;requestRender()}
function requestRender(){needsRedraw=true;if(!document.hidden&&animationRequest===null)animationRequest=requestAnimationFrame(tick)}
function configureBands(){const upper=Math.min(16000,audioContext.sampleRate*.48);for(let i=0;i<64;i++){bandStarts[i]=Math.max(1,Math.floor(40*(upper/40)**(i/64)/audioContext.sampleRate*analyzer.fftSize));bandEnds[i]=Math.min(rawFrequency.length-1,Math.ceil(40*(upper/40)**((i+1)/64)/audioContext.sampleRate*analyzer.fftSize))}}
function toast(message){$('toast').textContent=message;$('toast').hidden=false;clearTimeout(toastTimer);toastTimer=setTimeout(()=>$('toast').hidden=true,8500)}
function pickStyle(next){const s=styles.find(v=>v[0]===next);if(!s)return;requestRender();style=next;$('visual-name').textContent=s[1];$('visual-subtitle').textContent=s[2];document.querySelectorAll('.card').forEach(el=>{el.classList.toggle('active',el.dataset.style===style);el.setAttribute('aria-pressed',el.dataset.style===style)});updateFavorite();syncTron();if(window.parent!==window)window.parent?.postMessage?.({type:'afterglow-demo-state',visual:style},'*')}
function updateFavorite(){$('favorite').textContent=favorites.has(style)?'♥':'♡';$('favorite').setAttribute('aria-pressed',favorites.has(style))}
function pickPalette(next){if(!Object.hasOwn(palettes,next))return;requestRender();palette=next;document.documentElement.style.setProperty('--accent',palettes[palette][0]);document.querySelectorAll('.palette').forEach(el=>el.classList.toggle('active',el.dataset.palette===palette));requestThumbnails();if($('duo-speed'))syncDuoControls();syncTron()}
$('visual-count').textContent=String(styles.length).padStart(2,'0')+' / CHOOSE YOUR MOOD';
for(const [id,name] of styles){const b=document.createElement('button');b.className='card';b.dataset.style=id;b.setAttribute('aria-label',name+' visualizer');b.innerHTML='<canvas width="264" height="156"></canvas><span>'+name+'</span>';b.onclick=()=>pickStyle(id);$('gallery').appendChild(b)}
for(const [name,colors] of Object.entries(palettes)){const b=document.createElement('button');b.className='palette';b.dataset.palette=name;b.innerHTML='<span class="swatches">'+colors.map(c=>'<i style="background:'+c+'"></i>').join('')+'</span>'+name;b.onclick=()=>pickPalette(name);$('palettes').appendChild(b)}
function ambient(t,b,w,includeWaveform=true){for(let i=0;i<64;i++){const x=i/64;b[i]=Math.max(0,.16+.42*((Math.sin(x*9+t*.9)+1)/2)**2+.12*Math.sin(x*23-t*1.3))}if(includeWaveform)for(let i=0;i<256;i++){const x=i/256;w[i]=Math.sin(x*Math.PI*6+t)*.32+Math.sin(x*Math.PI*14-t*.7)*.12}}
// BEGIN YOSEMITE RENDERER
// The landscape is cached at each canvas size/palette; sprites decode once.
const yosemiteCache = new WeakMap();
const yosemiteSky = new Path2D();
const yosemiteSkyPoints = [[0,0],[1,0],[1,.257],[.971,.245],[.922,.205],[.91,.248],[.896,.260],[.87,.234],[.854,.221],[.837,.229],[.823,.256],[.811,.292],[.798,.346],[.77,.378],[.751,.392],[.72,.367],[.707,.406],[.683,.407],[.675,.420],[.647,.453],[.638,.430],[.62,.406],[.605,.393],[.588,.396],[.578,.393],[.566,.441],[.552,.483],[.526,.483],[.495,.459],[.47,.462],[.449,.497],[.42,.472],[.385,.465],[.365,.482],[.353,.462],[.337,.452],[.328,.431],[.316,.435],[.287,.385],[.283,.322],[.28,.242],[.25,.214],[.225,.207],[.208,.182],[.186,.172],[.166,.155],[.145,.142],[.13,.136],[.095,.149],[.09,.157],[.06,.156],[.02,.162],[0,.167]];
yosemiteSkyPoints.forEach(([x,y],i)=>i?yosemiteSky.lineTo(x*1672,y*941):yosemiteSky.moveTo(x*1672,y*941));
yosemiteSky.closePath();
const yosemiteClouds = [[.04,.015,.37,.0042],[.50,.070,.30,.0031],[.26,.220,.27,.0022],[.81,-.035,.43,.0050],[.67,.270,.24,.0018],[-.18,.130,.32,.0035]];
function renderYosemite(canvas,t,small=false){
  const ctx=canvas.getContext('2d'),W=canvas.width,H=canvas.height;
  if(W<1||H<1)return;
  ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';ctx.shadowBlur=0;
  if(!yosemiteAssetsReady){ctx.fillStyle='#627f9c';ctx.fillRect(0,0,W,H);ctx.restore();return}
  const scale=Math.max(W/1672,H/941),ox=(W-1672*scale)/2,oy=(H-941*scale)/2;
  let cached=yosemiteCache.get(canvas);
  if(!cached||cached.width!==W||cached.height!==H||cached.palette!==palette){
    const plate=document.createElement('canvas');plate.width=W;plate.height=H;
    const p=plate.getContext('2d');p.drawImage(yosemiteLandscape,ox,oy,1672*scale,941*scale);
    p.globalAlpha=palette==='Monochrome'?.035:.055;p.fillStyle=palettes[palette][0];p.fillRect(0,0,W,H);p.globalAlpha=1;
    const shade=p.createLinearGradient(0,0,0,H);shade.addColorStop(0,'#00000000');shade.addColorStop(.55,'#00000000');shade.addColorStop(1,'#0000006b');p.fillStyle=shade;p.fillRect(0,0,W,H);
    cached={width:W,height:H,palette,plate};yosemiteCache.set(canvas,cached);
  }
  ctx.drawImage(cached.plate,0,0);
  ctx.translate(ox,oy);ctx.scale(scale,scale);
  const quality=small?.3:detail,energy=Math.min(1,Math.max(0,(small?.12:rms)*gain*3));
  ctx.save();ctx.clip(yosemiteSky);
  for(let i=0;i<Math.min(yosemiteClouds.length,3+Math.floor(quality*3));i++){
    const [start,y,width,velocity]=yosemiteClouds[i],x=(start+t*velocity+width)%(1+2*width)-width;
    ctx.globalAlpha=i===2||i===4?.46:.78;
    ctx.drawImage(yosemiteCloud,x*1672,(y+Math.sin(t*.024+i)*.006)*941,width*1672,width*1672/3);
  }
  ctx.globalAlpha=.58;ctx.strokeStyle='#28394b';ctx.lineWidth=1.15;ctx.lineCap='round';ctx.beginPath();
  for(let i=0;i<2+Math.floor(quality*4);i++){
    const x=((.52+t*.0018+i*.016)%1.20-.10)*1672,y=(.325+Math.sin(t*.046+i*.65)*.028+i*.006)*941,wing=2.5+Math.sin(t*1.7+i)*1.1;
    ctx.moveTo(x-4,y-wing);ctx.quadraticCurveTo(x-1.7,y-wing,x,y);ctx.quadraticCurveTo(x+1.7,y-wing,x+4,y-wing);
  }
  ctx.stroke();ctx.restore();
  for(let i=0;i<(quality>.65?3:2);i++){
    const x=.265+Math.sin(t*.032+i*1.7)*.042,y=.635+i*.070+Math.sin(t*.024+i)*.008;
    ctx.globalAlpha=(.13-i*.025)*(.65+glow*.35+energy*.10);
    ctx.drawImage(yosemiteCloud,x*1672,y*941,1672*.48,941*.08);
  }
  ctx.globalAlpha=glow*(.035+energy*.065);ctx.globalCompositeOperation='screen';
  const light=ctx.createRadialGradient(1672*.22,941*.25,0,1672*.22,941*.25,1672*.62);
  light.addColorStop(0,palette==='Glacier'?'#c7eaff':'#ffe1ab');light.addColorStop(1,palette==='Glacier'?'#c7eaff00':'#ffe1ab00');
  ctx.fillStyle=light;ctx.fillRect(0,0,1672,941);ctx.restore();
}
// END YOSEMITE RENDERER

function renderSpace(canvas,t,b,small){
 const c=canvas.getContext('2d'),W=canvas.width,H=canvas.height,U=Math.min(W,H),C=palettes[palette],energy=Math.min(1,Math.max(0,rms*gain*3)),bank=Math.sin(t*.52)*.11,cx=W*(.5+bank),cy=H*(.45+Math.cos(t*.37)*.055);
 const point=(x,y,z)=>[cx+U*(x*Math.cos(bank)-y*Math.sin(bank))/z,cy+U*(x*Math.sin(bank)+y*Math.cos(bank))/z];
 const line=(pts,color,width=1)=>{c.beginPath();pts.forEach((p,i)=>i?c.lineTo(...p):c.moveTo(...p));c.strokeStyle=color;c.lineWidth=width;c.stroke()};
 c.globalAlpha=1;c.globalCompositeOperation='source-over';c.shadowBlur=0;c.fillStyle='#04061a';c.fillRect(0,0,W,H);
 const bg=c.createRadialGradient(cx,cy,0,cx,cy,Math.max(W,H)*.7);bg.addColorStop(0,C[1]+'45');bg.addColorStop(1,'#04061a');c.fillStyle=bg;c.fillRect(0,0,W,H);
 for(let i=0;i<Math.floor(90+(small?.3:detail)*150);i++){const a=i*2.399963,r=.16+Math.abs(Math.sin(i*43.7))*1.5,z=.16+(1-(i*.618+t*.28)%1)*3;c.globalAlpha=.28+.6/(z+1);line([point(Math.cos(a)*r,Math.sin(a)*r,z),point(Math.cos(a)*r,Math.sin(a)*r,z+.05+energy*.1)],'#fff',.5+1/(z+1))}c.globalAlpha=1;
 const objects=Array.from({length:9},(_,i)=>[i,.22+((i/9-t*.045)%1+1)%1*3.8]).sort((a,b)=>b[1]-a[1]);
 for(const [i,z] of objects){const side=i%2===0?-1:1,[x,y]=point(side*(.42+i%3*.12+.16/z),Math.sin(i*2.7)*.38,z),r=U*(i%3===0?.22:.07)/z;if(x+r*2<0||x-r*2>W||y+r*2<0||y-r*2>H)continue;
 if(i%3===0){const g=c.createRadialGradient(x-r*.4,y-r*.45,0,x-r*.4,y-r*.45,r*1.7);g.addColorStop(0,C[i%3]);g.addColorStop(1,'#060919');c.fillStyle=g;c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill();c.strokeStyle=C[0];c.globalAlpha=.3+glow*.35;c.lineWidth=1.5;c.stroke();c.globalAlpha=.6;c.beginPath();c.ellipse(x,y,r*1.6,r*.3,0,0,Math.PI*2);c.lineWidth=Math.max(1,r*.045);c.strokeStyle=C[2];c.stroke();c.globalAlpha=1;
 }else{const pts=[[x,y-r],[x+r*1.7,y+r*.6],[x+r*.3,y+r*.3],[x,y+r],[x-r*.3,y+r*.3],[x-r*1.7,y+r*.6],[x,y-r]];c.beginPath();pts.forEach((p,j)=>j?c.lineTo(...p):c.moveTo(...p));c.fillStyle='#263859';c.fill();line(pts,C[0],Math.max(1,r*.045));for(const side of [-1,1])line([[x+side*r*.35,y+r*.4],[x+side*r*.35,y+r*(1.2+energy)]],C[2],Math.max(2,r*.13))}}
 c.globalAlpha=.6;for(const side of [-1,1])line([[side<0?0:W,H*.72],[W*.5+side*W*.27,H*.89],[W*.5+side*W*.16,H]],C[0],2);
 line([[W*.5-13,H*.45],[W*.5-5,H*.45]],C[0]);line([[W*.5+5,H*.45],[W*.5+13,H*.45]],C[0]);c.globalAlpha=1;
}
const marioSprite=["....RRRRR...", "...RRRRRRRR.", "...BBBSSKS..", "..BSBSSSKSS.", "..BSBBSSSKSS", "...BSSSSKKK.", "....SSSSSS..", "...RRBRR....", "..RRRBRBRR..", ".RRRRBBBBRR.", ".SSRBYYBRSS.", ".SSSBBBBSSS.", "...BBBBBB...", "..BBB..BBB..", ".KKK....KKK.", "KKKK....KKKK"];
function renderMario(canvas,t,b){
 const ctx=canvas.getContext('2d'),scale=canvas.height/240,width=canvas.width/scale,travel=Math.max(0,t)*38%640,heroX=width*.28,camera=travel-heroX;
 const box=(x,y,w,h,color)=>{ctx.fillStyle=color;ctx.fillRect(x*scale,y*scale,w*scale,h*scale)};
 const grass='#52c447',soil='#8f4721',gold='#ffc42e';
 ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';ctx.shadowBlur=0;
 box(0,0,width,240,'#19386e');
 for(let i=-1;i<=Math.ceil(width/100)+2;i++){const x=i*100-travel*.2%100;box(x,56,34,9,'#c0d5ed');box(x+8,49,18,8,'#c0d5ed');for(let j=0;j<5;j++)box(x+j*10,174-Math.min(j,4-j)*11,10,28+Math.min(j,4-j)*11,'#28594e')}
 box(0,190,width,50,soil);box(0,188,width,5,grass);
 for(let i=-1;i<=Math.ceil(width/16)+2;i++){const x=i*16-travel%16;box(x,198,14,2,'#66351e');box(x,218,14,2,'#66351e');box(x,200,2,16,'#66351e')}
 for(let lap=Math.floor(camera/640)-1;lap<=Math.ceil((camera+width)/640)+1;lap++){
  const offset=lap*640-camera;
  for(const p of [160,400]){const x=offset+p;box(x,119,18,18,gold);box(x+2,121,14,2,'#ffe6a3');for(const [dx,dy,w,h] of [[7,123,6,3],[10,126,3,3],[7,129,3,2],[7,133,3,2]])box(x+dx,dy,w,h,soil)}
  for(const p of [280,500]){const x=offset+p;box(x-12,158,24,30,grass);box(x-16,150,32,10,grass);box(x-8,161,4,27,'#92ec7e');box(x+8,161,4,27,'#278137')}
  for(let j=0;j<8;j++){const x=offset+115+j*48,pulse=Math.min(1,Math.max(0,b[j*8]*gain));ctx.globalAlpha=glow*.35;box(x-4,90-pulse*9,10,14,gold);ctx.globalAlpha=1;box(x-2,92-pulse*9,6,10,gold)}
  box(offset+610,76,3,112,'#fff');box(offset+589,80,21,14,palettes[palette][0]);box(offset+606,71,10,6,gold);
 }
 let jump=0;for(const obstacle of [280,500]){const distance=Math.abs(travel-obstacle);if(distance<64)jump=Math.max(jump,86*(1-(distance/64)**2))}
 const step=Math.floor(t*10)%2===0?-1:1,colors={R:'#f83232',B:'#1f45d9',S:'#ffba75',K:'#381f14',Y:gold};
 marioSprite.forEach((line,row)=>{[...line].forEach((pixel,column)=>{if(colors[pixel])box(heroX+(column-6)*2+(row>12&&jump===0?step*(column<6?-1:1):0),188-jump-32+row*2,2,2,colors[pixel])})});
}

function render(canvas,kind,t,b,w,small=false){if(kind==='spaceFlight'){renderSpace(canvas,t,b,small);return}if(kind==='superMario'){renderMario(canvas,t,b);return}if(kind==='tron'){renderTron(canvas,t,b,small);return;}if(kind==='yosemite'){renderYosemite(canvas,t,small);return}const ctx=canvas.getContext('2d'),W=canvas.width,H=canvas.height,C=palettes[palette],D=Math.min(W,H);ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';ctx.shadowBlur=0;ctx.fillStyle='#090b13';ctx.fillRect(0,0,W,H);const bg=ctx.createRadialGradient(W/2,H/2,0,W/2,H/2,Math.max(W,H)*.6);bg.addColorStop(0,C[0]+'17');bg.addColorStop(1,C[0]+'00');ctx.fillStyle=bg;ctx.fillRect(0,0,W,H);ctx.globalCompositeOperation='lighter';const level=i=>Math.min(1,Math.max(0,b[Math.abs(i)%64]*gain));const stroke=(points,color,opacity=.65,width=1.5)=>{ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.strokeStyle=color;ctx.globalAlpha=opacity;ctx.lineWidth=width*(small?1:Math.max(1,devicePixelRatio));ctx.shadowColor=color;ctx.shadowBlur=small?0:glow*14;ctx.lineJoin='round';ctx.stroke();ctx.shadowBlur=0};
if(kind==='ironMan'){
 const cx=W*.5,cy=H*.46,radius=D*.29,red='#ff493b',gold='#ffd080',cyan='#75e8ff',energy=small?.35:Math.min(1,Math.max(0,rms*gain*3));
 const point=(a,r)=>[cx+Math.cos(a)*r,cy+Math.sin(a)*r];
 const arc=(r,start,length)=>Array.from({length:25},(_,i)=>point(start+length*i/24,r));
 const aura=ctx.createRadialGradient(cx,cy,0,cx,cy,radius);aura.addColorStop(0,cyan);aura.addColorStop(1,cyan+'00');ctx.globalAlpha=.12+energy*.16;ctx.fillStyle=aura;ctx.beginPath();ctx.arc(cx,cy,radius,0,Math.PI*2);ctx.fill();
 for(let ring=0;ring<3;ring++)for(let segment=0;segment<6;segment++){const a=segment*Math.PI/3+t*(ring%2===0?.10:-.14);stroke(arc(radius*(.78+ring*.19),a,Math.PI/3*.76),ring===1?red:gold,.6,ring===1?4:1.4)}
 const n=Math.floor(36+(small?.3:detail)*36);for(let i=0;i<n;i++){const a=i/n*Math.PI*2-Math.PI/2,v=level(Math.floor(i*64/n)),r=radius*1.23;stroke([point(a,r),point(a,r+D*(.008+v*.045))],i%6===0?gold:C[0],.35+v*.6,i%6===0?2:1)}
 for(let i=0;i<12;i++){const a=i*Math.PI/6;stroke([point(a,radius*.45),point(a+.12,radius*.66)],cyan,.45+level(i*5)*.5,3)}
 stroke(arc(radius*.70,0,Math.PI*2),cyan,.9,2);
 const core=Array.from({length:3},(_,i)=>point(-Math.PI/2+i*Math.PI*2/3,radius*(.40+energy*.035)));ctx.beginPath();core.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.closePath();ctx.fillStyle=cyan;ctx.globalAlpha=.16+energy*.30;ctx.fill();stroke([...core,core[0]],'#ffffff',.95,2.5);
 for(const sx of [-1,1])for(const sy of [-1,1]){const x=cx+sx*D*.43,y=cy+sy*D*.35;stroke([[x-sx*D*.065,y],[x,y],[x,y-sy*D*.05]],red,.65,1.4)}
}
if(kind==='halo'){
 const radius=D*.39,tilt=-.34+Math.sin(t*.07)*.08,flatten=.48+Math.sin(t*.09)*.08;
 const point=(a,r,lift=0)=>{const x=Math.cos(a)*r,y=Math.sin(a)*r*flatten-lift;return[W*.5+x*Math.cos(tilt)-y*Math.sin(tilt),H*.47+x*Math.sin(tilt)+y*Math.cos(tilt)]};
 const quality=small?.3:detail;
 for(let i=0;i<Math.floor(30+quality*65);i++){const x=Math.abs(Math.sin(i*127.1)*43758.5453%1)*W,y=Math.abs(Math.sin(i*311.7)*96321.9123%1)*H,r=(i%7===0?1.3:.65)*Math.max(.65,D/350);ctx.globalAlpha=.18+.3*(.5+.5*Math.sin(t*.4+i));ctx.fillStyle=C[2];ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fill()}
 const n=Math.floor(48+quality*48),order=haloOrder(n);
 for(const i of order){const a=i/n*Math.PI*2,b=(i+1)/n*Math.PI*2,v=level(Math.floor(i*64/n)),points=[point(a,radius*.82),point(a,radius),point(b,radius),point(b,radius*.82)];ctx.beginPath();points.forEach(([x,y],j)=>j?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.closePath();ctx.globalAlpha=.10+v*.18;ctx.fillStyle=C[i%5===0?1:0];ctx.fill();stroke([point(a,radius*.82),point(a,radius)],C[1],.35,.7);if(i%3===0)stroke([point(a,radius*.91),point(a,radius*.91,D*(.025+v*.13))],C[2],.4+v*.5,1.2)}
 for(const factor of [.82,.86,1])stroke(Array.from({length:129},(_,i)=>point(i/128*Math.PI*2,radius*factor)),C[factor===.86?1:0],.9,factor===.86?.8:2);
 for(let pulse=0;pulse<3;pulse++)stroke(Array.from({length:19},(_,i)=>point(t*.22+pulse*Math.PI*2/3+i*.018,radius*.96)),C[2],.9,2.5);
}
if(kind==='aurora'){const n=small?7:Math.floor(5+detail*8);for(let l=0;l<n;l++){const p=[];for(let i=0;i<=160;i++){const x=i/160,e=Math.sin(x*Math.PI)**.9;const v=Math.sin(x*8+t*.65+l*.19)*.16+Math.sin(x*15-t*.34+l*.11)*.08;p.push([x*W,H*(.5+e*v*(.65+level(Math.floor(x*63)))+(l-n/2)*.009)])}stroke(p,C[l%3],.28+.5*(l+1)/n,1.05)}}
if(kind==='spectrum'){const gap=W*.84/64,base=H*.72;for(let i=0;i<64;i++){const v=Math.max(2,level(i)*H*.51),x=W*.08+i*gap;ctx.globalAlpha=.9;const g=ctx.createLinearGradient(x,base-v,x,base);g.addColorStop(0,C[Math.floor(i/22)]);g.addColorStop(1,C[Math.floor(i/22)]+'44');ctx.fillStyle=g;ctx.fillRect(x,base-v,Math.max(1,gap*.58),v);ctx.globalAlpha=.1;ctx.fillRect(x,base+8,gap*.58,v*.16)}}
if(kind==='orbit'){const r=D*.24;for(let ring=0;ring<3;ring++){const p=[];for(let i=0;i<=180;i++){const a=i/180*Math.PI*2+t*(ring%2?-.06:.08),v=r*(1+ring*.22+level(Math.floor(i%180/180*63))*.26);p.push([W/2+Math.cos(a)*v,H/2+Math.sin(a)*v])}stroke(p,C[ring],.8-ring*.15)}for(let i=0;i<64;i++){const a=i/64*Math.PI*2+t*.08,r1=r*.82,r2=r1-level(i)*r*.35;stroke([[W/2+Math.cos(a)*r1,H/2+Math.sin(a)*r1],[W/2+Math.cos(a)*r2,H/2+Math.sin(a)*r2]],C[0],.5,1)}}
if(kind==='waveform'){for(let l=0;l<3;l++){const p=Array.from(w,(v,i)=>[W*(.05+i/255*.9),H/2+v*gain*H*(.28-l*.05)+(l-1)*9]);stroke(p,C[l],l===0?.9:.3,l===0?2:1)}}
if(kind==='tunnel'){for(let l=0;l<18;l++){const z=(l/18+t*.055)%1,r=z*z*Math.max(W,H)*.75*(1+level(l*3)*.1),a=t*.07+(1-z)*1.3,p=[];for(let i=0;i<7;i++){const th=(i%6)/6*Math.PI*2+a;p.push([W/2+Math.cos(th)*r,H/2+Math.sin(th)*r])}stroke(p,C[l%3],Math.sin(z*Math.PI)*.7,.8+z)}}
if(kind==='constellation'){const n=small?32:Math.floor(28+detail*55),points=Array.from({length:n},(_,i)=>[W*(.5+Math.sin(i*127.1+t*.025)*.43),H*(.5+Math.cos(i*311.7+t*.033)*.4)]),threshold=D*.22;for(let i=0;i<n;i++){for(let j=i+1;j<n;j++){const dx=points[i][0]-points[j][0],dy=points[i][1]-points[j][1],distanceSquared=dx*dx+dy*dy;if(distanceSquared<threshold*threshold)stroke([points[i],points[j]],C[i%3],(1-Math.sqrt(distanceSquared)/threshold)*.24,.6)}ctx.beginPath();ctx.arc(...points[i],1+level(i)*(small?1.5:5),0,Math.PI*2);ctx.globalAlpha=.9;ctx.fillStyle=C[i%3];ctx.shadowBlur=glow*10;ctx.shadowColor=C[i%3];ctx.fill();ctx.shadowBlur=0}}
if(kind==='terrain'){const n=small?15:Math.floor(12+detail*15);for(let row=0;row<n;row++){const z=row/n,scale=.15+z*.85,p=[];for(let i=0;i<64;i++){const x=i/63,ridge=level(i)*(.6+.4*Math.sin(x*12+z*7+t*.3));p.push([W*(.5+(x-.5)*scale*1.7),H*(.38+z*.56-ridge*scale*.25)])}stroke(p,C[row%3],.12+z*.58,.7+z)}}
if(kind==='bloom'){const n=small?7:Math.floor(5+detail*7);for(let l=0;l<n;l++){const p=[];for(let i=0;i<=240;i++){const a=i/240*Math.PI*2,petal=.65+.2*Math.sin(a*6+t*.3+l*.13),r=D*.28*(petal+level(Math.floor(i/241*63))*.25)*(.6+l*.075),th=a+t*.04+l*.035;p.push([W/2+Math.cos(th)*r,H/2+Math.sin(th)*r])}stroke(p,C[l%3],.25+l*.035,1)}}ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over'}
function drawThumbnails(){
 const key=[palette,gain,glow,yosemiteAssetsReady,tronMode,tronColor].join('/');
 if(key===thumbnailKey)return;
 thumbnailKey=key;
 document.querySelectorAll('.card').forEach(el=>render(el.querySelector('canvas'),el.dataset.style,7,thumbnailBands,thumbnailWave,true));
}
// Preferences contain UI settings only: never media, source credentials, or autoplay state.
const preferenceKey='afterglow.preferences.v1';let savedPreferences=null;
function bounded(value,min,max,fallback){return typeof value==='number'&&Number.isFinite(value)?Math.min(max,Math.max(min,value)):fallback}
function normalizePreferences(value){
 if(!value||typeof value!=='object'||Array.isArray(value)||value.version!==1)throw new Error('This is not a supported Afterglow preference file.');
 return {version:1,audioReactive:value.audioReactive!==false,tronMode:tronModes.some(m=>m[0]===value.tronMode)?value.tronMode:'lightCycles',tronColor:Object.hasOwn(tronColors,value.tronColor)?value.tronColor:'Light blue',style:styles.some(s=>s[0]===value.style)?value.style:'yosemite',palette:Object.hasOwn(palettes,value.palette)?value.palette:'Ultraviolet',gain:bounded(value.gain,.2,3,1.25),speed:bounded(value.speed,.1,2,.65),glow:bounded(value.glow,0,1,.6),detail:bounded(value.detail,.2,1,.65),fps:value.fps===30?30:60,volume:bounded(value.volume,0,1,.8),paused:value.paused===true,favorites:Array.isArray(value.favorites)?[...new Set(value.favorites.filter(s=>styles.some(item=>item[0]===s)))]:['aurora','orbit']};
}
function currentPreferences(){return normalizePreferences({version:1,audioReactive,tronMode,tronColor,style,palette,gain,speed,glow,detail,fps,volume:audio.volume,paused,favorites:[...favorites]})}
function preferenceStatus(text){$('preference-status').textContent=text;$('restore-preferences').disabled=!savedPreferences}
function syncControls(){
 for(const [name,value] of Object.entries({gain,speed,glow,detail})){$(name).value=value;$(name+'-value').textContent=name==='gain'||name==='speed'?value.toFixed(1)+'×':Math.round(value*100)+'%'}
 $('fps').value=fps;$('volume').value=audio.volume;syncDuoControls();
}
function applyPreferences(value){
 const p=normalizePreferences(value);audioReactive=p.audioReactive;tronMode=p.tronMode;tronColor=p.tronColor;gain=p.gain;speed=p.speed;glow=p.glow;detail=p.detail;fps=p.fps;audio.volume=p.volume;paused=p.paused;favorites=new Set(p.favorites);
 pickStyle(p.style);pickPalette(p.palette);syncControls();lastDraw=null;requestThumbnails();updatePlay();
}
function loadPreferences(){
 try{const raw=localStorage.getItem(preferenceKey);if(raw){savedPreferences=normalizePreferences(JSON.parse(raw));applyPreferences(savedPreferences);preferenceStatus('Loaded your locally saved preferences.')}else preferenceStatus('Save this setup to load it next time.')}
 catch(error){savedPreferences=null;preferenceStatus('Local preferences could not load. You can import a JSON backup or save a new setup.');}
}
function savePreferences(){++preferenceImportId;
 try{const p=currentPreferences();localStorage.setItem(preferenceKey,JSON.stringify(p));savedPreferences=p;preferenceStatus('Saved locally. Press Save again to keep later changes.')}
 catch(error){preferenceStatus('This browser blocked local saving. Export a JSON backup instead.');}
}
function restorePreferences(){++preferenceImportId;if(savedPreferences){applyPreferences(savedPreferences);preferenceStatus('Restored saved preferences.')}else preferenceStatus('No saved preferences available.')}
function resetPreferences(){++preferenceImportId;applyPreferences({version:1});preferenceStatus('Defaults restored. Your saved preferences are unchanged.')}
function forgetPreferences(){++preferenceImportId;try{localStorage.removeItem(preferenceKey);localStorage.removeItem('afterglow.tron');localStorage.removeItem('afterglow.audioReactive');savedPreferences=null;preferenceStatus('Saved preferences removed. Current settings and music are unchanged.')}catch(error){preferenceStatus('This browser blocked access to its local preferences.')}}
function exportPreferences(){
 try{const blob=new Blob([JSON.stringify(currentPreferences(),null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),link=document.createElement('a');link.href=url;link.download='Afterglow-preferences.json';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);preferenceStatus('Exported a local preference backup.')}
 catch(error){preferenceStatus('Could not export preferences: '+error.message)}
}
let preferenceImportId=0;
async function importPreferences(event){
 const file=event.target.files[0];if(!file)return;const token=++preferenceImportId;
 try{if(file.size>16384)throw new Error('Preference files must be smaller than 16 KB.');const text=await file.text();if(token!==preferenceImportId)return;applyPreferences(normalizePreferences(JSON.parse(text)));preferenceStatus('Imported preferences. Press Save to keep them for next time.')}
 catch(error){if(token===preferenceImportId)preferenceStatus('Could not import preferences: '+error.message)}
 finally{event.target.value=''}
}
$('save-preferences').onclick=savePreferences;$('restore-preferences').onclick=restorePreferences;$('reset-preferences').onclick=resetPreferences;$('forget-preferences').onclick=forgetPreferences;
$('export-preferences').onclick=exportPreferences;$('import-preferences').onclick=()=>$('preference-file').click();$('preference-file').onchange=importPreferences;

// Control and playback transitions are serialized by a generation token.
let requestId=0,playPending=false,connectingInput=false,micSink=null;
const sourceLinks={spotify:['Spotify','https://open.spotify.com/'],apple:['Apple Music','https://music.apple.com/'],other:['YouTube Music','https://music.youtube.com/']};
function ensureAudio(){
 if(!audioContext){
  if(!window.AudioContext&&!window.webkitAudioContext)throw new Error('Web Audio is unavailable. Open the preview in Safari or Chrome.');
  audioContext=new (window.AudioContext||window.webkitAudioContext)();
  analyzer=audioContext.createAnalyser();analyzer.fftSize=2048;analyzer.smoothingTimeConstant=.72;
  playerNode=audioContext.createMediaElementSource(audio);playerNode.connect(analyzer);analyzer.connect(audioContext.destination);
  rawFrequency=new Float32Array(analyzer.frequencyBinCount);rawWave=new Float32Array(analyzer.fftSize);configureBands();
 }
 return audioContext.resume();
}
function clearSignal(){bands.fill(0);wave.fill(0);rms=0}
function stopMic(){
 const stream=activeMic;activeMic=null;
 if(micSink){micSink.disconnect();micSink=null}
 if(micNode){micNode.disconnect();micNode=null}
 if(stream)stream.getTracks().forEach(track=>{track.onended=null;track.stop()});
 if(analyzer&&audioContext){analyzer.disconnect();analyzer.connect(audioContext.destination)}
}
function setSource(next){
 source=next;
 document.querySelectorAll('[data-source]').forEach(el=>{const selected=el.dataset.source===next;el.classList.toggle('selected',selected);el.setAttribute('aria-pressed',selected)});
 $('seek').classList.toggle('show',next==='local');updatePlay();
}
function updatePlay(){
 requestRender();
 const running=source==='local'?!audio.paused:source==='mic'?!!activeMic:!motionStopped();
 $('play').textContent=running?'Ⅱ':'▶';$('play').setAttribute('aria-label',source==='mic'?(connectingInput?'Cancel microphone connection':running?'Stop microphone':'Start microphone'):(running?'Pause':'Play'));
 $('play').disabled=playPending||(!['local','mic'].includes(source)&&reducedMotion);
 $('pause-motion').textContent=reducedMotion?'System Reduce Motion is on':paused?'Resume visual motion':'Pause visual motion';
 $('pause-motion').disabled=reducedMotion;
 $('audio-reactive').checked=audioReactive;
 $('response-note').textContent=audioReactive?'Measured response with a supported input':'Independent animation • playback continues';
 const measured=audioReactive&&(source==='local'||source==='mic');
 $('mode').textContent=!audioReactive?'INDEPENDENT MOTION':connectingInput&&source==='mic'?'CONNECTING INPUT':measured?(running?'LIVE AUDIO':'AUDIO IDLE'):'AMBIENT MOTION';
 const seekable=source==='local'&&Number.isFinite(audio.duration)&&audio.duration>0;
 $('volume').disabled=source!=='local';
 $('restart').disabled=!seekable;$('seek').disabled=!seekable;
}
function ambientMetadata(){ $('track-title').textContent='Make room for the music.';$('track-detail').textContent='Choose a source. Find your visual.' }
async function selectSource(next){
 if(next==='local'){++requestId;connectingInput=false;playPending=false;$('file').click();updatePlay();return}
 if(next==='system'){toast('System audio capture is available in the native Mac app. Import a file or use microphone input in this preview.');return}
 if(!['ambient','mic',...Object.keys(sourceLinks)].includes(next))return;
 const token=++requestId;playPending=false;connectingInput=false;audio.pause();stopMic();clearSignal();setSource(next);
 if(next==='mic'){
  connectingInput=true;updatePlay();
  $('track-title').textContent='The sound around you';$('track-detail').textContent='Microphone input • waiting for permission';
  try{
   await ensureAudio();if(token!==requestId)return;
   if(!navigator.mediaDevices?.getUserMedia)throw new Error('Microphone access is unavailable here. Try localhost or HTTPS, or import an audio file.');
   const stream=await navigator.mediaDevices.getUserMedia({audio:true});
   if(token!==requestId){stream.getTracks().forEach(track=>track.stop());return}
   activeMic=stream;analyzer.disconnect();
   micSink=audioContext.createGain();micSink.gain.value=0;analyzer.connect(micSink);micSink.connect(audioContext.destination);
   micNode=audioContext.createMediaStreamSource(stream);micNode.connect(analyzer);
   stream.getTracks().forEach(track=>track.onended=()=>{if(activeMic===stream){stopMic();clearSignal();updatePlay();toast('Microphone input ended. Choose Start listening to reconnect.')}});
   connectingInput=false;$('track-detail').textContent='Live input • no recording saved';updatePlay();
  }catch(error){if(token!==requestId)return;connectingInput=false;stopMic();clearSignal();updatePlay();toast(error.message)}
  return;
 }
 if(sourceLinks[next]){
  const [name,url]=sourceLinks[next];
  window.open(url,'_blank','noopener,noreferrer');
  $('track-title').textContent=name+' companion';$('track-detail').textContent='Playback stays in the music app • ambient visuals';
  toast('Start music in '+name+', then return here. Visuals run independently of the track. ');
  const link=document.createElement('a');link.href=url;link.target='_blank';link.rel='noopener noreferrer';link.textContent='Open '+name+' ↗';$('toast').appendChild(link);
 }else ambientMetadata();
}
async function importAudioFile(event){
 const file=event.target.files[0];if(!file)return;
 const token=++requestId;connectingInput=false;playPending=true;stopMic();audio.pause();clearSignal();updatePlay();
 try{
  await ensureAudio();if(token!==requestId)return;
  const previous=objectURL;objectURL=URL.createObjectURL(file);audio.src=objectURL;if(previous)URL.revokeObjectURL(previous);
  setSource('local');$('track-title').textContent=file.name.replace(/\.[^.]+$/,'');$('track-detail').textContent='Local file • measured spectrum';
  await audio.play();
 }catch(error){if(token===requestId)toast('This file could not play: '+error.message)}
 finally{event.target.value='';if(token===requestId){playPending=false;updatePlay()}}
}
async function togglePlayback(){
 if(playPending)return;
 if(source==='local'){
  const token=++requestId,shouldPlay=audio.paused;playPending=true;updatePlay();
  try{if(shouldPlay){await ensureAudio();if(token!==requestId)return;await audio.play()}else audio.pause()}
  catch(error){if(token===requestId)toast(error.message)}
  finally{if(token===requestId){playPending=false;updatePlay()}}
 }else if(source==='mic'){
  if(activeMic||connectingInput){++requestId;connectingInput=false;stopMic();clearSignal();updatePlay()}else await selectSource('mic');
 }else{paused=!paused;updatePlay()}
}
document.querySelectorAll('[data-source]').forEach(el=>el.onclick=()=>selectSource(el.dataset.source));
$('import').onclick=()=>selectSource('local');$('file').onchange=importAudioFile;$('play').onclick=togglePlayback;
$('restart').onclick=()=>{if(!$('restart').disabled){audio.currentTime=0;requestRender()}};
$('seek').oninput=event=>{if(source==='local'&&Number.isFinite(audio.duration)&&audio.duration>0)audio.currentTime=audio.duration*bounded(Number(event.target.value),0,1,0)};
$('volume').oninput=event=>audio.volume=bounded(Number(event.target.value),0,1,.8);
audio.ontimeupdate=()=>{if(Number.isFinite(audio.duration)&&audio.duration>0)$('seek').value=audio.currentTime/audio.duration};
audio.onplay=audio.onpause=audio.onended=audio.onloadedmetadata=updatePlay;
audio.onerror=()=>{if(source==='local'){updatePlay();toast('The browser cannot decode this file. Try an unprotected MP3 or WAV.')}};
for(const name of ['gain','speed','glow','detail'])$(name).oninput=event=>{
 const ranges={gain:[.2,3,1.25],speed:[.1,2,.65],glow:[0,1,.6],detail:[.2,1,.65]},v=bounded(Number(event.target.value),...ranges[name]);
 if(name==='gain')gain=v;if(name==='speed')speed=v;if(name==='glow')glow=v;if(name==='detail')detail=v;
 syncControls();if(name==='gain'||name==='glow')requestThumbnails();requestRender();
};
$('fps').onchange=event=>{fps=Number(event.target.value)===30?30:60;lastDraw=null;requestRender()};
$('favorite').onclick=()=>{favorites.has(style)?favorites.delete(style):favorites.add(style);updateFavorite()};
$('pause-motion').onclick=()=>{paused=!paused;updatePlay()};
$('expand').onclick=()=>{const enabled=document.body.classList.toggle('immersive');$('expand').setAttribute('aria-pressed',enabled);requestRender()};
function closeSettings(){if(innerWidth>1200)document.body.classList.add('settings-hidden');const panel=document.querySelector('.inspector');panel.classList.remove('mobile-open');panel.style.removeProperty('display');document.querySelector('.shell').style.removeProperty('grid-template-columns');$('settings-button').setAttribute('aria-expanded','false')}
document.addEventListener('keydown',event=>{if(event.key==='Escape'){document.body.classList.remove('immersive');$('expand').setAttribute('aria-pressed','false');closeSettings();requestRender()}});
$('settings-button').onclick=()=>{document.body.classList.remove('settings-hidden');const panel=document.querySelector('.inspector');if(innerWidth<=1200){const open=panel.classList.toggle('mobile-open');$('settings-button').setAttribute('aria-expanded',open)}else panel.scrollIntoView({behavior:reducedMotion?'auto':'smooth'})};
$('close-settings').onclick=closeSettings;


$('audio-reactive').onchange=event=>{audioReactive=event.target.checked;clearSignal();updatePlay()};
const gallery=$('gallery'),galleryScroll=$('gallery-scroll');
function syncGalleryScroll(){const extent=Math.max(0,gallery.scrollWidth-gallery.clientWidth);galleryScroll.disabled=extent===0;galleryScroll.value=extent?100*gallery.scrollLeft/extent:0}
galleryScroll.oninput=()=>{gallery.scrollLeft=Number(galleryScroll.value)/100*Math.max(0,gallery.scrollWidth-gallery.clientWidth)};
gallery.onscroll=syncGalleryScroll;
new ResizeObserver(syncGalleryScroll).observe(gallery);syncGalleryScroll();

const observer=new ResizeObserver(()=>{const c=$('visual'),r=c.getBoundingClientRect(),d=Math.min(2,devicePixelRatio||1,Math.sqrt(3000000/Math.max(1,r.width*r.height))),width=Math.max(1,Math.round(r.width*d)),height=Math.max(1,Math.round(r.height*d));if(c.width!==width||c.height!==height){c.width=width;c.height=height;requestRender()}});observer.observe($('visual'));
function tick(ms){
 animationRequest=null;
 if(document.hidden){last=0;lastDraw=null;return}
 const interval=1000/fps;
 // Avoid duplicate work on 120/144 Hz displays. Keep phase to prevent a 60 Hz
 // display's timestamp jitter from accidentally cutting the rate to 30 fps.
 if(lastDraw!==null&&ms-lastDraw<interval-.5){animationRequest=requestAnimationFrame(tick);return}
 const delta=last?Math.min(.05,(ms-last)/1000):0;last=ms;
 lastDraw=lastDraw===null||needsRedraw?ms:lastDraw+Math.max(1,Math.floor((ms-lastDraw+.5)/interval))*interval;
 if(!motionStopped())time+=delta*speed;
 const live=audioReactive&&analyzer&&((source==='local'&&!audio.paused&&!audio.ended)||(source==='mic'&&activeMic));
 if(live){
  analyzer.getFloatFrequencyData(rawFrequency);analyzer.getFloatTimeDomainData(rawWave);
  let energy=0;for(const v of rawWave)energy+=v*v;rms=Math.sqrt(energy/rawWave.length);
  for(let i=0;i<64;i++){let peak=-100;for(let j=bandStarts[i];j<=bandEnds[i];j++)peak=Math.max(peak,rawFrequency[j]);bands[i]=Math.max(0,Math.min(1,(peak+80)/70))}
  for(let i=0;i<256;i++)wave[i]=rawWave[i*8];
 }else if(audioReactive&&(source==='local'||source==='mic')){clearSignal()}else{ambient(time,bands,wave,style==='waveform');rms=.12}
 if(thumbnailsDirty){thumbnailsDirty=false;drawThumbnails()}
 render($('visual'),style,time,bands,wave);needsRedraw=false;
 if(!motionStopped()||live)animationRequest=requestAnimationFrame(tick);else{last=0;lastDraw=null}
}
document.addEventListener('visibilitychange',()=>{if(document.hidden){if(animationRequest!==null)cancelAnimationFrame(animationRequest);animationRequest=null;last=0;lastDraw=null}else requestRender()});
// BEGIN YOSEMITE IMAGES
const yosemiteLandscape=new Image(),yosemiteCloud=new Image();
let yosemiteAssetsReady=false,yosemiteImagesLoaded=0;
function yosemiteImageLoaded(){if(++yosemiteImagesLoaded===2){yosemiteAssetsReady=true;requestThumbnails();syncDuoControls()}}
yosemiteLandscape.onload=yosemiteCloud.onload=yosemiteImageLoaded;
yosemiteLandscape.onerror=yosemiteCloud.onerror=()=>toast('Yosemite artwork could not load. Reopen the original preview file.');
yosemiteLandscape.src='__YOSEMITE_LANDSCAPE_DATA__';
yosemiteCloud.src='__YOSEMITE_CLOUD_DATA__';
// END YOSEMITE IMAGES
pickStyle('yosemite');pickPalette('Ultraviolet');updatePlay();requestRender();
// Demo messages change presentation only. The same canvas, audio and clock stay alive.
window.addEventListener('message',event=>{
 if(event.source!==window.parent||!event.data||event.data.type!=='afterglow-duo-demo')return;
 const {pose,visual}=event.data;
 if(['closed','open','tabletop'].includes(pose)){document.body.dataset.demoPose=pose;requestRender()}
 if(styles.some(item=>item[0]===visual))pickStyle(visual);
});
function syncDuoControls(){
 $('duo-speed').value=speed;$('duo-glow').value=glow;
 $('duo-speed-value').textContent=speed.toFixed(1)+'×';$('duo-glow-value').textContent=Math.round(glow*100)+'%';
 document.querySelectorAll('[data-duo-palette]').forEach(el=>{const selected=el.dataset.duoPalette===palette;el.classList.toggle('active',selected);el.setAttribute('aria-pressed',selected)});
}
for(const [name,colors] of Object.entries(palettes)){
 const button=document.createElement('button');button.dataset.duoPalette=name;button.setAttribute('aria-label',name+' palette');button.innerHTML='<i style="background:'+colors[0]+'"></i>';
 button.onclick=()=>{pickPalette(name);syncDuoControls()};$('duo-palettes').appendChild(button);
}
for(const name of ['speed','glow'])$('duo-'+name).oninput=event=>{$(name).oninput(event);$(name).value=event.target.value;syncDuoControls()};
$('tron-mode').onchange=e=>{if(tronModes.some(m=>m[0]===e.target.value))tronMode=e.target.value;syncTron();requestThumbnails()};
document.querySelectorAll('[data-tron-color]').forEach(b=>b.onclick=()=>{tronColor=b.dataset.tronColor;syncTron();requestThumbnails()});
syncDuoControls();loadPreferences();syncTron();
motionPreference.addEventListener?.('change',event=>{reducedMotion=event.matches;last=0;updatePlay()});

window.addEventListener('pagehide',()=>{++requestId;playPending=false;stopMic();audio.pause();if(animationRequest!==null)cancelAnimationFrame(animationRequest);animationRequest=null});
