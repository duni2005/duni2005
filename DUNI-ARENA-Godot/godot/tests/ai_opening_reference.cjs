// Normalize transient brain traits to isolate tick/steering parity from RNG algorithms.
const fs=require('fs'),create=require('../../tests/arena-harness.cjs');const rows=[];
for(const plan of ['observe','circle','feint','flank']){
 const h=create(17);h.box.plan=plan;
 h.run(`gameKind='custom';roster=[{id:1,type:0,team:0,x:180,y:400},{id:2,type:0,team:1,x:620,y:400}];startBattle();Math.random=()=>.5;elapsed=0;
 for(let i=0;i<units.length;i++){const u=units[i];u.x=i?620:180;u.y=400;u.face=i?Math.PI:0;u.phase=1.2;u.moveSpeed=TYPES[u.type].speed;u.cooldown=0;u.headingX=u.headingY=u.vx=u.vy=u.kx=u.ky=0;Object.assign(u.ai,{mode:'observe',think:99,hold:99,lastTarget:null,nextInitiativeAt:5,commitUntil:0,phase:1.2,side:1,standoff:162,swerve:1.1,reaction:.2,tempo:1,patience:1,entryPlan:plan});u.ai.area={mode:'fight',nextThink:99,until:0,goal:null};}
 globalThis.trace=[];for(let i=1;i<=120;i++){step(1/60);if(i%15===0)trace.push({time:elapsed,actors:units.map(u=>({x:u.x,y:u.y,hx:u.headingX,hy:u.headingY,hp:u.hp,target:units.findIndex(e=>e.id===u.targetId)}))});}`);
 rows.push({plan,trace:h.run('trace')});
}
fs.writeFileSync('godot/migration/phase105-web-openings.json',JSON.stringify(rows,null,2));console.log('OPENING',rows.length,'normalized two-second full-tick fixtures');
