'use strict';
const MACHINE_GUN={type:23,capacity:20,reload:4,speed:4200,spread:.3,recoil:30,interval:.105};
function machineGunStatus(u){return u.hp<=0?'전투 불능':u.machineGunDash?'빠른 장전 · 탈출 대시':u.reloadRemaining>0?'재장전 '+u.reloadRemaining.toFixed(1)+'초':'탄창 '+u.ammo+' / 20';}
function refillMachineGun(u){u.ammo=MACHINE_GUN.capacity;u.reloadRemaining=0;u.cooldown=0;u.ai.disengageUntil=0;u.ai.attackDecision=null;u.ai.nextInitiativeAt=elapsed+random(.15,.65);}
function tickMachineGun(u,dt){if(u.reloadRemaining<=0)return;u.reloadRemaining=Math.max(0,u.reloadRemaining-dt);if(u.reloadRemaining===0){refillMachineGun(u);fx('gunFlash',u.x,u.y,'#e8d99d',.12,{angle:u.face,r:28});}}
function fireMachineGunRound(u,a){
 if(u.hp<=0||u.stun>0||u.ammo<=0||u.reloadRemaining>0)return false;
 const spread=MACHINE_GUN.spread*(random(-1,1)*.75+random(-1,1)*.25),angle=a.angle+spread,scale=unitScale(u),muzzle={x:u.x+Math.cos(angle)*55*scale,y:u.y+Math.sin(angle)*55*scale};
 projectiles.push({kind:'machineBullet',source:u,type:u.type,color:'#eed18f',...muzzle,vx:Math.cos(angle)*MACHINE_GUN.speed,vy:Math.sin(angle)*MACHINE_GUN.speed,damage:u.dmg,power:u.dmg,radius:14*scale,visualScale:scale,impulse:115,life:.35,trail:[],homing:false,guaranteed:false,piercing:false,bouncesRemaining:0,hiddenLaunch:a.hiddenLaunch,start:{...muzzle}});
 u.ammo--;u.shotsFired++;u.ai.disengageUntil=0;u.kx-=Math.cos(a.angle)*MACHINE_GUN.recoil;u.ky-=Math.sin(a.angle)*MACHINE_GUN.recoil;
 fx('gunFlash',u.x+Math.cos(a.angle)*68*scale,u.y+Math.sin(a.angle)*68*scale,'#ffe4a9',.07,{angle:a.angle,r:42*scale});
 burst(u.x+Math.cos(a.angle)*22,u.y+Math.sin(a.angle)*22,'#c9a85f',7,130,.6,a.angle+Math.PI/2,'debris');
 if(u.ammo===0){u.reloadRemaining=MACHINE_GUN.reload;u.ai.attackDecision=null;u.ai.disengageUntil=elapsed+.5;u.action='탄창 소진 · 재장전';}
 return true;
}
function advanceMachineGunAttack(u,dt){
 const a=u.attack;if(!a||a.kind!=='machineGun')return;if(u.hp<=0||u.stun>0){u.attack=null;return;}
 const target=units.find(v=>v.id===a.targetId&&v.hp>0&&canPerceive(u,v))??alive().filter(v=>v.faction!==u.faction&&canPerceive(u,v)).sort((x,y)=>dist(u,x)-dist(u,y))[0];
 if(!target){u.attack=null;return;}a.targetId=target.id;a.angle+=clamp(angleDelta(aimDirection(u,target),a.angle),-4*dt,4*dt);u.face=a.angle;a.t+=dt*attackRate(u);
 if(a.phase==='windup'&&a.t>=a.profile.windup){a.phase='active';a.t-=a.profile.windup;a.nextRound=MACHINE_GUN.interval;releaseAttack(u,a);}
 if(a.phase==='active'){
  while(u.ammo>0&&a.t+1e-8>=a.nextRound){fireMachineGunRound(u,a);a.nextRound+=MACHINE_GUN.interval;}
  u.action='기관총 · 연속 사격';if(u.ammo<=0||a.t>=a.profile.active){a.phase='recovery';a.t=0;u.action='재장전 준비';}
 }else if(a.phase==='recovery'&&a.t>=a.profile.recovery)u.attack=null;
}
function moveMachineGun(u,target,enemies,allies,dt){
 if(u.type!==23||u.ultCast||u.machineGunDash||u.combatStance==='rush'||u.combatStance==='cover'||u.tauntedUntil>elapsed||u.commandRetreatUntil>elapsed)return false;
 if(!target)return false;
 const near=enemies.slice().sort((a,b)=>dist(u,a)-dist(u,b))[0]??target,d=dist(u,target)||1,dx=(target.x-u.x)/d,dy=(target.y-u.y)/d,loading=u.reloadRemaining>0,desired=loading?440:365;
 const radial=clamp((d-desired)/85,-1.15,.9),side=u.attack?.phase==='active'?.05:.3;let mx=dx*radial-dy*u.ai.side*side,my=dy*radial+dx*u.ai.side*side;
 const closest=dist(u,near)||1;if(closest<220){mx+=(u.x-near.x)/closest*(220-closest)/80;my+=(u.y-near.y)/closest*(220-closest)/80;}
 steerArchetype(u,mx,my,dt,movementRate(u)*(u.attack?.phase==='windup'?.35:u.attack?.phase==='active'?.55:1));u.action=loading?'재장전 · 느린 후퇴':u.attack?'기관총 · 조준과 사격':'대치 · 사격 거리 유지';return true;
}
function startMachineGunReloadDash(u){
 const enemies=alive().filter(e=>e.faction!==u.faction&&canPerceive(u,e)),allies=alive().filter(a=>a.faction===u.faction&&a.id!==u.id),areas=collectBattleAreas(u,enemies,allies),candidates=[];
 for(let i=0;i<24;i++){const angle=i*Math.PI/12,point={x:clamp(u.x+Math.cos(angle)*260,38,762),y:clamp(u.y+Math.sin(angle)*260,38,762)},distance=dist(u,point);if(distance<85)continue;
  const clearance=enemies.length?Math.min(...enemies.map(e=>dist(point,e))):300,crowd=enemies.filter(e=>dist(point,e)<190).length,crossing=enemies.filter(e=>distanceToSegment(e,u,point)<50*unitScale(e)).length;
  candidates.push({point,score:clearance-crowd*170-crossing*100-battleAreaRisk(u,point,areas).total*130+random(-10,10)});
 }
 candidates.sort((a,b)=>b.score-a.score);const point=candidates[0]?.point??{x:clamp(800-u.x,38,762),y:clamp(800-u.y,38,762)},distance=dist(u,point)||1;
 refillMachineGun(u);u.machineGunDash={dx:(point.x-u.x)/distance,dy:(point.y-u.y)/distance,remaining:distance,speed:850,trailClock:0};u.ai.response=null;u.dodgeState=null;u.evadeTime=0;u.headingX=u.headingY=u.vx=u.vy=u.kx=u.ky=0;u.action='빠른 장전 · 탈출 대시';
}
function advanceMachineGunDash(u,dt){
 const dash=u.machineGunDash;if(!dash)return false;if(u.hp<=0||u.stun>0||duelLocked(u)){u.machineGunDash=null;return false;}
 const before={x:u.x,y:u.y},step=Math.min(dash.remaining,dash.speed*dt);u.x=clamp(u.x+dash.dx*step,28,772);u.y=clamp(u.y+dash.dy*step,28,772);dash.remaining-=dist(before,u);u.vx=(u.x-before.x)/dt;u.vy=(u.y-before.y)/dt;u.headingX=u.headingY=0;u.face=Math.atan2(dash.dy,dash.dx);u.action='빠른 장전 · 탈출 대시';dash.trailClock+=dt;
 if(dash.trailClock>=.025){dash.trailClock=0;fx('afterimage',before.x,before.y,'#eddca7',.1,{tx:u.x,ty:u.y,type:u.type,ownerId:u.id});}
 if(dash.remaining<1||dist(before,u)<.01){u.machineGunDash=null;u.ai.disengageUntil=elapsed+.2;}return true;
}
function renderMachineGunWeapon(u,a,p){
 const loading=u.reloadRemaining>0,active=a?.phase==='active',recoil=active?Math.sin(a.t/MACHINE_GUN.interval*Math.PI*2)*4:0;ctx.translate(20-recoil,13);if(loading)ctx.rotate(-.55+Math.sin(elapsed*7)*.07);else if(a?.phase==='windup')ctx.rotate(-.12*(1-p));
 ctx.fillStyle='#735b3e';ctx.fillRect(-13,-8,21,17);ctx.fillStyle='#39413e';ctx.fillRect(5,-11,31,22);ctx.fillStyle='#9fa79b';ctx.fillRect(8,-9,32,5);ctx.fillStyle='#222e2a';ctx.fillRect(34,-7,34,13);ctx.fillStyle='#bec6b5';ctx.fillRect(36,-7,32,3);ctx.fillStyle='#6c7767';for(let i=0;i<5;i++)ctx.fillRect(39+i*5,-3,2,7);ctx.fillStyle='#ddb975';for(let i=0;i<4;i++)ctx.fillRect(14+i*6,12,4,7);ctx.fillStyle='#3e473c';ctx.fillRect(5,12,10,15);ctx.fillRect(56,-12,4,5);
 if(loading){const shift=Math.sin(elapsed*8)*6;ctx.fillStyle='#d5b68b';ctx.fillRect(7+shift,17,7,10);}else if(active){pixelSprite(72,0,'#fff1bd',.7,'star',.7);bladeStreak(70,0,0,30,6,'#ffe2a2',.65);}
}
function renderMachineGunUnit(u){for(let i=0;i<20;i++)texel(u.x-29+i*3,u.y+40,2,i<u.ammo?'#d9c183':'#39463b',.9);if(u.reloadRemaining>0){ctx.fillStyle='#d5b981';ctx.fillRect(u.x-29,u.y+45,58*(1-u.reloadRemaining/4),3);}}
let duels=[],duelSerial=0;
function resetArchetypes(){duels=[];duelSerial=0;}
function duelFor(u){return u.duelId==null?null:duels.find(d=>d.id===u.duelId)??null;}
function duelLocked(u){return !!duelFor(u);}
function cancelDuel(d){for(const id of [d.masterId,d.targetId]){const u=units.find(v=>v.id===id);if(u){u.duelId=null;u.cooldown=Math.max(u.cooldown,.8);u.headingX=u.headingY=0;u.action=u.hp>0?'승부 후 재정비':'전투 불능';}}duels=duels.filter(v=>v!==d);}
function cancelAllDuels(){for(const d of [...duels])cancelDuel(d);}
function outsideDuelFactor(target,source){const d=duelFor(target);return d&&source.id!==d.masterId&&source.id!==d.targetId?(target.id===d.masterId?.2:.35):1;}
function archetypeStatus(u){if(u.hp<=0)return '전투 불능';if(duelLocked(u))return '가위바위보 진행 중';if(u.type===6)return u.attack?.phase==='windup'?(u.attack.t<2?'장전 ':'조준 ')+(5-u.attack.t).toFixed(1)+'초':u.sniperBurstReady?'삼연발 사격 준비':'관통 저격 준비';if(u.type===7)return u.reloadRemaining>0?'재장전 '+u.reloadRemaining.toFixed(1)+'초':'탄창 '+u.ammo+' / 2';if(u.type===9)return '연속펀치';return '완료 '+u.duelRounds+'판 · '+(3-u.duelRounds%3)+'판 후 확정 승리';}
function tickArchetype(u,dt){if(u.stun>0)return;if(u.type===23){tickMachineGun(u,dt);return;}if(u.type===7&&u.reloadRemaining>0){u.reloadRemaining=Math.max(0,u.reloadRemaining-dt);if(u.reloadRemaining===0){u.ammo=2;u.ai.shotDecisionAt=null;u.ai.disengageUntil=0;u.ai.mode='approach';burst(u.x,u.y,'#ffe2a5',12,110,.6,u.face);}}}
function cornerGoal(u,enemies,allies){const corners=[{x:65,y:65},{x:735,y:65},{x:65,y:735},{x:735,y:735}];const score=p=>{const safe=enemies.length?Math.min(...enemies.map(e=>dist(p,e))):450;const nearby=enemies.filter(e=>dist(p,e)<240).length;return safe-nearby*180-dist(u,p)*.12-allies.filter(a=>dist(a,p)<65).length*45;};return corners.sort((a,b)=>score(b)-score(a))[0];}
function steerArchetype(u,mx,my,dt,factor=1){if(u.type===18){steerTank(u,mx,my,dt,factor);return;}for(const v of alive()){if(v.id===u.id||!canPerceive(u,v))continue;const d=dist(u,v);if(d<56){const a=d>.01?Math.atan2(u.y-v.y,u.x-v.x):u.id<v.id?0:Math.PI;mx+=Math.cos(a)*(56-d)/25;my+=Math.sin(a)*(56-d)/25;}}
 const wall=55;if(u.x<wall)mx+=(wall-u.x)/wall;if(u.x>800-wall)mx-=(u.x-800+wall)/wall;if(u.y<wall)my+=(wall-u.y)/wall;if(u.y>800-wall)my-=(u.y-800+wall)/wall;
 const len=Math.hypot(mx,my);if(len>1){mx/=len;my/=len;}blendHeading(u,mx,my,dt,8);const x=u.x,y=u.y;u.x=clamp(x+u.headingX*u.moveSpeed*factor*dt,28,772);u.y=clamp(y+u.headingY*u.moveSpeed*factor*dt,28,772);u.vx=(u.x-x)/dt;u.vy=(u.y-y)/dt;}
function moveArchetype(u,target,enemies,allies,dt){if(duelLocked(u))return;if(u.type===8&&u.attack?.kind==='grapple')return;if(u.type===6&&u.attack){u.vx=u.vy=u.headingX=u.headingY=0;u.action=u.attack.phase==='windup'?(u.attack.t<2?'저격 장전':'저격 조준'):'저격 발사';return;}
 const b=u.ai;let mx=0,my=0,factor=1;const toward=(p,w=1)=>{const d=dist(u,p)||1;mx+=(p.x-u.x)/d*w;my+=(p.y-u.y)/d*w;};
 if(u.type===6){b.cornerClock=(b.cornerClock??0)-dt;const close=enemies.some(e=>dist(u,e)<180);if(!b.corner||b.cornerClock<=0){b.corner=cornerGoal(u,enemies,allies);b.cornerClock=random(.8,1.4);}if(dist(u,b.corner)>22)toward(b.corner);if(close){for(const e of enemies){const d=dist(u,e);if(d<180){mx+=(u.x-e.x)/(d||1)*.9;my+=(u.y-e.y)/(d||1)*.9;}}factor=1.12;}u.action=close?'안전한 구석으로 도주':'은둔 위치 확보';}
 else if(target){const d=dist(u,target)||1,dx=(target.x-u.x)/d,dy=(target.y-u.y)/d,side=b.side,sway=Math.sin(elapsed*2.3+b.phase)*.4;
 if(u.type===7){const reload=u.reloadRemaining>0,radial=reload?(d<300?-1:.1):(d>75?1:d<48?-.25:.2);mx=dx*radial-dy*(side*.45+sway);my=dy*radial+dx*(side*.45+sway);u.action=reload?'재장전 · 거리 벌리기':'더블배럴 돌격';if(u.attack){factor=.45;u.action=u.attack.phase==='windup'?'산탄 준비':'발사 반동';}}
 else{const radial=clamp((d-155)/90,-.6,.8);mx=dx*radial-dy*side*.7;my=dy*radial+dx*side*.7;b.hold-=dt;if(b.hold<=0){b.side*=-1;b.hold=random(.6,1.5);}u.action='대치 · 승부 상대 탐색';}
 const incoming=projectileThreat(u);if(incoming&&!u.attack&&incoming.time<b.reaction){const n=Math.hypot(incoming.p.vx,incoming.p.vy)||1;mx=mx*.3-incoming.p.vy/n*side;my=my*.3+incoming.p.vx/n*side;u.action='탄도 확인 · 측면 이동';}}
 else{toward(b.goal,.7);if(dist(u,b.goal)<45)b.goal={x:random(85,715),y:random(85,715)};u.action='주변 탐색';}
 steerArchetype(u,mx,my,dt,factor);
}
function archetypeAllowsAttack(u,target){if(duelLocked(u)||!canPerceive(u,target))return false;if(u.type===6)return !u.ai.corner||dist(u,u.ai.corner)<65||(elapsed-u.ai.lastAttack>9&&dist(u,target)>180);if(u.type===7){if(u.ammo<=0||u.reloadRemaining>0||dist(u,target)>140&&elapsed-u.ai.lastAttack<8)return false;if(u.ai.shotDecisionAt==null)u.ai.shotDecisionAt=elapsed+random(.08,.4);return elapsed>=u.ai.shotDecisionAt;}return !duelLocked(target)&&target.invincible<=0;}
function gunProjectile(u,angle,kind,damage,velocity,life,hidden){projectiles.push({x:u.x+Math.cos(angle)*43,y:u.y+Math.sin(angle)*43,vx:Math.cos(angle)*velocity,vy:Math.sin(angle)*velocity,source:u,color:u.color,damage,power:damage,life,type:u.type,kind,trail:[],visualScale:unitScale(u),radius:(kind==='sniper'?25:22)*unitScale(u),impulse:kind==='sniper'?350:115,hitIds:kind==='sniper'?new Set():undefined,piercing:kind==='sniper',bouncesRemaining:0,homing:false,guaranteed:false,hiddenLaunch:hidden,start:{x:u.x,y:u.y}});}
const SNIPER_NORMAL_SPREAD=Math.PI/72,SNIPER_BURST_SPREAD=.018;
function fireSniperRound(u,a){const spread=u.sniperBurstReady||a.burstRemaining>0?SNIPER_BURST_SPREAD:SNIPER_NORMAL_SPREAD,angle=a.angle+random(-spread,spread);gunProjectile(u,angle,'sniper',u.dmg,4700,.45,a.hiddenLaunch);u.kx-=Math.cos(angle)*230;u.ky-=Math.sin(angle)*230;fx('gunFlash',u.x+Math.cos(angle)*56,u.y+Math.sin(angle)*56,'#ffe3ac',.18,{angle,r:95});impactPause(2.5,angle);}
function fireArchetype(u,a){if(u.type===6){fireSniperRound(u,a);if(u.sniperBurstReady){u.sniperBurstReady=false;a.burstRemaining=2;a.nextBurst=.16;a.profile.active=.5;}addLog(`${u.name} · 대구경 관통 사격`);} else{if(u.ammo<=0||u.reloadRemaining>0)return;u.ai.shotDecisionAt=null;u.ammo--;u.shotsFired++;for(let i=0;i<7;i++)gunProjectile(u,a.angle+(i-3)*.125+random(-.012,.012),'pellet',u.dmg,720,.46,a.hiddenLaunch);u.kx-=Math.cos(a.angle)*340;u.ky-=Math.sin(a.angle)*340;fx('gunFlash',u.x+Math.cos(a.angle)*48,u.y+Math.sin(a.angle)*48,'#ffd58c',.16,{angle:a.angle,r:80});burst(u.x,u.y,'#ffd490',45,380,1.1,a.angle);impactPause(1.8,a.angle);if(u.ammo===0){u.reloadRemaining=4;addLog(`${u.name} · 탄창 비움 · 4초 재장전`);}}
}
function trySniperRepel(target,source,options={}){if(target.stun>0||target.type!==6||!options.melee||dist(target,source)>125||!canSeeAttack(target,source,options.attackOrigin??source,options.hiddenLaunch)||Math.random()>=.3)return null;const angle=Math.atan2(source.y-target.y,source.x-target.x);applyKnockback(source,Math.cos(angle)*980,Math.sin(angle)*980,target);stunParryEnemy(source,.24);target.attack=null;target.cooldown=Math.min(target.cooldown,.6);target.defensePose=.4;target.defenseLabel='밀쳐내기';target.ai.cornerClock=0;fx('repel',target.x,target.y,target.color,.25,{angle,r:105});burst(source.x,source.y,'#ffe5ad',65,580,1.2,angle);impactPause(2.4,angle);return{damage:0,defended:true,kind:'repel'};}
function startGrapple(u,ultimate=false){if(u.hp<=0||u.stun>0)return false;const candidates=alive().filter(v=>v.faction!==u.faction&&canPerceive(u,v)&&!duelLocked(v)&&v.invincible<=0&&dist(u,v)<230*unitScale(u));if(!candidates.length)return false;const target=candidates[Math.floor(Math.random()*candidates.length)];u.attack={kind:'grapple',ultimate,targetId:target.id,phase:'windup',t:0,angle:Math.atan2(target.y-u.y,target.x-u.x),profile:{...ATTACK_PROFILES[8]},serial:++u.attackSerial,hiddenLaunch:false};consumeAttackIntent(u);u.cooldown=2.5;u.revealTime=3;u.action='붙잡기 준비';return true;}
function advanceGrapple(u,dt){const a=u.attack;if(!a||a.kind!=='grapple')return;if(u.stun>0||u.hp<=0){u.attack=null;return;}const target=units.find(v=>v.id===a.targetId&&v.hp>0);if(!target||!canPerceive(u,target)||duelLocked(target)||target.invincible>0){u.attack=null;u.cooldown=.8;return;}a.t+=dt;const d=dist(u,target)||1;a.angle=Math.atan2(target.y-u.y,target.x-u.x);u.face=a.angle;u.vx=u.vy=u.headingX=u.headingY=0;if(a.t<.4){u.action='붙잡기 준비';return;}a.phase='active';u.action='승부 상대에게 급습';if(!a.fist){a.fist=spawnMeleeStrike(u,{...a,profile:{reach:58,cone:.25,active:1.25,impulse:0}},0);a.fist.power=20;a.fist.grappleTarget=target.id;a.fist.duelUltimate=a.ultimate;}a.fist.angle=a.angle;if(a.t>1.6){u.attack=null;u.cooldown=1.2;u.ai.lastAttack=elapsed;return;}const grabDistance=Math.max(12,54*unitScale(u)+27*(unitScale(target)-1));if(d<=grabDistance)return;const move=Math.min(d-grabDistance,320*dt);u.x=clamp(u.x+(target.x-u.x)/d*move,28,772);u.y=clamp(u.y+(target.y-u.y)/d*move,28,772);if(a.t>1.6){u.attack=null;u.cooldown=1.2;u.ai.lastAttack=elapsed;}}
function beginDuel(master,target,ultimate=false){if(heroRescuing(master)||heroRescuing(target)||heroRescueProtected(target)||master.hp<=0||target.hp<=0||master.stun>0||target.stun>0||duelLocked(master)||duelLocked(target)||master.faction===target.faction)return false;const d={id:++duelSerial,masterId:master.id,targetId:target.id,ultimate,damageFraction:ultimate?.5:.35,t:0,duration:2.2,resolved:false,mSign:0,tSign:0,result:null};duels.push(d);for(const u of [master,target]){u.duelId=d.id;u.attack=null;u.ultCast=null;u.evadeTime=0;u.kx=u.ky=u.vx=u.vy=u.headingX=u.headingY=0;u.revealTime=3;u.action='가위바위보 진행';}master.ai.lastAttack=elapsed;target.face=master.face+Math.PI;addLog(`${master.name} · ${target.name} 붙잡고 가위바위보`);return true;}
function resolveDuel(d){if(d.resolved)return;const m=units.find(u=>u.id===d.masterId),t=units.find(u=>u.id===d.targetId);if(!m||!t||m.hp<=0||t.hp<=0||m.stun>0||t.stun>0){cancelDuel(d);return;}d.resolved=true;m.duelRounds++;if(t.type===8)t.duelRounds++;const forceM=m.duelRounds%3===0,forceT=t.type===8&&t.duelRounds%3===0;d.mSign=Math.floor(Math.random()*3);d.tSign=Math.floor(Math.random()*3);if(forceM&&!forceT)d.mSign=(d.tSign+1)%3;if(forceT&&!forceM)d.tSign=(d.mSign+1)%3;
 const outcome=forceM&&forceT?'both':d.mSign===d.tSign?'draw':(d.mSign-d.tSign+3)%3===1?'master':'target';d.result=outcome;if(outcome==='draw'){addLog('가위바위보 · 무승부');return;}const winners=outcome==='both'?[m,t]:[outcome==='master'?m:t],loser=outcome==='master'?t:outcome==='target'?m:null;for(const w of winners){restoreCombatHp(w,w.maxHp*.05,w);fx('heal',w.x,w.y,'#a8ffd0',.38,{r:70});burst(w.x,w.y,'#a8ffd0',25,170,.5,-Math.PI/2,'mote');}if(loser)hit(loser,loser.maxHp*(d.damageFraction??.35),winners[0],{duelResult:true,impulse:0});addLog(`가위바위보 · ${winners.map(u=>u.name).join(' / ')} 승리${forceM||forceT?' · 숙련자':''}`);}
function advanceDuels(dt){for(const d of [...duels]){const m=units.find(u=>u.id===d.masterId),t=units.find(u=>u.id===d.targetId);if(!m||!t||m.hp<=0||t.hp<=0||m.stun>0||t.stun>0){cancelDuel(d);continue;}d.t+=dt;if(!d.resolved&&d.t>=1.7)resolveDuel(d);if(d.t>=d.duration)cancelDuel(d);}}
function renderArchetypeUnit(u){if(u.type===23){renderMachineGunUnit(u);return;}if(u.type===6&&u.attack?.phase==='windup'){const a=u.attack,p=a.t/5;if(a.t>=2){ctx.save();ctx.strokeStyle=p>.9?'#ffe6b3':'#b9835d';ctx.globalAlpha*=.18+p*.35;ctx.lineWidth=p>.9?3:1;ctx.setLineDash(p>.9?[]:[8,8]);ctx.beginPath();ctx.moveTo(u.x+Math.cos(a.angle)*48,u.y+Math.sin(a.angle)*48);ctx.lineTo(u.x+Math.cos(a.angle)*1200,u.y+Math.sin(a.angle)*1200);ctx.stroke();ctx.restore();}for(let i=0;i<10;i++)texel(u.x-25+i*5,u.y-55,4,i<p*10?'#ffd69a':'#3d4038',.8);}
 if(u.type===7){for(let i=0;i<2;i++){ctx.fillStyle=i<u.ammo?'#ffe0a4':'#56483b';ctx.fillRect(u.x-11+i*13,u.y-56,8,5);}if(u.reloadRemaining>0){const p=1-u.reloadRemaining/4;slashStroke(u.x,u.y,37,-Math.PI/2,-Math.PI/2+p*Math.PI*2,'#e4bc73',5,.7);}}
}
function renderDuels(){for(const d of duels){const m=units.find(u=>u.id===d.masterId),t=units.find(u=>u.id===d.targetId);if(!m||!t||m.hp<=0||t.hp<=0||m.stun>0||t.stun>0)continue;pixelBeam(m.x,m.y,t.x,t.y,'#efb1de',5,.65);const phase=Math.floor(d.t*7),ms=d.resolved?d.mSign:phase%3,ts=d.resolved?d.tSign:(phase+1)%3;for(const [u,sign,won] of [[m,ms,d.result==='master'||d.result==='both'],[t,ts,d.result==='target'||d.result==='both']]){circle(u.x,u.y-76,24,won?'#715632':'#382d43');circle(u.x,u.y-76,24,won?'#ffe196':'#d5a8e7',false,2);renderEmoji(TYPES.length+sign,u.x,u.y-76,38);}}}
function renderArchetypeWeapon(u,a,p){if(u.type===25){renderPuppetWeapon(u,a,p);return;}if(u.type===24){renderFrogWeapon(u,a,p);return;}if(u.type===23){renderMachineGunWeapon(u,a,p);return;}if(u.type===22){renderGalaxyWeapon(u,a,p);return;}if(u.type===21){renderMirrorWeapon(u,a,p);return;}if(u.type===19){renderFanaticWeapon(u,a,p);return;}if(u.type===20){renderLightningWeapon(u,a,p);return;}if(u.type===17){renderHeroWeapon(u,a,p);return;}if(u.type===18){renderTankWeapon(u,a,p);return;}if(u.type===16){renderPaladinWeapon(u,a,p);return;}if(u.type===14){renderSwordsmanWeapon(u,a,p);return;}if(u.type===15){renderSatelliteWeapon(u,a,p);return;}if(u.type===13){renderBombWeapon(u,a,p);return;}if(u.type===12){renderPredatorJaw(u,a,p);return;}if(u.type===10){renderGreatSwordWeapon(u,a,p);return;}if(u.type===11)return;if(u.type===9){renderPunchWeapon(u,a,p);return;}if(u.type===8){ctx.save();ctx.translate(a?.kind==='grapple'?35-p*12:32,14);ctx.rotate(a?.kind==='grapple'?-.4:0);renderEmoji(8,0,0,28);ctx.restore();return;}
 const sniper=u.type===6,loading=sniper?(a?.phase==='windup'&&a.t<2):u.reloadRemaining>0;ctx.translate(20,12);if(loading)ctx.rotate(-.45+(u.stun>0?0:Math.sin(elapsed*9)*.06));ctx.fillStyle='#826044';ctx.fillRect(-8,-8,23,16);ctx.fillStyle='#263237';ctx.fillRect(8,-9,sniper?56:38,18);ctx.fillStyle='#bac8c1';ctx.fillRect(15,-7,sniper?58:38,5);if(!sniper)ctx.fillRect(15,3,38,5);if(sniper){ctx.fillStyle='#c0d0cc';ctx.fillRect(25,-17,23,6);ctx.fillStyle='#ecba71';ctx.fillRect(34,-11,5,8);ctx.fillRect(74,-4,9,5);}else{ctx.fillStyle='#6e5340';ctx.fillRect(4,6,14,12);ctx.fillStyle='#f0ca83';ctx.fillRect(47,-8,6,16);}if(loading){const n=Math.sin(elapsed*8)*7;ctx.fillStyle='#ffd29a';ctx.fillRect(11+n,12,5,10);pixelSprite(17+n,9,u.color,1,'metal',.7);}if(a?.phase==='active'){bladeStreak(sniper?83:53,0,0,sniper?82:58,16,'#fff0c7',1-p);}}

function startPunchCombo(u,target){if(!target||target.hp<=0||u.hp<=0||u.attack||u.ultCast||u.stun>0||duelLocked(u))return false;const profile={...ATTACK_PROFILES[9]};u.attack={kind:'punchCombo',targetId:target.id,phase:'windup',t:0,angle:Math.atan2(target.y-u.y,target.x-u.x),profile,punch:0,serial:++u.attackSerial,hiddenLaunch:isConcealed(u)};consumeAttackIntent(u);u.cooldown=1.2+u.cd*random(.3,.55);u.revealTime=3;u.action='연속펀치 준비';return true;}
function advancePunchCombo(u,dt){const a=u.attack;if(!a||a.kind!=='punchCombo')return;if(u.hp<=0||u.stun>0){u.attack=null;return;}a.t+=dt;const target=units.find(v=>v.id===a.targetId&&v.hp>0&&canPerceive(u,v));if(a.phase==='windup'){if(target&&a.t<a.profile.windup*.75)a.angle+=angleDelta(Math.atan2(target.y-u.y,target.x-u.x),a.angle)*Math.min(1,dt*13);u.face=a.angle;if(a.t>=a.profile.windup){a.t=0;a.phase='active';const last=a.punch===2,profile={...a.profile,impulse:last?570:95};const fist=spawnMeleeStrike(u,{...a,profile},u.dmg*(last?1.35:1));fist.punch=true;fist.finisher=last;u.kx+=Math.cos(a.angle)*(last?140:70);u.ky+=Math.sin(a.angle)*(last?140:70);u.ai.lastAttack=elapsed;u.action=last?'마무리 펀치':'연속펀치';burst(u.x+Math.cos(a.angle)*65,u.y+Math.sin(a.angle)*65,u.color,last?32:14,last?260:160,.5,a.angle);}}
else if(a.phase==='active'&&a.t>=a.profile.active){a.phase='recovery';a.t=0;}else if(a.phase==='recovery'&&a.t>=a.profile.recovery){if(a.punch<2){a.punch++;a.t=0;a.phase='windup';a.profile.windup=.12;u.action='다음 펀치 준비';}else{u.attack=null;u.ai.disengageUntil=elapsed+random(.35,.7);u.ai.mode='retreat';u.action='펀치 후 간격 조절';}}}
function renderPunchWeapon(u,a,p){const combo=a?.kind==='punchCombo',hand=combo?a.punch%2:0,extension=combo?(a.phase==='windup'?-p*10:a.phase==='active'?Math.sin(p*Math.PI)*34:10*(1-p)):0;for(let i=0;i<2;i++){ctx.save();ctx.translate(25+(i===hand?extension:0),i===0?-19:19);ctx.rotate(i===0?-.18:.18);renderEmoji(9,0,0,combo&&a.punch===2&&i===hand?34:27);ctx.restore();}}
function ringTarget(u,enemies){return enemies.map(e=>({e,n:enemies.filter(v=>dist(v,e)<240).length,d:dist(u,e)})).sort((a,b)=>b.n-a.n||a.d-b.d)[0]?.e;}
function advanceRingRush(u,a,dt){if(!a.dashing){a.dashing=true;a.dashTime=0;a.dashHits=new Set();u.action='링 돌진';}a.dashTime+=dt;const from={x:u.x,y:u.y},d=dist(u,a.point)||1,move=Math.min(d,680*dt);u.x=clamp(u.x+(a.point.x-u.x)/d*move,28,772);u.y=clamp(u.y+(a.point.y-u.y)/d*move,28,772);u.kx=u.ky=0;u.vx=(u.x-from.x)/dt;u.vy=(u.y-from.y)/dt;u.face=Math.atan2(a.point.y-from.y,a.point.x-from.x);a.angle=u.face;fx('afterimage',from.x,from.y,u.color,.1,{tx:u.x,ty:u.y,type:u.type,ownerId:u.id});for(const v of alive()){if(frogUnavailable(v)||v.faction===u.faction||v.invincible>0)continue;const range=dist(u,v);if(!a.dashHits.has(v.id)&&distanceToSegment(v,from,u)<105){a.dashHits.add(v.id);hit(v,22,u,{impulse:0,attackOrigin:u});if(v.hp>0&&!duelLocked(v)&&!basicParryPerfect(v)){const angle=Math.atan2(u.y-v.y,u.x-v.x);applyKnockback(v,Math.cos(angle)*400,Math.sin(angle)*400,u);fx('repel',v.x,v.y,u.color,.2,{angle,r:70});}}if(range<230&&!duelLocked(v)&&!basicParryPerfect(v)){const pull=170*(1-range/230)*dt;v.x=clamp(v.x+(u.x-v.x)/(range||1)*pull,28,772);v.y=clamp(v.y+(u.y-v.y)/(range||1)*pull,28,772);}}
return dist(u,a.point)<12||a.dashTime>=.8;}
function createRing(u){ultimateZones.push({kind:'ring',source:u,x:u.x,y:u.y,r:150*unitScale(u),life:10,max:10,tick:0,pulse:0,contacts:new Map(),positions:new Map()});impact(u.x,u.y,u.color,2.8,u.face);addLog(`${u.name} · 10초 링 생성`);}
function advanceRingZone(z,dt){for(const [id,time] of z.contacts)z.contacts.set(id,Math.max(0,time-dt));for(const v of alive()){if(frogUnavailable(v)||v.faction===z.source.faction)continue;const dx=v.x-z.x,dy=v.y-z.y,edge=Math.max(Math.abs(dx),Math.abs(dy)),previous=z.positions.get(v.id),crossed=previous!=null&&((previous<z.r&&edge>=z.r)||(previous>z.r&&edge<=z.r)),touch=Math.abs(edge-z.r)<27||crossed;z.positions.set(v.id,edge);if(!touch||z.contacts.get(v.id)>0||v.invincible>0)continue;z.contacts.set(v.id,.6);const angle=Math.atan2(-dy,-dx),result=hit(v,14,z.source,{angle,impulse:650,attackOrigin:{x:v.x-Math.cos(angle)*35,y:v.y-Math.sin(angle)*35}});if(result.damage>0&&v.hp>0&&!duelLocked(v)){// The ropes apply inward momentum; they never snap a unit to a new position.
impact(v.x,v.y,'#ffe1b1',2,angle,true);}}}
function renderRingZone(z){const alpha=Math.min(1,z.life)*ctx.globalAlpha,r=z.r;ctx.save();ctx.globalAlpha=alpha;ctx.fillStyle='#ddb587';ctx.globalAlpha*=.055;ctx.fillRect(z.x-r,z.y-r,r*2,r*2);ctx.globalAlpha=alpha;const corners=[[-1,-1],[1,-1],[1,1],[-1,1]];for(let layer=0;layer<3;layer++){const inset=layer*5;ctx.strokeStyle=layer===0?'#f7d6aa':layer===1?'#e07a5b':'#5c83bc';ctx.lineWidth=layer===0?4:3;ctx.strokeRect(z.x-r+inset,z.y-r+inset,(r-inset)*2,(r-inset)*2);}for(const [x,y] of corners){ctx.fillStyle='#553b31';ctx.fillRect(z.x+x*r-9,z.y+y*r-9,18,18);ctx.fillStyle='#f2d1a0';ctx.fillRect(z.x+x*r-6,z.y+y*r-6,12,12);ctx.fillStyle='#fff0d1';ctx.fillRect(z.x+x*r-4,z.y+y*r-4,5,5);}for(let i=0;i<4;i++){const a=i*Math.PI/2+Math.PI/4;bladeStreak(z.x+Math.cos(a)*26,z.y+Math.sin(a)*26,a,18,5,'#f5ce9e',.35);}ctx.restore();}


// Champion weapons use the same preparation, physical contacts and interruption rules.
function paladinAuraFactor(u){return u.type===16?1+.05*alive().filter(v=>v.id!==u.id&&v.faction===u.faction&&dist(u,v)<200).length:1;}
function championAttackFactor(u){return (u.type===3&&u.shadowTime>0?.8:1)*faithAttackFactor(u)*(u.type===14&&!alive().some(v=>v.id!==u.id&&v.faction===u.faction&&dist(u,v)<180)?1.3:1)*paladinAuraFactor(u);}
function onChampionDamage(u,actual){
 if(actual<=0)return;
 if(u.type===14&&u.attack?.kind==='slashCombo'){u.attack=null;for(const s of meleeStrikes)if(s.source===u&&!s.ultimate)s.life=0;u.cooldown=Math.max(u.cooldown,.65);u.ai.disengageUntil=elapsed+random(.35,.8);u.action='연속 베기 중단';}
 if(u.type===15&&u.hp>0){u.satelliteBursts??=[];u.satelliteBursts.push({remaining:.16,damage:u.dmg*.2});fx('charge',u.x,u.y,u.color,.16,{r:45,unitId:u.id});}
}
function startSlashCombo(u,target){
 if(!target||target.hp<=0||u.hp<=0||u.attack||u.ultCast||u.stun>0||duelLocked(u))return false;
 u.attack={kind:'slashCombo',targetId:target.id,phase:'windup',t:0,angle:Math.atan2(target.y-u.y,target.x-u.x),profile:{...ATTACK_PROFILES[14]},slash:0,fired:false,serial:++u.attackSerial,hiddenLaunch:isConcealed(u)};
 consumeAttackIntent(u);u.cooldown=2.1+u.cd*random(.35,.65);u.revealTime=3;u.action='연속 베기 준비';return true;
}
function advanceSlashCombo(u,dt){
 const a=u.attack;if(!a||a.kind!=='slashCombo')return;if(u.hp<=0||u.stun>0){u.attack=null;return;}a.t+=dt*attackRate(u);
 const target=units.find(v=>v.id===a.targetId&&v.hp>0&&canPerceive(u,v));
 if(a.phase==='windup'){
  if(target&&a.t<a.profile.windup*.7)a.angle+=angleDelta(Math.atan2(target.y-u.y,target.x-u.x),a.angle)*Math.min(1,dt*10);u.face=a.angle;
  if(a.t>=a.profile.windup){a.phase='active';a.fired=true;a.t=0;const final=a.slash===2,s=spawnMeleeStrike(u,a,u.dmg*(final?3:a.slash===1?1.1:1));s.swordCombo=true;s.finisher=final;u.ai.lastAttack=elapsed;u.action=final?'회전 마무리':'전진 베기';burst(u.x+Math.cos(a.angle)*70,u.y+Math.sin(a.angle)*70,final?'#e5faff':u.color,final?36:18,final?350:200,.7,a.angle);if(final)impactPause(2.3,a.angle);}
 }else if(a.phase==='active'){
  const from={x:u.x,y:u.y},move=Math.min(dt,Math.max(0,a.profile.active-(a.t-dt)))*(a.slash===2?100:210);u.x=clamp(u.x+Math.cos(a.angle)*move,28,772);u.y=clamp(u.y+Math.sin(a.angle)*move,28,772);u.vx=(u.x-from.x)/dt;u.vy=(u.y-from.y)/dt;
  if(move>0)fx('afterimage',from.x,from.y,u.color,.1,{tx:u.x,ty:u.y,type:u.type,ownerId:u.id});if(a.t>=a.profile.active){a.phase='recovery';a.t=0;}
 }else if(a.t>=a.profile.recovery){
  if(a.slash<2){const slash=a.slash+1;u.attack={...a,slash,phase:'windup',t:0,fired:false,serial:++u.attackSerial,profile:{...ATTACK_PROFILES[14],windup:slash===2?.36:.2,active:slash===2?.24:.22,reach:slash===2?205:122,cone:slash===2?Math.PI:1.4,impulse:slash===2?450:110}};u.action='다음 베기 준비';}
  else{u.attack=null;u.ai.commitUntil=0;u.ai.disengageUntil=elapsed+random(.45,.9);u.ai.mode='retreat';u.action='베기 후 이탈';}
 }
}
const BLADE_DASH_SPEED=2200;
function isBladeDashing(u){return u.type===14&&u.hp>0&&u.stun<=0&&u.ultCast?.dashing===true;}
function advanceBladeDash(u,a,dt){
 const step=a.dashing?dt:Math.min(dt,Math.max(0,a.t-a.duration));
 if(!a.dashing){
  const target=units.find(v=>v.id===a.targetId&&v.hp>0&&canPerceive(u,v)),point=target??a.point;
  a.angle=Math.atan2(point.y-u.y,point.x-u.x);const dx=Math.cos(a.angle),dy=Math.sin(a.angle);let length=Math.max(300,dist(u,point)+150);
  // Aim beyond the last visible opponent aligned with the locked dash, rather than stopping at the first body.
  for(const enemy of alive()){if(enemy.faction===u.faction||!canPerceive(u,enemy))continue;const x=enemy.x-u.x,y=enemy.y-u.y,along=x*dx+y*dy,side=Math.abs(x*dy-y*dx);if(along>0&&along<620&&side<95*unitScale(u)+27*unitScale(enemy))length=Math.max(length,along+27*unitScale(enemy)+100);}
  const wallX=Math.abs(dx)<1e-8?Infinity:((dx>0?772:28)-u.x)/dx,wallY=Math.abs(dy)<1e-8?Infinity:((dy>0?772:28)-u.y)/dy;
  a.remaining=Math.max(0,Math.min(650,length,wallX,wallY));a.dashDistance=a.remaining;a.dashOrigin={x:u.x,y:u.y};a.dashEnd={x:u.x+dx*a.remaining,y:u.y+dy*a.remaining};a.dashing=true;a.phase='dash';a.dashHits=new Set();u.kx=u.ky=u.headingX=u.headingY=0;
 }
 const from={x:u.x,y:u.y},move=Math.min(a.remaining,BLADE_DASH_SPEED*step);u.x=clamp(u.x+Math.cos(a.angle)*move,28,772);u.y=clamp(u.y+Math.sin(a.angle)*move,28,772);a.remaining=Math.max(0,a.remaining-dist(from,u));u.face=a.angle;u.vx=dt>0?(u.x-from.x)/dt:0;u.vy=dt>0?(u.y-from.y)/dt:0;u.headingX=u.headingY=0;u.action='일섬 · 관통 대시';
 if(move>0)fx('afterimage',from.x,from.y,'#e3faff',.12,{tx:u.x,ty:u.y,type:u.type,ownerId:u.id});
 // Fractional windup overshoot can be almost zero: only a meaningful blocked move ends transit.
 if(a.remaining>.001&&!(move>.001&&dist(from,u)<.001))return false;
 a.dashing=false;a.phase='slash';a.dashEnd={x:u.x,y:u.y};releaseBladePath(u,a);return true;
}
function releaseBladePath(u,a){
 const strike=spawnMeleeStrike(u,{...a,serial:++u.attackSerial,profile:{reach:115,cone:0,active:.1,impulse:540},hiddenLaunch:false},u.dmg*3.6,true);
 strike.dashSlash=true;strike.dashOrigin={...a.dashOrigin};strike.dashEnd={...a.dashEnd};strike.pathWidth=95*unitScale(u);strike.hitIds=a.dashHits??new Set();
 fx('issenCut',strike.dashOrigin.x,strike.dashOrigin.y,'#c7f3ff',.36,{tx:strike.dashEnd.x,ty:strike.dashEnd.y,width:strike.pathWidth});impactPause(3.2,a.angle);u.action='일섬 · 경로 참격';
}
function crowdControlRemaining(v){
 const duel=duelFor(v);let remaining=Math.max(v.stun??0,duel?Math.max(0,duel.duration-duel.t):0,Math.max(0,(v.tauntedUntil??0)-elapsed));
 for(const z of ultimateZones)if(z.kind==='blackhole'&&z.source.faction!==v.faction&&dist(z,v)<z.r&&v.invincible<=0)remaining=Math.max(remaining,z.life);return remaining;
}
function satelliteControlTarget(u,enemies){return enemies.filter(e=>e.hp>0&&canPerceive(u,e)&&dist(u,e)<480*unitScale(u)&&crowdControlRemaining(e)>0).sort((a,b)=>crowdControlRemaining(b)-crowdControlRemaining(a)||dist(u,a)-dist(u,b))[0]??null;}
function moveSatellite(u,dt){
 const b=u.ai;b.wanderClock=(b.wanderClock??0)-dt;if(!b.wanderGoal||b.wanderClock<=0||dist(u,b.wanderGoal)<45){b.wanderGoal={x:random(65,735),y:random(65,735)};b.wanderClock=random(1.2,3);b.side=Math.random()<.5?-1:1;}
 const d=dist(u,b.wanderGoal)||1,dx=(b.wanderGoal.x-u.x)/d,dy=(b.wanderGoal.y-u.y)/d,sway=Math.sin(elapsed*2.2+b.phase)*.3;steerArchetype(u,dx-dy*sway,dy+dx*sway,dt,movementRate(u)*(u.attack?.phase==='windup'?.75:1));if(!u.attack)u.face=Math.atan2(u.headingY,u.headingX);u.action=u.attack?'전류 감지 · 발사 준비':'방황 · 궤도 이동';
}
function launchSatelliteMissile(u,target,damage,enhanced=false,spread=0){
 if(!target||target.hp<=0)return null;const lead=dist(u,target)/(enhanced?500:430)*.18,angle=Math.atan2(target.y+(target.vy??0)*lead-u.y,target.x+(target.vx??0)*lead-u.x)+spread,speed=enhanced?500:430,scale=unitScale(u);
 const p={kind:'missile',source:u,type:u.type,color:enhanced?'#d0fff0':u.color,x:u.x+Math.cos(angle)*34*scale,y:u.y+Math.sin(angle)*34*scale,vx:Math.cos(angle)*speed,vy:Math.sin(angle)*speed,damage,power:damage,life:2.6,visualScale:scale,radius:(enhanced?24:18)*scale,impulse:enhanced?280:150,trail:[],bouncesRemaining:0,targetId:target.id,guideRemaining:.45,homing:true,guaranteed:false,hiddenLaunch:isConcealed(u),enhanced};projectiles.push(p);u.shotsFired++;fx('gunFlash',p.x,p.y,p.color,.12,{angle,r:enhanced?45:28});burst(p.x,p.y,'#ffe8b8',8,160,.3,angle+Math.PI);return p;
}
function launchSatelliteSalvo(u,count,damage,enhanced=false){
 const targets=alive().filter(v=>v.faction!==u.faction&&canPerceive(u,v)&&dist(u,v)<(enhanced?520:480)*unitScale(u)).sort((a,b)=>dist(u,a)-dist(u,b));if(!targets.length)return 0;const offset=Math.floor(Math.random()*targets.length);
 for(let i=0;i<count;i++)launchSatelliteMissile(u,targets[(offset+i)%targets.length],damage,enhanced,(i-(count-1)/2)*Math.min(.12,.6/Math.max(1,count-1)));return count;
}
function advanceSatelliteBursts(u,dt){
 if(u.type!==15||!u.satelliteBursts?.length||u.hp<=0||u.stun>0||duelLocked(u))return;
 for(const salvo of u.satelliteBursts)salvo.remaining-=dt;const ready=u.satelliteBursts.filter(s=>s.remaining<=0);u.satelliteBursts=u.satelliteBursts.filter(s=>s.remaining>0);for(const salvo of ready)launchSatelliteSalvo(u,4,salvo.damage);
}
function advanceSatelliteGuidance(p,dt){
 if(p.kind!=='missile'||p.guideRemaining<=0)return;const target=units.find(v=>v.id===p.targetId&&v.hp>0&&canPerceive(p.source,v)),speed=Math.hypot(p.vx,p.vy);if(target){const current=Math.atan2(p.vy,p.vx),desired=Math.atan2(target.y-p.y,target.x-p.x),turn=clamp(angleDelta(desired,current),-1.7*Math.min(dt,p.guideRemaining),1.7*Math.min(dt,p.guideRemaining)),angle=current+turn;p.vx=Math.cos(angle)*speed;p.vy=Math.sin(angle)*speed;}p.guideRemaining=Math.max(0,p.guideRemaining-dt);if(p.guideRemaining<=0)p.homing=false;
}
function satelliteMissileImpact(p,target){
 attackHit(target,p.damage,p.source,{angle:Math.atan2(p.vy,p.vx),impulse:p.impulse,attackToken:p,hiddenLaunch:p.hiddenLaunch,attackOrigin:{x:target.x-p.vx*.04,y:target.y-p.vy*.04}});p.life=0;impact(target.x,target.y,p.color,p.enhanced?1.8:1.1,Math.atan2(p.vy,p.vx));
}
function renderSwordsmanWeapon(u,a,p){
 if(u.ultCast){const ult=u.ultCast;ctx.rotate(ult.dashing?-.2:-1.3);ctx.translate(ult.dashing?25:8,14);sword(ult.dashing?105:85,7,'#e8faff');return;}ctx.translate(20,13);sword(a?.slash===2?92:82,7,'#dceff5');ctx.fillStyle='#507b8a';ctx.fillRect(1,-4,12,8);if(a?.phase==='windup')texel(82,0,4,'#efffff',p*.8);
}
function renderSatelliteWeapon(u,a,p){
 ctx.rotate(Math.sin(elapsed*1.7+u.phase)*.12);const charge=a?.phase==='windup'||u.ultCast||u.satelliteBursts?.length;
 for(const side of [-1,1]){ctx.fillStyle='#36555d';ctx.fillRect(-10,side<0?-36:23,22,13);ctx.fillStyle='#7196a2';for(let i=0;i<3;i++)ctx.fillRect(-8+i*7,side<0?-34:25,5,9);ctx.fillStyle=charge?'#e5fff4':'#74b8a6';ctx.fillRect(28,side*15-5,11,10);if(charge)bladeStreak(40,side*15,0,10+(a?p*12:8),4,'#d6ffef',.8);}
}
function renderSatelliteMissile(p){
 const angle=Math.atan2(p.vy,p.vx),scale=p.enhanced?1.4:1;ctx.save();ctx.translate(p.x,p.y);ctx.rotate(angle);ctx.scale(scale,scale);bladeStreak(-16,0,0,35,5,'#f5c991',.6);ctx.fillStyle='#567b81';ctx.fillRect(-11,-7,6,3);ctx.fillRect(-11,4,6,3);ctx.fillStyle='#bdd8dc';ctx.fillRect(-12,-4,21,8);ctx.fillStyle='#f4fffc';ctx.fillRect(4,-3,8,6);ctx.fillStyle='#7fafa4';ctx.fillRect(12,-2,4,4);texel(-17,0,5,'#ffda9a',.95);texel(-24,0,3,'#dfaa70',.65);ctx.restore();
}

function releasePaladinAttack(u,a){
 u.paladinSwings=(u.paladinSwings??0)+1;const strike=spawnMeleeStrike(u,a,u.dmg*(a.paladinBash?.65:1.25));strike.shieldBash=a.paladinBash;u.action=a.paladinBash?'방패 강타':'검 참격';
 burst(u.x+Math.cos(a.angle)*55,u.y+Math.sin(a.angle)*55,'#fff0bc',a.paladinBash?24:16,220,.65,a.angle,'shard');if(a.paladinBash)impactPause(1.6,a.angle);
}
function releasePaladinGuardian(u){
 ultimateZones.push({kind:'holy',source:u,x:u.x,y:u.y,r:PALADIN_GUARDIAN.radius*unitScale(u),life:PALADIN_GUARDIAN.duration,max:PALADIN_GUARDIAN.duration,tick:0,pulse:0});
 for(const ally of alive())if(ally.faction===u.faction&&dist(u,ally)<PALADIN_GUARDIAN.radius*unitScale(u)){restoreCombatHp(ally,ally.maxHp*PALADIN_GUARDIAN.healFraction,u);ally.paladinBlessingTime=PALADIN_GUARDIAN.duration;fx('healBeam',u.x,u.y,'#ffe8a3',.45,{tx:ally.x,ty:ally.y});fx('paladinBlessing',ally.x,ally.y,'#fff0bc',.65,{unitId:ally.id,r:75});burst(ally.x,ally.y,'#ffe8a3',16,100,Math.PI*2,0,'mote');}
}
function renderPaladinWeapon(u,a,p){
 const bash=a?.paladinBash??true;ctx.save();const extension=a?(a.phase==='windup'?-p*14:a.phase==='active'?Math.sin(p*Math.PI/2)*38:18*(1-p)):0;ctx.translate(28+(bash?extension:0),-17);ctx.fillStyle='#8c794f';ctx.strokeStyle='#fff0bd';ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(-9,-22);ctx.lineTo(13,-20);ctx.lineTo(20,0);ctx.lineTo(6,25);ctx.lineTo(-9,13);ctx.closePath();ctx.fill();ctx.stroke();ctx.fillStyle='#eddc9b';ctx.fillRect(-2,-13,5,27);ctx.fillRect(-7,-3,17,5);ctx.restore();
 ctx.save();ctx.translate(24,20);if(a&&!bash)ctx.rotate(a.phase==='windup'?-p*1.6:a.phase==='active'?-1.6+p*3:1.4*(1-p));if(u.ultCast)ctx.rotate(-1.2);sword(78,8,'#fff2cf');ctx.restore();if((u.paladinBlessingTime??0)>0)bladeStreak(-4,-40,-Math.PI/2,15,6,'#ffe6a0',.8);
}

// Favor a wounded ally or allied cluster; keep a stable destination while closing in.
function paladinRallyTarget(u,allies){
 const friends=allies.filter(v=>v.hp>0&&v.id!==u.id&&v.faction===u.faction);if(!friends.length)return null;
 const score=v=>friends.filter(a=>dist(v,a)<220).length*1.4+(1-v.hp/v.maxHp)*3.5-dist(u,v)*.003;
 const best=friends.slice().sort((a,b)=>score(b)-score(a))[0],previous=friends.find(v=>v.id===u.ai.holyRallyId),target=previous&&score(previous)>=score(best)-.7?previous:best;u.ai.holyRallyId=target.id;return target;
}
function paladinNeedsRally(u,allies){
 if(u.type!==16||u.hp<=0||u.ultGauge<100||u.hp/u.maxHp<=.25||u.ultReadyAge>=6||u.tauntedUntil>elapsed)return false;
 const target=paladinRallyTarget(u,allies);return !!target&&dist(u,target)>140*unitScale(u);
}
function movePaladinRally(u,allies,dt){
 if(u.type!==16||u.attack||u.ultCast||u.stun>0||u.evadeTime>0||duelLocked(u)||novelLocked(u)||u.commandRetreatUntil>elapsed||!paladinNeedsRally(u,allies))return false;
 const target=paladinRallyTarget(u,allies),d=dist(u,target)||1,dx=(target.x-u.x)/d,dy=(target.y-u.y)/d;let mx=dx,my=dy;const obstruction=alive().find(v=>v.id!==u.id&&v.id!==target.id&&canPerceive(u,v)&&dist(u,v)<110&&distanceToSegment(v,u,target)<56&&(v.x-u.x)*dx+(v.y-u.y)*dy>0);if(obstruction){const side=u.ai.side??1;mx=dx*.35-dy*side*1.3;my=dy*.35+dx*side*1.3;}steerArchetype(u,mx,my,dt,movementRate(u));u.action='수호신 · 아군 합류';return true;
}
