'use strict';
const ULTIMATE_AUTO_CHARGE=1.5;
const PALADIN_GUARDIAN={radius:280,healFraction:.2,damageMultiplier:1.3,duration:10};
const ULTIMATES=[
{name:'천공참',help:'전방을 크게 베고 관통 검기를 발사합니다.',windup:.65},
{name:'일점 관통',help:'3초 차징 후 거대한 관통 화살 발사. 기본 피해 105.',windup:3},
{name:'사건의 지평선',help:'6초간 적을 끌어당기며 피해를 주는 블랙홀 생성.',windup:1.1},
{name:'그림자 지배',help:'10초간 완전 은신, 치명타 확률 +15%p. 공격속도 -25%, 공격 피해 -20%.',windup:.65},
{name:'절대 수호',help:'HP가 가장 낮은 아군에게 10초 무적. 아군이 없으면 자신에게 사용.',windup:.75},
{name:'생명의 성역',help:'10초간 자신과 아군을 회복시키는 치유 장판 생성.',windup:.9},
{name:'삼연발',help:'다음 사격에 관통탄 3발 연속 발사.',windup:.6},
null,
{name:'최후의 승부',help:'가위바위보 진행. 패자 HP 50% 감소, 승자 HP 5% 회복.',windup:.65},
{name:'링',help:'적 무리로 돌진해 끌어당긴 뒤 10초간 링 생성. 로프에 닿은 적은 피해와 중앙 넉백.',windup:.65},
{name:'특대검!',help:'특대검으로 강력한 일직선 관통 충격을 발사합니다.',windup:1.5},
{name:'멀티 축소저주',help:'주변 적을 차례로 박치기해 축소 저주를 부여합니다.',windup:.85},
{name:'부셔먹기',help:'전방 최대 3명에게 강한 피해. 타격 후 HP 20% 이하인 적 처형.',windup:1.4},
{name:'왕폭탄',help:'거대 폭탄 투척. 2.5초 뒤 피해 260%의 광역 폭발과 강한 넉백.',windup:.9},
{name:'일섬',help:'적을 관통해 대시한 뒤 지나간 경로 전체를 벱니다. 피해 360%, 강한 넉백.',windup:.65},
{name:'지원포격',help:'(3 + 생존 아군 수)발의 강화 미사일 발사. 각 피해 180%.',windup:.8},
{name:'수호신',help:'주변 아군 HP 20% 회복, 10초간 공격 피해 +30%.',windup:.9},
{name:'악당처단',help:'가장 많은 피해를 준 적에게 돌진해 강한 펀치. 피해 420%, 강한 넉백.',windup:.65},
{name:'화염포',help:'다음 포탄 피해 170%, 폭발 범위 증가. 적중 지점에 5초 화염 장판.',windup:.8},
{name:'신앙심',help:'성자의 궁극기 게이지 +20%p.',windup:.7},
{name:'방출',help:'주변 적에게 피해 260%, 넉백, 감전 2중첩.',windup:.9},
{name:'반사',help:'3초간 모든 공격을 무효화하고 같은 위력의 빛탄으로 반사합니다.',windup:.45},
{name:'지평선',help:'가까운 적에게 7초간 추적 블랙홀 부여. 블랙홀 주변 아군 투사체를 시계방향으로 강하게 끌어당깁니다.',windup:.9},
{name:'빠른 장전',help:'탄창이 비면 안전한 방향으로 대시하며 즉시 20발 재장전.',windup:.25},
{name:'낼름 퉤',help:'죽기 직전 아군을 무적으로 삼킨 뒤 안전한 곳으로 뱉습니다. HP 10% 회복.',windup:.2},
{name:'조종',help:'조종의 실에 적중한 적 1명을 7초간 아군으로 만듭니다.',windup:.85}
];
let ultimateZones=[];
function resetUltimates(){ultimateZones=[];resetLightningDischarges();}
function chargeUltimate(u,damage,dealt){
 if(!u||skillChargeBlocked(u)||damage<=0)return;
 if(typeof chargeTranscendence==='function')chargeTranscendence(u,damage,dealt);
 if(!ULTIMATES[u.type]||u.ultCast)return;
 const gain=damage/u.maxHp*(dealt?65:90)*(u.type===3?1.3:u.type===0?1.2:1)*ultimateChargeEfficiency(u);
 gainUltimate(u,gain);
}
function skillChargeBlocked(u){return !u||u.hp<=0||u.stun>0||!!u.puppetControl||(u.rootTime??0)>0||(u.bindTime??0)>0||(u.snareTime??0)>0||(u.rootedUntil??0)>elapsed||frogUnavailable(u)||duelLocked(u)||crowdControlRemaining(u)>0;}
function gainUltimate(u,gain){if(skillChargeBlocked(u)||!ULTIMATES[u.type]||u.ultCast||gain<=0)return 0;const before=u.ultGauge??0;u.ultGauge=clamp(before+gain,0,100);return u.ultGauge-before;}
function ultimateChargeEfficiency(u){return ((u.type===3&&u.shadowTime>0||u.type===4&&u.guardianUltTime>0)?.2:1)*combatFatigueFactor(u,'charge');}
function advanceAutomaticUltimate(u,dt){if(u.frogAction||dt<=0)return;gainUltimate(u,ULTIMATE_AUTO_CHARGE*dt*ultimateChargeEfficiency(u));}
function criticalChance(u,target){return clamp(u.critChance+(u.type===3&&target.hp>=target.maxHp?.1:0)+(u.type===3&&u.shadowTime>0?.15:0),0,1)}
function attackHit(target,damage,source,options={}){const crit=Math.random()<criticalChance(source,target);return hit(target,damage*championAttackFactor(source)*(crit?1.5:1),source,{...options,crit})}
function advanceUltimateTimers(u,dt){u.mirrorReflectTime=Math.max(0,(u.mirrorReflectTime??0)-dt);u.invincible=Math.max(0,u.invincible-dt);u.shadowTime=Math.max(0,u.shadowTime-dt);u.guardianUltTime=Math.max(0,(u.guardianUltTime??0)-dt);u.paladinBlessingTime=Math.max(0,(u.paladinBlessingTime??0)-dt);u.ultThink-=dt;if(u.ultGauge>=100)u.ultReadyAge+=dt;else u.ultReadyAge=0}
function considerUltimate(u,enemies,allies){if(frogUnavailable(u)||u.frogAction||u.type===24)return;if(areaOffenseBlocked(u)&&!u.strategyUltimateReady&&![4,5,16,19,21,23].includes(u.type))return;if(basicParryPerfect(u)||u.ai.response?.mode==='parry')return;if(typeof strategyBlocksAttack==='function'&&strategyBlocksAttack(u))return;if(u.heroRescue||u.machineGunDash||u.bomberRush||!ULTIMATES[u.type]||duelLocked(u)||novelLocked(u)||u.type===10&&u.lostSword)return;if(u.ultGauge<100||u.ultThink>0||u.ultCast||u.attack||u.stun>0||u.evadeTime>0)return;u.ultThink=random(.35,.95);const target=u.type===22?enemies.slice().sort((a,b)=>dist(u,a)-dist(u,b))[0]:u.type===17?heroVillainTarget(u,enemies):enemies.find(e=>e.id===u.targetId)||enemies.slice().sort((a,b)=>dist(u,a)-dist(u,b))[0],hurt=u.hp/u.maxHp,urgent=u.ultReadyAge>4;let ready=false,patient=null;
if(u.type===0)ready=!!target&&(dist(u,target)<200||(urgent&&dist(u,target)<480));
if(u.type===1)ready=!!target&&(dist(u,target)>120||hurt<.3||urgent);
if(u.type===2)ready=!!target&&(enemies.filter(e=>dist(e,target)<210).length>=2||hurt<.55||urgent);
if(u.type===3)ready=!!target&&(dist(u,target)<280||hurt<.6||urgent);
if(u.type===4){patient=weakestAlly(u,allies)||u;ready=patient.hp/patient.maxHp<.65||enemies.some(e=>dist(e,patient)<170)||urgent;if(patient.invincible>0)ready=false}
if(u.type===5)ready=[u,...allies].some(v=>dist(u,v)<180&&v.hp/v.maxHp<.75)&&(!!target||urgent);
if(u.type===6)ready=!!target&&!u.sniperBurstReady;
if(u.type===8)ready=enemies.some(e=>dist(u,e)<230&&!duelLocked(e)&&e.invincible<=0);
if(u.type===9)ready=!!target&&(enemies.filter(e=>dist(e,target)<240).length>=2||dist(u,target)<380||urgent);
if(u.type===10)ready=!!target&&(dist(u,target)<430||urgent);
if(u.type===11)ready=!!target&&(enemies.filter(e=>dist(u,e)<300*unitScale(u)).length>=2||urgent);
if(u.type===12)ready=!!target&&dist(u,target)<175*unitScale(u)&&(enemies.filter(e=>dist(u,e)<200*unitScale(u)).length>=2||target.hp/target.maxHp<.5||urgent);
if(u.type===13)ready=!!target&&dist(u,target)<420&&(enemies.filter(e=>dist(e,target)<210).length>=2||hurt<.5||urgent);
if(u.type===14)ready=!!target&&dist(u,target)<560;
if(u.type===15)ready=enemies.some(e=>dist(u,e)<520);
if(u.type===16)ready=!paladinNeedsRally(u,allies)&&([u,...allies].some(v=>dist(u,v)<PALADIN_GUARDIAN.radius*unitScale(u)&&(v.hp/v.maxHp<.8||enemies.some(e=>dist(e,v)<200)))||urgent);
if(u.type===17)ready=!!target&&dist(u,target)<720;
if(u.type===18)ready=!!target&&!u.tankFlameReady;
if(u.type===25)ready=!!target&&dist(u,target)<530&&!target.puppetControl;
if(u.type===23){if(u.ammo>0||u.reloadRemaining<=.4)return;ready=true;}
if(u.type===22)ready=!!target&&dist(u,target)<450;
if(u.type===21)ready=!!target&&(u.mirrorReflectTime??0)<=0&&(!!projectileThreat(u)||enemies.some(e=>e.attack?.phase==='windup'&&e.attack.targetId===u.id||e.ultCast?.targetId===u.id)||hurt<.55&&dist(u,target)<260||urgent);
if(u.type===19){patient=fanaticSaint(u);ready=!!patient&&!!ULTIMATES[patient.type]&&patient.ultGauge<100&&!patient.ultCast;if(!ready)return;}
if(u.type===20)ready=enemies.some(e=>dist(u,e)<250*unitScale(u))&&(enemies.filter(e=>dist(u,e)<280*unitScale(u)).length>=2||hurt<.6||urgent);
if(u.type===18&&u.tankFlameReady)return;
if(u.strategyUltimateReady&&(target||u.type===4||u.type===5)&&!(u.type===16&&paladinNeedsRally(u,allies)))ready=true;if(!ready)return;u.strategyUltimateReady=false;const cluster=u.type===9?ringTarget(u,enemies):target;const angle=cluster?aimDirection(u,cluster):u.face;u.ultCast={t:0,angle,duration:ULTIMATES[u.type].windup,targetId:patient?.id??target?.id,point:cluster?{x:clamp(cluster.x+cluster.vx*.4,u.type===9?175:28,u.type===9?625:772),y:clamp(cluster.y+cluster.vy*.4,u.type===9?175:28,u.type===9?625:772)}:{x:u.x,y:u.y}};if(u.type!==18)u.face=angle;u.ultGauge=0;u.ultReadyAge=0;u.vx=0;u.vy=0;u.headingX=0;u.headingY=0;u.kx*=.2;u.ky*=.2;u.ultUses++;u.action='궁극기 준비 · '+ULTIMATES[u.type].name;fx('charge',u.x,u.y,u.color,u.ultCast.duration,{r:100,unitId:u.id});floatText(u,ULTIMATES[u.type].name,'#f4dbff');addLog(`${u.name} · 궁극기 ${ULTIMATES[u.type].name}`)}
function ultimateProjectile(u,a,kind,damage,speed,radius){projectiles.push({x:u.x+Math.cos(a.angle)*42,y:u.y+Math.sin(a.angle)*42,vx:Math.cos(a.angle)*speed,vy:Math.sin(a.angle)*speed,source:u,color:kind==='giantArrow'?'#eaff97':'#ffccaa',damage,life:3,type:u.type,trail:[],bouncesRemaining:0,ultimate:kind,radius:radius*unitScale(u),visualScale:unitScale(u),impulse:460,hitIds:new Set(),homing:false,guaranteed:false,hiddenLaunch:isConcealed(u)})}
function advanceUltimateCast(u,dt){const a=u.ultCast;if(!a)return;if(u.hp<=0){u.ultCast=null;return}if(u.stun>0){u.action='기절 · 궁극기 준비 중단';return}a.t+=dt;if(u.type!==18)u.face=a.angle;u.action='궁극기 준비 · '+ULTIMATES[u.type].name;if(a.t<a.duration)return;
if(u.type===25)launchPuppetControl(u,a);
if(u.type===23)startMachineGunReloadDash(u);
if(u.type===22)createGalaxyHorizon(u,a);
if(u.type===21)startMirrorReflection(u);
if(u.type===19)releaseFaithPrayer(u,a);
if(u.type===20)releaseLightningDischarge(u,a);
if(u.type===17){if(!advanceHeroUltimate(u,a,dt))return;}
if(u.type===18){u.tankFlameReady=true;fx('tankLoad',u.x,u.y,'#ffb96d',.5,{unitId:u.id,r:65});}
if(u.type===14){if(!advanceBladeDash(u,a,dt))return;}
if(u.type===16)releasePaladinGuardian(u);
if(u.type===15)launchSatelliteSalvo(u,3+alive().filter(v=>v.id!==u.id&&v.faction===u.faction).length,u.dmg*1.8,true);
if(u.type===11){if(!advanceDolphinUltimate(u,a,dt))return;}
if(u.type===13)throwBomb(u,a,true);
if(u.type===12)releasePredatorBite(u,a,true);
if(u.type===10)launchGreatImpact(u,a);
if(u.type===9){if(!advanceRingRush(u,a,dt))return;createRing(u);}
if(u.type===0){spawnMeleeStrike(u,{...a,serial:++u.attackSerial,profile:{reach:215,cone:1.5,active:.3,impulse:480},hiddenLaunch:isConcealed(u)},u.dmg*2.8,true);ultimateProjectile(u,a,'swordWave',u.dmg*2.3,390,48)}
if(u.type===1)ultimateProjectile(u,a,'giantArrow',u.dmg*7,590,64);
if(u.type===2)ultimateZones.push({kind:'blackhole',source:u,x:clamp(a.point.x,70,730),y:clamp(a.point.y,70,730),r:195*unitScale(u),life:6,max:6,tick:0,pulse:0});
if(u.type===3){u.shadowTime=10;fx('smoke',u.x,u.y,u.color,1.5,{r:180})}
if(u.type===4){u.guardianUltTime=10;const ally=units.find(v=>v.id===a.targetId&&v.hp>0&&v.faction===u.faction)||weakestAlly(u,alive().filter(v=>v.faction===u.faction))||u;ally.invincible=10;fx('healBeam',u.x,u.y,'#ffeaa3',.8,{tx:ally.x,ty:ally.y});floatText(ally,'절대 수호 · 10초','#ffeaa3')}
if(u.type===5)ultimateZones.push({kind:'healing',source:u,x:u.x,y:u.y,r:175*unitScale(u),life:10,max:10,tick:0,pulse:0});
if(u.type===6)u.sniperBurstReady=true;
if(u.type===8)startGrapple(u,true);
if(![14,17,18,19,20,21,22,25].includes(u.type)){impact(u.x,u.y,u.color,2.6,a.angle);burst(u.x,u.y,'#fff5db',50,390);}u.ultCast=null;u.cooldown=Math.max(u.cooldown,.6);u.ai.disengageUntil=elapsed+random(.45,.95);u.action='궁극기 발동';}
function advanceUltimateZones(dt){advanceLightningDischarges(dt);for(let i=ultimateZones.length-1;i>=0;i--){const z=ultimateZones[i];z.life-=dt;if(z.kind==='galaxy'){advanceGalaxyZone(z,dt);if(z.life<=1e-8)ultimateZones.splice(i,1);continue;}if(z.kind==='tankFire'){advanceTankFire(z,dt);if(z.life<=1e-8)ultimateZones.splice(i,1);continue;}z.tick+=dt;z.pulse+=dt;if(z.kind==='ring'){advanceRingZone(z,dt);if(z.life<=0)ultimateZones.splice(i,1);continue;}for(const v of alive()){const d=dist(v,z);if(z.kind==='blackhole'&&!frogUnavailable(v)&&!isBladeDashing(v)&&v.faction!==z.source.faction&&d<z.r&&v.invincible<=0&&(v.mirrorReflectTime??0)<=0&&v.evadeTime<=0&&!basicParryPerfect(v)){const strength=(1-d/z.r)*145,dx=(z.x-v.x)/(d||1),dy=(z.y-v.y)/(d||1);v.x=clamp(v.x+dx*strength*dt,28,772);v.y=clamp(v.y+dy*strength*dt,28,772)}}if(z.tick>=.5){z.tick-=.5;for(const v of alive()){if(dist(v,z)>z.r)continue;if(z.kind==='healing'&&v.faction===z.source.faction){const amount=restoreCombatHp(v,v.id===z.source.id?1.75:2.5,z.source);if(amount>0){fx('heal',v.x,v.y,'#a4ffcd',.5,{r:42})}}else if(z.kind==='blackhole'&&v.faction!==z.source.faction)hit(v,4,z.source,{impulse:0,attackOrigin:z})}}if(z.life<=0)ultimateZones.splice(i,1)}}
