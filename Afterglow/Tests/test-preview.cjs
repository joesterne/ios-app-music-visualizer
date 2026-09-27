// Behavioral scheduler tests in a Node VM; this is not browser rendering QA.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const html = fs.readFileSync(path.join(__dirname, '../Preview.html'), 'utf8');
const script = html.split('<script>')[1].split('</script>')[0];
const windowEvents = new Map(), parentWindow = {};
const events = new Map(), callbacks = new Map(), elements = new Map();
let nextId = 0, paints = 0, reads = 0;
const element = () => ({
  dataset: {}, classList: { toggle() {}, add() {}, remove() {} }, style: { setProperty() {}, removeProperty() {} },
  setAttribute() {}, appendChild() {}, scrollIntoView() {}, click() {},
  getBoundingClientRect: () => ({ width: 900, height: 500 }),
  querySelector: () => element(), width: 900, height: 500,
});
const document = {
  hidden: false, documentElement: element(), body: element(),
  getElementById(id) { if (!elements.has(id)) elements.set(id, element()); return elements.get(id); },
  createElement: element, querySelectorAll: () => [], querySelector: element,
  addEventListener: (event, callback) => events.set(event, callback),
};
const context = vm.createContext({
  document, innerWidth: 1400, devicePixelRatio: 2,
  matchMedia: () => ({ matches: false }), console, URL,
  Image: class {},
  Path2D: class { moveTo() {} lineTo() {} closePath() {} },
  Audio: class { constructor() { this.paused = true; } pause() {} },
  ResizeObserver: class { observe() {} },
  window: { parent: parentWindow, addEventListener: (event,callback)=>windowEvents.set(event,callback) },
  setTimeout, clearTimeout,
  requestAnimationFrame(callback) { const id = ++nextId; callbacks.set(id, callback); return id; },
  cancelAnimationFrame(id) { callbacks.delete(id); },
  paint() { paints++; },
  readFrequency(array) { reads++; array.fill(-45); },
  readWave(array) { array.fill(.1); },
});
vm.runInContext(script, context);
vm.runInContext('render = paint;', context);
const run = code => vm.runInContext(code, context);
function step(ms) {
  const scheduled = [...callbacks.values()]; callbacks.clear();
  for (const callback of scheduled) callback(ms);
}
// A 120 Hz browser should not do 120 audio/drawing passes per second.
for (let i = 0; i <= 120; i++) step(i * 1000 / 120);
assert.ok(paints >= 59 && paints <= 62, `120 Hz produced ${paints} draws`);
// Preserve the cap on ordinary and non-integer-multiple refresh rates too.
for (const hz of [60, 144]) {
  run('last=0;lastDraw=null;needsRedraw=true');
  paints=0;
  for(let i=0;i<=hz;i++) step(i*1000/hz);
  assert.ok(paints>=59 && paints<=62, `${hz} Hz produced ${paints} draws`);
}
// The battery-saving option actually reduces analysis and rendering work.
run('fps=30;last=0;lastDraw=null;needsRedraw=true');paints=0;
for(let i=0;i<=120;i++)step(i*1000/120);
assert.ok(paints>=29&&paints<=32, `30 fps preference produced ${paints} draws`);
run('fps=60;lastDraw=null');
// A paused ambient studio sleeps until a setting requests another frame.
run('paused = true; requestRender()'); step(1100);
assert.equal(callbacks.size, 0);
let before = paints;
run('gain = 2; requestRender()'); step(1200);
assert.equal(paints, before + 1); assert.equal(callbacks.size, 0);
// Live audio continues to update while motion time remains frozen.
run(`source='mic'; activeMic={getTracks:()=>[]}; analyzer={fftSize:2048,getFloatFrequencyData:readFrequency,getFloatTimeDomainData:readWave};
 audioContext={sampleRate:48000}; rawFrequency=new Float32Array(1024); rawWave=new Float32Array(2048);
 configureBands(); requestRender();`);
let frozenTime = run('time');
step(1300); step(1320);
assert.ok(reads > 0); assert.equal(run('time'), frozenTime);
// Cache covers the same logarithmic bins, including the Nyquist clamp.
for (const rate of [8000, 44100, 48000, 96000, 384000]) {
  run(`audioContext.sampleRate=${rate};configureBands()`);
  const ranges = run('Array.from(bandStarts, (start,i)=>[start,bandEnds[i]])');
  for (let i=0;i<64;i++) {
    const upper=Math.min(16000,rate*.48);
    assert.equal(ranges[i][0], Math.max(1,Math.floor(40*(upper/40)**(i/64)/rate*2048)));
    assert.equal(ranges[i][1], Math.min(1023,Math.ceil(40*(upper/40)**((i+1)/64)/rate*2048)));
  }
}
// Hidden tabs cancel work and resume with one scheduled frame, without catch-up.
document.hidden=true; events.get('visibilitychange')();
assert.equal(callbacks.size,0);
before=reads; step(4000); assert.equal(reads,before);
document.hidden=false; events.get('visibilitychange')(); assert.equal(callbacks.size,1);
step(5000); assert.equal(reads,before+1);
// Poses and visual changes must preserve the existing audio objects and clock.
const stateBefore = run('[time, audio, analyzer, objectURL, source, paused]');
windowEvents.get('message')({source:parentWindow,data:{type:'afterglow-duo-demo',pose:'tabletop',visual:'orbit'}});
assert.equal(document.body.dataset.demoPose,'tabletop');assert.equal(run('style'),'orbit');
const stateAfter=run('[time, audio, analyzer, objectURL, source, paused]');
for(let i=0;i<stateBefore.length;i++)assert.equal(stateBefore[i],stateAfter[i]);
windowEvents.get('message')({source:{},data:{type:'afterglow-duo-demo',pose:'closed',visual:'aurora'}});
assert.equal(document.body.dataset.demoPose,'tabletop');assert.equal(run('style'),'orbit');
windowEvents.get('message')({source:parentWindow,data:{type:'afterglow-duo-demo',pose:'invalid',visual:'invalid'}});
assert.equal(document.body.dataset.demoPose,'tabletop');assert.equal(run('style'),'orbit');
console.log('PASS: 60 fps cap, paused idle, setting redraw, live audio with frozen motion, cached bands, background suspension/resume, Duo pose continuity and message validation.');
