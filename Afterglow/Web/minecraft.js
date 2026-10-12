"use strict";
// Minecraft is a clock-driven block world. Terrain, trees, torches, creepers and
// ores are derived from world-column seeds, so pause and Reduce Motion freeze the
// scene exactly and long sessions never accumulate state.
function minecraftRandom(seed) {
 const value=Math.sin(seed*127.1+311.7)*43758.5453;
 return value-Math.floor(value);
}
// Surface height (1-6 blocks) eases between seeded control points every eight columns.
function minecraftColumn(column) {
 const c=Number.isFinite(column)?Math.floor(column):0,cell=Math.floor(c/8),f=(c-cell*8)/8,s=f*f*(3-2*f);
 const a=minecraftRandom(cell*3+11),b=minecraftRandom(cell*3+14),r=minecraftRandom(c*5+2);
 return {height:Math.round(1+(a+(b-a)*s)*5),tree:r<.1,torch:r>=.1&&r<.16,creeper:r>=.16&&r<.19};
}
// Ore kinds: 0 coal, 1 iron, 2 gold (mids), 3 redstone (bass), 4 diamond (treble); -1 is plain stone.
function minecraftOre(column,depth) {
 if(depth<4)return -1;
 const r=minecraftRandom(column*31+depth*17+5);
 return r<.08?Math.floor(r/.08*5):-1;
}
const minecraftOreColors=['#1e1e1e','#d8af93','#f7d33c','#e0261f','#4ee6e0'];
function renderMinecraft(canvas,time,bands,small=false) {
 const ctx=canvas.getContext('2d'),W=canvas.width,H=canvas.height,U=Math.min(W,H);
 if(W<=1||H<=1)return;
 const t=Math.max(0,Number.isFinite(time)?time:0),quality=small?.3:detail,accent=palettes[palette][0];
 const band=(from,to)=>{let sum=0;for(let i=from;i<to;i++)sum+=Number(bands?.[i])||0;return Math.min(1,Math.max(0,sum/(to-from)*gain))};
 const energy=Math.min(1,Math.max(0,rms*gain*3)),levels=[0,band(8,24)*.6,band(8,24),band(0,8),band(36,64)];
 const B=Math.max(4,Math.round(U/20)),p=B/16;
 ctx.save();ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';ctx.shadowBlur=0;
 const box=(x,y,w,h,color,alpha=1)=>{ctx.globalAlpha=alpha;ctx.fillStyle=color;ctx.fillRect(Math.round(x),Math.round(y),Math.ceil(w),Math.ceil(h))};
 const mix=(a,b,k)=>{const n=[a,b].map(c=>parseInt(c.slice(1),16));return 'rgb('+[16,8,0].map(s=>Math.round((n[0]>>s&255)*(1-k)+(n[1]>>s&255)*k)).join(',')+')'};
 // A two-minute day: sun and moon trade places on opposite sides of one arc.
 const angle=t/120*Math.PI*2,daylight=.5+.5*Math.cos(angle);
 const sky=ctx.createLinearGradient(0,0,0,H);sky.addColorStop(0,mix('#0b1030','#6f9cff',daylight));sky.addColorStop(.6,mix('#1b2350','#b7d0ff',daylight));
 ctx.fillStyle=sky;ctx.fillRect(0,0,W,H);
 for(let i=0;i<Math.floor(20+quality*40);i++)box(minecraftRandom(i+600)*W,minecraftRandom(i+700)*H*.55,Math.max(1,B*.09),Math.max(1,B*.09),'#ffffff',(1-daylight)*(.4+.6*minecraftRandom(i+800)));
 const orb=(x,y,day)=>{const s=B*1.6;if(day){box(x-s/2,y-s/2,s,s,'#fff6b0');box(x-s*.3,y-s*.3,s*.6,s*.6,'#ffd84a')}else{box(x-s/2,y-s/2,s,s,'#e6ebf5');box(x-s*.2,y-s*.25,s*.25,s*.25,'#b9c0d0');box(x+s*.12,y+s*.08,s*.18,s*.18,'#b9c0d0')}};
 orb(W*.5+W*.4*Math.sin(angle),H*.5-H*.4*Math.cos(angle),true);
 orb(W*.5-W*.4*Math.sin(angle),H*.5+H*.4*Math.cos(angle),false);
 for(let i=0;i<4;i++){
  const w=B*(4+minecraftRandom(i+40)*5),span=W+w*2,x=((minecraftRandom(i+50)*span-t*B*.35)%span+span)%span-w,y=H*(.07+minecraftRandom(i+60)*.12);
  box(x,y,w,B*.7,'#ffffff',.35+daylight*.5);box(x+w*.2,y-B*.35,w*.45,B*.4,'#ffffff',.35+daylight*.5);
 }
 // The world scrolls left at 1.6 blocks per second; columns are addressed by world index.
 const scroll=t*1.6,first=Math.floor(scroll),offset=(scroll-first)*B,base=Math.floor(H*.8/B);
 const columns=Math.ceil(W/B)+2,speckles=quality>.15?Math.floor(1+quality*3):0;
 const texture=(x,y,seed,color)=>{for(let k=0;k<speckles;k++){const r=minecraftRandom(seed+k*3.1);box(x+Math.floor(r*4)*B/4,y+Math.floor(minecraftRandom(seed+k*5.7)*4)*B/4,B/4,B/4,color,.35)}};
 const glows=[],torches=[];
 for(let i=-1;i<columns;i++){
  const c=first+i,info=minecraftColumn(c),x=i*B-offset,top=(base-info.height)*B;
  for(let row=0;top+row*B<H;row++){
   const y=top+row*B,seed=c*97+row*13;
   if(row===0){box(x,y,B,B,'#8a5a35');texture(x,y,seed,'#6b4426');box(x,y,B,B*.28,'#5fa83a');box(x+B*.25,y+B*.28,B/4,B/8,'#5fa83a')}
   else if(row<4){box(x,y,B,B,'#7b5233');texture(x,y,seed,'#5f3e25')}
   else{
    box(x,y,B,B,row>11?'#55565c':'#7f7f7f');texture(x,y,seed,row>11?'#3f4045':'#6a6a6a');
    const ore=minecraftOre(c,row);
    if(ore>=0){for(const [ox,oy] of [[.15,.2],[.55,.15],[.3,.55],[.65,.6]])box(x+B*ox,y+B*oy,B*.22,B*.22,minecraftOreColors[ore]);if(ore>1)glows.push([x,y,ore])}
   }
   if(row<3)box(x,y,B,B*.06,'#000000',.08);
  }
  if(info.tree){
   for(let k=1;k<=4;k++){box(x+B*.1,top-k*B,B*.8,B,'#6b4f2a');box(x+B*.3,top-k*B,B*.12,B,'#4f3a1f')}
   for(const [lx,ly] of [[-1,-5],[0,-5],[1,-5],[-1,-4],[1,-4],[0,-6]]){box(x+lx*B,top+ly*B,B,B,'#3f8a2b');texture(x+lx*B,top+ly*B,c*41+lx*7+ly,'#2d6a1f')}
  }else if(info.torch){
   box(x+B*.44,top-B*.6,B*.13,B*.6,'#8a6a3a');torches.push([x+B*.5,top-B*.65,c]);
  }else if(info.creeper){
   const cx=x+B*.2,body='#5bb54a';
   box(cx,top-B*.35,B*.25,B*.35,'#3f8f32');box(cx+B*.35,top-B*.35,B*.25,B*.35,'#3f8f32');
   box(cx+B*.05,top-B*1.3,B*.5,B,body);box(cx+B*.15,top-B*1.1,B*.12,B*.12,'#7fd06a');box(cx+B*.33,top-B*.75,B*.12,B*.12,'#3f8f32');
   box(cx-B*.1,top-B*2.1,B*.8,B*.8,body);
   box(cx+B*.02,top-B*1.9,B*.18,B*.18,'#101410');box(cx+B*.42,top-B*1.9,B*.18,B*.18,'#101410');
   box(cx+B*.22,top-B*1.72,B*.2,B*.32,'#101410');
  }
 }
 // The miner steps up and drops down with the blocks under their feet.
 const minerX=Math.round(W*.36),world=scroll+minerX/B,column=Math.floor(world),frac=world-column;
 const h0=minecraftColumn(column).height,h1=minecraftColumn(column+1).height;
 const step=Math.min(1,Math.max(0,(frac-.6)/.3)),ease=step*step*(3-2*step);
 const lift=h1>h0?(h1-h0)*ease+Math.sin(ease*Math.PI)*.35:h1<h0?(frac>.85?(h1-h0)*Math.min(1,(frac-.85)/.15):0):0;
 const feet=(base-h0-lift)*B,swing=Math.sin(t*7);
 const limb=(px,py,w,h,angle,color,extra)=>{ctx.save();ctx.translate(Math.round(px),Math.round(py));ctx.rotate(angle);ctx.globalAlpha=1;ctx.fillStyle=color;ctx.fillRect(-w/2,0,w,h);if(extra)extra();ctx.restore()};
 limb(minerX,feet-12*p,4*p,12*p,-swing*.55,'#2c307e');
 limb(minerX,feet-24*p,4*p,12*p,swing*.5,'#26878b');
 box(minerX-2*p,feet-24*p,4*p,12*p,'#2fa3a8');
 limb(minerX,feet-12*p,4*p,12*p,swing*.55,'#3b3f9e');
 box(minerX-4*p,feet-32*p,8*p,8*p,'#c69c7b');box(minerX-4*p,feet-32*p,8*p,2.5*p,'#4a3222');box(minerX-4*p,feet-32*p,2*p,5*p,'#4a3222');
 box(minerX+2*p,feet-28.5*p,1.5*p,1.5*p,'#3a3aa0');
 // The pickaxe swings harder with louder input.
 const chop=-.9-swing*.5-energy*.6*Math.abs(Math.sin(t*9));
 limb(minerX,feet-23*p,4*p,12*p,chop,'#c69c7b',()=>{ctx.fillStyle='#7a5a30';ctx.fillRect(-.75*p,9*p,1.5*p,11*p);ctx.fillStyle='#4ee6e0';for(let k=-4;k<=4;k++)ctx.fillRect(k*1.4*p-.75*p,18*p+Math.abs(k)*.5*p,1.5*p,1.5*p)});
 // Night falls over the whole world; light sources are drawn above it.
 box(0,0,W,H,'#060a20',(1-daylight)*.5);
 ctx.globalCompositeOperation='lighter';
 for(const [x,y,ore] of glows){const level=levels[ore];if(level>.02)box(x-B*.2,y-B*.2,B*1.4,B*1.4,minecraftOreColors[ore],level*(.15+glow*.35))}
 ctx.globalCompositeOperation='source-over';
 for(const [x,y,c] of torches){
  const flicker=.8+.2*Math.sin(t*13+c*2.3),r=B*(1+energy*1.2)*flicker;
  const halo=ctx.createRadialGradient(x,y,0,x,y,r*1.6);halo.addColorStop(0,'#ffcf5a');halo.addColorStop(1,'#ffcf5a00');
  ctx.globalAlpha=(.06+.5*(1-daylight))*(.4+glow*.6);ctx.fillStyle=halo;ctx.fillRect(x-r*1.6,y-r*1.6,r*3.2,r*3.2);
  box(x-B*.1,y-B*.12,B*.2,B*.2,'#ffe27a');box(x-B*.05,y-B*.06,B*.1,B*.1,'#fff7d0');
 }
 // Experience orbs drift up from the miner in the palette accent.
 ctx.shadowColor=accent;ctx.shadowBlur=small?0:glow*B*.6;
 for(let i=0;i<Math.floor(3+quality*6);i++){
  const rise=(t*.35+minecraftRandom(i+900))%1,size=p*(2.5+energy*2.5);
  box(minerX+Math.sin(t*1.3+i*2.1)*B*1.4-size/2,feet-B*2.4-rise*B*3,size,size,accent,(1-rise)*(.5+glow*.5));
 }
 ctx.restore();
}
