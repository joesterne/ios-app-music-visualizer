// Exercise the wrapper's real script without a browser: no iframe remounts during poses/tour.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');const html=fs.readFileSync(path.join(root,'Duo-Demo.html'),'utf8');
const script=html.slice(html.indexOf('<script>')+8,html.lastIndexOf('</script>'));
const messages=[],events=new Map(),callbacks=new Map(),elements=new Map();let serial=0,loads=0;
function element(){return {dataset:{},style:{values:{},setProperty(k,v){this.values[k]=v}},setAttribute(k,v){this[k]=String(v)},clientWidth:700,clientHeight:595,tagName:'DIV'}}
const poses=['closed','open','tabletop'].map(pose=>Object.assign(element(),{dataset:{pose},tagName:'BUTTON'}));
const visuals=['yosemite','aurora','orbit'].map(visual=>Object.assign(element(),{dataset:{visual},tagName:'BUTTON'}));
const app=element();app.contentWindow={postMessage:data=>messages.push(data)};
Object.defineProperty(app,'srcdoc',{set(v){loads++;this.source=v},get(){return this.source}});elements.set('app',app);
const doc={hidden:false,getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id)},querySelectorAll(query){return query.includes('data-pose')?poses:visuals},addEventListener:(e,cb)=>events.set(e,cb)};
const context=vm.createContext({document:doc,window:{addEventListener:(e,cb)=>events.set(e,cb)},Math,requestAnimationFrame(cb){const id=++serial;callbacks.set(id,cb);return id},cancelAnimationFrame(id){callbacks.delete(id)}});
vm.runInContext(script,context);assert.equal(loads,1);assert.equal(app.srcdoc,fs.readFileSync(path.join(root,'Preview.html'),'utf8'));
app.onload();assert.equal(messages.at(-1).pose,'open');
for(const button of poses){button.onclick();assert.equal(messages.at(-1).pose,button.dataset.pose);assert.equal(loads,1)}
events.get('message')({source:app.contentWindow,data:{type:'afterglow-demo-state',visual:'orbit'}});
poses[0].onclick();assert.equal(messages.at(-1).visual,undefined,'Pose changes must not override a saved or in-app visual');
visuals[2].onclick();assert.equal(messages.at(-1).visual,'orbit');assert.equal(loads,1);
elements.get('tour').onclick();
for(const ms of [0,6000,12000,18000,21000]){const current=[...callbacks.values()];callbacks.clear();current.forEach(cb=>cb(ms))}
assert.equal(messages.at(-1).pose,'open');assert.equal(messages.at(-1).visual,'aurora');assert.equal(loads,1);assert.equal(callbacks.size,0);
elements.get('tour').onclick();doc.hidden=true;events.get('visibilitychange')();assert.equal(callbacks.size,0);
const stage=elements.get('demo-stage');stage.clientWidth=300;events.get('resize')();
const d=elements.get('device').style.values;assert.ok(d['--w']*d['--scale']<=stage.clientWidth-30+.001);
console.log('PASS: embedded app matches preview, pose/visual controls, tour progression, hidden pause, narrow sizing; iframe loaded exactly once.');
