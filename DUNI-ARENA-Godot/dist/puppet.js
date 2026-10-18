'use strict';
const PUPPET={share:.3,controlDuration:7,threadSpeed:660,controlSpeed:540};
function puppetOriginalFaction(u){return u.puppetControl?.originalFaction??u.faction;}
function setupBattlePuppets(){for(const u of units){u.puppetLinks=u.type===25?alive().filter(v=>v.id!==u.id&&v.faction===u.faction).sort((a,b)=>dist(u,a)-dist(u,b)||a.id-b.id).slice(0,2).map(v=>v.id):[];}}
function puppetLinkedAllies(u){if(u?.type!==25||u.hp<=0)return [];return (u.puppetLinks??[]).map(id=>units.find(v=>v.id===id)).filter(v=>v&&v.hp>0&&v.faction===u.faction);}
// Redistribute post-mitigation HP damage, never absorbed shield damage or another shared hit.
function planPuppetDamage(u,damage,source,options={}){
 if(options.puppetShared||!(damage>0))return null;const allies=puppetLinkedAllies(u);if(!allies.length)return null;
 const total=Math.min(damage,Math.round(damage*PUPPET.share));if(total<=0)return null;const each=Math.floor(total/allies.length),remainder=total-each*allies.length;
 return{owner:u,source,total,shares:allies.map((v,i)=>({unit:v,damage:each+(i<remainder?1:0)}))};
}
function applyPuppetDamage(plan){if(!plan)return;for(const share of plan.shares)receivePuppetDamage(share.unit,share.damage,plan.source,plan.owner);}
function receivePuppetDamage(u,damage,source,owner){
 if(!(damage>0)||u.hp<=0||u.invincible>0||u.frogRescueGuard||heroRescueProtected(u)||frogHidden(u))return 0;
 damage=Math.round(damage*combatFatigueFactor(u,'taken'));
 if(interceptLethalDamage(u,Math.max(0,damage-activeShieldHp(u))))return 0;
 const absorbed=absorbShield(u,damage),amount=damage-absorbed,actual=Math.min(u.hp,amount);
 if(actual>=u.hp)finalHitConfirmed(u,source??owner);u.hp=Math.max(0,u.hp-amount);
 if(absorbed>0){if(source&&source.faction!==u.faction)chargeUltimate(source,absorbed,true);chargeUltimate(u,absorbed,false);}
 if(actual>0){u.lastDamage=elapsed;u.lastDamageSourceId=source?.id??null;u.revealTime=3;u.flash=.1;u.recoveryPose=.16;u.hitAngle=Math.atan2(u.y-owner.y,u.x-owner.x);u.hitRecoil=4;onNovelDamage(u,actual);if(source)creditBattleDamage(source,u,actual);chargeUltimate(u,actual,false);if(source&&source.faction!==u.faction)chargeUltimate(source,actual,true);floatText(u,'−'+amount);burst(u.x,u.y,'#ee879b',12,180,.7,u.hitAngle,'shard');}
 fx('puppetTransfer',owner.x,owner.y,'#ff8e9f',.28,{tx:u.x,ty:u.y,fromId:owner.id,toId:u.id});
 if(u.hp===0)eliminateUnit(u,source?.faction!==u.faction?source:null,u.hitAngle??0);return actual;
}
function puppetThread(u,angle,control=false){const scale=unitScale(u),speed=control?PUPPET.controlSpeed:PUPPET.threadSpeed,damage=control?u.dmg*3.5:u.dmg,p={kind:control?'controlThread':'sharpThread',source:u,type:25,x:clamp(u.x+Math.cos(angle)*35*scale,20.001,779.999),y:clamp(u.y+Math.sin(angle)*35*scale,20.001,779.999),vx:Math.cos(angle)*speed,vy:Math.sin(angle)*speed,damage:control?0:damage,power:damage,life:control?1.5:1.2,radius:(control?25:18)*scale,visualScale:scale,impulse:145,trail:[],color:control?'#ee819f':'#f5b5d4',homing:false,guaranteed:false,hiddenLaunch:isConcealed(u)};projectiles.push(p);u.shotsFired++;return p;}
function launchPuppetThreads(u,a){for(const offset of [-.16,0,.16])puppetThread(u,a.angle+offset);fx('puppetSnap',u.x,u.y,'#fac6df',.22,{angle:a.angle,r:75});burst(u.x+Math.cos(a.angle)*35,u.y+Math.sin(a.angle)*35,'#f7bfd8',18,200,.6,a.angle,'shard');u.kx-=Math.cos(a.angle)*35;u.ky-=Math.sin(a.angle)*35;}
function launchPuppetControl(u,a){puppetThread(u,a.angle,true);fx('puppetSnap',u.x,u.y,'#ff98b2',.3,{angle:a.angle,r:110});burst(u.x,u.y,'#ffabbf',24,240,.7,a.angle,'shard');}
function resetPuppetIntent(u){
 endHeroRescue(u);
 releaseFrogAction(u,{heal:true});const duel=duelFor(u);if(duel)cancelDuel(duel);
 u.attack=u.ultCast=u.heroRescue=u.machineGunDash=u.dodgeState=u.strategyDash=u.frogHop=null;u.parryTime=u.evadeTime=0;u.targetId=null;u.targetClock=0;u.ai=createBrain();u.ai.nextInitiativeAt=elapsed+random(.15,.65);u.headingX=u.headingY=u.vx=u.vy=u.kx=u.ky=0;u.coverAllyId=null;
 u.tauntedBy=null;u.tauntedUntil=0;u.focusTargetId=null;u.focusUntil=0;u.pendingRetreat=false;u.pendingTauntIds=[];u.commandRetreatUntil=0;u.retreatPoint=null;u.strategyUltimateReady=false;
 for(const s of meleeStrikes)if(s.source===u)s.life=0;
 if(u.combatStance==='cover')bindCoverAlly(u);
}
function startPuppetControl(u,source,{team=source.team,faction=source.faction,duration=PUPPET.controlDuration}={}){
 if(u.hp<=0||u.faction===faction||frogUnavailable(u)||u.invincible>0||u.frogRescueGuard)return false;
 const prior=u.puppetControl;u.puppetControl={ownerId:source.id,remaining:duration,originalTeam:prior?.originalTeam??u.team,originalFaction:prior?.originalFaction??u.faction};u.team=team;u.faction=faction;resetPuppetIntent(u);u.cooldown=Math.max(u.cooldown,.25);u.revealTime=Math.max(u.revealTime,1);u.action='조종';
 fx('puppetBind',u.x,u.y,'#ff90af',.5,{unitId:u.id,r:90});burst(u.x,u.y,'#ff9aba',20,200,Math.PI*2,0,'shard');addLog(`${source.name} · ${u.name} 7초 조종`);return true;
}
function puppetControlImpact(p,target){
 p.life=0;if(target.hp<=0||target.invincible>0||target.frogRescueGuard||frogUnavailable(target)||target.faction===p.source.faction)return;
 const angle=Math.atan2(p.vy,p.vx),origin={x:target.x-p.vx*.04,y:target.y-p.vy*.04};const blocked=interceptMirrorAttack(target,p.source,p.power,{angle,attackToken:p,attackOrigin:origin})||tryBasicParry(target,p.source,angle,p.power,p);if(blocked)return;
 if(target.evadeTime>0&&canSeeAttack(target,p.source,origin,p.hiddenLaunch))return;
 if(startPuppetControl(target,p.source)){impactPause(1.3,angle);fx('puppetSnap',target.x,target.y,'#ffb5c9',.28,{angle,r:80});}
}
function endPuppetControl(u,{visual=true}={}){
 const control=u.puppetControl;if(!control)return;u.team=control.originalTeam;u.faction=control.originalFaction;u.puppetControl=null;resetPuppetIntent(u);
 if(visual&&u.hp>0){fx('puppetBind',u.x,u.y,'#dec0cd',.25,{unitId:u.id,r:60});burst(u.x,u.y,'#dec0cd',12,150,.7,u.face,'shard');u.action='조종 해제';}
}
function advancePuppetControls(dt){for(const u of units){const c=u.puppetControl;if(!c)continue;c.remaining=Math.max(0,c.remaining-dt);if(c.remaining<=1e-8||u.hp<=0)endPuppetControl(u);}}
function releaseAllPuppetControls(){for(const u of units)if(u.puppetControl)endPuppetControl(u,{visual:false});}
function onPuppetDeath(u){if(u.puppetControl)endPuppetControl(u,{visual:false});}
function snapshotPuppetControl(u){const c=u.puppetControl,owner=units.find(v=>v.id===c.ownerId);return{remaining:c.remaining,team:u.team,faction:u.faction,ownerGuildId:owner?.guildId??null,ownerRoomEnemyId:owner?.roomEnemyId??null,roomId:towerFloor()?.id};}
function restoreTowerPuppetControls(){for(const u of units){const state=u.towerAlly?towerMember(u.guildId)?.state:u.towerEnemy?towerFloor().enemyState[u.roomEnemyId]?.state:null,c=state?.puppetControl;if(!c||!(c.remaining>0)||u.hp<=0)continue;const owner=units.find(v=>c.ownerGuildId!=null?v.guildId===c.ownerGuildId:c.roomId===towerFloor()?.id&&c.ownerRoomEnemyId!=null&&v.roomEnemyId===c.ownerRoomEnemyId);u.puppetControl={ownerId:owner?.id??null,remaining:c.remaining,originalTeam:u.team,originalFaction:u.faction};u.team=c.team;u.faction=c.faction;resetPuppetIntent(u);}}
function puppetTowerFriendly(u){return !!u?.towerAlly&&u.faction==='team:0';}
// Fine red threads remain behind the fighters; damage pulses briefly brighten the same path.
function renderPuppetCurve(a,b,color='#e57691',width=3,alpha=.6){if(dist(a,b)<1)return;const sag=Math.min(55,dist(a,b)*.1);ctx.save();ctx.strokeStyle=color;ctx.lineWidth=width;ctx.globalAlpha*=alpha;ctx.beginPath();ctx.moveTo(a.x,a.y);ctx.bezierCurveTo(a.x+(b.x-a.x)*.3,a.y+sag,b.x-(b.x-a.x)*.25,b.y+sag,b.x,b.y);ctx.stroke();ctx.restore();}
function renderPuppetLinks(){for(const u of units){if(u.type!==25||u.hp<=0||frogHidden(u))continue;for(const ally of puppetLinkedAllies(u)){if(frogHidden(ally))continue;renderPuppetCurve(u,ally);pixelSprite(ally.x,ally.y+28,'#e97492',.5,'ember',.65);}}for(const e of effects){if(e.kind==='puppetTransfer'){const a=units.find(v=>v.id===e.fromId)??e,b=units.find(v=>v.id===e.toId)??{x:e.tx,y:e.ty},t=1-e.life/e.max;renderPuppetCurve(a,b,e.color,3,1-t);pixelSprite(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t+Math.sin(t*Math.PI)*15,e.color,.8,'ember',1-t*.4);}}}
function renderPuppetStatus(u){if(!u.puppetControl)return;const r=33*unitScale(u);for(const side of [-1,1]){const x=u.x+side*r,y=u.y-8;renderPuppetCurve({x:u.x+side*14,y:u.y-48},{x,y},'#ff8dac',2,.75);pixelSprite(x,y,'#ffb5cf',.6,'ember',.85);}ctx.save();ctx.translate(u.x,u.y-48);ctx.rotate(.2);ctx.fillStyle='#ffe6ee';ctx.fillRect(-12,-2,24,4);ctx.fillRect(-2,-8,4,16);ctx.restore();}
function renderPuppetThread(p){const a=Math.atan2(p.vy,p.vx),control=p.kind==='controlThread';for(let i=0;i<p.trail.length-1;i++){const from=p.trail[i],to=p.trail[i+1];renderPuppetCurve(from,to,p.color,control?3:2,.08+i*.045);}bladeStreak(p.x,p.y,a,control?76:62,control?13:7,p.color,.9);bladeStreak(p.x+Math.cos(a)*8,p.y+Math.sin(a)*8,a,32,3,'#fff4fb',1);if(control){const side=Math.sin(elapsed*15)*12;pixelBeam(p.x-Math.sin(a)*side,p.y+Math.cos(a)*side,p.x+Math.sin(a)*side,p.y-Math.cos(a)*side,'#ffb7d0',4,.8);}}
function renderPuppetWeapon(u,a,p){ctx.save();ctx.translate(28,5);ctx.rotate(a?.phase==='windup'?-p*.6:.18);ctx.fillStyle='#a78169';ctx.fillRect(-15,-3,32,6);ctx.fillStyle='#e8c2a4';ctx.fillRect(-3,-14,6,28);for(const side of [-1,1]){ctx.strokeStyle='#db7698';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(side*12,1);ctx.lineTo(side*15,22+(a?.phase==='windup'?-p*12:0));ctx.stroke();}if(a?.phase==='windup'||u.ultCast)pixelSprite(14,0,u.ultCast?'#ff8fad':'#f4c0dc',1+p*.5,'star',.7);ctx.restore();}
function renderPuppetEffect(e){if(e.kind==='puppetTransfer')return;const t=1-e.life/e.max,alpha=1-t,unit=e.unitId?units.find(u=>u.id===e.unitId):null,x=unit?.x??e.x,y=unit?.y??e.y;
 if(e.kind==='puppetBind'){for(let i=0;i<4;i++){const a=i*Math.PI/2+t*.8;bladeStreak(x+Math.cos(a)*e.r*(.3+.5*t),y+Math.sin(a)*e.r*(.3+.5*t),a+Math.PI/2,35*(1-t),6,e.color,alpha);}return;}
 for(const offset of [-.35,0,.35]){const a=e.angle+offset;bladeStreak(x+Math.cos(a)*e.r*.45,y+Math.sin(a)*e.r*.45,a,e.r*(1-t),5,e.color,alpha);}
}
