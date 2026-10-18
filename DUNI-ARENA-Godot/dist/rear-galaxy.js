'use strict';
// Backline plans choose a safe firing station rather than a melee counter-attack route.
function rearTarget(u,target,seen){if(hasBehavior(target,'후열'))return true;const dx=target.x-u.x,dy=target.y-u.y,d=Math.hypot(dx,dy)||1;return seen.some(e=>e.id!==target.id&&e.faction===target.faction&&(dx*(target.x-e.x)+dy*(target.y-e.y))/d>80&&Math.abs(dx*(target.y-e.y)-dy*(target.x-e.x))/d<170);}
function dependencyAnchor(u,enemies,allies){
 let friends=allies.filter(a=>a.hp>0&&!hasBehavior(a,'의존형'));if(!friends.length){const leader=[u,...allies].filter(a=>a.hp>0).sort((a,b)=>a.id-b.id)[0];friends=leader&&leader.id!==u.id?[leader]:[];}
 return friends.sort((a,b)=>{const frontline=a.range<100?0:1,other=b.range<100?0:1;return frontline-other||dist(u,a)-dist(u,b);})[0]??null;
}
function rearStation(u,target,enemies,allies){
 const friend=hasBehavior(u,'의존형')?dependencyAnchor(u,enemies,allies):null,options=[{x:u.x,y:u.y}],preferred=u.range*(u.combatStance==='cautious'?.92:.86);
 let support=null;
 if(friend){const threat=enemies.slice().sort((a,b)=>dist(friend,a)-dist(friend,b))[0]??target,angle=threat?Math.atan2(friend.y-threat.y,friend.x-threat.x):friend.face+Math.PI;support={friend,angle};for(const offset of [-.4,0,.4])for(const distance of [110,155])options.push({x:clamp(friend.x+Math.cos(angle+offset)*distance,55,745),y:clamp(friend.y+Math.sin(angle+offset)*distance,55,745)});}
 if(target){const base=Math.atan2(u.y-target.y,u.x-target.x);for(let i=-4;i<=4;i++){const angle=base+i*.28;options.push({x:clamp(target.x+Math.cos(angle)*preferred,55,745),y:clamp(target.y+Math.sin(angle)*preferred,55,745)});}}
 for(let i=0;i<8;i++)options.push({x:clamp(u.x+Math.cos(i*Math.PI/4)*100,55,745),y:clamp(u.y+Math.sin(i*Math.PI/4)*100,55,745)});
 const context=collectBattleAreas(u,enemies,allies),score=p=>{const nearest=enemies.length?Math.min(...enemies.map(e=>dist(p,e))):400,range=target?dist(p,target):preferred,occupied=allies.filter(a=>dist(p,a)<65).length;let value=-Math.max(0,225-nearest)*2.8-Math.abs(range-preferred)*.2-Math.max(0,range-u.range*.96)*2-dist(p,u)*.055-occupied*40-battleAreaRisk(u,p,context).total*100;
  if(support){const f=support.friend,d=dist(p,f),behind=(p.x-f.x)*Math.cos(support.angle)+(p.y-f.y)*Math.sin(support.angle);value-=Math.max(0,90-behind)*1.5+Math.abs(d-125)*.7+Math.max(0,d-210)*2;}
  return value;};options.sort((a,b)=>score(b)-score(a));return{...options[0],friendId:friend?.id??null};
}
function moveRear(u,target,enemies,allies,dt){
 if(!hasBehavior(u,'후열')&&!(u.type===5&&hasBehavior(u,'의존형'))||u.combatStance==='rush'||u.combatStance==='cover'||u.tauntedUntil>elapsed||u.commandRetreatUntil>elapsed||u.bomberRush||u.ultCast)return false;
 const b=u.ai,near=enemies.slice().sort((a,c)=>dist(u,a)-dist(u,c))[0],close=near&&dist(u,near)<210;
 if(!b.rearGoal||elapsed>=(b.rearThinkAt??0)||b.rearTargetId!==target?.id||b.rearGoal.friendId&&!allies.some(a=>a.id===b.rearGoal.friendId)){b.rearGoal=rearStation(u,target,enemies,allies);b.rearTargetId=target?.id??null;b.rearThinkAt=elapsed+random(close?.18:.5,close?.4:1);}
 const goal=b.rearGoal,d=dist(u,goal)||1;let mx=(goal.x-u.x)/d*Math.min(1,d/35),my=(goal.y-u.y)/d*Math.min(1,d/35);
 if(close){const gap=dist(u,near)||1,w=clamp((210-gap)/85,0,1.4);mx+=(u.x-near.x)/gap*w;my+=(u.y-near.y)/gap*w;}
 const incoming=projectileThreat(u);if(incoming&&incoming.time<b.reaction*(u.combatStance==='cautious'?1.2:1)&&!u.attack){const len=Math.hypot(incoming.p.vx,incoming.p.vy)||1;mx=mx*.4-incoming.p.vy/len*b.side;my=my*.4+incoming.p.vx/len*b.side;}
 const rate=u.attack?(u.attack.phase==='windup'?.3:.55):close?1.1:1;steerArchetype(u,mx,my,dt,movementRate(u)*rate);u.action=close?'후열 · 적에게서 이탈':goal.friendId?'아군 뒤 · 치유 지원':d>30?'후열 · 안전한 사격 위치 확보':'후열 · 자리 유지';return true;
}
const GALAXY={type:22,speed:240,spread:1.35,duration:7,radius:270};
function setupBattleGalaxies(){
 for(const u of units)u.cosmicMarked=false;
 for(const source of alive().filter(u=>u.type===GALAXY.type)){const target=alive().filter(u=>u.faction!==source.faction).sort((a,b)=>dist(source,b)-dist(source,a)||a.id-b.id)[0];if(target)target.cosmicMarked=true;}
}
function cosmicDamageFactor(u){return u?.cosmicMarked ? .7 : 1;}
function launchGalaxyStars(u,a){
 for(let i=0;i<5;i++){const angle=a.angle+(i-2)*GALAXY.spread/4+random(-.018,.018),scale=unitScale(u);projectiles.push({kind:'star',source:u,type:u.type,color:i%2?'#e8d0ff':'#b4a7ff',x:u.x+Math.cos(angle)*38*scale,y:u.y+Math.sin(angle)*38*scale,vx:Math.cos(angle)*GALAXY.speed,vy:Math.sin(angle)*GALAXY.speed,damage:u.dmg,power:u.dmg,impulse:155,radius:18*scale,visualScale:scale,life:3.6,trail:[],bouncesRemaining:0,homing:false,guaranteed:false,hiddenLaunch:a.hiddenLaunch});}
 u.shotsFired++;fx('gunFlash',u.x+Math.cos(a.angle)*36,u.y+Math.sin(a.angle)*36,'#e9dcff',.18,{angle:a.angle,r:50});
}
function createGalaxyHorizon(u,a){const target=units.find(v=>v.id===a.targetId&&v.hp>0&&v.faction!==u.faction);if(!target)return false;ultimateZones.push({kind:'galaxy',source:u,targetId:target.id,x:target.x,y:target.y,r:GALAXY.radius*unitScale(u),life:GALAXY.duration,max:GALAXY.duration,pulse:0});return true;}
function advanceGalaxyZone(z,dt){const target=units.find(u=>u.id===z.targetId&&u.hp>0);if(!target){z.life=0;return;}z.x=target.x;z.y=target.y;z.pulse+=dt;}
function advanceGalaxyProjectiles(dt){
 const wells=ultimateZones.filter(z=>z.kind==='galaxy'&&z.life>0).filter(z=>{const target=units.find(u=>u.id===z.targetId&&u.hp>0);if(!target)return false;z.x=target.x;z.y=target.y;return true;});if(!wells.length)return;
 for(const p of projectiles){if(p.life<=0||p.kind==='bomb'&&p.flight<=0)continue;
  const eligible=wells.filter(z=>z.source.faction===p.source.faction&&dist(p,z)<=z.r);if(!eligible.length)continue;
  const well=eligible.sort((a,b)=>dist(p,a)-dist(p,b))[0],dx=well.x-p.x,dy=well.y-p.y,d=Math.hypot(dx,dy)||1,speed=Math.hypot(p.vx,p.vy);if(speed<1)continue;
  const nx=dx/d,ny=dy/d,inward=d<35?2.2:1.5+.7*d/well.r,tangent=d<35?.1:.7;
  // Steer continuously; normal swept collision still handles every projectile.
  const desired=Math.atan2(ny*inward-nx*tangent,nx*inward+ny*tangent),angle=Math.atan2(p.vy,p.vx),turn=clamp(angleDelta(desired,angle),-18*dt,18*dt),next=angle+turn;
  p.vx=Math.cos(next)*speed;p.vy=Math.sin(next)*speed;p.galaxyCurved=true;
 }
}
function renderGalaxyWeapon(u,a,p){ctx.translate(32,8);const charge=a?.phase==='windup'||!!u.ultCast;pixelSprite(0,0,'#d5c2ff',charge?1+p:1,'star',1);for(let i=0;i<3;i++){const angle=elapsed*.9+i*Math.PI*2/3;pixelSprite(Math.cos(angle)*17,Math.sin(angle)*12,'#f0e5ff',.4,'star',charge?.7:.35);}}
function renderGalaxyStar(p){const angle=Math.atan2(p.vy,p.vx);for(let i=1;i<p.trail.length;i+=2){const v=p.trail[i];pixelSprite(v.x,v.y,p.color,.32,'star',i/p.trail.length*.35);}bladeStreak(p.x-Math.cos(angle)*12,p.y-Math.sin(angle)*12,angle,30,6,p.color,.55);pixelSprite(p.x,p.y,'#f9efff',1.1,'star',1);}
function renderGalaxyZone(z,alpha){
 const t=z.pulse,phase=t*1.9;ctx.globalAlpha=alpha*.16;ctx.fillStyle='#292043';ctx.beginPath();ctx.ellipse(z.x,z.y,z.r*.6,z.r*.42,0,0,Math.PI*2);ctx.fill();ctx.globalAlpha=alpha;
 for(let i=0;i<4;i++){const radius=38+i*22,start=phase+i*1.6;slashStroke(z.x,z.y,radius,start,start+2.3,i%2?'#bca2ef':'#7e6baa',i===0?8:5,alpha*.65);}
 for(let i=0;i<12;i++){const a=phase+i*2.39996,r=35+((i*19-t*20)%130+130)%130;pixelSprite(z.x+Math.cos(a)*r,z.y+Math.sin(a)*r*.78,i%3?'#ac96dc':'#efe1ff',i%3?.35:.6,'star',alpha*.45);}
 ctx.globalAlpha=alpha*.8;circle(z.x,z.y,19,'#0c091e');slashStroke(z.x,z.y,24,phase,phase+3.3,'#dfceff',4,alpha*.85);
}
function renderCosmicStatus(u){if(!u.cosmicMarked)return;pixelSprite(u.x+33,u.y-39,'#bd9ae6',.5,'star',.75);}
