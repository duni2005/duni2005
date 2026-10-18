// Instruments actual executable functions without changing dist files.
const fs=require('fs'),path=require('path'),create=require('../../tests/arena-harness.cjs');
const scenarios=JSON.parse(fs.readFileSync(process.argv[3]||'godot/migration/phase105-scenarios.json','utf8'));
const results=[];
for(const c of scenarios){const h=create(c.seed);h.box.fixture=c;
 h.run(`gameKind='custom';roster=fixture.entries.map((e,i)=>({id:i+1,type:e.type,team:e.team,x:e.x,y:e.y,stance:e.stance}));startBattle();for(let i=0;i<units.length;i++){units[i].x=fixture.entries[i].x;units[i].y=fixture.entries[i].y;}cinema.enabled=false;`);
 h.run(`globalThis.measure={first_attack:null,first_hit:null,attacks:0,hits:0,parry:0,dodge:0,clash:0,travel:0,gap:0,gap_samples:0,target_changes:0,idle:0,danger_time:0,escape:0,trace:[]};
 const originalStart=startAttack;startAttack=function(u,t,kind,...rest){const result=originalStart(u,t,kind,...rest);if(result&&kind!=='heal'){measure.attacks++;measure.first_attack??=elapsed;}return result;};
 const originalDamage=resolveDamage;resolveDamage=function(t,...args){const hp=t.hp,result=originalDamage(t,...args);if(t.hp<hp){measure.hits++;measure.first_hit??=elapsed;}return result;};
 const originalParry=startBasicParry;startBasicParry=function(...args){const result=originalParry(...args);if(result)measure.parry++;return result;};
 const originalClash=resolveClash;resolveClash=function(...args){measure.clash++;return originalClash(...args);};`);
 // Run full ticks, sample motion separately from AI intent.
 h.run(`{let nextSample=0;const previous=units.map(u=>({x:u.x,y:u.y,target:null,esc:false,hp:u.hp}));for(let tick=0;tick<fixture.seconds*fixture.fps&&running;tick++){
 const dt=1/fixture.fps;step(dt);for(let i=0;i<units.length;i++){const u=units[i],p=previous[i];if(u.hp<p.hp){measure.hit_ticks=(measure.hit_ticks??0)+1;}p.hp=u.hp;measure.travel+=Math.hypot(u.x-p.x,u.y-p.y);p.x=u.x;p.y=u.y;
 if(u.targetId!==p.target){if(p.target!==null)measure.target_changes++;p.target=u.targetId;}
 if(u.hp>0){const foes=alive().filter(e=>e.faction!==u.faction);if(foes.length){measure.gap+=Math.min(...foes.map(e=>dist(u,e)));measure.gap_samples++;}if(!u.attack&&!u.ultCast)measure.idle+=dt;
 const context=collectBattleAreas(u,foes,alive().filter(a=>a.faction===u.faction&&a!==u));if(battleAreaRisk(u,u,context).total>.2)measure.danger_time+=dt;const esc=u.ai.area?.mode==='escape';if(esc&&!p.esc)measure.escape++;p.esc=esc;}
 }
 if(elapsed>=nextSample-1e-8){measure.trace.push({time:elapsed,actors:units.map(u=>({x:u.x,y:u.y,hp:u.hp,alive:u.hp>0,target:units.findIndex(e=>e.id===u.targetId),plan:u.ai.mode,intent:u.ai.attackDecision?.at??null,state:u.attack?.phase??'idle',heading:[u.headingX,u.headingY],movement:u.action,initiative:u.ai.nextInitiativeAt}))});nextSample+=.25;}
 }measure.dodge=units.reduce((n,u)=>n+(u.ai.responseCounts?.dodge??0),0);measure.gap=measure.gap_samples?measure.gap/measure.gap_samples:0;measure.duration=elapsed;measure.completed=finished;}`);
 results.push({name:c.name,seed:c.seed,...h.run('measure')});console.log('WEB',c.name,c.seed,results.at(-1).first_attack,results.at(-1).travel);
}
fs.writeFileSync(process.argv[2]||'godot/migration/phase105-web-comparison.json',JSON.stringify(results,null,2));
