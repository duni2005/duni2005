'use strict';
// The swallowed fighter stays a real unit: its HP, team and guild identity never change.
const FROG={tongueSpeed:900,pullSpeed:760,hold:.65,bodySpeed:650,rescueRange:1100};
function frogUnavailable(u){return !!u&&(u.frogCarrierId!=null||!!u.frogFlight);}
function frogHidden(u){if(u?.frogCarrierId==null)return false;const owner=units.find(v=>v.id===u.frogCarrierId);return owner?.frogAction?.phase==='hold';}
function frogTarget(u,enemies){return enemies.filter(e=>e.hp>0&&!frogUnavailable(e)&&canPerceive(u,e)).slice().sort((a,b)=>b.hp-a.hp||dist(u,a)-dist(u,b))[0]??null;}
function frogStop(u){u.vx=u.vy=u.headingX=u.headingY=0;}
function frogHopLift(u){return u.type===24&&u.frogHop?Math.sin(Math.PI*clamp(u.frogHop.t/u.frogHop.duration,0,1))*30:0;}
function moveFrog(u,target,enemies,allies,dt){
 if(u.attack||u.ultCast||u.frogAction||basicParryPerfect(u)||u.ai.response?.mode==='parry'){u.frogHop=null;frogStop(u);return true;}
 if(!u.frogHop){
  frogStop(u);u.frogHopWait=(u.frogHopWait??random(.45,1.5))-dt;u.action='폴짝 · 쉬는 중';if(u.frogHopWait>0)return true;
  let goal={x:random(75,725),y:random(75,725)};const context=collectBattleAreas(u,enemies,allies),risk=battleAreaRisk(u,u,context).total,areaGoals=risk>.3||u.hp/u.maxHp<.65?battleAreaGoal(u,target,context):null;
  const near=enemies.slice().sort((a,b)=>dist(u,a)-dist(u,b))[0];
  if(areaGoals&&risk>.3&&areaGoals.improvement>.2&&Math.random()<.65)goal=areaGoals.escape;
  else if(areaGoals?.refuge&&areaGoals.benefit>.65&&Math.random()<.55)goal=areaGoals.refuge;
  else if(u.combatStance==='cover'&&allies.length){const friend=allies.slice().sort((a,b)=>dist(u,a)-dist(u,b))[0];goal={x:friend.x+random(-80,80),y:friend.y+random(-80,80)};}
  else if(near&&(dist(u,near)<130||u.hp/u.maxHp<.35&&dist(u,near)<200)){const a=Math.atan2(u.y-near.y,u.x-near.x)+random(-.5,.5);goal={x:u.x+Math.cos(a)*210,y:u.y+Math.sin(a)*210};}
  else if(target&&(dist(u,target)>u.range*.9||u.combatStance==='rush')){const a=Math.atan2(target.y-u.y,target.x-u.x)+random(-.45,.45);goal={x:u.x+Math.cos(a)*200,y:u.y+Math.sin(a)*200};}
  const d=dist(u,goal)||1,len=Math.min(d,random(85,155)),angle=Math.atan2(goal.y-u.y,goal.x-u.x);const end={x:clamp(u.x+Math.cos(angle)*len,35,765),y:clamp(u.y+Math.sin(angle)*len,35,765)};
  u.frogHop={dx:(end.x-u.x),dy:(end.y-u.y),duration:clamp(.5*105/u.moveSpeed,.28,.65),t:0};u.face=angle;
  burst(u.x,u.y+20,'#b9dca0',10,100,.9,angle+Math.PI,'debris');
 }
 const h=u.frogHop,before={x:u.x,y:u.y},step=Math.min(dt,h.duration-h.t);h.t+=step;
 u.x=clamp(u.x+h.dx*step/h.duration,28,772);u.y=clamp(u.y+h.dy*step/h.duration,28,772);u.vx=(u.x-before.x)/dt;u.vy=(u.y-before.y)/dt;u.action='폴짝';u.face=Math.atan2(h.dy,h.dx);
 if(h.t>=h.duration-1e-8){u.frogHop=null;u.frogHopWait=random(.4,1.6);burst(u.x,u.y+20,'#b9dca0',10,130,.8,u.face,'debris');frogStop(u);}return true;
}
function launchFrogTongue(u,a){
 u.frogHop=null;frogStop(u);const scale=unitScale(u),x=u.x+Math.cos(a.angle)*30*scale,y=u.y+Math.sin(a.angle)*30*scale;
 projectiles.push({kind:'frogTongue',source:u,type:24,x,y,vx:Math.cos(a.angle)*FROG.tongueSpeed,vy:Math.sin(a.angle)*FROG.tongueSpeed,radius:21*scale,visualScale:scale,damage:u.dmg,power:u.dmg,life:a.profile.reach*scale/FROG.tongueSpeed,trail:[],color:'#f6a6ad',hiddenLaunch:a.hiddenLaunch,homing:false,guaranteed:false});
 burst(x,y,'#f6c1c0',10,150,.5,a.angle,'mote');
}
function clearFrogVictim(v){v.frogCarrierId=null;v.frogFlight=null;v.frogRescueGuard=false;v.kx=v.ky=0;frogStop(v);}
function captureFrogUnit(u,v,rescue=false){
 if(u.hp<=0||v.hp<=0||u.frogAction||heroRescuing(v)||heroRescueProtected(v)||frogUnavailable(v)||duelLocked(v)&&!rescue)return false;
 // Remove pending swings and casts so a grabbed fighter cannot attack from inside the frog.
 interruptStunnedActions(v);v.ultCast=null;v.heroRescue=null;v.frogHop=null;v.frogCarrierId=u.id;v.frogRescueGuard=rescue;v.kx=v.ky=0;
 u.attack=null;u.ultCast=null;u.frogHop=null;u.parryTime=0;u.dodgeState=null;u.evadeTime=0;u.kx=u.ky=0;frogStop(u);
 for(const s of meleeStrikes)if(s.source===u||s.source===v)s.life=0;
 u.face=Math.atan2(v.y-u.y,v.x-u.x);u.frogAction={targetId:v.id,rescue,phase:rescue?'prepare':'pull',t:0,pullTime:0,holdTime:0};u.cooldown=Math.max(u.cooldown,u.cd);u.action=rescue?'낼름 퉤 · 아군 구출':'꿀꺽 · 끌어당기기';
 if(rescue)fx('charge',u.x,u.y,'#d9ffa6',.2,{r:65,unitId:u.id});return true;
}
function frogTongueImpact(p,v){
 p.life=0;const u=p.source;if(u.hp<=0||u.stun>0||u.frogAction||frogUnavailable(v)||v.invincible>0||duelLocked(v)||!canPerceive(u,v))return;
 const angle=Math.atan2(p.vy,p.vx),options={attackToken:p,angle,attackOrigin:p,hiddenLaunch:p.hiddenLaunch};
 const blocked=interceptMirrorAttack(v,u,p.power,options)||tryBasicParry(v,u,angle,p.power,p);if(blocked)return;
 if(v.evadeTime>0&&canSeeAttack(v,u,p,p.hiddenLaunch))return;
 if(captureFrogUnit(u,v)){fx('metalHit',p.x,p.y,'#f6c1c0',.18,{r:55,angle});burst(p.x,p.y,'#f6c1c0',14,220,.6,angle,'shard');}
}
function tryFrogRescue(patient){
 if(!patient||patient.hp<=0||frogUnavailable(patient)||patient.invincible>0||patient.frogRescueGuard)return false;
 const frog=units.filter(u=>u.type===24&&u.id!==patient.id&&u.faction===patient.faction&&u.hp>0&&u.ultGauge>=100&&u.stun<=0&&!frogUnavailable(u)&&!u.frogAction&&!duelLocked(u)&&!u.strategyDash&&dist(u,patient)<=FROG.rescueRange*unitScale(u)).sort((a,b)=>dist(a,patient)-dist(b,patient))[0];
 if(!frog||!captureFrogUnit(frog,patient,true))return false;
 frog.ultGauge=0;frog.ultReadyAge=0;frog.ultUses++;frog.strategyUltimateReady=false;addLog(`${frog.name} · 낼름 퉤 · ${patient.name} 구출`);return true;
}
function frogSafePoint(patient){
 const enemies=alive().filter(v=>v.faction!==patient.faction&&!frogUnavailable(v)),friends=alive().filter(v=>v.faction===patient.faction&&v.id!==patient.id&&!frogUnavailable(v)),context=collectBattleAreas(patient,enemies,friends),choices=[];
 for(let x=75;x<=725;x+=65)for(let y=75;y<=725;y+=65){const p={x,y},nearest=enemies.length?Math.min(...enemies.map(e=>dist(e,p))):400,danger=battleAreaRisk(patient,p,context).total,healing=ultimateZones.some(z=>z.kind==='healing'&&z.source.faction===patient.faction&&dist(z,p)<z.r),crowd=friends.filter(v=>dist(v,p)<60).length;choices.push({...p,score:nearest-danger*500-crowd*100+(healing?70:0)-dist(patient,p)*.06});}
 return choices.sort((a,b)=>b.score-a.score)[0]??{x:400,y:400};
}
function spitFrogUnit(u,a,v){
 const rescue=a.rescue,enemies=alive().filter(e=>e.faction!==u.faction&&e!==v&&!frogUnavailable(e)&&canPerceive(u,e)),enemy=enemies.sort((b,c)=>dist(u,b)-dist(u,c))[0];
 let goal=rescue?frogSafePoint(v):enemy?{x:enemy.x,y:enemy.y}:{x:400,y:400};let angle=Math.atan2(goal.y-u.y,goal.x-u.x);if(!rescue&&!enemy&&dist(u,goal)<50)angle=u.face;
 u.face=angle;const scale=unitScale(v),speed=rescue?850:FROG.bodySpeed,travel=rescue?Math.max(1,dist(u,goal)):Math.max(150,enemy?dist(u,enemy)+100:230);
 const p={kind:'frogBody',source:u,cargo:v,rescue,type:24,x:u.x,y:u.y,vx:Math.cos(angle)*speed,vy:Math.sin(angle)*speed,radius:36*scale,visualScale:scale,damage:u.dmg*(1+Math.floor(v.maxHp/60)*.1),power:u.dmg*(1+Math.floor(v.maxHp/60)*.1),life:Math.min(rescue?1.3:1.15,travel/speed),trail:[],color:rescue?'#c2f58e':'#f6bdad',hiddenLaunch:false,homing:false,guaranteed:false,resolved:false};
 v.frogCarrierId=null;v.frogFlight=p;v.frogRescueGuard=rescue;projectiles.push(p);u.frogAction=null;u.cooldown=Math.max(u.cooldown,u.cd);u.frogHopWait=random(.5,1.2);frogStop(u);
 if(rescue)restoreCombatHp(v,v.maxHp*.1,u);
 fx('muzzle',u.x+Math.cos(angle)*35,u.y+Math.sin(angle)*35,p.color,.14,{r:65,angle});burst(u.x,u.y,p.color,20,280,.7,angle,'shard');u.kx-=Math.cos(angle)*70;u.ky-=Math.sin(angle)*70;u.action=rescue?'낼름 퉤 · 안전한 곳으로':'꿀꺽 퉤 · 발사';
}
function releaseFrogAction(u,{heal=false}={}){
 const a=u.frogAction;if(!a)return;const v=units.find(v=>v.id===a.targetId);u.frogAction=null;
 if(v?.frogCarrierId===u.id){if(a.phase==='hold'){v.x=clamp(u.x+Math.cos(u.face)*42,28,772);v.y=clamp(u.y+Math.sin(u.face)*42,28,772);}clearFrogVictim(v);if(a.rescue){v.invincible=Math.max(v.invincible,.4);if(heal&&v.hp>0)restoreCombatHp(v,v.maxHp*.1,u);}}
}
function advanceFrogActions(dt){
 for(const u of units){const a=u.frogAction;if(!a)continue;const v=units.find(v=>v.id===a.targetId);
  if(u.hp<=0||u.stun>0||!v||v.hp<=0||v.frogCarrierId!==u.id){releaseFrogAction(u,{heal:true});continue;}
  a.t+=dt;frogStop(u);frogStop(v);u.kx=u.ky=v.kx=v.ky=0;
  if(a.phase==='prepare'){if(a.t>=.2)a.phase='pull';continue;}
  if(a.phase==='pull'){
   a.pullTime+=dt;const d=dist(u,v),step=Math.min(d,FROG.pullSpeed*dt),dx=(u.x-v.x)/(d||1),dy=(u.y-v.y)/(d||1);v.x=clamp(v.x+dx*step,28,772);v.y=clamp(v.y+dy*step,28,772);v.vx=dx*step/dt;v.vy=dy*step/dt;u.face=Math.atan2(v.y-u.y,v.x-u.x);v.action=a.rescue?'구출 · 끌려오는 중':'혀에 붙잡힘';
   if(dist(u,v)<8){a.phase='hold';a.holdTime=0;fx('heal',u.x,u.y,a.rescue?'#d7ffad':'#f6c1c0',.22,{r:50});}else if(a.pullTime>1.5)releaseFrogAction(u,{heal:true});
  }else if(a.phase==='hold'){v.x=u.x;v.y=u.y;a.holdTime+=dt;u.action=a.rescue?'낼름 · 아군 보호':'꿀꺽 · 머금기';if(a.holdTime>=(a.rescue?.35:FROG.hold))spitFrogUnit(u,a,v);}
 }
}
function finishFrogBody(p,{damage=true}={}){
 if(p.resolved)return;p.resolved=true;p.life=0;const v=p.cargo;if(!v||v.frogFlight!==p)return;
 v.x=clamp(p.x,28,772);v.y=clamp(p.y,28,772);clearFrogVictim(v);
 if(p.rescue){v.invincible=Math.max(v.invincible,.4);fx('heal',v.x,v.y,'#c2f58e',.35,{r:75});burst(v.x,v.y,'#dcffbc',16,180,.8,Math.atan2(p.vy,p.vx),'mote');}
 else if(damage&&v.hp>0){attackHit(v,p.damage*.7,p.source,{angle:Math.atan2(p.vy,p.vx),impulse:150,attackToken:p,attackOrigin:p,visibleHazard:true});}
 if(v.hp>0){v.cooldown=Math.max(v.cooldown,.4);v.ai.disengageUntil=elapsed+.35;v.frogHopWait=random(.5,1);}
}
function frogBodyImpact(p,target){
 if(p.rescue)return;const angle=Math.atan2(p.vy,p.vx);attackHit(target,p.damage,p.source,{angle,impulse:390,attackToken:p,attackOrigin:p,visibleHazard:true});impact(p.x,p.y,'#e5eeaf',2,angle);finishFrogBody(p,{damage:true});
}
function onFrogDeath(u){releaseFrogAction(u,{heal:true});if(u.frogCarrierId!=null){const owner=units.find(v=>v.id===u.frogCarrierId);if(owner)releaseFrogAction(owner);}if(u.frogFlight)finishFrogBody(u.frogFlight,{damage:false});}
function releaseAllFrogCargo(){for(const u of units)releaseFrogAction(u);for(const p of projectiles)if(p.kind==='frogBody')finishFrogBody(p,{damage:false});for(const v of units)if(frogUnavailable(v))clearFrogVictim(v);}
function renderFrogTongue(p){const u=p.source;pixelBeam(u.x,u.y,p.x,p.y,'#ad687d',14,.9);pixelBeam(u.x,u.y,p.x,p.y,'#ffc4c3',7,.95);pixelSprite(p.x,p.y,'#ffc4c3',1.1,'ember');}
function renderFrogActions(){for(const u of units){const a=u.frogAction;if(!a)continue;const v=units.find(v=>v.id===a.targetId);if(!v)continue;if(a.phase!=='hold'){pixelBeam(u.x,u.y,v.x,v.y,'#ae667c',15,.9);pixelBeam(u.x,u.y,v.x,v.y,a.rescue?'#e1ffad':'#ffcbcb',7,.95);pixelSprite(v.x,v.y,a.rescue?'#d6ffa2':'#ffb2c0',1.3,'ember');}else{const pulse=1+Math.sin(a.holdTime*12)*.05;ctx.save();ctx.translate(u.x,u.y);ctx.scale(pulse,1);slashStroke(0,0,35,-.7,.7,a.rescue?'#dcffa5':'#ffc4c3',12,.9);ctx.restore();}}}
function renderFrogBody(p){
 const angle=Math.atan2(p.vy,p.vx);for(let i=0;i<p.trail.length;i+=2){const t=p.trail[i];bladeStreak(t.x,t.y,angle,30,9,p.color,.12+i*.03);}
 ctx.save();ctx.translate(p.x,p.y);ctx.rotate(elapsed*9);circle(0,0,27,'#23332b');renderEmoji(p.cargo.type,0,0,43);circle(0,0,28,unitHpColor(p.cargo),false,3);ctx.restore();bladeStreak(p.x- Math.cos(angle)*32,p.y-Math.sin(angle)*32,angle,68,11,p.color,.8);
}
function renderFrogWeapon(u,a,p){if(!a)return;ctx.save();ctx.translate(25,0);const stretch=a.phase==='windup'?p:0;ctx.fillStyle='#ac6076';ctx.beginPath();ctx.ellipse(0,0,11+stretch*9,9,0,0,Math.PI*2);ctx.fill();slashStroke(-4,0,14,-1.6,1.6,'#ffc3c3',8,.95);ctx.restore();}
