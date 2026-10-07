"use strict";
// Forest Walk is a pure clock-driven scene. Fixed pools and seeded encounter
// windows keep pause/reduced motion deterministic and memory bounded.
function forestRandom(seed) {
 const value=Math.sin(seed*127.1+311.7)*43758.5453;
 return value-Math.floor(value);
}
function forestEncounter(time) {
 const t=Math.max(0,Number.isFinite(time)?time:0),slot=Math.floor(t/10);
 const start=forestRandom(slot*7+1)*2,duration=5+forestRandom(slot*7+2)*2;
 const progress=(t-slot*10-start)/duration;
 if(progress<0||progress>=1)return null;
 return {kind:Math.floor(forestRandom(slot*7+3)*4),side:forestRandom(slot*7+4)<.5?-1:1,
  depth:.48+forestRandom(slot*7+5)*.18,progress,opacity:Math.min(1,progress*6,(1-progress)*6)};
}
function renderForestWalk(canvas,time,bands,small=false) {
 const ctx=canvas.getContext('2d'),W=canvas.width,H=canvas.height,U=Math.min(W,H);
 if(W<=1||H<=1)return;
 const t=Math.max(0,Number.isFinite(time)?time:0),energy=Math.min(1,Math.max(0,rms*gain*3));
 const quality=small?.3:detail,accent=palettes[palette][0];
 ctx.save();ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';ctx.shadowBlur=0;
 const polygon=(points,color,alpha=1)=>{ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.closePath();ctx.fillStyle=color;ctx.globalAlpha=alpha;ctx.fill()};
 const ellipse=(x,y,rx,ry,color,alpha=1)=>{ctx.beginPath();ctx.ellipse(x,y,rx,ry,0,0,Math.PI*2);ctx.fillStyle=color;ctx.globalAlpha=alpha;ctx.fill()};
 const line=(points,color,width,alpha=1)=>{ctx.beginPath();points.forEach(([x,y],i)=>i?ctx.lineTo(x,y):ctx.moveTo(x,y));ctx.strokeStyle=color;ctx.lineWidth=width;ctx.lineCap='round';ctx.lineJoin='round';ctx.globalAlpha=alpha;ctx.stroke()};
 const sky=ctx.createLinearGradient(0,0,0,H);sky.addColorStop(0,'#122f35');sky.addColorStop(.4,'#759484');sky.addColorStop(1,'#102e26');ctx.fillStyle=sky;ctx.fillRect(0,0,W,H);
 const sun=ctx.createRadialGradient(W*.52,H*.29,0,W*.52,H*.29,U*.5);sun.addColorStop(0,'#f5e6a67a');sun.addColorStop(1,'#e6d99a00');ctx.fillStyle=sun;ctx.fillRect(0,0,W,H);
 // Far trunks and soft evergreen silhouettes establish depth behind the trail.
 for(let i=0;i<28;i++){
  const x=forestRandom(i+80)*W,base=H*(.39+forestRandom(i+120)*.13),height=H*(.15+forestRandom(i+160)*.25);
  line([[x,base],[x,base-height]],'#264e49',U*.006,.35);
  polygon([[x-U*.055,base-H*.04],[x,base-height],[x+U*.055,base-H*.04]],'#315d50',.4);
 }
 polygon([[0,H*.47],[W*.5,H*.37],[W,H*.47],[W,H],[0,H]],'#183d2e');
 polygon([[W*.485,H*.38],[W*.515,H*.38],[W*.57,H*.56],[W*.69,H*.78],[W*.88,H],[W*.12,H],[W*.36,H*.72],[W*.46,H*.53]],'#938967');
 polygon([[W*.49,H*.39],[W*.51,H*.39],[W*.53,H*.57],[W*.61,H*.78],[W*.73,H],[W*.32,H],[W*.43,H*.71]],'#b0a07a',.55);
 // Travel moves objects toward the viewer. Wrapping occurs in distant haze.
 const rows=small?9:Math.floor(10+quality*8);
 const trees=Array.from({length:rows},(_,row)=>({row,z:(row/rows+t*.035)%1})).sort((a,b)=>a.z-b.z);
 for(const {row,z} of trees){
  const depth=z*z;
  for(const side of [-1,1]){
   const seed=row*13+(side+1)*17,x=W*(.5+side*(.07+depth*(.52+forestRandom(seed)*.3)));
   const y=H*(.39+depth*.69),height=H*(.16+depth*.76),width=U*(.014+depth*.043);
   const sway=Math.sin(t*.6+seed)*U*.004*(1+energy*.4);
   line([[x,y],[x+sway,y-height]],depth>.45?'#172f29':'#36594a',width);
   line([[x-width*.22,y],[x+sway-width*.22,y-height]],'#99a775',Math.max(1,width*.12),.22);
   for(let tier=0;tier<3;tier++){
    const tip=y-height+height*tier*.19,spread=height*(.2+tier*.025);
    polygon([[x+sway,tip],[x-spread,tip+height*.48],[x+spread,tip+height*.48]],depth>.45?'#174735':'#3c6550',.96);
    polygon([[x+sway,tip],[x-spread,tip+height*.48],[x,tip+height*.38]],'#769363',.16);
   }
  }
 }
 for(let i=0;i<4;i++)polygon([[W*(.45+i*.05),0],[W*(.48+i*.055),0],[W*(.19+i*.24),H*.86],[W*(.08+i*.24),H*.86]],'#ffe8a3',(.024+energy*.025)*glow);
 // Ferns and stones remain outside the center of the walking path.
 for(let i=0;i<Math.floor(12+quality*24);i++){
  const z=(forestRandom(i+260)+t*.045)%1,d=z*z,side=i%2?-1:1;
  const x=W*(.5+side*(.08+d*.65)),y=H*(.43+d*.62),s=U*(.002+d*.012);
  ellipse(x,y,s*1.6,s*.55,'#91a579',.45);
  line([[x-s*2,y-s],[x,y],[x+s,y-s*2]],'#659265',Math.max(1,s*.3),.7);
 }
 const encounter=forestEncounter(t);
 if(encounter){
  const {kind,side,depth,progress,opacity}=encounter;
  const x=W*(.5+side*(.18+depth*.1)-side*Math.sin(progress*Math.PI)*.045),y=H*(depth+.12);
  const s=U*(kind===0?.045:kind===3?.026:.03),hop=kind===2?Math.abs(Math.sin(progress*19))*s*.2:0;
  ctx.save();ctx.translate(x,y-hop);ctx.scale(-side*s,s);ctx.globalAlpha=opacity;
  // Local primitives preserve the encounter fade for every body part.
  const oval=(x,y,rx,ry,c)=>ellipse(x,y,rx,ry,c,opacity);
  const shape=(p,c)=>polygon(p,c,opacity);
  const limb=(p,c,w)=>line(p,c,w,opacity);
  if(kind===3){
   const flap=Math.sin(t*6)*.7;
   limb([[-1,-.8-flap],[0,0],[1,-.8-flap]],'#e4dcb5',.14);oval(0,0,.18,.3,'#cbb98f');
  }else{
   const coat=kind===0?'#bf9b6a':kind===1?'#d48343':'#b1b2a0';
   oval(0,-.55,kind===0?.85:.72,kind===0?.46:.38,coat);
   if(kind===1){shape([[-.4,-.45],[-1.65,-.95],[-1.35,-.3],[-.5,-.2]],coat);shape([[-1.65,-.95],[-1.35,-.3],[-1.12,-.36]],'#efe3bd')}
   if(kind===2){oval(-.66,-.46,.23,.23,'#e2dcc2');oval(.52,-1.2,.12,.55,coat);oval(.8,-1.15,.13,.5,coat)}
   if(kind===0){limb([[.5,-.55],[.75,-1.5]],coat,.34);limb([[.65,-1.77],[.4,-2.3],[.2,-2.4]],'#d6bc8a',.09);limb([[.4,-2.3],[.62,-2.45]],'#d6bc8a',.07)}
   oval(kind===0?.85:.65,kind===0?-1.55:-.85,.38,.26,coat);
   if(kind!==2)shape([[.48,kind===0?-1.7:-1],[.5,kind===0?-2:-1.4],[.8,kind===0?-1.7:-1]],coat);
   for(let leg=0;leg<4;leg++){const lx=-.48+leg*.3,swing=Math.sin(t*3+leg)*.09;limb([[lx,-.35],[lx+swing,.26]],coat,kind===0?.12:.15)}
   oval(kind===0?1:.8,kind===0?-1.6:-.9,.045,.045,'#172b28');
  }
  ctx.restore();
 }
 // The walker is seen from behind: boots, swinging limbs, pack and ochre coat.
 const stride=Math.sin(t*4),bob=Math.cos(t*8)*U*.002,s=U*.075;
 const x=W*.5+Math.sin(t*2)*U*.003,y=H*.76+bob;
 ellipse(x,y+s*.42,s*.7,s*.16,'#122c26',.28);
 line([[x-s*.2,y-s*.3],[x-s*.23-stride*s*.18,y+s*.3]],'#243d39',s*.19);
 line([[x+s*.2,y-s*.3],[x+s*.23+stride*s*.18,y+s*.3]],'#243d39',s*.19);
 line([[x-s*.35,y-s*1.23],[x-s*.56,y-s*.48+stride*s*.14]],'#d4ab64',s*.16);
 line([[x+s*.35,y-s*1.23],[x+s*.56,y-s*.48-stride*s*.14]],'#d4ab64',s*.16);
 polygon([[x-s*.31,y-s*1.45],[x+s*.31,y-s*1.45],[x+s*.4,y-s*.27],[x-s*.4,y-s*.27]],'#d7ad62');
 ellipse(x,y-s*1.76,s*.24,s*.29,'#d4b38a');
 ellipse(x,y-s*1.93,s*.32,s*.14,'#647356');
 polygon([[x-s*.26,y-s*1.35],[x+s*.26,y-s*1.35],[x+s*.28,y-s*.57],[x-s*.28,y-s*.57]],'#42675d');
 line([[x-s*.18,y-s*1.28],[x+s*.18,y-s*1.28]],'#c8c092',s*.055);
 // Palette colors tint fireflies only, preserving the woodland's natural colors.
 ctx.shadowColor=accent;ctx.shadowBlur=small?0:glow*U*.018;
 for(let i=0;i<Math.floor(8+quality*24);i++){
  const fx=W*(.08+forestRandom(i+400)*.84)+Math.sin(t*.45+i)*U*.018;
  const fy=H*(.3+forestRandom(i+460)*.53)+Math.cos(t*.6+i)*U*.014;
  ellipse(fx,fy,U*(.0015+energy*.0012),U*(.0015+energy*.0012),accent,(.3+.7*Math.pow(Math.sin(t+i),2))*(.4+glow*.6));
 }
 ctx.restore();
}
