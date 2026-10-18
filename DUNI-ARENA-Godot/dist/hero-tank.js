'use strict';
// New fighters share physical contacts and defense; their rushes advance from their current positions.
const HERO_RESCUE_SPEED=1050,HERO_ULT_SPEED=900,TANK_TURN_SPEED=.75;
function turnUnitFace(u,desired,dt){const delta=angleDelta(desired,u.face);u.face+=u.type===18?clamp(delta,-TANK_TURN_SPEED*dt,TANK_TURN_SPEED*dt):delta*Math.min(1,dt*8);}
function creditBattleDamage(source,target,amount){if(source&&source.faction!==target.faction&&amount>0)source.damageDealt=(source.damageDealt??0)+amount;}
function heroVillainTarget(u,enemies){return enemies.filter(e=>e.hp>0&&canPerceive(u,e)).slice().sort((a,b)=>(b.damageDealt??0)-(a.damageDealt??0)||dist(u,a)-dist(u,b))[0]??null;}
function heroRescuing(u){return u?.type===17&&u.hp>0&&!!u.heroRescue;}
function heroRescueProtected(friend){const u=units.find(v=>v.id===friend.heroRescueOwnerId);return heroRescuing(u)&&u.heroRescue.targetId===friend.id&&u.faction===friend.faction;}
function endHeroRescue(u){const friend=units.find(v=>v.id===u.heroRescue?.targetId);if(friend?.heroRescueOwnerId===u.id)delete friend.heroRescueOwnerId;u.heroRescue=null;}
function isHeroRushing(u){return u.type===17&&u.hp>0&&u.stun<=0&&(u.heroRescue?.phase==='rush'||u.ultCast?.dashing===true);}
function moveHeroRush(u,point,speed,dt,stopDistance,angle=null){
 const from={x:u.x,y:u.y},d=dist(u,point),desired=Math.atan2(point.y-u.y,point.x-u.x);if(angle===null)u.face=desired;else u.face=angle+clamp(angleDelta(desired,angle),-6*dt,6*dt);
 const move=Math.min(Math.max(0,d-stopDistance),speed*Math.max(0,dt));u.x=clamp(u.x+Math.cos(u.face)*move,28,772);u.y=clamp(u.y+Math.sin(u.face)*move,28,772);u.vx=dt>0?(u.x-from.x)/dt:0;u.vy=dt>0?(u.y-from.y)/dt:0;u.kx=u.ky=u.headingX=u.headingY=0;
 if(move>.01)fx('afterimage',from.x,from.y,u.color,.1,{tx:u.x,ty:u.y,type:u.type,ownerId:u.id});return dist(u,point)<=stopDistance+2;
}
function tryHeroRescue(friend){
 if(friend.hp<=0||frogUnavailable(friend))return false;
 const u=alive().filter(v=>v.type===17&&v.id!==friend.id&&v.faction===friend.faction&&!v.heroRescueUsed).sort((a,b)=>dist(a,friend)-dist(b,friend))[0];if(!u)return false;
 // This once-per-battle passive takes precedence over ordinary action/CC locks.
 const duel=duelFor(u);if(duel)cancelDuel(duel);if(u.frogCarrierId!=null){const carrier=units.find(v=>v.id===u.frogCarrierId);if(carrier)releaseFrogAction(carrier);}if(u.frogFlight)finishFrogBody(u.frogFlight,{damage:false});
 u.stun=0;u.stunRevision=(u.stunRevision??0)+1;friend.heroRescueOwnerId=u.id;
 u.heroRescueUsed=true;u.heroRescue={phase:'rush',t:0,targetId:friend.id,rushTime:0};u.attack=u.ultCast=null;for(const s of meleeStrikes)if(s.source===u)s.life=0;u.parryTime=0;u.dodgeState=null;u.evadeTime=0;u.strategyDash=null;u.headingX=u.headingY=u.kx=u.ky=0;u.ai.response=null;u.revealTime=3;
 fx('barrierHit',friend.x,friend.y,'#ffe1b9',.3,{unitId:friend.id,r:65,angle:u.face});fx('charge',u.x,u.y,u.color,.15,{unitId:u.id,r:70});return true;
}
function advanceHeroRescue(u,allies,dt){
 if(!heroRescuing(u))return false;
 const a=u.heroRescue,friend=units.find(v=>v.id===a.targetId&&v.hp>0&&v.faction===u.faction);if(!friend){endHeroRescue(u);return false;}
 a.t+=dt;a.rushTime+=dt;u.action='영웅등장 · 아군에게 돌진';
 const arrived=moveHeroRush(u,friend,HERO_RESCUE_SPEED,dt,65*unitScale(u));if(!arrived){if(a.rushTime>2)endHeroRescue(u);return true;}
 friend.shieldHp=Math.max(activeShieldHp(friend),60);friend.shieldTime=Math.max(friend.shieldTime??0,10);fx('barrierGain',friend.x,friend.y,'#9bddeb',.35,{unitId:friend.id,r:48});
 const radius=220*unitScale(u),point={x:friend.x,y:friend.y};fx('heroArrival',point.x,point.y,'#ffd99c',.8,{r:radius,angle:u.face});burst(point.x,point.y,'#ffcf86',70,480,Math.PI*2,u.face,'debris');impactPause(3,u.face);
 for(const enemy of alive()){if(enemy.faction===u.faction||dist(point,enemy)>radius+24*unitScale(enemy))continue;const angle=Math.atan2(enemy.y-point.y,enemy.x-point.x),result=attackHit(enemy,u.dmg*1.6,u,{angle,impulse:650,attackOrigin:point,visibleHazard:true,attackToken:a});if(result.damage>0&&enemy.hp>0)stunParryEnemy(enemy,2);}
 endHeroRescue(u);u.cooldown=Math.max(u.cooldown,.6);u.ai.disengageUntil=elapsed+.7;u.action='영웅등장 · 구출 충격';return true;
}
function releaseHeroPunch(u,a,ultimate=false){const s=spawnMeleeStrike(u,a,u.dmg*(ultimate?4.2:1),ultimate);s.heroPunch=true;s.finisher=ultimate;burst(u.x+Math.cos(a.angle)*70,u.y+Math.sin(a.angle)*70,ultimate?'#ffe1a8':u.color,ultimate?40:16,ultimate?450:220,.7,a.angle,'shard');if(ultimate)impactPause(3,a.angle);}
function advanceHeroUltimate(u,a,dt){
 const target=units.find(v=>v.id===a.targetId&&v.hp>0&&v.faction!==u.faction);if(!target||!canPerceive(u,target)){u.action='악당처단 · 목표 이탈';return true;}
 if(!a.dashing&&a.phase!=='punch'){a.dashing=true;a.phase='rush';a.rushTime=0;}
 if(a.dashing){const step=a.rushTime===0?Math.min(dt,Math.max(0,a.t-a.duration)):dt;a.rushTime+=step;a.point={x:target.x,y:target.y};u.action='악당처단 · 추격 돌진';const arrived=moveHeroRush(u,target,HERO_ULT_SPEED,step,75*unitScale(u),a.angle);a.angle=u.face;if(!arrived){if(a.rushTime>2){a.dashing=false;return true;}return false;}a.dashing=false;a.phase='punch';a.punchTime=0;fx('charge',u.x,u.y,'#ffb0a7',.25,{unitId:u.id,r:80});return false;}
 a.punchTime+=dt;u.action='악당처단 · 강펀치 준비';u.vx=u.vy=u.headingX=u.headingY=0;if(a.punchTime<.15)a.angle=Math.atan2(target.y-u.y,target.x-u.x);u.face=a.angle;if(a.punchTime<.25)return false;
 releaseHeroPunch(u,{...a,serial:++u.attackSerial,profile:{reach:155,cone:.25,active:.2,impulse:720},hiddenLaunch:false},true);return true;
}
function tankRearDamageFactor(target,source,options){if(target.type!==18||options.duelResult||options.parryRecoil||options.clashRecoil)return 1;const origin=options.attackOrigin??source;if(!origin||dist(target,origin)<.001)return 1;const incoming=Math.atan2(origin.y-target.y,origin.x-target.x);return Math.cos(angleDelta(incoming,target.face))<-.5?1.75:1;}
function steerTank(u,mx,my,dt,factor=1){
 const len=Math.hypot(mx,my),from={x:u.x,y:u.y};if(len>.01){const desired=Math.atan2(my,mx);u.tankHeadingAngle??=u.face;u.tankHeadingAngle+=clamp(angleDelta(desired,u.tankHeadingAngle),-.65*dt,.65*dt);const alignment=Math.max(0,Math.cos(angleDelta(desired,u.tankHeadingAngle))),travel=u.moveSpeed*Math.min(1,len)*Math.min(1.15,factor)*alignment*dt;u.x=clamp(u.x+Math.cos(u.tankHeadingAngle)*travel,28,772);u.y=clamp(u.y+Math.sin(u.tankHeadingAngle)*travel,28,772);u.headingX=Math.cos(u.tankHeadingAngle)*Math.min(1,len)*alignment;u.headingY=Math.sin(u.tankHeadingAngle)*Math.min(1,len)*alignment;}else u.headingX=u.headingY=0;
 u.vx=(u.x-from.x)/dt;u.vy=(u.y-from.y)/dt;
}
function moveTank(u,target,enemies,allies,dt){
 if(u.attack){u.vx=u.vy=u.headingX=u.headingY=0;u.action=u.attack.phase==='windup'?'포탄 · 장전과 조준':'포탄 발사 후 정비';return;}
 if(!target){const goal=u.ai.goal;if(dist(u,goal)<55)u.ai.goal={x:random(90,710),y:random(90,710)};const d=dist(u,u.ai.goal)||1;steerTank(u,(u.ai.goal.x-u.x)/d,(u.ai.goal.y-u.y)/d,dt,.6);u.action='탐색 · 차체 회전';return;}
 const d=dist(u,target)||1,dx=(target.x-u.x)/d,dy=(target.y-u.y)/d,b=u.ai,desired=u.combatStance==='rush'?220:elapsed<b.disengageUntil?390:330,radial=clamp((d-desired)/110,-1,1);let mx=dx*radial-dy*b.side*.18,my=dy*radial+dx*b.side*.18;
 for(const v of [...enemies,...allies]){const range=dist(u,v);if(range<80){mx+=(u.x-v.x)/(range||1)*.5;my+=(u.y-v.y)/(range||1)*.5;}}if(u.x<60)mx+=1;if(u.x>740)mx-=1;if(u.y<60)my+=1;if(u.y>740)my-=1;
 steerTank(u,mx,my,dt,movementRate(u));u.action=d<240?'거리 확보 · 느린 후진':Math.abs(angleDelta(aimDirection(u,target),u.face))>.16?'포신 회전 · 조준':'대치 · 포격 시점 판단';
}
function fireTankShell(u,a){
 const enhanced=u.tankFlameReady===true;u.tankFlameReady=false;const scale=unitScale(u),speed=620,angle=a.angle,damage=u.dmg*(enhanced?1.7:1),muzzle={x:u.x+Math.cos(angle)*64*scale,y:u.y+Math.sin(angle)*64*scale};
 const p={kind:'tankShell',source:u,type:u.type,color:enhanced?'#ffae62':u.color,x:muzzle.x,y:muzzle.y,vx:Math.cos(angle)*speed,vy:Math.sin(angle)*speed,damage,power:damage,life:2,trail:[],radius:25*scale,visualScale:scale,blastRadius:(enhanced?160:130)*scale,impulse:enhanced?560:440,enhanced,hiddenLaunch:a.hiddenLaunch,homing:false,guaranteed:false,bouncesRemaining:0};projectiles.push(p);u.shotsFired++;
 applyKnockback(u,-Math.cos(angle)*140,-Math.sin(angle)*140,u);fx('gunFlash',muzzle.x,muzzle.y,'#ffe2ad',.16,{angle,r:90});burst(muzzle.x,muzzle.y,'#e7c494',18,300,.7,angle,'shard');impactPause(1.7,angle);return p;
}
function explodeTankShell(p){
 if(p.detonated||p.life<=0)return;p.detonated=true;p.life=0;const point={x:p.x,y:p.y},angle=Math.atan2(p.vy,p.vx);fx('tankBlast',point.x,point.y,p.color,.4,{r:p.blastRadius,angle,enhanced:p.enhanced});impactPause(p.enhanced?3.2:2.7,angle);burst(point.x,point.y,'#ffcc88',40,430,1.3,angle,'debris');
 for(const enemy of alive()){if(enemy.faction===p.source.faction||dist(point,enemy)>p.blastRadius+24*unitScale(enemy))continue;const falloff=1-.35*clamp(dist(point,enemy)/p.blastRadius,0,1);attackHit(enemy,p.damage*falloff,p.source,{angle:Math.atan2(enemy.y-point.y,enemy.x-point.x),impulse:p.impulse,hiddenLaunch:p.hiddenLaunch,visibleHazard:true,attackOrigin:point,attackToken:p});}
 if(p.enhanced)ultimateZones.push({kind:'tankFire',source:p.source,x:point.x,y:point.y,r:150*(p.visualScale??1),life:5,max:5,tick:0,pulse:0,damage:p.source.dmg*.1});
}
function advanceTankFire(z,dt){z.pulse+=dt;z.tick+=Math.min(dt,Math.max(0,z.life+dt));while(z.tick>=.5-1e-8){z.tick-=.5;for(const enemy of alive()){if(enemy.faction===z.source.faction||dist(z,enemy)>z.r)continue;hit(enemy,z.damage,z.source,{impulse:0,attackOrigin:z,visibleHazard:true,attackToken:z});}}}
function renderHeroWeapon(u,a,p){
 const ult=u.ultCast,rescue=u.heroRescue,preparing=a?.phase==='windup'||ult&&!ult.dashing||rescue?.phase==='prepare',active=a?.phase==='active',pull=preparing?-16*(ult?clamp(ult.t/ult.duration,0,1):p):active?45*Math.sin(p*Math.PI):0;
 for(const side of [-1,1]){ctx.save();ctx.translate(28+(side===1?pull:0),side*18);ctx.rotate(side*.2);ctx.fillStyle='#754c47';ctx.fillRect(-14,-7,20,14);ctx.fillStyle='#e88f86';ctx.fillRect(-9,-8,22,16);ctx.fillStyle='#ffd8b3';ctx.fillRect(5,-10,20,20);ctx.fillStyle='#fff1d3';ctx.fillRect(14,-8,8,4);ctx.restore();}
}
function renderTankWeapon(u,a,p){
 const recoil=a?.phase==='active'?-13*Math.sin(p*Math.PI):0;ctx.fillStyle='#485240';ctx.fillRect(-26,-36,46,9);ctx.fillRect(-26,27,46,9);ctx.fillStyle='#9cac7d';for(let i=0;i<5;i++){ctx.fillRect(-23+i*9,-34,5,5);ctx.fillRect(-23+i*9,29,5,5);}ctx.fillStyle='#7a8861';ctx.fillRect(20,-11,16,22);ctx.fillStyle='#c2ce9d';ctx.fillRect(23,-8,10,5);ctx.fillStyle='#3d463a';ctx.fillRect(27+recoil,-7,40,14);ctx.fillStyle=u.tankFlameReady?'#ffc37c':'#b6c19d';ctx.fillRect(30+recoil,-5,35,5);ctx.fillStyle='#dce5bb';ctx.fillRect(57+recoil,-9,12,18);ctx.fillStyle='#283128';ctx.fillRect(65+recoil,-6,5,12);if(a?.phase==='windup'&&p>.65)texel(71,0,4,u.tankFlameReady?'#ffbc76':'#fff0c9',p*.8);
}
function renderHeroStrike(s){const angle=s.angle,t=clamp(s.age/s.duration,0,1),scale=s.visualScale,x=s.source.x+Math.cos(angle)*(35+s.reach*.55),y=s.source.y+Math.sin(angle)*(35+s.reach*.55);bladeStreak(x,y,angle,s.finisher?180*scale:95*scale,s.finisher?50*scale:25*scale,s.finisher?'#ffc1a0':'#f3a49d',1-t*.6);bladeStreak(x+Math.cos(angle)*15,y+Math.sin(angle)*15,angle,s.finisher?125*scale:70*scale,s.finisher?22*scale:10*scale,'#fff2d5',1-t*.5);}
function renderTankShell(p){const angle=Math.atan2(p.vy,p.vx);ctx.save();ctx.translate(p.x,p.y);ctx.rotate(angle);bladeStreak(-22,0,0,p.enhanced?85:55,p.enhanced?17:9,p.enhanced?'#ef9950':'#d2b989',.7);ctx.fillStyle='#75664b';ctx.fillRect(-14,-8,24,16);ctx.fillStyle=p.enhanced?'#ffc17b':'#ebe5ba';ctx.fillRect(-9,-5,22,10);ctx.fillStyle='#fff1cd';ctx.fillRect(10,-4,7,8);ctx.restore();}
function renderHeroPressureFront(e,r,width,color,alpha){
 ctx.save();ctx.globalAlpha*=alpha;ctx.fillStyle=color;
 // Broad pressure bands with stepped edges; gaps keep the arena readable.
 for(let segment=0;segment<8;segment++){
  const start=e.angle+segment*Math.PI/4+.02,end=start+Math.PI/4-.045,n=12,points=[];
  for(let j=0;j<=n;j++){const a=start+(end-start)*j/n,edge=r+(vfxNoise(segment*n+j,e.x)-.5)*5;points.push({a,edge});}
  ctx.beginPath();for(const [j,{a,edge}]of points.entries()){const x=Math.round((e.x+Math.cos(a)*edge)/PIXEL)*PIXEL,y=Math.round((e.y+Math.sin(a)*edge)/PIXEL)*PIXEL;j?ctx.lineTo(x,y):ctx.moveTo(x,y);}
  for(let j=n;j>=0;j--){const {a,edge}=points[j],inner=edge-width;ctx.lineTo(Math.round((e.x+Math.cos(a)*inner)/PIXEL)*PIXEL,Math.round((e.y+Math.sin(a)*inner)/PIXEL)*PIXEL);}
  ctx.closePath();ctx.fill();
 }
 ctx.restore();
}
function renderHeroTankEffect(e){const p=1-e.life/e.max,alpha=1-p;if(e.kind==='tankLoad'){const u=units.find(v=>v.id===e.unitId),x=u?.x??e.x,y=u?.y??e.y;for(const side of [-1,1])bladeStreak(x+side*22,y-30-p*35,-Math.PI/2,40*(1-p),9,'#ffbd73',alpha);return;}
 if(e.kind==='heroArrival'){
  // A bright contact flash followed by two broad, broken pressure fronts.
  const expansion=1-Math.pow(1-p,3),r=e.r*1.45*(.1+.9*expansion),fade=Math.pow(alpha,1.4);
  ctx.save();ctx.globalAlpha*=fade*.18;
  const glow=ctx.createRadialGradient(e.x,e.y,0,e.x,e.y,r);glow.addColorStop(0,'#fff3d6');glow.addColorStop(.65,'#e9a05d');glow.addColorStop(1,'#e9a05d00');circle(e.x,e.y,r,glow);ctx.restore();
  for(let wave=0;wave<2;wave++){
   const q=clamp((p-wave*.14)/(1-wave*.14),0,1);if(wave&&p<.14)continue;
   const radius=e.r*(wave?1.12:1.45)*(.1+.9*(1-Math.pow(1-q,3))),width=(wave?22:38)*Math.pow(1-q,1.2);
   renderHeroPressureFront(e,radius,width,'#f2b36b',fade*.9);
   renderHeroPressureFront(e,radius+3,width*.3,'#fff3d4',fade);
  }
  for(let i=0;i<18;i++){const a=i*2.39996+e.angle,d=r*(.8+vfxNoise(i,e.y)*.25);texel(e.x+Math.cos(a)*d,e.y+Math.sin(a)*d,5+5*alpha,i%3?'#edb67f':'#fff0c7',fade*.8);}
  if(p<.38)hitGlyph(e.x,e.y,e.angle,115,'#ffe1ae',p/.38,1-p/.38);return;
 }
 const r=e.r*(.25+.65*Math.sin(Math.min(1,p*2)*Math.PI/2));pixelSprite(e.x,e.y,p<.3?'#ffda9c':'#e99a55',Math.max(1,r/28),'blast',alpha);hitGlyph(e.x,e.y,e.angle,r*.8,'#fff0c1',p,alpha*.8);for(let i=0;i<6;i++){const a=i*Math.PI/3+e.angle;bladeStreak(e.x+Math.cos(a)*r,e.y+Math.sin(a)*r,a,35*(1-p),7,'#d7b284',alpha*.65);}
}
function renderTankFire(z,alpha){ctx.save();ctx.globalAlpha=alpha*.16;circle(z.x,z.y,z.r,'#d27536');ctx.globalAlpha=alpha;for(let i=0;i<19;i++){const a=i*2.39996,r=z.r*Math.sqrt(vfxNoise(i,z.x)),x=z.x+Math.cos(a)*r,y=z.y+Math.sin(a)*r,t=(z.pulse*1.8+i*.13)%1;pixelSprite(x,y-t*14,t<.4?'#efa15d':'#dc7942',.6+(1-t)*.7,'ember',alpha*(.7-t*.35));bladeStreak(x,y-9-t*25,-Math.PI/2,16+16*(1-t),5,'#ffcf80',alpha*(1-t)*.55);}ctx.restore();}
