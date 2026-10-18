'use strict';
// Session-only tower: rooms reveal on entry; clearing half a floor unlocks the next.
const TOWER_KINDS={shop:{name:'상점',icon:'🛒',help:'골드로 아이템 구매'},recruit:{name:'길드원 모집',icon:'🤝',help:'무작위 세 종류 · 토큰으로 개별 영입'},rest:{name:'길드 휴식소',icon:'⛺',help:'플레이어 또는 길드원 회복'},event:{name:'이벤트',icon:'❓',help:'보급품 하나 선택'},battle:{name:'전투',icon:'⚔️',help:'AI 전투 · 승리 보상'},miniboss:{name:'미니보스',icon:'💀',help:'강한 적 · 더 큰 보상'},boss:{name:'보스',icon:'👑',help:'챕터 보스 전투'}};
const TOWER_RECRUIT_REROLL_COST=200,TOWER_RETREAT_TIME=20;
const TOWER_EVENT_INFO={prediction:{name:'전투 예측',icon:'🎲'},promotion:{name:'승급',icon:'⭐️'},hotSpring:{name:'온천',icon:'♨️'},supply:{name:'보물상자',icon:'🎁'}};
const HOT_SPRING_COST=200,HOT_SPRING_REWARDS=['item','items','gold250','tokens','gold500','strategy','unit','gold100','gold300'];
const TOWER_CHAPTER_FLOORS=5,TOWER_CHAPTERS=3,TOWER_DEPTH=TOWER_CHAPTER_FLOORS*TOWER_CHAPTERS;
const TOWER_BASE_ROOMS=6;
const TOWER_ROOM_GROWTH_FLOORS=3;
function towerRoomCount(depth){return TOWER_BASE_ROOMS+Math.floor(Math.max(0,depth)/TOWER_ROOM_GROWTH_FLOORS);}
const TOWER_ITEMS=[
 {id:'vital',name:'생명의 부적',icon:'💚',cost:90,help:'최대 HP +20%',hp:1.2,dmg:1,speed:1},
 {id:'fang',name:'날카로운 송곳니',icon:'🦷',cost:100,help:'공격력 +15%',hp:1,dmg:1.15,speed:1},
 {id:'boots',name:'바람 장화',icon:'👟',cost:80,help:'이동속도 +10%',hp:1,dmg:1,speed:1.1},
 {id:'reengrave',name:'재각인',icon:'🔄',cost:120,help:'선택한 유닛의 장비를 모두 회수 · 일회성',consumable:true},
 {id:'greenNecklace',name:'초록 목걸이',icon:'📿',cost:110,help:'주는 치유 · 받는 치유 +10%',healingPower:1.1},
 {id:'goldToken',name:'황금 토큰',icon:'🟡',cost:120,help:'참전 후 생존하여 승리하면 🪙 +40G',victoryGold:40},
 {id:'vigorTotem',name:'원기 토템',icon:'🌿',cost:160,help:'5초마다 주변 아군 HP 6 회복 · 자신은 3.6 회복',totem:true},
 {id:'chargeTotem',name:'충전 토템',icon:'🔋',cost:180,help:'4초마다 주변 아군 궁극기 +4% · 자신은 +2.4%',chargeTotem:true},
 {id:'predatorFang',name:'포식자의 엄니',icon:'🦷',cost:200,help:'처치마다 이 유닛의 공격력 영구 +1.5%',killGrowth:true},
 {id:'thickAwl',name:'굵은 송곳',icon:'📌',cost:180,help:'새 전투 시작 시 오른쪽으로 송곳 투척 · 적중한 적 1명 4초 기절. 후퇴한 방 재전투에서는 발동하지 않습니다.',openingAwl:true}
];
let tower=null,towerRosterBackup=null,towerSelectedUnitId=null,towerPlacementUnitId=null,towerShopTab='inventory',towerPredictionContext=null;
const TOWER_DEATH_HP_RATE=.05,TOWER_CONQUEST_HEAL_RATE=.1,TOWER_CONQUEST_ENERGY=1,TOWER_REVIVE_LIMIT=2;
function towerConquestHealing(){return tower.maxHp*TOWER_CONQUEST_HEAL_RATE;}
let towerScenes={active:null,queue:[]};
let towerRetreat=null;
function towerRetreatActive(){return !!towerRetreat;}
function resetTowerRetreat(){const state=towerRetreat;towerRetreat=null;$('towerRetreatScene').hidden=true;delete $('battleScreen').dataset.retreat;for(const entry of state?.controls??[])entry.element.disabled=entry.disabled;}
function towerRetreatScale(){if(!towerRetreat)return 1;const p=clamp(towerRetreat.t/1.3,0,1);return 1-p*p*(3-2*p);}
function advanceTowerRetreat(wallDt){
 if(!towerRetreat)return false;const state=towerRetreat;if(state.run!==tower||screen!=='battle'){resetTowerRetreat();return false;}
 state.t+=Math.max(0,wallDt);const slow=Math.min(Math.max(0,wallDt),.1)*towerRetreatScale();advancePresentation(slow);advanceKillPresentation(slow);
 // The accepted retreat is already saved. Continue visual motion without new damage or decisions.
 for(const u of units){if(u.hp>0){const velocity=state.motion.get(u.id);u.x=clamp(u.x+velocity.x*slow,28,772);u.y=clamp(u.y+velocity.y*slow,28,772);}u.flash=Math.max(0,u.flash-slow);if(u.attack){const a=u.attack,limit=a.profile?.[a.phase]??a.t;a.t=Math.min(limit,a.t+slow);}if(u.ultCast)u.ultCast.t=Math.min(u.ultCast.duration,u.ultCast.t+slow);}
 for(const p of projectiles){p.x+=p.vx*slow;p.y+=p.vy*slow;p.life=Math.max(0,p.life-slow);}
 for(const strike of meleeStrikes){strike.age=Math.min(strike.duration,strike.age+slow);strike.life=Math.max(0,strike.life-slow);}
 $('towerRetreatScene').style.opacity=String(clamp(state.t/1.25,0,1));const text=$('towerRetreatSceneTitle');text.style.opacity=String(clamp((state.t-.25)/.5,0,1));text.style.transform=reducedMotion?'none':`translateY(${(1-clamp(state.t/.7,0,1))*8}px)`;
 if(state.t>=state.duration){const destination=state.destination,push=state.push;resetTowerRetreat();if(destination)showScreen(destination,push);}
 return true;
}
// Player HP exhaustion ends the run immediately; only visual motion continues while fading.
let towerHpGameOver=null;
function towerHpGameOverActive(){return !!towerHpGameOver;}
function resetTowerHpGameOver(){const state=towerHpGameOver;towerHpGameOver=null;$('towerGameOverScene').hidden=true;delete $('battleScreen').dataset.gameover;for(const entry of state?.controls??[])entry.element.disabled=entry.disabled;}
function towerHpGameOverScale(){if(!towerHpGameOver)return 1;const p=clamp(towerHpGameOver.t/1.45,0,1);return 1-p*p*(3-2*p);}
function beginTowerHpGameOver(){
 if(gameKind!=='tower'||!tower||tower.hp>0||tower.hpGameOverShown||screen!=='battle')return false;
 if(typeof resetTranscendence==='function')resetTranscendence();tower.hpGameOverShown=true;tower.gameOverReason='hp';
 if(tower.phase==='battle')settleTowerBattle(false,true);
 tower.gameOver=true;tower.phase='gameover';resetTowerStances();if(tower.result)tower.result.gameOver=true;
 resetTowerRetreat();resetTowerScenes();closeTurningPoint();cancelAllDuels();running=false;paused=false;finished=true;accumulator=0;hitStop=0;
 cinema.intro=cinema.anticipation=cinema.ending=0;cinema.confirmed=false;$('battleIntro').hidden=$('cinemaBars').hidden=$('winner').hidden=true;
 for(const id of ['battleDetails','unitStrategy','characterInfo'])if($(id).open)$(id).close();
 const elements=[$('homeLogo'),$('returnSetup'),$('rematch'),$('pause'),$('showStatus'),...document.querySelectorAll('[data-speed]')],controls=elements.map(element=>({element,disabled:!!element.disabled}));for(const element of elements)element.disabled=true;
 const motion=new Map(units.map(u=>{const vx=(u.vx??0)+(u.kx??0),vy=(u.vy??0)+(u.ky??0),limit=Math.min(1,Math.max(300,u.moveSpeed*2)/(Math.hypot(vx,vy)||1));return[u.id,{x:vx*limit,y:vy*limit}];}));
 towerHpGameOver={run:tower,t:0,duration:2.8,motion,controls};$('battleScreen').dataset.gameover='true';$('towerGameOverScene').style.opacity='0';$('towerGameOverScene').hidden=false;$('towerGameOverSceneTitle').style.opacity='0';$('towerGameOverSceneHp').textContent='💚 0 / '+tower.maxHp;$('stateLabel').textContent='게임오버';renderTowerBattleHud();return true;
}
function advanceTowerHpGameOver(wallDt){
 if(!towerHpGameOver)return false;const state=towerHpGameOver;if(state.run!==tower||screen!=='battle'){resetTowerHpGameOver();return false;}
 const dt=Math.min(Math.max(0,wallDt),.1),before=towerHpGameOverScale();state.t+=dt;const slow=dt*(before+towerHpGameOverScale())*.5;
 if(slow>0){advancePresentation(slow);advanceKillPresentation(slow);
  for(const u of units){if(u.hp>0){const v=state.motion.get(u.id);u.x=clamp(u.x+v.x*slow,28,772);u.y=clamp(u.y+v.y*slow,28,772);}u.flash=Math.max(0,u.flash-slow);if(u.attack){const a=u.attack;a.t=Math.min(a.profile?.[a.phase]??a.t,a.t+slow);}if(u.ultCast)u.ultCast.t=Math.min(u.ultCast.duration,u.ultCast.t+slow);}
  for(const p of projectiles){p.x+=p.vx*slow;p.y+=p.vy*slow;p.life=Math.max(0,p.life-slow);}for(const strike of meleeStrikes){strike.age=Math.min(strike.duration,strike.age+slow);strike.life=Math.max(0,strike.life-slow);}
 }
 $('towerGameOverScene').style.opacity=String(clamp(state.t/1.6,0,1));const title=$('towerGameOverSceneTitle');title.style.opacity=String(clamp((state.t-.4)/.6,0,1));title.style.transform=reducedMotion?'none':`translateY(${(1-clamp(state.t/1.2,0,1))*10}px)`;
 if(state.t>=state.duration){resetTowerHpGameOver();meleeStrikes=[];projectiles=[];for(const u of units){u.attack=null;u.ultCast=null;}showScreen('tower');}
 return true;
}
function resetTowerScenes(){towerScenes={active:null,queue:[]};$('towerScene').hidden=true;}
function queueTowerScene(scene){
 if(scene.kind==='entry'){towerScenes.queue=towerScenes.queue.filter(s=>s.kind!=='entry');if(towerScenes.active?.kind==='entry')towerScenes.active=null;}
 towerScenes.queue.push({...scene,run:tower,t:0,duration:scene.kind==='chapterConquest'?3.6:scene.kind==='promotion'?3:scene.kind==='conquest'?2.8:scene.kind==='recruit'?2.5:2.1});advanceTowerScenes(0);
}
function advanceTowerScenes(dt){
 const visible=!!tower&&!tower.gameOver&&(['tower','towerSetup'].includes(screen)||(screen==='battle'&&(gameKind==='tower'||hasTowerPrediction())));
 if(!visible){resetTowerScenes();return;}
 const currentScene=s=>s.run===tower&&(s.kind!=='entry'||screen==='tower')&&(s.kind!=='recruit'||screen==='tower'&&tower.phase===(s.phase??'recruit')&&s.nodeId===tower.nodeId);
 towerScenes.queue=towerScenes.queue.filter(currentScene);
 if(towerScenes.active&&!currentScene(towerScenes.active))towerScenes.active=null;
 if(!towerScenes.active){
  $('towerScene').hidden=true;if(!towerScenes.queue.length||screen==='battle'&&(running||cinema.ending>0))return;
  const scene=towerScenes.active=towerScenes.queue.shift(),overlay=$('towerScene');overlay.dataset.kind=scene.kind;
  if(scene.kind==='promotion')$('towerSceneIcon').innerHTML=`<span class="promotion-fusion"><i>${EMOJIS[scene.type]}</i><i>${EMOJIS[scene.type]}</i><i>${EMOJIS[scene.type]}</i><b>${'⭐️'.repeat(scene.stars)}</b></span>`;else $('towerSceneIcon').textContent=scene.icon;$('towerSceneTitle').textContent=scene.title;$('towerSceneReward').textContent=scene.reward??'';$('towerSceneReward').hidden=!scene.reward;
  overlay.setAttribute('role',scene.kind==='recruit'?'button':'status');overlay.tabIndex=scene.kind==='recruit'?0:-1;overlay.setAttribute('aria-label',scene.kind==='recruit'?'영입 연출 건너뛰기':'방 연출');overlay.hidden=false;
 }
 const scene=towerScenes.active;scene.t+=Math.max(0,dt);const fadeIn=.2,fadeOut=.8,opacity=Math.min(clamp(scene.t/fadeIn,0,1),clamp((scene.duration-scene.t)/fadeOut,0,1));
 $('towerScene').style.opacity=String(opacity);$('towerSceneContent').style.transform=reducedMotion?'none':`translateY(${(1-clamp(scene.t/.3,0,1))*8}px) scale(${.96+.04*clamp(scene.t/.3,0,1)})`;
 if(scene.t>=scene.duration){towerScenes.active=null;$('towerScene').hidden=true;}
}
function towerRoomIcon(node){return TOWER_EVENT_INFO[node.eventType]?.icon??TOWER_KINDS[node.kind].icon;}
function skipTowerRecruitScene(e){
 if(towerScenes.active?.kind!=='recruit')return false;
 e?.preventDefault();e?.stopPropagation();towerScenes.active=null;$('towerScene').hidden=true;advanceTowerScenes(0);return true;
}
const TOWER_FLOOR_BONUSES={heal:{icon:'💚',name:'모든 유닛 HP +20%'},item:{icon:'🎁',name:'무작위 아이템 1개'},tokens:{icon:'💎',name:'토큰 +2'}};
function towerFloorReward(depth){
 if(!tower?.route[depth])return null;tower.floorRewards??={};
 return tower.floorRewards[depth]??=(()=>{const kind=['heal','item','tokens'][Math.floor(Math.random()*3)];return{kind,...(kind==='item'?{itemKind:TOWER_ITEMS[Math.floor(Math.random()*TOWER_ITEMS.length)].id}:{})};})();
}
function openTowerFloorReward(depth){
 const reward=towerFloorReward(depth);if(!reward)return false;const p=towerFloorProgress(depth),received=tower.conqueredFloors.includes(depth),bonus=TOWER_FLOOR_BONUSES[reward.kind];
 $('towerConquestTitle').textContent=(depth+1)+'층 정복 보상';
 $('towerConquestContent').innerHTML=`<div class="conquest-progress"><b>${p.cleared} / ${p.total}방 정복</b><span>${Math.round(p.cleared/p.total*100)}%</span><div role="progressbar" aria-label="층 정복 진행도" aria-valuemin="0" aria-valuemax="${p.total}" aria-valuenow="${p.cleared}"><i style="width:${p.cleared/p.total*100}%"></i></div></div><ul class="conquest-rewards"><li><span>💚</span><b>플레이어 HP +10%</b></li><li><span>⚡</span><b>모든 유닛 기력 +1</b></li><li><span>${bonus.icon}</span><b>${bonus.name}</b><small>추가 보상</small></li></ul><p class="conquest-status ${received?'received':''}">${received?'✓ 보상 지급 완료':'모든 방 정복 시 자동 지급'}</p><small class="conquest-unlock">다음 층 해금: ${p.required}방 클리어${towerChapterFloor(depth)===TOWER_CHAPTER_FLOORS?' · 보스 격파 필요':''}</small>`;
 $('towerConquest').showModal();return true;
}
function healTowerMemberHp(m,base,revive=false){
 if(!m||m.hp<=0&&!revive||base<=0)return 0;const stats=towerMemberStats(m),amount=Math.min(Math.max(0,stats.hp-m.hp),healingAmount(base,null,stats));m.hp+=amount;return amount;
}
function healTowerGuild(amount,livingOnly=false){for(const m of tower.guild){if(livingOnly&&m.hp<=0)continue;const dead=m.hp<=0;healTowerMemberHp(m,towerMemberStats(m).hp*amount,!livingOnly);if(dead&&m.hp>0){m.state.bomberRush=false;m.state.bomberRushTime=0;m.state.bomberFuse=null;}}}
function rewardTowerFloorConquest(depth){
 const progress=towerFloorProgress(depth);tower.conqueredFloors??=[];
 if(!progress.total||progress.cleared!==progress.total||tower.conqueredFloors.includes(depth))return false;
 const bonus=towerFloorReward(depth);tower.conqueredFloors.push(depth);const before=tower.hp;tower.hp=Math.min(tower.maxHp,tower.hp+towerConquestHealing());
 for(const m of tower.guild)m.energy=clamp(m.energy+TOWER_CONQUEST_ENERGY,0,TOWER_MAX_ENERGY);
 if(bonus.kind==='heal')healTowerGuild(.2);else if(bonus.kind==='item')tower.inventory.push({id:tower.nextItemId++,kind:bonus.itemKind,equippedTo:null});else awardTowerResources(0,2,towerActionPoint('[data-conquest-reward="'+depth+'"]'));
 queueTowerScene({kind:'conquest',icon:'👑',title:(depth+1)+'층 정복',reward:(tower.hp>before?'💚 HP +'+(tower.hp-before):'💚 HP 최대')+' · ⚡ 기력 +1\n'+TOWER_FLOOR_BONUSES[bonus.kind].name});
 return true;
}
function conquerTowerChapter(depth){
 const rooms=tower?.route[depth];if(!rooms||towerChapterFloor(depth)!==TOWER_CHAPTER_FLOORS||!rooms.some(node=>node.kind==='boss'&&node.cleared))return false;
 const chapter=Math.floor(depth/TOWER_CHAPTER_FLOORS)+1;tower.conqueredChapters??=[];
 if(tower.conqueredChapters.includes(chapter))return false;
 tower.conqueredChapters.push(chapter);
 queueTowerScene({kind:'chapterConquest',icon:'👑',title:chapter+'챕터 정복',reward:(depth+1)+'층 보스 격파'});
 return true;
}
const TOWER_FORMATIONS=['전열','분산','쌍익','포위','밀집'];
function assignTowerEnemyLevels(enemies,depth){
 const average=towerAverageEnemyLevel(depth),levels=Array(enemies.length).fill(average);
 // Balanced variation preserves a strictly increasing average on every floor.
 if(average>0)for(let i=0;i+1<levels.length;i+=2)if(i===0||Math.random()<.65){levels[i]--;levels[i+1]++;}
 for(let i=levels.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[levels[i],levels[j]]=[levels[j],levels[i]];}
 enemies.forEach((enemy,i)=>enemy.enemyLevel=levels[i]);
}
function towerAverageEnemyLevel(depth){return Math.max(0,Math.round(depth*1.6));}
function towerEnemyCount(kind,depth){if(kind==='boss')return Math.min(7,4+Math.floor(depth/5)+Math.floor(Math.random()*2));if(kind==='miniboss')return Math.min(6,2+Math.floor(depth/6)+Math.floor(Math.random()*2));return Math.min(12,3+Math.floor(depth*.7)+Math.floor(Math.random()*2));}
function towerPickEnemy(pool,chosen,depth){const available=pool.filter(type=>TYPES[type]&&chosen.filter(v=>v.type===type).length<2),fresh=available.filter(type=>!chosen.some(v=>v.type===type)),options=fresh.length&&Math.random()<.68?fresh:available;
 const weighted=options.map(type=>({type,weight:depth<3?Math.max(.35,180/TYPES[type].cost):1}));let roll=Math.random()*weighted.reduce((n,p)=>n+p.weight,0);for(const option of weighted){roll-=option.weight;if(roll<=0)return option.type;}return weighted.at(-1).type;}
function towerEnemyProfile(type,rank='normal'){const boss=rank==='boss',elite=rank==='elite';return{type,towerEnemy:true,towerBoss:boss,towerElite:boss||elite,towerBodyScale:boss?1.85:elite?1.5:1,enemyHpMultiplier:boss?3.6:elite?2.5:1,enemyDamageMultiplier:boss?2.15:elite?1.65:1,enemyDefenseMultiplier:boss?2:elite?1.5:1,enemySpeedMultiplier:boss?1.12:elite?1.08:1};}
function towerEnemyPosition(enemy,index,count,formation,placed){const radius=27*enemy.towerBodyScale,minX=415+radius,maxX=780-radius,minY=28+radius,maxY=772-radius,front=TYPES[enemy.type].range<100,valid=point=>point.x>=minX&&point.x<=maxX&&point.y>=minY&&point.y<=maxY&&placed.every(p=>dist(p,point)>=radius+27*p.towerBodyScale+18);
 for(let attempt=0;attempt<160;attempt++){let x=random(minX,maxX),y=random(minY,maxY);if(attempt<90){if(formation==='전열'){x=front||enemy.towerBoss?random(minX,minX+85):random(maxX-95,maxX);y=65+(index+.5)*670/count+random(-55,55);}else if(formation==='쌍익'){x=random(minX,maxX);y=(index%2?590:205)+random(-95,95);}else if(formation==='포위'){const angle=-1.22+(index+.5)/count*2.44+random(-.1,.1),r=random(260,335);x=400+Math.cos(angle)*r;y=400+Math.sin(angle)*r;}else if(formation==='밀집'){x=(index%2?660:520)+random(-65,65);y=(index%2?555:235)+random(-95,95);}}
 const point={x:clamp(x,minX,maxX),y:clamp(y,minY,maxY)};if(valid(point))return point;}
 const candidates=[];for(let x=minX;x<=maxX;x+=24)for(let y=minY;y<=maxY;y+=24){const point={x,y};if(valid(point))candidates.push(point);}if(!candidates.length)throw Error('적 배치 공간이 부족합니다.');return candidates[Math.floor(Math.random()*candidates.length)];}
function createTowerEncounter(kind,depth){if(!['battle','miniboss','boss'].includes(kind))return{enemies:[],enemyDeployment:[],strength:1,formation:null};const count=towerEnemyCount(kind,depth),formation=TOWER_FORMATIONS[Math.floor(Math.random()*TOWER_FORMATIONS.length)],chosen=[],front=[0,3,4,7,8,9,10,11,12,14,16,17,19],ranged=[1,2,6,13,15,18,20,21,22,23,24,25],support=[4,5,15,16,17,19,24,25],all=TYPES.map((_,type)=>type);
 if(kind==='boss'){const type=towerPickEnemy([0,2,4,7,9,10,11,12,13],chosen,depth);chosen.push(towerEnemyProfile(type,'boss'));chosen.push(towerEnemyProfile(towerPickEnemy(all.filter(v=>v!==type),chosen,depth),'elite'));}else if(kind==='miniboss')chosen.push(towerEnemyProfile(towerPickEnemy(front,chosen,depth),'elite'));
 for(const pool of [front,ranged,support]){if(chosen.length>=count)break;const fresh=pool.filter(type=>!chosen.some(v=>v.type===type));chosen.push(towerEnemyProfile(towerPickEnemy(fresh.length?fresh:all.filter(type=>!chosen.some(v=>v.type===type)),chosen,depth)));}while(chosen.length<count)chosen.push(towerEnemyProfile(towerPickEnemy(all,chosen,depth)));
 assignTowerEnemyLevels(chosen,depth);const placed=[];for(let i=0;i<chosen.length;i++){const enemy=chosen[i];placed.push({...enemy,...towerEnemyPosition(enemy,i,chosen.length,formation,placed)});}return{enemies:placed.map(p=>p.type),enemyDeployment:placed,strength:.8,formation};}
function towerEnemyLevel(enemy,node=towerFloor()){return Math.max(0,Math.floor(enemy.enemyLevel??towerAverageEnemyLevel(node?.depth??0)));}
function towerEnemyStats(enemy,node=towerFloor()){
 const type=TYPES[enemy.type],level=towerEnemyLevel(enemy,node),base=.8,growth=stat=>1+level*TOWER_GROWTH[stat];
 return{hp:Math.round(type.hp*base*growth('hp')*(enemy.enemyHpMultiplier??1)),dmg:type.dmg*base*growth('dmg')*(enemy.enemyDamageMultiplier??1),speed:type.speed*base*growth('speed')*(enemy.enemySpeedMultiplier??1),defensePower:type.defensePower*base*growth('defensePower')*(enemy.enemyDefenseMultiplier??enemy.enemyDamageMultiplier??1),scale:enemy.towerBodyScale??1};
}
function towerEnemyKillReward(enemy){
 const rarity=towerRecruitCost(enemy.type)/2,level=towerEnemyLevel(enemy),factor=rarity*(1+level*.12);
 return{gold:Math.round((10+Math.floor(Math.random()*31))*factor),tokens:Math.random()<Math.min(.25,.03*factor)?1:0};
}
function towerRoomQuotas(count){
 // Round each share to whole rooms, reserving categories in the requested priority.
 const battle=Math.min(count,Math.round(count*.4)),rest=Math.min(count-battle,Math.max(1,Math.round(count*.15))),services=Math.min(count-battle-rest,clamp(Math.round(count*.25),1,4));
 return{battle,rest,services,event:count-battle-rest-services};
}
function createTowerFloorKinds(depth,count){
 const quota=towerRoomQuotas(count),chapterFloor=towerChapterFloor(depth),milestone=chapterFloor===3?'miniboss':chapterFloor===TOWER_CHAPTER_FLOORS?'boss':null;
 const combat=Array(quota.battle).fill('battle'),services=Array.from({length:quota.services},(_,i)=>i===0?'recruit':i===1?'shop':Math.random()<.5?'recruit':'shop');
 if(milestone==='miniboss')combat.shift();
 const kinds=milestone==='boss'?[...Array(quota.rest).fill('rest'),...Array(count-quota.rest-1).fill('event')]:[...combat,...Array(quota.rest).fill('rest'),...services,...Array(quota.event).fill('event')];
 // Preserve the starting floor's familiar slots while applying the same quotas.
 if(depth===0&&count===TOWER_BASE_ROOMS)return ['recruit','shop','rest','battle','event','battle'];
 for(let i=kinds.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[kinds[i],kinds[j]]=[kinds[j],kinds[i]];}
 if(milestone)kinds.splice(Math.floor(count/2),0,milestone);
 return kinds;
}
function towerChapterFloor(depth){return depth%TOWER_CHAPTER_FLOORS+1;}
function towerRoomVisible(node){return !!(node.revealed||node.public);}
// Draw on first entry so the odds reflect events actually encountered in this run.
function chooseTowerEventType(){
 const encountered=new Set(tower.route.flat().filter(node=>node.kind==='event'&&node.revealed).map(node=>node.eventType));
 const choices=Object.keys(TOWER_EVENT_INFO).map(type=>({type,weight:encountered.has(type)?1:4}));
 let roll=Math.random()*choices.reduce((sum,choice)=>sum+choice.weight,0);
 for(const choice of choices){roll-=choice.weight;if(roll<0)return choice.type;}
 return choices[choices.length-1].type;
}
function createTowerRoute(){
 return Array.from({length:TOWER_DEPTH},(_,depth)=>{const chapter=Math.floor(depth/TOWER_CHAPTER_FLOORS),count=towerRoomCount(depth),kinds=createTowerFloorKinds(depth,count);
 return kinds.map((kind,lane)=>{const combat=['battle','miniboss','boss'].includes(kind),eventType=null;return{id:depth+':'+lane,depth,lane,chapter:chapter+1,kind,eventType,shopStock:null,prediction:null,name:(depth+1)+'층 · '+(lane+1)+'번 방 • '+towerRoomLabel({kind,eventType}),revealed:false,public:kind==='miniboss'||kind==='boss',cleared:false,enemyState:{},recruitOffers:kind==='recruit'?createTowerRecruitOffers():[],...createTowerEncounter(kind,depth),reward:kind==='boss'?1000:kind==='miniboss'?700:350+depth*50,tokens:kind==='boss'?3:kind==='miniboss'?2:combat?1:0};});});
}
const TOWER_MAX_ENERGY=5,TOWER_MAX_EQUIPMENT=2,TOWER_MAX_LEVEL=10,TOWER_MAX_STARS=2,TOWER_STAR_LEVELS=40;
const TOWER_GROWTH={hp:.12,dmg:.08,defensePower:.08,speed:.02};
const VIGOR_TOTEM={interval:5,radius:165,healing:6};
const CHARGE_TOTEM={interval:4,radius:165,charge:4};
// Persist timers and counters. AI decisions and melee contacts restart on re-entry.
const TOWER_STATE_FIELDS=['cooldown','heal','totemClock','chargeTotemClock','dash','defenseCooldown','parryCooldown','parryTime','parryCounterUsed','parryPulseUsed','shieldHp','shieldTime','ironDefenseTime','stun','invincible','shadowTime','guardianUltTime','mirrorReflectTime','revealTime','curseTime','guardRemaining','guardStacks','guardReady','damageTakenTotal','dolphinStacks','predatorStacks','shotsFired','duelRounds','ammo','reloadRemaining','sniperBurstReady','ultReadyAge','ultUses','pickupTime','bomberRush','bomberRushTime','bomberFuse','transferUsed','strategyUltimateReady','satelliteBursts','paladinSwings','paladinBlessingTime','tankFlameReady','tankHeadingAngle','shockStacks','face'];
function createTowerRecruitOffers(){const pool=TYPES.map((_,type)=>type);for(let i=pool.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[pool[i],pool[j]]=[pool[j],pool[i]];}return pool.slice(0,3).map((type,slot)=>({slot,type,purchased:false}));}
function createGuildMember(type){if(!TYPES[type])throw Error('존재하지 않는 길드원입니다.');return{id:nextId++,type,level:0,stars:0,hp:TYPES[type].hp,ultGauge:0,transGauge:0,energy:TOWER_MAX_ENERGY,stance:'normal',fangKills:0,state:{}};}
function newTowerState(){return{phase:'lobby',floor:-1,unlockedFloor:0,mapScroll:0,nodeId:null,route:createTowerRoute(),visited:[],conqueredFloors:[],conqueredChapters:[],floorRewards:{},gold:1200,tokens:5,hp:100,maxHp:100,gameOver:false,guild:[0,0,1,5].map(createGuildMember),lastFormation:[],inventory:[],nextItemId:1,strategyCards:[{id:1,kind:'mango',usedDepth:null,readyFloor:0},{id:2,kind:'evade',usedDepth:null,readyFloor:0},{id:3,kind:'shield',usedDepth:null,readyFloor:0},{id:4,kind:'shield',usedDepth:null,readyFloor:0}],nextStrategyCardId:5,result:null,deathIds:new Set(),deathLoss:0,restRetry:false};}
function towerFloor(){return tower?.route.flat().find(n=>n.id===tower.nodeId);}
function isTowerCombat(node=towerFloor()){return !!node&&['battle','miniboss','boss'].includes(node.kind);}
function towerMember(id){return tower?.guild.find(m=>m.id===id);}
function towerMemberStars(m){return clamp(Math.floor(m?.stars??0),0,TOWER_MAX_STARS);}
function towerMemberName(m){return TYPES[m.type].name+(towerMemberStars(m)?' '+ '⭐️'.repeat(towerMemberStars(m)):'');}
function towerEquipmentLimit(m){return TOWER_MAX_EQUIPMENT+towerMemberStars(m);}
function towerMemberPortrait(m){return `<span class="guild-ranked-portrait">${portrait(m.type)}${towerMemberStars(m)?'<i class="guild-star-badge">'+'⭐️'.repeat(towerMemberStars(m))+'</i>':''}</span>`;}
const TOWER_RECRUIT_PREMIUM={3:3,18:4,0:2,13:4,17:4};
function towerRecruitCost(type){return TOWER_RECRUIT_PREMIUM[type]??(type===12?5:type<6?2:3);}
function towerUpgradeCost(id=towerSelectedUnitId){return 80+(towerMember(id)?.level??0)*20;}
function towerEquippedCopies(id){return tower.inventory.filter(i=>i.equippedTo===id);}
function towerEquippedItems(id){return towerEquippedCopies(id).map(copy=>TOWER_ITEMS.find(i=>i.id===copy.kind)).filter(Boolean);}
function towerEquippedCopy(id){return towerEquippedCopies(id)[0];}
function towerEquippedItem(id){return towerEquippedItems(id)[0];}
function towerAvailableItems(){return tower.inventory.filter(copy=>copy.equippedTo==null);}
function towerMemberStats(m){const type=TYPES[m.type],level=clamp(m.level,0,TOWER_MAX_LEVEL)+towerMemberStars(m)*TOWER_STAR_LEVELS,items=towerEquippedItems(m.id),factor=stat=>items.reduce((n,item)=>n*(item[stat]??1),1);return{hp:Math.round(type.hp*(1+level*TOWER_GROWTH.hp)*factor('hp')),dmg:type.dmg*(1+level*TOWER_GROWTH.dmg)*factor('dmg')*(1+(m.fangKills??0)*.015),speed:type.speed*(1+level*TOWER_GROWTH.speed)*factor('speed'),defensePower:type.defensePower*(1+level*TOWER_GROWTH.defensePower),healingPower:factor('healingPower'),victoryGold:items.reduce((n,item)=>n+(item.victoryGold??0),0),totemCount:items.filter(item=>item.totem).length,chargeTotemCount:items.filter(item=>item.chargeTotem).length,fangCount:items.filter(item=>item.killGrowth).length,openingAwlCount:items.filter(item=>item.openingAwl).length};}
function customEquipmentStats(p){
 const type=TYPES[p.type],items=customEquippedItems(p),factor=stat=>items.reduce((n,item)=>n*(item[stat]??1),1);
 return{hp:Math.round(type.hp*factor('hp')),dmg:type.dmg*factor('dmg'),speed:type.speed*factor('speed'),defensePower:type.defensePower,healingPower:factor('healingPower'),totemCount:items.filter(item=>item.totem).length,chargeTotemCount:items.filter(item=>item.chargeTotem).length,fangCount:items.filter(item=>item.killGrowth).length,openingAwlCount:items.filter(item=>item.openingAwl).length};
}
function applyCustomEquipment(){
 if(gameKind!=='custom')return;
 for(const u of units){
  const stats=customEquipmentStats(u);u.customItems=customEquippedItems(u).map(item=>item.id);u.maxHp=stats.hp;u.hp=u.maxHp;u.dmg=stats.dmg;u.moveSpeed*=stats.speed/TYPES[u.type].speed;u.healingPower=stats.healingPower;
  u.totemCount=stats.totemCount;u.totemClock=VIGOR_TOTEM.interval;u.chargeTotemCount=stats.chargeTotemCount;u.chargeTotemClock=CHARGE_TOTEM.interval;
  u.fangCount=stats.fangCount;u.openingAwlCount=stats.openingAwlCount;u.customFangKills=0;u.customEquipmentBaseDamage=u.dmg;
 }
}
function showTotemPulse(source,kind,radius){fx('totemPulse',source.x,source.y,kind==='healing'?'#6efa98':'#ffdd65',.9,{r:radius*unitScale(source),itemKind:kind});}
function showTotemReceipt(target,kind){fx('totemReceipt',target.x,target.y,kind==='healing'?'#6efa98':'#ffdd65',.65,{unitId:target.id,r:42,itemKind:kind});}
function advanceTowerEquipment(dt){
 if(dt<=0||!['tower','custom'].includes(gameKind)||gameKind==='tower'&&tower?.phase!=='battle')return;
 for(const source of alive()){
  if(gameKind==='tower'?!source.towerAlly:!source.customItems?.length)continue;
  const nearby=radius=>alive().filter(ally=>ally.faction===source.faction&&dist(source,ally)<=radius*unitScale(source));
  if(source.totemCount){source.totemClock=(source.totemClock??VIGOR_TOTEM.interval)-dt;
   while(source.totemClock<=1e-8){source.totemClock+=VIGOR_TOTEM.interval;showTotemPulse(source,'healing',VIGOR_TOTEM.radius);
    for(const ally of nearby(VIGOR_TOTEM.radius))if(restoreCombatHp(ally,VIGOR_TOTEM.healing*source.totemCount*(ally===source ? .6 : 1),source)>0)showTotemReceipt(ally,'healing');
   }
  }
  if(source.chargeTotemCount){source.chargeTotemClock=(source.chargeTotemClock??CHARGE_TOTEM.interval)-dt;
   while(source.chargeTotemClock<=1e-8){source.chargeTotemClock+=CHARGE_TOTEM.interval;showTotemPulse(source,'charge',CHARGE_TOTEM.radius);
    for(const ally of nearby(CHARGE_TOTEM.radius)){if(gainUltimate(ally,CHARGE_TOTEM.charge*source.chargeTotemCount*(ally===source ? .6 : 1)*ultimateChargeEfficiency(ally))>0)showTotemReceipt(ally,'charge');}
   }
  }
 }
}
function showFangGrowth(source){fx('itemGrowth',source.x,source.y,'#ffc18a',.7,{unitId:source.id,r:55});}
function onTowerEquipmentKill(source){
 if(gameKind==='custom'&&source?.fangCount){source.customFangKills=(source.customFangKills??0)+source.fangCount;source.strategyBaseDamage=source.customEquipmentBaseDamage*(1+source.customFangKills*.015);applyStanceStats(source);showFangGrowth(source);return;}
 if(gameKind!=='tower'||tower?.phase!=='battle'||!source.towerAlly||!source.fangCount)return;
 const member=towerMember(source.guildId);if(!member)return;member.fangKills=(member.fangKills??0)+source.fangCount;
 source.strategyBaseDamage=towerMemberStats(member).dmg;applyStanceStats(source);showFangGrowth(source);
}
function resetTowerStances(){
 if(!tower)return;for(const member of tower.guild)member.stance='normal';
 for(const p of roster)if(p.towerAlly)p.stance='normal';
 for(const u of units)if(u.towerAlly){u.stance=u.combatStance='normal';applyStanceStats(u);}
 strategyUnitId=null;if($('unitStrategy').open)$('unitStrategy').close();
}
function towerMemberReady(m){return !!m&&m.hp>0;}
function towerMissingEnergy(m){return TOWER_MAX_ENERGY-clamp(m.energy??TOWER_MAX_ENERGY,0,TOWER_MAX_ENERGY);}
function towerFatigueHelp(m){const missing=towerMissingEnergy(m);return missing?'기력 부족 · 받는 피해 +'+missing*3+'% · 피해량 −'+missing*5+'% · 궁극기 충전 −'+missing*7+'%':'';}
function ensureTowerPromotion(node=towerFloor()){
 if(node?.kind!=='event'||node.eventType!=='promotion')return null;
 node.promotion??={limit:1+Math.floor(Math.random()*3),used:0,selected:[]};return node.promotion;
}
function towerPromotionBusy(){return towerScenes.active?.kind==='promotion'||towerScenes.queue.some(s=>s.kind==='promotion');}
function towerPromotionAvailable(){const p=ensureTowerPromotion();return gameKind==='tower'&&!tower?.gameOver&&tower?.phase==='event'&&p&&p.used<p.limit&&!towerPromotionBusy();}
function towerPromotionEligible(m){return !!m&&m.hp>0&&m.level===TOWER_MAX_LEVEL&&towerMemberStars(m)<TOWER_MAX_STARS;}
function towerPromotionMembers(){return(ensureTowerPromotion()?.selected??[]).map(towerMember);}
function towerPromotionValid(){const members=towerPromotionMembers(),first=members[0];return members.length===3&&members.every(m=>towerPromotionEligible(m)&&m.type===first.type&&towerMemberStars(m)===towerMemberStars(first))&&new Set(members.map(m=>m.id)).size===3;}
function selectTowerPromotionMember(id){
 if(!towerPromotionAvailable())return false;const state=ensureTowerPromotion(),m=towerMember(id),index=state.selected.indexOf(id);
 if(index>=0){state.selected.splice(index,1);renderTowerPromotion();return true;}
 const first=towerPromotionMembers()[0];if(!towerPromotionEligible(m)||state.selected.length>=3||first&&(first.type!==m.type||towerMemberStars(first)!==towerMemberStars(m)))return false;
 state.selected.push(id);renderTowerPromotion();return true;
}
function renderTowerPromotion(){
 const scroll=$('towerBody').querySelector?.('.promotion-guild')?.scrollTop??0,state=ensureTowerPromotion(),members=towerPromotionMembers(),first=members[0],remaining=state.limit-state.used;
 renderTowerRoom(`<div class="tower-prep-heading"><div><h2>⭐️ 승급</h2><p>남은 승급 ${remaining}회</p></div><button class="secondary" data-tower-action="promotionDone">완료 · 지도로</button></div><p class="promotion-rule">같은 종류·성급의 Lv.10 유닛 3명</p><div class="promotion-selected" aria-label="승급 대상 3명">${[0,1,2].map(i=>members[i]?`<button data-promotion-member="${members[i].id}" aria-label="${towerMemberName(members[i])} 선택 해제">${towerMemberPortrait(members[i])}<small>#${members[i].id}</small></button>`:'<span class="promotion-empty">＋</span>').join('')}<span class="promotion-arrow">➜</span><div class="promotion-result">${first?towerMemberPortrait({...first,stars:towerMemberStars(first)+1}):'<span>⭐️</span>'}<small>${first?TYPES[first.type].name+' '+'⭐️'.repeat(towerMemberStars(first)+1):'승급'}</small></div></div><div class="promotion-guild" role="group" aria-label="승급할 보유 유닛 선택">${tower.guild.map(m=>{const selected=state.selected.includes(m.id),eligible=towerPromotionEligible(m)&&(!first||first.type===m.type&&towerMemberStars(first)===towerMemberStars(m)),stats=towerMemberStats(m);return `<button class="promotion-member ${selected?'selected':''}" data-promotion-member="${m.id}" aria-pressed="${selected}" ${!selected&&(!eligible||state.selected.length===3||remaining===0)?'disabled':''}>${towerMemberPortrait(m)}<b>${towerMemberName(m)}</b><small>#${m.id} · Lv.${m.level}</small><span class="unit-mini-vitals"><i class="mini-hp"><em style="width:${clamp(m.hp/stats.hp*100,0,100)}%"></em></i><i class="mini-energy"><em style="width:${m.energy/TOWER_MAX_ENERGY*100}%"></em></i></span><small>${m.hp<=0?'사망':towerMemberStars(m)===TOWER_MAX_STARS?'최고 성급':m.level<TOWER_MAX_LEVEL?'Lv.10 필요':selected?'선택됨':'승급 가능'}</small></button>`;}).join('')}</div><div class="promotion-footer"><span>${members.length} / 3명 선택${first?' · 장비 '+(towerEquipmentLimit(first)+1)+'칸':''}</span><button class="primary" data-tower-action="promote" ${!towerPromotionValid()||!remaining?'disabled':''}>승급 <span>⭐️</span></button></div>`);const grid=$('towerBody').querySelector?.('.promotion-guild');if(grid)grid.scrollTop=scroll;
}
function promoteTowerMembers(){
 if(!towerPromotionAvailable()||!towerPromotionValid())return false;
 const state=ensureTowerPromotion(),[lead,...others]=towerPromotionMembers(),oldMax=towerMemberStats(lead).hp,consumed=new Set(others.map(m=>m.id));
 // The first selected member keeps identity and equipment; consumed members return their equipment intact.
 for(const item of tower.inventory)if(consumed.has(item.equippedTo))item.equippedTo=null;
 lead.stars=towerMemberStars(lead)+1;lead.level=0;const nextMax=towerMemberStats(lead).hp;lead.hp=clamp(lead.hp+Math.max(0,nextMax-oldMax),0,nextMax);
 tower.guild=tower.guild.filter(m=>!consumed.has(m.id));tower.lastFormation=tower.lastFormation.filter(p=>!consumed.has(p.guildId));for(const node of tower.route.flat())if(node.deploymentDraft)node.deploymentDraft=node.deploymentDraft.filter(p=>!consumed.has(p.guildId));roster=roster.filter(p=>!p.towerAlly||!consumed.has(p.guildId));
 towerSelectedUnitId=lead.id;if(consumed.has(towerPlacementUnitId))towerPlacementUnitId=lead.id;state.used++;state.selected=[];
 renderTower();queueTowerScene({kind:'promotion',type:lead.type,stars:lead.stars,icon:'⭐️',title:towerMemberName(lead),reward:'승급 완료 · 장비 '+towerEquipmentLimit(lead)+'칸'});return true;
}
function finishTowerPromotion(){if(gameKind!=='tower'||tower?.gameOver||tower?.phase!=='event'||towerFloor()?.eventType!=='promotion'||towerPromotionBusy())return false;ensureTowerPromotion().selected=[];return completeTowerNode('승급 완료');}
function towerStatusLabels(m,compact=false){const s=m.state,labels=[];if(towerMissingEnergy(m))labels.push(compact?'피로 '+towerMissingEnergy(m)+'칸':towerFatigueHelp(m));if(s.shieldHp>0&&s.shieldTime>0)labels.push('보호막 '+Math.ceil(s.shieldHp)+' · '+s.shieldTime.toFixed(1)+'초');if(s.ironDefenseTime>0)labels.push('철벽방어 '+s.ironDefenseTime.toFixed(1)+'초');if(s.curseTime>0)labels.push('축소 '+s.curseTime.toFixed(1)+'초');if(s.parryTime>0)labels.push('패링 '+s.parryTime.toFixed(1)+'초');if(s.parryCooldown>0)labels.push('패링 대기 '+s.parryCooldown.toFixed(1)+'초');if(s.stun>0)labels.push('기절 '+s.stun.toFixed(1)+'초');if(s.invincible>0)labels.push('무적 '+s.invincible.toFixed(1)+'초');if(s.mirrorReflectTime>0)labels.push('반사 '+s.mirrorReflectTime.toFixed(1)+'초');if(s.shadowTime>0)labels.push('은신 '+s.shadowTime.toFixed(1)+'초 · 충전 효율 −80%');if(s.guardianUltTime>0)labels.push('수호 유지 '+s.guardianUltTime.toFixed(1)+'초 · 충전 효율 −80%');if(s.guardRemaining>0)labels.push('방어태세 '+s.guardRemaining.toFixed(1)+'초');if(s.guardStacks)labels.push('특대검 강화 '+s.guardStacks);if(s.dolphinStacks)labels.push('축소 '+s.dolphinStacks+'중첩');if(s.predatorStacks)labels.push('비늘 '+s.predatorStacks+'중첩');if(s.lostSword)labels.push('검 회수 필요');if(s.sniperBurstReady)labels.push('삼연발 준비');if(s.reloadRemaining>0)labels.push('장전 '+s.reloadRemaining.toFixed(1)+'초');if(s.retreatRemaining>0)labels.push('도주 '+s.retreatRemaining.toFixed(1)+'초');if(s.specialRemaining>0)labels.push('공격 강화 '+s.specialRemaining.toFixed(1)+'초');return labels;}
function towerNextNodes(){return tower.route.flat().filter(n=>n.depth<=tower.unlockedFloor);}
function towerFloorProgress(depth){const rooms=tower.route[depth]??[];return{cleared:rooms.filter(n=>n.cleared).length,required:Math.ceil(rooms.length/2),total:rooms.length};}
function clearTowerRoom(){
 const node=towerFloor();if(!node||node.cleared)return false;node.cleared=true;if(!tower.visited.includes(node.id))tower.visited.push(node.id);
 while(tower.unlockedFloor<TOWER_DEPTH-1){
  const depth=tower.unlockedFloor,p=towerFloorProgress(depth),bossCleared=tower.route[depth].some(room=>room.kind==='boss'&&room.cleared);
  if(p.cleared<p.required||towerChapterFloor(depth)===TOWER_CHAPTER_FLOORS&&!bossCleared)break;
  tower.unlockedFloor++;
 }
 const last=tower.route.at(-1),progress=towerFloorProgress(TOWER_DEPTH-1);tower.conquered=progress.cleared>=progress.required&&last.some(n=>n.kind==='boss'&&n.cleared);
 rewardTowerFloorConquest(node.depth);if(node.kind==='boss')conquerTowerChapter(node.depth);return true;
}
function towerGuildDefeated(){return !!tower&&tower.guild.length>0&&tower.guild.every(m=>m.hp<=0);}
function checkTowerGameOver(){
 if(!tower)return false;if(tower.hp<=0){tower.gameOverReason='hp';beginTowerHpGameOver();}if(!tower.gameOver&&tower.hp>0&&!towerGuildDefeated())return false;
 tower.gameOver=true;tower.phase='gameover';resetTowerStances();if(tower.result)tower.result.gameOver=true;return true;
}
let towerAbandonRun=null;
let towerUnitsRun=null,towerUnitsTab='guild';
function canOpenTowerUnits(){return !!tower&&gameKind==='tower'&&screen==='tower'&&tower.phase==='route'&&!tower.gameOver&&tower.hp>0;}
function towerRouteManagementActive(){return canOpenTowerUnits()&&towerUnitsRun===tower&&$('towerUnits').open;}
function canManageTowerEquipment(){return screen==='tower'&&!!tower&&!tower.gameOver&&(['prepare','shop'].includes(tower.phase)||towerRouteManagementActive());}
function closeTowerMenu(){if($('towerMenu').open)$('towerMenu').close();}
function openTowerMenu(){if(screen!=='tower'||!tower)return false;closeTowerUnits();$('towerMenu').showModal();return true;}
function closeTowerUnits(){
 if(towerUnitsRun){closeTowerItemInfo();if($('characterInfo').open)$('characterInfo').close();}
 towerUnitsRun=null;if($('towerUnits').open)$('towerUnits').close();
 // Keep currency flights above the dialog while managing a guild member.
 if($('towerFeedback').parentElement===$('towerUnits'))document.body?.appendChild?.($('towerFeedback'));
}
function closeTowerManagement(){closeTowerMenu();closeTowerUnits();}
function openTowerUnits(){
 if(!canOpenTowerUnits())return false;closeTowerMenu();towerUnitsRun=tower;towerUnitsTab='guild';$('towerUnitsMessage').textContent='';renderTowerUnits();$('towerUnits').showModal();$('towerFeedback').parentElement&&$('towerUnits').appendChild?.($('towerFeedback'));return true;
}
function renderTowerUnits(){
 if(!canOpenTowerUnits()||towerUnitsRun!==tower)return false;
 if(!towerMember(towerSelectedUnitId))towerSelectedUnitId=tower.guild[0]?.id??null;
 const content=$('towerUnitsContent'),oldStrip=content.querySelector?.('.tower-character-strip'),oldGrid=content.querySelector?.('.inventory-grid,.guild-grid'),left=oldStrip?.scrollLeft??0,top=oldGrid?.scrollTop??0;
 renderTowerWallet('towerUnitsWallet');for(const button of document.querySelectorAll('[data-unit-tab]'))button.setAttribute('aria-selected',button.dataset.unitTab===towerUnitsTab);
 content.innerHTML=(towerUnitsTab==='guild'?'':towerCharacterStrip())+'<div id="towerUnitsPane" class="tower-shop-detail" role="tabpanel" aria-labelledby="towerUnitTab-'+towerUnitsTab+'"></div>';
 renderTowerShop($('towerUnitsPane'),towerUnitsTab);const strip=content.querySelector?.('.tower-character-strip'),grid=content.querySelector?.('.inventory-grid,.guild-grid');if(strip)strip.scrollLeft=left;if(grid)grid.scrollTop=top;return true;
}
$('openTowerMenu').onclick=openTowerMenu;$('closeTowerMenu').onclick=closeTowerMenu;$('openTowerUnits').onclick=openTowerUnits;$('closeTowerUnits').onclick=closeTowerUnits;
$('towerUnits').addEventListener('cancel',closeTowerUnits);$('towerUnits').addEventListener('close',closeTowerUnits);
$('towerUnits').addEventListener('click',e=>{
 if(!towerRouteManagementActive())return;
 const tab=e.target.closest('[data-unit-tab]');if(tab&&['guild','inventory','upgrade'].includes(tab.dataset.unitTab)){towerUnitsTab=tab.dataset.unitTab;renderTowerUnits();return;}
 const member=e.target.closest('[data-tower-member]');if(member){const id=+member.dataset.towerMember,m=towerMember(id);if(!m)return;if(towerSelectedUnitId===id){openCharacterInfo(m.type,{guildId:id});return;}towerSelectedUnitId=id;renderTowerUnits();return;}
 const item=e.target.closest('[data-tower-equip]');if(item){openTowerItemInfo(+item.dataset.towerEquip);return;}
 const card=e.target.closest('[data-inventory-card]');if(card){openStrategyCardInfo(+card.dataset.inventoryCard);return;}
 if(e.target.closest('[data-tower-action="upgrade"]'))upgradeTowerCharacter();
});
function canAbandonTower(){return !!tower&&!tower.gameOver&&!['lobby','complete','gameover'].includes(tower.phase)&&screen==='tower';}
function closeTowerAbandon(){towerAbandonRun=null;if($('towerAbandonConfirm').open)$('towerAbandonConfirm').close();}
function openTowerAbandon(){
 if(!canAbandonTower())return false;closeTowerManagement();towerAbandonRun=tower;$('towerAbandonConfirm').showModal();return true;
}
function confirmTowerAbandon(){
 const run=towerAbandonRun;closeTowerAbandon();if(run!==tower||!canAbandonTower())return false;
 tower.gameOver=true;tower.gameOverReason='abandon';tower.phase='gameover';tower.result=null;resetTowerStances();
 closeTowerManagement();resetTowerScenes();resetTowerFeedback();closeTowerItemInfo();closeTurningPoint();running=false;paused=false;finished=true;accumulator=0;
 for(const id of ['towerConquest','towerRevival','unitStrategy','characterInfo'])if($(id).open)$(id).close();
 showScreen('tower');return true;
}
function towerEventInProgress(){return !!tower&&!tower.gameOver&&['event','predictionEvent','predictionBattle'].includes(tower.phase)&&towerFloor()?.kind==='event'&&!towerFloor().cleared;}
function towerEventNavigationNotice(){const message='이벤트를 완료한 뒤 탐험 지도로 돌아갈 수 있습니다.';if(screen==='battle')$('stateLabel').textContent=message;else towerMessage(message);}
function towerCombatEntryLocked(){return !!tower&&!tower.gameOver&&gameKind==='tower'&&['prepare','deploy'].includes(tower.phase)&&isTowerCombat()&&!towerFloor().cleared;}
function towerCombatNavigationNotice(){towerMessage('전투를 진행한 뒤 지도로 돌아갈 수 있습니다.');}
function returnTowerMap(){if(towerCombatEntryLocked()){towerCombatNavigationNotice();return false;}if(towerRetreatActive())return false;if(towerEventInProgress()){towerEventNavigationNotice();return false;}if(checkTowerGameOver()){showScreen('tower');return false;}if(tower.phase==='battle')return retreatTowerBattle();if(tower.phase==='deploy')refundTowerDraft();if(['shop','recruit'].includes(tower.phase))clearTowerRoom();tower.phase='route';showScreen('tower');return true;}
function towerRoomLabel(node){return TOWER_EVENT_INFO[node.eventType]?.name??TOWER_KINDS[node.kind].name;}
function towerRoomReenterable(node){return ['shop','recruit'].includes(node.kind)||node.kind==='event'&&node.eventType==='promotion';}
function towerRoomConsumed(node){return node.cleared&&(isTowerCombat(node)||node.kind==='rest'||node.kind==='event'&&(node.eventType!=='promotion'||(node.promotion?.used??0)>=(node.promotion?.limit??1)));}
function ensureTowerShopStock(node=towerFloor()){
 if(node?.kind!=='shop')return [];
 if(node.shopStock)return node.shopStock;
 const pick=(list,count)=>{const pool=[...list];for(let i=pool.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[pool[i],pool[j]]=[pool[j],pool[i]];}return pool.slice(0,count);};
 const equipment=pick(TOWER_ITEMS,2+Math.floor(Math.random()*2)),cards=pick(STRATEGY_CARDS,2+Math.floor(Math.random()*2));
 node.shopStock=[...equipment.map(item=>({category:'equipment',kind:item.id})),...cards.map(card=>({category:'card',kind:card.kind}))].map(offer=>{const quantity=Math.random()<.2?2:1;return{...offer,quantity,initialQuantity:quantity};});return node.shopStock;
}
function towerShopOffers(category){return ensureTowerShopStock().filter(o=>o.category===category);}
function towerShopCopies(offer){if(!offer.purchasedCopies)offer.purchasedCopies=Array.from({length:offer.initialQuantity},(_,i)=>i<offer.initialQuantity-offer.quantity);return offer.purchasedCopies.map((purchased,index)=>({index,purchased}));}
function availableTowerShopCopy(offer,index){if(!offer||offer.quantity<=0)return -1;const copies=towerShopCopies(offer);if(index===undefined)return copies.find(c=>!c.purchased)?.index??-1;return Number.isInteger(index)&&copies[index]&&!copies[index].purchased?index:-1;}
function towerEnemyRemaining(node=towerFloor()){return node?.enemyDeployment.filter((_,i)=>(node.enemyState?.[i]?.hp??1)>0).length??0;}
function enterTower({push=true}={}){
 if(towerRetreatActive())return false;
 if(hasTowerPrediction()){if(!leaveTowerPrediction()){towerEventNavigationNotice();return false;}showScreen('tower',push);return;}
 if(gameKind==='tower'&&screen==='battle'&&running){retreatTowerBattle({push});return false;}
 if(gameKind!=='tower'){restoreCustomRoster();towerRosterBackup=roster.map(p=>({...p}));}
 if(!tower)tower=newTowerState();
 if(tower.phase==='deploy'){refundTowerDraft();tower.phase='prepare';}
 gameKind='tower';showScreen('tower',push);
}
function leaveTowerMode(){if(towerCombatEntryLocked()){towerCombatNavigationNotice();return false;}if(tower?.phase==='deploy'){refundTowerDraft();tower.phase='prepare';}if(towerRosterBackup){roster=towerRosterBackup.map(p=>({...p}));towerRosterBackup=null;}}
function towerMessage(text){$('towerMessage').textContent=text;if($('towerUnits').open)$('towerUnitsMessage').textContent=text;}
let towerItemSelection=null;
function openTowerItemInfo(id){
 const member=towerMember(towerSelectedUnitId),copy=tower?.inventory.find(c=>c.id===id),item=TOWER_ITEMS.find(i=>i.id===copy?.kind);
 if(!canManageTowerEquipment()||!member||!item||copy.equippedTo!=null)return false;
 const equipped=towerEquippedCopies(member.id),full=equipped.length>=towerEquipmentLimit(member),blocked=item.consumable?!equipped.length:full;
 towerItemSelection={run:tower,nodeId:tower.nodeId,memberId:member.id,itemId:id,phase:tower.phase};
 $('towerItemIcon').textContent=item.icon;$('towerItemTitle').textContent=item.name;$('towerItemDescription').textContent=item.help;
 $('towerItemTarget').textContent=towerMemberName(member)+' #'+member.id+' · '+equipped.length+'/'+towerEquipmentLimit(member);
 $('towerItemNote').textContent=item.consumable?(blocked?'회수할 장비가 없습니다.':'선택한 유닛의 장비를 회수합니다.'):full?'장비 칸이 가득 찼습니다.':'이 유닛에게 장착합니다.';
 $('confirmTowerItem').textContent=item.consumable?'사용':'장착';$('confirmTowerItem').disabled=blocked;$('towerItemInfo').showModal();return true;
}
function closeTowerItemInfo(){towerItemSelection=null;if($('towerItemInfo').open)$('towerItemInfo').close();}
function confirmTowerItem(){
 const selected=towerItemSelection;if(!selected||selected.run!==tower||selected.nodeId!==tower.nodeId||selected.memberId!==towerSelectedUnitId||selected.phase!==tower.phase||!canManageTowerEquipment())return false;
 if(!toggleTowerItem(selected.itemId))return false;closeTowerItemInfo();return true;
}
$('closeTowerItem').onclick=closeTowerItemInfo;$('cancelTowerItem').onclick=closeTowerItemInfo;$('confirmTowerItem').onclick=confirmTowerItem;
$('towerItemInfo').addEventListener('close',()=>{towerItemSelection=null;});

// These flights use screen coordinates and wall time; they never delay game accounting.
let towerFeedback={run:null,flights:[],sparks:[],batches:[],pulses:[]};
function towerElementPoint(element){const r=element?.getBoundingClientRect?.();return r?.width&&r?.height?{x:r.left+r.width/2,y:r.top+r.height/2}:null;}
function towerActionRoot(){return towerRouteManagementActive()?$('towerUnitsContent'):$('towerBody');}
function towerActionPoint(selector){const root=towerActionRoot();return towerElementPoint(root.querySelector?.(selector))??towerElementPoint(root);}
function towerCombatPoint(unit){
 const r=canvas.getBoundingClientRect?.();if(!r?.width||!r?.height||!unit)return null;
 return{x:clamp(r.left+((unit.x-cinema.x+shakeX)*cinema.zoom+400)/800*r.width,r.left,r.right),y:clamp(r.top+((unit.y-cinema.y+shakeY)*cinema.zoom+400)/800*r.height,r.top,r.bottom)};
}
function towerWalletTarget(kind){
 const id=screen==='battle'?'towerBattleHud':screen==='towerSetup'?'teamCosts':screen==='tower'?(towerRouteManagementActive()?'towerUnitsWallet':'towerWallet'):null,root=id&&$(id);
 if(!root||root.hidden)return null;const cell=root.querySelector?.('[data-wallet-kind="'+kind+'"]');
 const point=towerElementPoint(kind==='hp'?cell?.querySelector(':scope > i'):cell?.querySelector('.resource-icon'));
 return point?{cell,point}:null;
}
function resetTowerFeedback(){
 for(const effect of [...towerFeedback.flights,...towerFeedback.sparks])effect.element.remove();
 for(const pulse of towerFeedback.pulses)pulse.cell.classList.remove('wallet-hit','wallet-gain','wallet-spend','purchase-arrival');
 towerFeedback={run:tower,flights:[],sparks:[],batches:[],pulses:[]};
}
function towerVisibleHp(){return clamp(tower.hp+towerFeedback.batches.filter(b=>b.run===tower&&b.kind==='hp'&&!b.arrived).reduce((n,b)=>n+b.amount,0),0,tower.maxHp);}
function updateTowerWalletValues(root){
 const cell=kind=>root.querySelector?.('[data-wallet-kind="'+kind+'"]');
 const gold=cell('gold'),token=cell('tokens'),hp=cell('hp');if(!gold||!token||!hp)return false;
 gold.querySelector('b').innerHTML=tower.gold.toLocaleString('ko-KR')+'<small> G</small>';token.querySelector('b').textContent=tower.tokens;
 const visible=towerVisibleHp();hp.querySelector('b').innerHTML=visible+' <small>/ '+tower.maxHp+'</small>';hp.querySelector(':scope > i > em').style.width=visible/tower.maxHp*100+'%';return true;
}
function renderTowerWallet(id){const root=$(id);if(!updateTowerWalletValues(root))root.innerHTML=walletMarkup();}
function refreshTowerFeedbackWallets(){for(const id of ['towerWallet','teamCosts','towerBattleHud','towerUnitsWallet'])updateTowerWalletValues($(id));}
function towerSpendTarget(batch){
 if(screen!=='tower'||tower.nodeId!==batch.nodeId||tower.phase!==batch.phase)return null;
 const button=towerActionRoot().querySelector?.(batch.selector),cell=button?.closest?.('.guild-recruit-card')??button;
 return cell?{cell,point:towerElementPoint(cell.querySelector?.('.portrait, :scope > span'))??towerElementPoint(cell)??batch.destination}:null;
}
function spendTowerResources(gold,tokens,selector,scene=null){
 tower.gold-=gold;tower.tokens-=tokens;
 const destination=towerActionPoint(selector),options={direction:'spend',selector,destination,nodeId:tower.nodeId,phase:tower.phase,scene:scene?{...scene,nodeId:tower.nodeId}:null};
 let queued=false;if(gold>0)queued=queueTowerFeedback('gold',gold,towerWalletTarget('gold')?.point,options)||queued;
 if(tokens>0)queued=queueTowerFeedback('tokens',tokens,towerWalletTarget('tokens')?.point,options)||queued;
 if(scene&&!queued)queueTowerScene(options.scene);
}
function queueTowerFeedback(kind,amount,origin,options={}){
 if(!(amount>0)||!origin||typeof document.createElement!=='function')return false;
 if(towerFeedback.run!==tower)resetTowerFeedback();const target=towerWalletTarget(kind),layer=$('towerFeedback');if(!target||!layer)return false;
 const batch={run:tower,kind,amount,arrived:false,...options};towerFeedback.batches.push(batch);
 if(batch.direction==='spend')towerFeedbackPulse(target.cell,'wallet-spend');
 const count=kind==='hp'?12:kind==='gold'?clamp(Math.ceil(Math.sqrt(amount)/3),3,9):clamp(Math.ceil(amount),1,5);
 for(let i=0;i<count;i++){
  const element=document.createElement('span');element.className='wallet-flight wallet-flight-'+kind;element.textContent=kind==='gold'?'🪙':kind==='tokens'?'💎':'';layer.appendChild(element);
  const side=i%2?1:-1,from={x:origin.x+random(-10,10),y:origin.y+random(-8,8)};
  towerFeedback.flights.push({element,batch,primary:i===0,from,control:{x:from.x+side*random(25,65),y:from.y+(batch.direction==='spend'?1:-1)*random(35,85)},t:0,delay:i*(kind==='hp'?.012:.035),duration:reducedMotion?.35:.72+random(0,.1)});
 }
 return true;
}
function awardTowerResources(gold,tokens,origin=null){
 tower.gold+=gold;tower.tokens+=tokens;queueTowerFeedback('gold',gold,origin);queueTowerFeedback('tokens',tokens,origin);
}
function towerFeedbackPulse(cell,className){
 cell.classList.add(className);const pulse=towerFeedback.pulses.find(p=>p.cell===cell&&p.className===className);if(pulse)pulse.remaining=.32;else towerFeedback.pulses.push({cell,className,remaining:.32});
}
function towerWalletImpact(kind,target,spending=false){
 const color=kind==='hp'?'#ff535b':kind==='gold'?'#ffdb75':'#92e6ff',layer=$('towerFeedback'),className=kind==='hp'?'wallet-hit':'wallet-gain';
 towerFeedbackPulse(target.cell,spending?'purchase-arrival':className);
 for(let i=0;i<8;i++){
  const element=document.createElement('i');element.className='wallet-impact-spark';element.style.background=color;element.style.boxShadow='0 0 6px '+color;layer.appendChild(element);
  const angle=i*Math.PI/4+random(-.15,.15),speed=random(35,90);towerFeedback.sparks.push({element,x:target.point.x,y:target.point.y,vx:Math.cos(angle)*speed,vy:Math.sin(angle)*speed,t:0,duration:.32});
 }
}
function advanceTowerFeedback(wallDt){
 if(towerFeedback.run!==tower||!['tower','towerSetup','battle'].includes(screen)||screen==='battle'&&gameKind!=='tower'&&!hasTowerPrediction()){resetTowerFeedback();return;}
 const dt=Math.min(Math.max(0,wallDt),.1);
 for(const pulse of towerFeedback.pulses){pulse.remaining-=dt;if(pulse.remaining<=0)pulse.cell.classList.remove(pulse.className);}towerFeedback.pulses=towerFeedback.pulses.filter(p=>p.remaining>0);
 for(const flight of towerFeedback.flights){
  flight.t+=dt;const spending=flight.batch.direction==='spend',target=spending?towerSpendTarget(flight.batch):towerWalletTarget(flight.batch.kind);if(!target){flight.element.style.opacity='0';if(spending||flight.t>2){flight.batch.arrived=true;flight.batch.cancelled=true;flight.done=true;}continue;}
  const t=clamp((flight.t-flight.delay)/flight.duration,0,1),p=t*t,q=1-p;
  const x=q*q*flight.from.x+2*q*p*flight.control.x+p*p*target.point.x,y=q*q*flight.from.y+2*q*p*flight.control.y+p*p*target.point.y;
  flight.element.style.transform='translate('+x+'px,'+y+'px) translate(-50%,-50%) rotate('+(flight.batch.kind==='hp'?t*100:Math.sin(t*8)*15)+'deg) scale('+(1-t*.25)+')';flight.element.style.opacity=flight.t<flight.delay?'0':'1';
  if(t>=1){flight.done=true;if(!flight.batch.arrived){flight.batch.arrived=true;refreshTowerFeedbackWallets();}towerWalletImpact(flight.batch.kind,target,spending);}
 }
 for(const flight of towerFeedback.flights)if(flight.done)flight.element.remove();towerFeedback.flights=towerFeedback.flights.filter(f=>!f.done);
 for(const batch of towerFeedback.batches)if(!towerFeedback.flights.some(f=>f.batch===batch)&&batch.scene&&!batch.cancelled&&batch.run===tower&&screen==='tower'&&tower.nodeId===batch.nodeId&&tower.phase===batch.phase)queueTowerScene(batch.scene);
 towerFeedback.batches=towerFeedback.batches.filter(b=>towerFeedback.flights.some(f=>f.batch===b));
 for(const spark of towerFeedback.sparks){spark.t+=dt;spark.x+=spark.vx*dt;spark.y+=spark.vy*dt;spark.element.style.transform='translate('+spark.x+'px,'+spark.y+'px) rotate(45deg)';spark.element.style.opacity=String(1-spark.t/spark.duration);if(spark.t>=spark.duration)spark.element.remove();}towerFeedback.sparks=towerFeedback.sparks.filter(s=>s.t<s.duration);
 // Many simultaneous deaths still have a bounded visual cost.
 while(towerFeedback.sparks.length>180)towerFeedback.sparks.shift().element.remove();
 while(towerFeedback.flights.length>320){const old=towerFeedback.flights.shift();old.batch.arrived=true;old.element.remove();refreshTowerFeedbackWallets();}
}
function walletMarkup(){return `<div data-wallet-kind="gold"><span><i class="resource-icon" aria-hidden="true">🪙</i> 골드</span><b>${tower.gold.toLocaleString('ko-KR')}<small> G</small></b></div><div data-wallet-kind="tokens"><span><i class="resource-icon" aria-hidden="true">💎</i> 토큰</span><b>${tower.tokens}</b></div><div class="tower-player-hp" data-wallet-kind="hp"><span aria-label="플레이어 HP"><i class="resource-icon" aria-hidden="true">💚</i></span><b>${towerVisibleHp()} <small>/ ${tower.maxHp}</small></b><i><em style="width:${towerVisibleHp()/tower.maxHp*100}%"></em></i></div>`;}
function towerResultMarkup(r){return `<div class="tower-result-lines">${isTowerCombat()?`<div class="result-loss"><p class="result-loss-title">유닛 손실 ${r.lossCount??0}명</p><p>💚 HP -${(r.deathLoss??0)+(r.penalty??0)}</p></div>`:''}${r.reward?`<div class="result-reward"><p class="result-reward-title">승리 보상</p><p>🪙 +${r.reward}</p><p>💎 +${r.tokens??0}</p></div>`:''}${r.event?'<p>'+r.event+'</p>':''}${r.strategyReward?'<p>🃏 '+r.strategyReward+'</p>':''}</div>`;}
function renderTower(){
 if(!tower)return;checkTowerGameOver();const locked=towerEventInProgress()||towerCombatEntryLocked();$('towerHome').disabled=locked;$('towerAbandon').hidden=!canAbandonTower();$('openTowerUnits').hidden=!canOpenTowerUnits();if(!canOpenTowerUnits())closeTowerUnits();else if(towerRouteManagementActive())renderTowerUnits();$('homeLogo').disabled=locked;const floor=towerFloor(),body=$('towerBody');if(!towerMember(towerSelectedUnitId))towerSelectedUnitId=tower.guild[0]?.id??null;renderTowerWallet('towerWallet');$('towerTitle').textContent=tower.gameOver?'두니 타워 • 게임오버':tower.phase==='complete'?'두니 타워 정복 완료':tower.phase==='route'?'두니 타워 • 탐험 지도':tower.phase==='rest'&&tower.restRetry?(tower.floor+1)+'층 • 길드 휴식소':floor?.name??'두니 타워 정복';towerMessage('');body.dataset.phase=tower.phase;
 if(tower.phase==='gameover'){body.innerHTML=`<div class="tower-result tower-gameover"><div class="eyebrow">GAME OVER</div><span class="tower-castle" aria-hidden="true">🏴</span><h2>${tower.gameOverReason==='abandon'?'탐험 포기':tower.gameOverReason==='hp'?'플레이어 HP 소진':'길드원 전원 전투불능'}</h2>${tower.result?towerResultMarkup(tower.result):''}<p>${tower.floor>=0?(tower.floor+1)+'층 · ':''}클리어 ${tower.visited.length}방 · 길드원 ${tower.guild.length}명</p><button class="primary" data-tower-action="new">새로운 도전 <span>↗</span></button></div>`;return;}
 if(tower.phase==='lobby'){body.innerHTML=`<div class="tower-intro tower-lobby"><span class="tower-castle" aria-hidden="true">🏰</span><h2>개쩌는 길드원을 모집하며 탑을 박살내세요!</h2><p class="tower-lobby-subtitle">탑의 정상엔 빛나는 망고가 기다리고 있습니다.</p><button class="primary" data-tower-action="enter">던전 입장 <span>▶</span></button><small class="tower-lobby-note">던전을 탐험하고 전투에서 승리해 더 강한 길드를 만들어 나가세요.<br>조심하세요! HP가 0이 되거나 모든 길드원이 사망하면 탐험이 종료됩니다!</small></div>`;return;}
 if(tower.phase==='complete'){body.innerHTML=`<div class="tower-result"><span class="tower-castle">🥭</span><h2>두니 타워 정복!</h2><p>보스를 쓰러뜨리고 망고를 얻었습니다.</p><button class="primary" data-tower-action="new">새로운 도전 <span>↗</span></button></div>`;return;}
 if(tower.phase==='route'){renderTowerRoute();return;}
 if(tower.phase==='predictionEvent'){renderTowerPredictionEvent();return;}
 if(tower.phase==='rest'){renderTowerRoom(`<div class="tower-prep-heading"><div><h2>길드 휴식소</h2></div><button class="primary" data-tower-action="map">지도로 <span>▶</span></button></div>${towerCharacterStrip()}<div class="tower-event guild-rest"><div class="tower-event-options"><button data-tower-rest="player"><span>💚</span><b>플레이어 회복</b><small>HP +15</small></button><button data-tower-rest="resources"><span>🪙</span><b>자원 획득</b><small>🪙 +350 · 💎 +1</small></button><button data-tower-rest="guild"><span>⛺</span><b>생존 유닛 회복</b><small>HP +35%</small></button><button data-tower-rest="revive" ${tower.guild.some(m=>m.hp<=0)?'':'disabled'}><span>✨</span><b>사망 유닛 부활</b><small>최대 2명 · HP 20%</small></button></div></div>`);return;}
 if(tower.phase==='event'&&floor?.eventType==='promotion'){renderTowerPromotion();return;}
 if(tower.phase==='event'&&floor?.eventType==='hotSpring'){renderTowerHotSpring();return;}
 if(tower.phase==='event'){const loot=ensureTowerTreasureLoot();renderTowerRoom(`<div class="tower-prep-heading"><div><h2>보물상자</h2></div></div>${towerCharacterStrip()}<div class="tower-event"><div class="tower-event-options"><button data-tower-event="heal"><span>💚</span><b>플레이어 회복</b><small>HP +10</small></button><button data-tower-event="guild"><span>⛺</span><b>생존 유닛 회복</b><small>HP +10% · ⚡ 기력 +1</small></button><button data-tower-event="gold"><span>🪙</span><b>자원 획득</b><small>🪙 +300 · 💎 +1</small></button><button data-tower-event="loot"><span>${loot.kind==='item'?'🎁':'🃏'}</span><b>${loot.kind==='item'?'무작위 아이템':'무작위 전략카드'}</b><small>${loot.kind==='item'?'아이템 1개':'전략카드 1장'}</small></button></div></div>`);return;}
 if(tower.phase==='result'){const r=tower.result;body.innerHTML=`<div class="tower-result"><div class="eyebrow">${r.won||r.roomCleared?'ROOM CLEAR':r.retreat?'RETREAT':'TRY AGAIN'}</div><h2>${r.won||r.roomCleared?'방 클리어!':r.retreat?'안전하게 후퇴했습니다':'길드원을 정비해 다시 도전하세요'}</h2>${towerResultMarkup(r)}<button class="primary" data-tower-action="continue">탐험 지도로 <span>▶</span></button></div>`;return;}
 if(tower.phase==='cleared'){body.innerHTML=`<div class="tower-result"><div class="eyebrow">EXPLORED ROOM</div><h2>${floor.name}</h2><p>이미 클리어한 방입니다. 보상은 다시 지급되지 않습니다.</p><button class="primary" data-tower-action="map">탐험 지도로</button></div>`;return;}
 if(['prepare','shop','recruit'].includes(tower.phase))renderTowerOperations();
}
function renderTowerRoute(){
 $('towerBody').innerHTML=`<div class="tower-route-heading"><h2>두니 타워 탐험</h2><p>방 절반 클리어 시 다음 층 해금 · 다음 챕터는 보스 격파 필요</p></div>${tower.conquered?'<div class="tower-conquered"><b>🥭 두니 타워 정복!</b><span>남은 방도 자유롭게 탐험하세요.</span><button class="text-button" data-tower-action="new">새로운 도전 ↗</button></div>':''}<div class="tower-floors" tabindex="0" aria-label="전체 타워 층 지도">${tower.route.map((rooms,depth)=>{const unlocked=depth<=tower.unlockedFloor,p=towerFloorProgress(depth);return `<section class="tower-floor-row ${unlocked?'unlocked':'locked'}" aria-label="${depth+1}층 ${unlocked?'해금':'잠김'}"><div class="tower-floor-heading"><b>${depth+1}층 <small>챕터 ${Math.floor(depth/TOWER_CHAPTER_FLOORS)+1}${tower.conqueredChapters?.includes(Math.floor(depth/TOWER_CHAPTER_FLOORS)+1)?' · 정복 ✓':''}</small></b><button type="button" data-conquest-reward="${depth}" class="conquest-button ${tower.conqueredFloors.includes(depth)?'received':''}" style="--conquest-angle:${p.cleared/p.total*360}deg" aria-haspopup="dialog" aria-label="${depth+1}층 정복 보상 · ${p.cleared}/${p.total}방"><span>${unlocked?'':'🔒 '}층 정복 보상${tower.conqueredFloors.includes(depth)?' ✓':''}</span></button></div><div class="tower-room-row ${rooms.some(n=>n.public)?'milestone':''}" style="--room-columns:${rooms.length+(rooms.length%2===0?1:0)}">${rooms.map(n=>`<button data-tower-node="${n.id}" class="tower-room ${n.public?'public-room '+n.kind:''} ${n.cleared?'cleared':''} ${towerRoomConsumed(n)?'consumed':''} ${n.id===tower.nodeId&&!towerRoomConsumed(n)?'last-room':''}" ${unlocked?'':'disabled'} aria-label="${depth+1}층 ${n.lane+1}번 방 · ${towerRoomVisible(n)?towerRoomLabel(n):'미탐험'}${n.cleared?' · 클리어':''}"><small>${n.lane+1}번 방</small><span>${towerRoomVisible(n)?towerRoomIcon(n):'?'}</span><b>${towerRoomVisible(n)?towerRoomLabel(n):'미탐험'}</b><em>${n.cleared?(n.eventType==='promotion'&&!towerRoomConsumed(n)?'✓ 클리어 · 재입장':'✓ 클리어'):towerRoomVisible(n)&&isTowerCombat(n)?'적 '+towerEnemyRemaining(n)+'명':unlocked?'탐험 가능':'잠김'}</em></button>`).join('')}</div></section>`;}).join('')}</div>`;
 const map=$('towerBody').querySelector?.('.tower-floors');if(map){map.scrollTop=tower.mapScroll??0;map.addEventListener('scroll',()=>tower.mapScroll=map.scrollTop);}
}

function chooseTowerNode(id,origin=null){if(towerRetreatActive()||checkTowerGameOver()||tower.phase!=='route')return false;const node=towerNextNodes().find(n=>n.id===id);if(!node)return false;if(isTowerCombat(node)&&!node.cleared&&!tower.guild.some(towerMemberReady)){towerMessage('참전 가능한 길드원이 없습니다. 휴식소에서 회복하세요.');return false;}origin??=towerActionPoint('[data-tower-node="'+id+'"]');const discovered=!node.revealed;if(discovered&&node.kind==='event'){if(!TOWER_EVENT_INFO[node.eventType])node.eventType=chooseTowerEventType();node.name=(node.depth+1)+'층 · '+(node.lane+1)+'번 방 • '+towerRoomLabel(node);}if(discovered)awardTowerResources(50,0,origin);node.revealed=true;tower.nodeId=node.id;tower.floor=node.depth;tower.result=null;tower.deathLoss=0;tower.deathIds=new Set();tower.restRetry=false;tower.phase=node.cleared&&!towerRoomReenterable(node)?'cleared':isTowerCombat(node)?'prepare':node.kind;if(tower.phase==='event'&&node.eventType==='prediction')tower.phase='predictionEvent';if(node.eventType==='promotion'){const promotion=ensureTowerPromotion(node);promotion.selected=[];}if(node.kind==='shop')ensureTowerShopStock(node);towerShopTab=tower.phase==='prepare'?'inventory':tower.phase;renderTower();if(discovered){towerMessage('새로운 방 탐험 · 🪙 +50G');queueTowerScene({kind:'entry',icon:towerRoomIcon(node),title:towerRoomLabel(node)});}return true;}
function energyMarkup(m){return `<span class="guild-energy" aria-label="기력 ${m.energy} / ${TOWER_MAX_ENERGY}">${Array.from({length:TOWER_MAX_ENERGY},(_,i)=>`<i class="${i<m.energy?'filled':''}"></i>`).join('')}</span>`;}
function renderTowerRoom(markup){const body=$('towerBody'),left=body.querySelector?.('.tower-character-strip')?.scrollLeft??0;body.innerHTML=markup;const strip=body.querySelector?.('.tower-character-strip');if(strip)strip.scrollLeft=left;}
function towerCharacterStrip(){return `<div class="tower-character-strip inventory-characters" role="group" aria-label="보유 길드원 선택">${tower.guild.map(m=>{const items=towerEquippedItems(m.id),stats=towerMemberStats(m);return `<button data-tower-member="${m.id}" class="${m.id===towerSelectedUnitId?'selected':''} ${m.hp<=0?'guild-dead':''}" aria-pressed="${m.id===towerSelectedUnitId}" aria-label="${towerMemberName(m)} · Lv.${m.level} · HP ${Math.ceil(m.hp)} / ${stats.hp} · 기력 ${m.energy} / ${TOWER_MAX_ENERGY} · ${items.map(item=>item.name).join(' · ')||'장비 없음'}" title="${towerMemberName(m)}">${towerMemberPortrait(m)}<small>#${m.id} · Lv.${m.level}</small><span class="tower-mini-item" aria-hidden="true">${items.map(item=>item.icon).join('')||'·'}</span><span class="unit-mini-vitals"><i class="mini-hp" role="progressbar" aria-label="HP" aria-valuemin="0" aria-valuemax="${stats.hp}" aria-valuenow="${Math.ceil(m.hp)}"><em style="width:${clamp(m.hp/stats.hp*100,0,100)}%"></em></i><i class="mini-energy" role="progressbar" aria-label="기력" aria-valuemin="0" aria-valuemax="${TOWER_MAX_ENERGY}" aria-valuenow="${m.energy}"><em style="width:${clamp(m.energy/TOWER_MAX_ENERGY*100,0,100)}%"></em></i></span></button>`;}).join('')}</div>`;}
function guildCardMarkup(m,{deploy=false}={}){const stats=towerMemberStats(m),placed=deploy&&roster.some(p=>p.towerAlly&&p.guildId===m.id),ready=towerMemberReady(m),selected=deploy?m.id===towerPlacementUnitId:m.id===towerSelectedUnitId,status=m.hp<=0?'사망':placed?'배치됨':'참전 가능',effects=towerStatusLabels(m,true);return `<button class="${deploy?'deployment-card':'guild-card'} ${selected?'selected':''} ${!ready?'guild-unavailable':''} ${m.hp<=0?'guild-dead':''} ${placed?'guild-placed':''}" ${deploy?'data-guild-unit':'data-tower-member'}="${m.id}" aria-pressed="${selected}" aria-label="${towerMemberName(m)} · Lv.${m.level} · HP ${Math.ceil(m.hp)} / ${stats.hp} · 기력 ${m.energy} / 5 · ${status}" style="--color:${TYPES[m.type].color}"><b>${towerMemberName(m)}</b><div class="guild-card-identity">${towerMemberPortrait(m)}<small>#${m.id} · Lv.${m.level}</small></div><div class="guild-card-vitals"><span>HP ${Math.ceil(m.hp)} / ${stats.hp}</span><i class="guild-hp"><em style="width:${clamp(m.hp/stats.hp*100,0,100)}%"></em></i><small>궁극기 ${Math.floor(m.ultGauge)}%</small></div>${energyMarkup(m)}<small class="guild-card-status">${status}${effects.length?' · '+effects.join(' · '):''}</small></button>`;}
function renderTowerLibrary(){const library=$('characterLibrary');library.dataset.kind='tower';library.innerHTML=tower.guild.map(m=>guildCardMarkup(m,{deploy:true})).join('');}
function renderTowerOperations(){
 const oldStrip=$('towerBody').querySelector?.('.tower-character-strip'),oldGrid=$('towerBody').querySelector?.('.inventory-grid'),oldGuild=$('towerBody').querySelector?.('.guild-grid'),stripScroll=oldStrip?.scrollLeft??0,gridScroll=oldGrid?.scrollTop??0,guildScroll=oldGuild?.scrollTop??0;
 if(!towerMember(towerSelectedUnitId))towerSelectedUnitId=tower.guild[0]?.id??null;
 const current=towerFloor(),preparing=tower.phase==='prepare',tabs=preparing?[['inventory','인벤토리'],['upgrade','강화']]:tower.phase==='shop'?[['shop','장비 구매'],['cards','전략카드'],['inventory','인벤토리']]:[['recruit','길드원 모집']];if(!tabs.some(([id])=>id===towerShopTab))towerShopTab=tabs[0][0];
 $('towerBody').innerHTML=`<div class="tower-prep-heading"><div><h2>${preparing?'전투 전 정비':TOWER_KINDS[tower.phase].name}${preparing?'<small>적 '+towerEnemyRemaining(current)+'명 · '+current.formation+'</small>':''}</h2>${towerShopTab==='upgrade'||tower.phase==='recruit'?'':`<p>${preparing?'생존·기력 확인 · 보유 길드원 무료 배치':TOWER_KINDS[tower.phase].help}</p>`}</div><button class="primary" data-tower-action="${preparing?'floor':'map'}">${preparing?'배치하기':'지도로'} <span>▶</span></button></div><div class="tower-shop-tabs" ${tabs.length===1?'hidden':''} role="tablist" aria-label="타워 정비">${tabs.map(([id,name])=>`<button role="tab" aria-selected="${id===towerShopTab}" data-tower-tab="${id}">${name}</button>`).join('')}</div>${tower.phase==='recruit'?'':towerCharacterStrip()}<div id="towerShopDetail" class="tower-shop-detail"></div>`;
 renderTowerShop();
 const strip=$('towerBody').querySelector?.('.tower-character-strip'),grid=$('towerBody').querySelector?.('.inventory-grid'),guild=$('towerBody').querySelector?.('.guild-grid');if(strip)strip.scrollLeft=stripScroll;if(grid)grid.scrollTop=gridScroll;if(guild)guild.scrollTop=guildScroll;
}
function renderTowerShop(detail=$('towerShopDetail'),tab=towerShopTab){
 if(tower.phase==='recruit'&&detail===$('towerShopDetail'))towerShopTab=tab='recruit';
 const m=towerMember(towerSelectedUnitId)??tower.guild[0];if(!m){detail.innerHTML='<p>보유 유닛 없음</p>';return;}
 if(tab==='guild'){detail.innerHTML='<div class="guild-grid" role="group" aria-label="보유 유닛 목록">'+tower.guild.map(m=>guildCardMarkup(m)).join('')+'</div>';return;}
 if(tab==='inventory'){
 const available=towerAvailableItems(),equipped=towerEquippedCopies(m.id);
 const slots=available.map(copy=>{const item=TOWER_ITEMS.find(i=>i.id===copy.kind);return `<button class="inventory-slot ${item.consumable?'inventory-consumable':''}" data-tower-equip="${copy.id}" aria-label="${item.name} · 설명 보기" title="${item.name} · ${item.help}"><span>${item.icon}</span><small>${item.name}</small><em>설명</em></button>`;});
 slots.push(...strategyInventorySlots());
 while(slots.length<24)slots.push('<div class="inventory-slot empty" aria-hidden="true"></div>');
 detail.innerHTML=`<div class="inventory-heading"><b>${towerMemberName(m)} · ${equipped.length}/${towerEquipmentLimit(m)}</b><span>아이템 ${available.length}개 · 전략카드 ${tower.strategyCards.length}장</span></div><p class="inventory-help">선택한 유닛에게 아이템을 장착하세요<br>장착한 아이템은 재각인으로 해제할 수 있습니다.</p><div class="inventory-grid" role="group" aria-label="보유 아이템과 전략카드">${slots.join('')}</div>`;return;
 }
 if(tab==='cards'&&typeof strategyShopMarkup==='function'){detail.innerHTML=strategyShopMarkup();return;}
 if(tab==='upgrade'){
 const stats=towerMemberStats(m);
 detail.innerHTML=`<div class="tower-upgrade"><div class="upgrade-unit"><div class="upgrade-identity"><b>${towerMemberName(m)}</b><span>Lv.${m.level}</span></div><div class="upgrade-vitals"><div class="upgrade-vital" aria-label="HP ${Math.ceil(m.hp)} / ${stats.hp}"><i class="vital-icon" aria-hidden="true">❤️</i><i class="guild-hp" role="progressbar" aria-label="HP" aria-valuemin="0" aria-valuemax="${stats.hp}" aria-valuenow="${Math.ceil(m.hp)}"><em style="width:${clamp(m.hp/stats.hp*100,0,100)}%"></em></i><small>${Math.ceil(m.hp)} / ${stats.hp}</small></div><div class="upgrade-vital" aria-label="기력 ${m.energy} / ${TOWER_MAX_ENERGY}"><i class="vital-icon" aria-hidden="true">⚡</i>${energyMarkup(m)}<small>${m.energy} / ${TOWER_MAX_ENERGY}</small></div></div></div><div class="upgrade-stats"><div><span>최대 HP</span><strong>+${Math.round(TOWER_GROWTH.hp*100)}%</strong></div><div><span>공격력</span><strong>+${Math.round(TOWER_GROWTH.dmg*100)}%</strong></div><div><span>방어력</span><strong>+${Math.round(TOWER_GROWTH.defensePower*100)}%</strong></div><div><span>이동속도</span><strong>+${Math.round(TOWER_GROWTH.speed*100)}%</strong></div></div><button class="secondary" data-tower-action="upgrade" ${m.level>=TOWER_MAX_LEVEL||tower.gold<towerUpgradeCost(m.id)?'disabled':''}>${m.level>=TOWER_MAX_LEVEL?'Lv.10 · 최대 레벨':'강화 · 🪙 '+towerUpgradeCost(m.id)+'G'}</button></div>`;return;
 }
 if(tab==='shop'){const offers=towerShopOffers('equipment');detail.innerHTML=`<div class="tower-items">${offers.flatMap(offer=>{const i=TOWER_ITEMS.find(i=>i.id===offer.kind);return towerShopCopies(offer).map(copy=>`<button data-tower-buy="${i.id}" data-shop-copy="${copy.index}" class="${copy.purchased?'shop-purchased':''}" ${copy.purchased||tower.gold<i.cost?'disabled':''}><span>${i.icon}</span><b>${i.name}</b><small>${i.help}</small><strong class="shop-price">${copy.purchased?'구매 완료':'🪙 '+i.cost+'G'}</strong></button>`);}).join('')}</div>`;return;}

 detail.innerHTML=`<div class="guild-recruit-tools"><button class="secondary" data-tower-action="reroll" ${tower.gold<TOWER_RECRUIT_REROLL_COST?'disabled':''} aria-label="모집 후보 리롤 · ${TOWER_RECRUIT_REROLL_COST}골드">⟳ 리롤 · 🪙 ${TOWER_RECRUIT_REROLL_COST}G</button></div><div class="guild-recruit-grid">${towerFloor().recruitOffers.map(offer=>{const type=offer.type,t=TYPES[type],cost=towerRecruitCost(type);return `<div class="guild-recruit-card">${portrait(type)}<b>${t.name}</b><small>HP ${t.hp} · ATK ${t.dmg}</small><button class="text-button" data-recruit-info="${type}">능력 보기 ⓘ</button><button class="secondary" data-tower-recruit="${offer.slot}" ${offer.purchased||tower.tokens<cost?'disabled':''}>${offer.purchased?'영입 완료':'💎 '+cost+' 토큰 · 영입'}</button></div>`;}).join('')}</div>`;
}
function rerollTowerRecruit(){const node=towerFloor();if(gameKind!=='tower'||tower?.gameOver||towerRetreatActive()||tower?.phase!=='recruit'||node?.kind!=='recruit'||tower.gold<TOWER_RECRUIT_REROLL_COST)return false;const offers=createTowerRecruitOffers();spendTowerResources(TOWER_RECRUIT_REROLL_COST,0,'[data-tower-action="reroll"]');node.recruitOffers=offers;renderTower();return true;}
function recruitTowerMember(slot){if(tower.phase!=='recruit'||!Number.isInteger(slot))return false;const offer=towerFloor()?.recruitOffers.find(o=>o.slot===slot);if(!offer||offer.purchased||tower.tokens<towerRecruitCost(offer.type))return false;const m=createGuildMember(offer.type);spendTowerResources(0,towerRecruitCost(offer.type),'[data-tower-recruit="'+slot+'"]',{kind:'recruit',icon:EMOJIS[m.type],title:towerMemberName(m),reward:'길드원 영입'});tower.guild.push(m);offer.purchased=true;towerSelectedUnitId=m.id;renderTower();towerMessage('');return true;}
function buyTowerItem(kind,copyIndex){const item=TOWER_ITEMS.find(i=>i.id===kind),offer=towerShopOffers('equipment').find(o=>o.kind===kind);if(tower.phase!=='shop'||!item||!offer||tower.gold<item.cost)return false;const index=availableTowerShopCopy(offer,copyIndex);if(index<0)return false;spendTowerResources(item.cost,0,'[data-tower-buy="'+kind+'"][data-shop-copy="'+index+'"]');offer.purchasedCopies[index]=true;offer.quantity--;tower.inventory.push({id:tower.nextItemId++,kind,equippedTo:null});renderTower();towerMessage(item.name+' 구매 완료');return true;}

function toggleTowerItem(id){
 if(!canManageTowerEquipment()||!towerMember(towerSelectedUnitId))return false;
 const m=towerMember(towerSelectedUnitId),copy=tower.inventory.find(i=>i.id===id),item=TOWER_ITEMS.find(i=>i.id===copy?.kind);if(!copy||!item)return false;
 if(copy.equippedTo!=null){towerMessage('장착한 장비는 재각인으로 회수할 수 있습니다.');return false;}
 const equipped=towerEquippedCopies(m.id);
 if(item.id==='reengrave'){
  if(!equipped.length){towerMessage('회수할 장비가 없습니다.');return false;}
  for(const gear of equipped)gear.equippedTo=null;
  tower.inventory=tower.inventory.filter(i=>i.id!==copy.id);m.hp=clamp(m.hp,0,towerMemberStats(m).hp);
  renderTower();towerMessage(towerMemberName(m)+' · 장비 '+equipped.length+'개 회수');return true;
 }
 if(equipped.length>=towerEquipmentLimit(m)){towerMessage('장비는 최대 '+towerEquipmentLimit(m)+'개까지 장착할 수 있습니다.');return false;}
 if(item.totem&&!towerMemberStats(m).totemCount)m.state.totemClock=VIGOR_TOTEM.interval;if(item.chargeTotem&&!towerMemberStats(m).chargeTotemCount)m.state.chargeTotemClock=CHARGE_TOTEM.interval;copy.equippedTo=m.id;renderTower();towerMessage(item.name+' 장착');return true;
}
function upgradeTowerCharacter(){const m=towerMember(towerSelectedUnitId),cost=towerUpgradeCost();if(checkTowerGameOver()||!(tower.phase==='prepare'||towerRouteManagementActive())||!m||m.level>=TOWER_MAX_LEVEL||tower.gold<cost)return false;const oldMaxHp=towerMemberStats(m).hp,wasDead=m.hp<=0;spendTowerResources(cost,0,'[data-tower-action="upgrade"]');m.level++;const newMaxHp=towerMemberStats(m).hp,recovery=healTowerMemberHp(m,Math.max(0,newMaxHp-oldMaxHp),true);if(wasDead&&m.type===13){m.state.bomberRush=false;m.state.bomberRushTime=0;m.state.bomberFuse=null;}renderTower();towerMessage(towerMemberName(m)+' Lv.'+m.level+' · HP +'+Math.round(recovery*10)/10);return true;}
function completeTowerNode(note){if(!['shop','recruit','event','rest'].includes(tower.phase)||tower.restRetry)return false;clearTowerRoom();tower.result={won:true,reward:0,tokens:0,penalty:0,deathLoss:0,event:note};tower.phase='route';renderTower();if(note)towerMessage(note);return true;}
function continueTower(){if(tower.phase!=='result')return false;tower.phase='route';renderTower();return true;}
let towerReviveSelection=new Set(),towerReviveRoomId=null;
function towerRestAvailable(){return !!tower&&!checkTowerGameOver()&&tower.phase==='rest'&&!towerFloor()?.cleared;}
function finishTowerRest(note){if(tower.restRetry){tower.restRetry=false;tower.phase='prepare';towerShopTab='inventory';renderTower();towerMessage(note);return true;}return completeTowerNode(note);}
function chooseTowerRest(choice,origin=null){
 if(!towerRestAvailable()||!['player','resources','guild','revive'].includes(choice))return false;
 if(choice==='revive')return openTowerRevival();
 if(choice==='player')tower.hp=Math.min(tower.maxHp,tower.hp+15);
 if(choice==='resources'){origin??=towerActionPoint('[data-tower-rest="resources"]');awardTowerResources(350,1,origin);}
 if(choice==='guild')for(const m of tower.guild.filter(m=>m.hp>0)){const maxHp=towerMemberStats(m).hp;healTowerMemberHp(m,maxHp*.35);}
 return finishTowerRest({player:'💚 HP +15',resources:'🪙 +350 · 💎 +1',guild:'생존 유닛 HP +35%'}[choice]);
}
function openTowerRevival(){if(!towerRestAvailable()||!tower.guild.some(m=>m.hp<=0))return false;towerReviveSelection.clear();towerReviveRoomId=tower.nodeId;renderTowerRevival();$('towerRevival').showModal();return true;}
function renderTowerRevival(){
 const dead=tower.guild.filter(m=>m.hp<=0);$('towerRevivalUnits').innerHTML=dead.map(m=>`<button type="button" data-revive-member="${m.id}" aria-pressed="${towerReviveSelection.has(m.id)}" class="revival-unit ${towerReviveSelection.has(m.id)?'selected':''}">${towerMemberPortrait(m)}<b>${towerMemberName(m)}</b><small>Lv.${m.level}</small><span>💚 ${Math.ceil(healingAmount(towerMemberStats(m).hp*.2,null,towerMemberStats(m)))}<small> / ${towerMemberStats(m).hp}</small></span></button>`).join('');$('towerRevivalCount').textContent=towerReviveSelection.size+' / '+TOWER_REVIVE_LIMIT+'명 선택';$('confirmTowerRevival').disabled=towerReviveSelection.size===0;
}
function selectTowerRevival(id){if(!towerRestAvailable()||towerReviveRoomId!==tower.nodeId||towerMember(id)?.hp>0||!towerMember(id))return false;if(towerReviveSelection.has(id))towerReviveSelection.delete(id);else if(towerReviveSelection.size<TOWER_REVIVE_LIMIT)towerReviveSelection.add(id);else return false;renderTowerRevival();return true;}
function confirmTowerRevival(){
 if(!towerRestAvailable()||towerReviveRoomId!==tower.nodeId||towerReviveSelection.size<1||towerReviveSelection.size>TOWER_REVIVE_LIMIT)return false;
 const members=[...towerReviveSelection].map(id=>towerMember(id));if(members.some(m=>!m||m.hp>0))return false;
 for(const m of members){healTowerMemberHp(m,towerMemberStats(m).hp*.2,true);m.state.bomberRush=false;m.state.bomberRushTime=0;m.state.bomberFuse=null;}
 $('towerRevival').close();towerReviveSelection.clear();return finishTowerRest('길드원 '+members.length+'명 · HP 20% 부활');
}
function retreatTowerRest(){return returnTowerMap();}
function renderTowerHotSpring(){
 const result=towerFloor().hotSpring;
 renderTowerRoom(`<div class="tower-prep-heading"><div><h2>♨️ 온천</h2></div>${result?'<button class="primary" data-tower-action="map">지도로 <span>▶</span></button>':''}</div>${towerCharacterStrip()}<div class="tower-event hot-spring-event">${result?`<div class="hot-spring-reward" data-hot-spring="${result.choice}" role="status"><span aria-hidden="true">${result.icon}</span><h2>${result.title}</h2><p>${result.detail}</p></div>`:`<div class="tower-event-options"><button data-tower-event="bathe" data-hot-spring="bathe"><span>♨️</span><b>온천에 들어가기</b><small>생존 유닛 HP +10%<br>기력 +2칸</small></button><button data-tower-event="lottery" data-hot-spring="lottery" ${tower.gold<HOT_SPRING_COST?'disabled':''}><span>🎟️</span><b>온천 복권 구매</b><small>무작위 보상</small><strong class="shop-price">🪙 ${HOT_SPRING_COST}G</strong></button></div>`}</div>`);
}
function chooseTowerHotSpring(choice,origin=null){
 const node=towerFloor();if(tower?.gameOver||tower.phase!=='event'||node?.eventType!=='hotSpring'||node.cleared||node.hotSpring||!['bathe','lottery'].includes(choice)||choice==='lottery'&&tower.gold<HOT_SPRING_COST)return false;
 origin??=towerActionPoint('[data-tower-event="'+choice+'"]');let result,scene=null;
 if(choice==='bathe'){
  for(const m of tower.guild.filter(m=>m.hp>0)){const maxHp=towerMemberStats(m).hp;healTowerMemberHp(m,maxHp*.1);m.energy=clamp(m.energy+2,0,TOWER_MAX_ENERGY);}
  result={choice,icon:'♨️',title:'온천욕 완료',detail:'생존 유닛 HP +10% · 기력 +2칸'};
 }else{
  const reward=HOT_SPRING_REWARDS[Math.floor(Math.random()*HOT_SPRING_REWARDS.length)];result={choice,reward,icon:'🎟️',title:'복권 당첨',detail:''};
  if(reward==='item'||reward==='items'){
   const count=reward==='items'?2:1,items=Array.from({length:count},()=>TOWER_ITEMS[Math.floor(Math.random()*TOWER_ITEMS.length)]);
   for(const item of items)tower.inventory.push({id:tower.nextItemId++,kind:item.id,equippedTo:null});result.icon=items[0].icon;result.detail=items.map(i=>i.icon+' '+i.name).join(' · ');
  }else if(reward==='strategy'){
   const card=STRATEGY_CARDS[Math.floor(Math.random()*STRATEGY_CARDS.length)];giveStrategyCard(card.kind);result.icon=card.icon;result.detail=card.name+' 전략카드';
  }else if(reward==='unit'){
   const member=createGuildMember(Math.floor(Math.random()*TYPES.length));tower.guild.push(member);towerSelectedUnitId=member.id;result.icon=EMOJIS[member.type];result.detail=towerMemberName(member)+' 영입';scene={kind:'recruit',phase:'event',icon:result.icon,title:towerMemberName(member),reward:'길드원 영입'};
  }else if(reward==='tokens'){result.icon='💎';result.detail='💎 +3';
  }else{result.icon='🪙';result.gold=Number(reward.slice(4));result.detail='🪙 +'+result.gold+'G';}
  spendTowerResources(HOT_SPRING_COST,0,'[data-hot-spring="lottery"]',scene);
  if(result.gold)awardTowerResources(result.gold,0,origin);if(reward==='tokens')awardTowerResources(0,3,origin);
 }
 node.hotSpring=result;clearTowerRoom();tower.result={won:true,reward:0,tokens:0,penalty:0,deathLoss:0,event:result.detail};renderTower();return true;
}
function ensureTowerTreasureLoot(node=towerFloor()){
 if(node.treasureLoot)return node.treasureLoot;const kind=Math.random()<.5?'item':'card',pool=kind==='item'?TOWER_ITEMS:STRATEGY_CARDS;
 return node.treasureLoot={kind,rewardKind:pool[Math.floor(Math.random()*pool.length)][kind==='item'?'id':'kind']};
}
function chooseTowerEvent(choice,origin=null){
 const node=towerFloor();if(node?.eventType==='hotSpring')return chooseTowerHotSpring(choice,origin);
 if(tower.phase!=='event'||['prediction','promotion'].includes(node?.eventType)||node?.cleared||!['gold','guild','heal','loot'].includes(choice))return false;
 origin??=towerActionPoint('[data-tower-event="'+choice+'"]');let note;
 if(choice==='gold'){awardTowerResources(300,1,origin);note='🪙 +300 · 💎 +1';}
 if(choice==='heal'){tower.hp=Math.min(tower.maxHp,tower.hp+10);note='💚 HP +10';}
 if(choice==='guild'){healTowerGuild(.1,true);for(const m of tower.guild)if(m.hp>0)m.energy=clamp(m.energy+1,0,TOWER_MAX_ENERGY);note='생존 유닛 HP +10% · ⚡ 기력 +1';}
 if(choice==='loot'){const loot=ensureTowerTreasureLoot(node);if(loot.kind==='item'){tower.inventory.push({id:tower.nextItemId++,kind:loot.rewardKind,equippedTo:null});note=TOWER_ITEMS.find(i=>i.id===loot.rewardKind).name;}else{giveStrategyCard(loot.rewardKind);note=STRATEGY_CARDS.find(c=>c.kind===loot.rewardKind).name;}}
 return completeTowerNode('보물상자 · '+note);
}
function enterTowerFloor(){
 if(checkTowerGameOver()||tower.phase!=='prepare'||!isTowerCombat()||towerFloor().cleared)return false;const f=towerFloor();tower.result=null;tower.deathLoss=0;tower.deathIds=new Set();
 if(!f.enemyDeployment?.length)Object.assign(f,createTowerEncounter(f.kind,f.depth));roster=f.enemyDeployment.flatMap((enemy,roomEnemyId)=>{const saved=f.enemyState[roomEnemyId];return saved?.hp<=0?[]:[{...enemy,...(saved?{x:saved.x,y:saved.y,stance:saved.stance}:{}),roomEnemyId,id:nextId++,team:1}];});tower.phase='deploy';selectedTeam=0;selectedCharacter=null;towerPlacementUnitId=null;placementTool='character';mapId='square';modeId='classic';restoreTowerFormation(f.deploymentDraft??tower.lastFormation??[]);showScreen('towerSetup');return true;
}
function towerDraftFormation(){return roster.filter(p=>p.towerAlly).map(p=>({guildId:p.guildId,x:p.x,y:p.y}));}
function towerFormationPosition(preferred){
 const point={x:clamp(preferred.x,40,380),y:clamp(preferred.y,40,760)},free=p=>roster.every(u=>dist(u,p)>=58);if(free(point))return point;
 // A retried room can have surviving enemies in the old deployment. Use the nearest free allied position.
 const candidates=[];for(let x=40;x<=380;x+=20)for(let y=40;y<=760;y+=20){const p={x,y};if(free(p))candidates.push(p);}return candidates.sort((a,b)=>dist(a,point)-dist(b,point))[0]??null;
}
function restoreTowerFormation(formation){
 for(const saved of formation){const m=towerMember(saved.guildId);if(!towerMemberReady(m)||!Number.isFinite(saved.x)||!Number.isFinite(saved.y)||roster.some(p=>p.towerAlly&&p.guildId===m.id))continue;const point=towerFormationPosition(saved);if(point)roster.push({id:m.id,guildId:m.id,type:m.type,team:0,...point,towerAlly:true,costPaid:TYPES[m.type].cost,stance:m.stance});}
}
function selectTowerPlacementMember(id){const m=towerMember(id);if(!m)return;if(towerPlacementUnitId===id&&placementTool==='character'){openCharacterInfo(m.type,{guildId:m.id});return;}towerPlacementUnitId=id;placementTool='character';renderRoster();}
function decorateTowerDeployment(){
 const placed=roster.filter(p=>p.towerAlly);$('setupTitle').textContent=towerFloor().name+(towerFloor().kind==='boss'?' · 강화 보스':'');$('budgetTitle').textContent='';$('budgetFunds').textContent='';$('budgetCaption').hidden=true;$('teamCosts').classList.add('tower-wallet');$('deploymentBudget').classList.add('tower-resource-budget');$('teamCosts').setAttribute('aria-label','골드, 토큰, 플레이어 HP');renderTowerWallet('teamCosts');
 $('placementTeams').hidden=true;$('towerDeployHint').hidden=true;$('towerDeployHint').textContent='';$('deploymentMap').classList.add('tower-map');$('openSetupSettings').textContent='← 정비';$('backHome').hidden=true;$('clearRoster').disabled=!placed.length;
 $('configSummary').textContent='';
 const m=towerMember(towerPlacementUnitId);
 if(placementTool==='eraser')$('validation').textContent='아군을 누르면 인벤토리로 돌려보냅니다.';
 else $('validation').textContent=!m?'보유 길드원을 골라 배치하세요.':!towerMemberReady(m)?towerMemberName(m)+' · 사망 · 휴식소에서 부활':placed.some(p=>p.guildId===m.id)?towerMemberName(m)+' · 이미 배치됨':towerMemberName(m)+' · HP '+Math.ceil(m.hp)+' · 기력 '+m.energy+'/5 · 무료 배치';
}
function addTowerParticipant(id,{x,y}={}){
 const m=towerMember(id);if(tower.phase!=='deploy'||!m){$('validation').textContent='유닛 인벤토리에서 길드원을 선택하세요.';return false;}
 if(!towerMemberReady(m)){$('validation').textContent='사망한 길드원은 배치할 수 없습니다.';return false;}
 if(roster.some(p=>p.towerAlly&&p.guildId===id)){$('validation').textContent='이 길드원은 이미 배치했습니다.';return false;}
 const point=Number.isFinite(x)&&Number.isFinite(y)?{x:clamp(x,40,760),y:clamp(y,40,760)}:findPlacement();
 if(!point||point.x>380){$('validation').textContent='왼쪽 블루 영역에 아군을 배치하세요.';return false;}
 if(roster.some(p=>dist(p,point)<58)){$('validation').textContent='유닛과 조금 떨어진 곳에 배치하세요.';return false;}
 roster.push({id:m.id,guildId:m.id,type:m.type,team:0,...point,towerAlly:true,costPaid:TYPES[m.type].cost,stance:m.stance});renderRoster();return true;
}
function removeTowerParticipant(id){if(tower.phase!=='deploy')return false;const p=roster.find(p=>p.id===id&&p.towerAlly);if(!p){$('validation').textContent='배치된 적은 지울 수 없습니다.';return false;}roster=roster.filter(u=>u.id!==id);renderRoster();return true;}
function refundTowerDraft(){if(tower?.phase!=='deploy')return;roster=roster.filter(p=>!p.towerAlly);}
function returnTowerPreparation(){if(tower.phase!=='deploy')return;towerFloor().deploymentDraft=towerDraftFormation();refundTowerDraft();tower.phase='prepare';showScreen('tower');}
function validateTowerDraft(){if(!['deploy','battle'].includes(tower.phase))return '층에 먼저 입장하세요.';const allies=roster.filter(p=>p.towerAlly);if(!allies.length)return '생존한 길드원을 1명 이상 배치하세요.';if(allies.some(p=>!towerMemberReady(towerMember(p.guildId)))||new Set(allies.map(p=>p.guildId)).size!==allies.length)return '배치한 길드원의 상태를 확인하세요.';if(!roster.some(p=>p.towerEnemy))return '적 배치를 확인하세요.';return '';}
function launchTowerBattle({cinematic=true}={}){if(tower.phase!=='deploy')return false;const error=validateTowerDraft();if(error){$('validation').textContent=error;return false;}const formation=towerDraftFormation();tower.phase='battle';tower.deathIds=new Set();tower.deathLoss=0;tower.lastEnemyDefeat=null;const success=startBattle({cinematic});if(success){towerFloor().combatStarted=true;tower.lastFormation=formation;delete towerFloor().deploymentDraft;}else tower.phase='deploy';return success;}
function applyTowerStats(){for(const u of units){if(u.towerAlly){const m=towerMember(u.guildId),stats=towerMemberStats(m);u.fatigueMissing=towerMissingEnergy(m);u.healingPower=stats.healingPower;u.victoryGold=stats.victoryGold;u.totemCount=stats.totemCount;u.totemClock=VIGOR_TOTEM.interval;u.chargeTotemCount=stats.chargeTotemCount;u.chargeTotemClock=CHARGE_TOTEM.interval;u.fangCount=stats.fangCount;u.openingAwlCount=stats.openingAwlCount;u.maxHp=stats.hp;u.hp=clamp(m.hp,0,u.maxHp);u.ultGauge=m.ultGauge;u.transGauge=clamp(m.transGauge??0,0,100);u.dmg=stats.dmg;u.defensePower=stats.defensePower;u.towerBaseMoveSpeed??=u.moveSpeed;u.moveSpeed=u.towerBaseMoveSpeed*(stats.speed/TYPES[u.type].speed);for(const key of TOWER_STATE_FIELDS)if(m.state[key]!==undefined)u[key]=m.state[key];if(u.guardRemaining>0)u.guardAnchor={x:u.x,y:u.y};if(m.state.lostSword){const {dx,dy,...sword}=m.state.lostSword;u.lostSword={...sword,x:clamp(u.x+dx,35,765),y:clamp(u.y+dy,35,765)};}}else if(u.towerEnemy){const stats=towerEnemyStats(u);u.maxHp=stats.hp;const saved=towerFloor().enemyState[u.roomEnemyId];u.hp=saved?clamp(saved.hp,0,u.maxHp):u.maxHp;u.ultGauge=saved?.ultGauge??0;if(saved){u.x=clamp(saved.x,28,772);u.y=clamp(saved.y,28,772);for(const key of TOWER_STATE_FIELDS)if(saved.state[key]!==undefined)u[key]=saved.state[key];if(u.guardRemaining>0)u.guardAnchor={x:u.x,y:u.y};if(saved.state.lostSword){const {dx,dy,...sword}=saved.state.lostSword;u.lostSword={...sword,x:clamp(u.x+dx,35,765),y:clamp(u.y+dy,35,765)};}}u.dmg=stats.dmg;u.defensePower=stats.defensePower;u.towerBaseMoveSpeed??=u.moveSpeed;u.moveSpeed=u.towerBaseMoveSpeed*(stats.speed/TYPES[u.type].speed);}}restoreTowerEnemyCasts();}
function restoreTowerStrategyState(u){const state=u.towerAlly?towerMember(u.guildId)?.state:u.towerEnemy?towerFloor().enemyState[u.roomEnemyId]?.state:null;if(!state)return;u.commandRetreatUntil=state.retreatRemaining??0;u.strategySpecialUntil=state.specialRemaining??0;applyStanceStats(u);}
function snapshotTowerMember(u){const m=towerMember(u.guildId);if(!m)return;m.hp=clamp(u.hp,0,u.maxHp);m.ultGauge=clamp(u.ultGauge,0,100);m.transGauge=clamp(u.transGauge??0,0,100);m.stance=u.combatStance??u.stance??'normal';const state=snapshotTowerCombatState(u);m.state=state;}
function snapshotTowerCombatState(u){const state={};if(u.puppetControl)state.puppetControl=snapshotPuppetControl(u);for(const key of TOWER_STATE_FIELDS)if(u[key]!==undefined)state[key]=u[key];state.retreatRemaining=Math.max(0,(u.commandRetreatUntil??0)-elapsed);state.specialRemaining=Math.max(0,(u.strategySpecialUntil??0)-elapsed);if(u.lostSword){const {x,y,...sword}=u.lostSword;state.lostSword={...sword,dx:x-u.x,dy:y-u.y};}return state;}
function snapshotTowerEnemies(){const room=towerFloor();for(const u of units.filter(u=>u.towerEnemy))room.enemyState[u.roomEnemyId]={hp:clamp(u.hp,0,u.maxHp),ultGauge:clamp(u.ultGauge,0,100),x:u.x,y:u.y,stance:u.combatStance??u.stance??'normal',combatId:u.id,ultCast:cloneTowerCast(u.ultCast),state:snapshotTowerCombatState(u)};}
function cloneTowerCast(value){if(value==null||typeof value!=='object')return value;if(value instanceof Set)return new Set([...value]);if(Array.isArray(value))return value.map(cloneTowerCast);return Object.fromEntries(Object.entries(value).map(([key,v])=>[key,cloneTowerCast(v)]));}
function restoreTowerEnemyCasts(){const saved=towerFloor().enemyState,ids=new Map(units.filter(u=>u.towerEnemy).map(u=>[saved[u.roomEnemyId]?.combatId,u.id]));for(const u of units.filter(u=>u.towerEnemy)){const cast=cloneTowerCast(saved[u.roomEnemyId]?.ultCast);if(!cast)continue;if(cast.targetId!==undefined)cast.targetId=ids.get(cast.targetId)??cast.targetId;if(cast.targets)cast.targets=cast.targets.map(id=>ids.get(id)??id);if(cast.dashHits)cast.dashHits=new Set([...cast.dashHits].map(id=>ids.get(id)??id));if(u.type===14&&cast.dashing)delete cast.strikeId;u.ultCast=cast;}}
function towerUnitDied(u){if(tower?.phase!=='battle')return;if(u.towerEnemy){const node=towerFloor();if(!isTowerCombat(node)||u.hp>0||u.roomEnemyId==null)return;node.killRewards??={};if(Object.hasOwn(node.killRewards,u.roomEnemyId))return;const reward=towerEnemyKillReward(u);node.killRewards[u.roomEnemyId]=reward;tower.lastEnemyDefeat=towerCombatPoint(u);awardTowerResources(reward.gold,reward.tokens,tower.lastEnemyDefeat);renderTowerBattleHud();return;}if(!u.towerAlly||tower.deathIds.has(u.id))return;tower.deathIds.add(u.id);const loss=TYPES[u.type].cost*TOWER_DEATH_HP_RATE,before=tower.hp;tower.deathLoss+=loss;tower.hp=Math.max(0,tower.hp-loss);queueTowerFeedback('hp',before-tower.hp,towerCombatPoint(u));renderTowerBattleHud();}
function renderTowerBattleHud(){const floor=towerFloor();if(!tower||!isTowerCombat(floor)){$('towerBattleHud').hidden=true;return;}const active=tower.phase==='battle',ending=towerHpGameOverActive()||finished&&cinema.enabled&&cinema.ending>0;for(const id of ['returnSetup','rematch'])$(id).classList.toggle('retreat-action',active);$('returnSetup').hidden=true;$('returnSetup').disabled=ending||active&&!canRetreatTower();$('returnSetup').textContent=active?(elapsed>=TOWER_RETREAT_TIME?'← 후퇴하기':'← 후퇴까지 '+Math.ceil(TOWER_RETREAT_TIME-elapsed)+'초'):'← 탐험 지도로';$('rematch').disabled=ending||active&&!canRetreatTower();$('rematch').textContent=active?'후퇴하기':'탐험 지도로';$('towerBattleHud').hidden=false;renderTowerWallet('towerBattleHud');}
function settleTowerBattle(won,forfeit=false,retreat=false){
 if(tower?.phase!=='battle')return false;releaseAllFrogCargo();snapshotTowerEnemies();for(const u of units)if(u.hp<=0)towerUnitDied(u);if(tower.hp<=0)won=false;const healSurvivors=won&&!towerFloor().cleared,participants=new Set();for(const u of units.filter(u=>u.towerAlly)){if(healSurvivors&&u.hp>0)restoreCombatHp(u,u.maxHp*.3,null);snapshotTowerMember(u);participants.add(u.guildId);}for(const m of tower.guild)m.energy=clamp(m.energy+(participants.has(m.id)?-1:1),0,TOWER_MAX_ENERGY);releaseAllPuppetControls();
 const f=towerFloor(),equipmentGold=won&&!f.cleared?units.filter(u=>u.towerAlly&&u.hp>0).reduce((n,u)=>n+(u.victoryGold??0),0):0,reward=won&&!f.cleared?f.reward+equipmentGold:0,tokens=won&&!f.cleared?f.tokens:0,penalty=won||retreat||tower.hp<=0?0:20;tower.hp=Math.max(0,tower.hp-penalty);awardTowerResources(reward-equipmentGold,tokens,tower.lastEnemyDefeat??towerCombatPoint(cinema.focus));if(equipmentGold)for(const u of units.filter(u=>u.towerAlly&&u.hp>0&&u.victoryGold>0))awardTowerResources(u.victoryGold,0,towerCombatPoint(u));
 tower.result={won,reward,tokens,equipmentGold,penalty,deathLoss:tower.deathLoss,lossCount:tower.deathIds.size,forfeit,retreat,participants:participants.size,reserves:tower.guild.length-participants.size};if(won&&!f.cleared&&f.kind==='miniboss'&&typeof giveStrategyCard==='function'){const kind=STRATEGY_CARDS[Math.floor(Math.random()*STRATEGY_CARDS.length)].kind;giveStrategyCard(kind);tower.result.strategyReward=STRATEGY_CARDS.find(c=>c.kind===kind).name;}const enemies=units.filter(u=>u.towerEnemy);if(tower.hp>0&&(won||(enemies.length&&enemies.every(u=>u.hp<=0))))clearTowerRoom();tower.result.roomCleared=f.cleared;tower.phase='result';checkTowerGameOver();renderTowerBattleHud();return true;
}
function towerVerdict(){return `${tower.gameOver?'<p>길드원 전원 전투불능 · 탐험 종료</p>':''}${towerResultMarkup(tower.result)}`;}
function canRetreatTower(){return !(typeof transcendenceFrozen==='function'&&transcendenceFrozen())&&!towerHpGameOverActive()&&!towerRetreatActive()&&!tower?.gameOver&&tower?.hp>0&&tower?.phase==='battle'&&running&&elapsed>=TOWER_RETREAT_TIME&&units.some(u=>u.towerAlly&&u.hp>0)&&units.some(u=>u.towerEnemy&&u.hp>0);}
function retreatTowerBattle({navigate=true,destination='tower',push=true}={}){
 if(!canRetreatTower()||!settleTowerBattle(false,false,true))return false;
 running=false;paused=false;finished=false;accumulator=0;closeTurningPoint();tower.phase='route';cinema.intro=cinema.anticipation=cinema.ending=0;$('battleIntro').hidden=$('cinemaBars').hidden=$('winner').hidden=true;
 const elements=[$('homeLogo'),$('returnSetup'),$('rematch'),$('pause'),$('showStatus'),...document.querySelectorAll('[data-speed]')],controls=elements.map(element=>({element,disabled:!!element.disabled}));for(const element of elements)element.disabled=true;
 const motion=new Map(units.map(u=>{const vx=(u.vx??0)+(u.kx??0),vy=(u.vy??0)+(u.ky??0),speed=Math.hypot(vx,vy)||1,limit=Math.min(1,Math.max(300,u.moveSpeed*2)/speed);return[u.id,{x:vx*limit,y:vy*limit}];}));
 towerRetreat={run:tower,t:0,duration:1.9,destination:navigate?destination:null,push,controls,motion};$('battleScreen').dataset.retreat='true';$('towerRetreatScene').style.opacity='0';$('towerRetreatScene').hidden=false;$('towerRetreatSceneTitle').style.opacity='0';$('stateLabel').textContent='후퇴';return true;
}
function returnTowerFromBattle(){if(tower.phase==='battle')return retreatTowerBattle();showScreen('tower');return true;}
function ensureTowerPrediction(node=towerFloor()){
 if(node?.kind!=='event'||node.eventType!=='prediction')return null;
 if(!node.prediction)node.prediction={teams:createPredictionTeams(),pick:null,stake:100,status:'ready',result:null};return node.prediction;
}
function renderTowerPredictionEvent(){
 const bet=ensureTowerPrediction();if(!bet)return;
 renderTowerRoom(`<div class="tower-prediction-heading"><div><div class="eyebrow">BATTLE PREDICTION</div><h2>전투 예측</h2></div></div><div class="tower-prediction-choices" role="group" aria-label="승리 예상 팀">${predictionChoicesMarkup(bet.teams,bet.pick,'data-tower-pick')}</div><div class="tower-wager"><span>몇 골드를 걸까?</span><div role="group" aria-label="예측에 걸 골드">${[50,100,200].map(stake=>`<button data-tower-stake="${stake}" aria-pressed="${bet.stake===stake}" class="${bet.stake===stake?'selected':''}" ${tower.gold<stake?'disabled':''}>🪙 ${stake}G</button>`).join('')}</div><p>성공 🪙 ${bet.stake*2}G + 💎 토큰 1개 · 실패 참가 골드 소모 · 무승부 반환</p><button class="primary" data-tower-action="predict" ${bet.pick===null||tower.gold<bet.stake?'disabled':''}>🪙 ${bet.stake}G 걸고 관전 <span>▶</span></button></div>`);
}
function chooseTowerPredictionTeam(team){const bet=ensureTowerPrediction();if(tower.phase!=='predictionEvent'||!bet||bet.status!=='ready'||!bet.teams.some(t=>t.team===team))return false;bet.pick=team;renderTower();return true;}
function chooseTowerPredictionStake(stake){const bet=ensureTowerPrediction();if(tower.phase!=='predictionEvent'||!bet||bet.status!=='ready'||![50,100,200].includes(stake)||tower.gold<stake)return false;bet.stake=stake;renderTower();return true;}
function hasTowerPrediction(){return !!towerPredictionContext&&towerPredictionContext.run===tower;}
function launchTowerPrediction({cinematic=true}={}){
 const bet=ensureTowerPrediction(),node=towerFloor();if(tower.phase!=='predictionEvent'||running||!bet||bet.status!=='ready'||bet.pick===null||tower.gold<bet.stake)return false;
 towerPredictionContext={run:tower,node,roster:roster.map(p=>({...p})),teams:predictionTeams,pick:predictionPick,result:predictionResult};
 predictionTeams=bet.teams;predictionPick=bet.pick;predictionResult=null;roster=createPredictionRoster(bet.teams);gameKind='prediction';mapId='square';modeId='classic';tower.gold-=bet.stake;bet.status='running';tower.phase='predictionBattle';
 const started=startBattle({cinematic});if(started)battleSnapshot.towerPredictionRoomId=node.id;if(!started){tower.gold+=bet.stake;bet.status='ready';leaveTowerPrediction();tower.phase='predictionEvent';showScreen('tower');return false;}return true;
}
function settleTowerPrediction(result){
 if(!hasTowerPrediction())return '';const {node}=towerPredictionContext,bet=node.prediction;if(bet.status==='running'){
 bet.status='resolved';bet.result=result;bet.payout=result==='correct'?bet.stake*2:result==='draw'?bet.stake:0;bet.tokens=result==='correct'?1:0;awardTowerResources(bet.payout,bet.tokens,towerCombatPoint(cinema.focus));
 tower.nodeId=node.id;tower.floor=node.depth;clearTowerRoom();tower.phase='predictionResult';
 }
 return `<p class="tower-prediction-reward">${bet.result==='correct'?'예측 보상 +'+bet.payout+'G · 💎 토큰 +1':bet.result==='draw'?'무승부 · '+bet.stake+'G 반환':bet.result==='abandoned'?'예측 포기 · '+bet.stake+'G 소모':'예측 실패 · '+bet.stake+'G 소모'}</p>`;
}
function leaveTowerPrediction(){
 if(!hasTowerPrediction())return false;if(towerPredictionContext.node.prediction.status==='running'){towerEventNavigationNotice();return false;}
 const saved=towerPredictionContext;roster=saved.roster.map(p=>({...p}));predictionTeams=saved.teams;predictionPick=saved.pick;predictionResult=saved.result;towerPredictionContext=null;running=false;paused=false;finished=true;accumulator=0;gameKind='tower';tower.phase='route';return true;
}
function returnTowerPrediction(){if(!leaveTowerPrediction())return false;showScreen('tower');return true;}
function renderTowerPredictionBattleHud(){
 if(!hasTowerPrediction())return;for(const id of ['returnSetup','rematch'])$(id).classList.remove('retreat-action');const bet=towerPredictionContext.node.prediction;
 $('battleModeLabel').textContent='타워 이벤트 · 전투 예측';$('towerBattleHud').hidden=false;renderTowerWallet('towerBattleHud');
 $('returnSetup').disabled=bet.status==='running';$('returnSetup').textContent=bet.status==='running'?'이벤트 진행 중':'← 탐험 지도로';$('rematch').disabled=bet.status==='running';$('rematch').textContent=bet.status==='running'?'경기 종료 후 지도 복귀':'탐험 지도로';$('homeLogo').disabled=bet.status==='running';
}
$('towerAbandon').onclick=openTowerAbandon;$('cancelTowerAbandon').onclick=closeTowerAbandon;$('confirmTowerAbandon').onclick=confirmTowerAbandon;
$('towerAbandonConfirm').addEventListener('cancel',closeTowerAbandon);$('towerAbandonConfirm').addEventListener('close',()=>{towerAbandonRun=null;});
$('newTower').onclick=()=>enterTower();$('towerHome').onclick=()=>{closeTowerMenu();showScreen('home');};
$('towerBody').addEventListener('click',e=>{
 const conquest=e.target.closest('[data-conquest-reward]');if(conquest){openTowerFloorReward(+conquest.dataset.conquestReward);return;}
 const inventoryCard=e.target.closest('[data-inventory-card]');if(inventoryCard){openStrategyCardInfo(+inventoryCard.dataset.inventoryCard);return;}
 const promoteMember=e.target.closest('[data-promotion-member]');if(promoteMember){selectTowerPromotionMember(+promoteMember.dataset.promotionMember);return;}
 const pick=e.target.closest('[data-tower-pick]');if(pick){chooseTowerPredictionTeam(+pick.dataset.towerPick);return;}
 const stake=e.target.closest('[data-tower-stake]');if(stake){chooseTowerPredictionStake(+stake.dataset.towerStake);return;}
 const node=e.target.closest('[data-tower-node]');if(node){chooseTowerNode(node.dataset.towerNode);return;}
 const member=e.target.closest('[data-tower-member]');if(member){const id=+member.dataset.towerMember,m=towerMember(id);if(!m)return;if(towerSelectedUnitId===id){openCharacterInfo(m.type,{guildId:id});return;}towerSelectedUnitId=id;renderTower();return;}
 const tab=e.target.closest('[data-tower-tab]');if(tab){towerShopTab=tab.dataset.towerTab;renderTower();return;}
 const buy=e.target.closest('[data-tower-buy]');if(buy){buyTowerItem(buy.dataset.towerBuy,+buy.dataset.shopCopy);return;}
 const equip=e.target.closest('[data-tower-equip]');if(equip){openTowerItemInfo(+equip.dataset.towerEquip);return;}
 const recruit=e.target.closest('[data-tower-recruit]');if(recruit){recruitTowerMember(+recruit.dataset.towerRecruit);return;}
 const info=e.target.closest('[data-recruit-info]');if(info){openCharacterInfo(+info.dataset.recruitInfo);return;}
 const rest=e.target.closest('[data-tower-rest]');if(rest){chooseTowerRest(rest.dataset.towerRest);return;}
 const event=e.target.closest('[data-tower-event]');if(event){chooseTowerEvent(event.dataset.towerEvent);return;}
 const action=e.target.closest('[data-tower-action]')?.dataset.towerAction;
 if(action==='enter'&&tower.phase==='lobby'){tower.phase='route';renderTower();}
 if(action==='promote')promoteTowerMembers();if(action==='promotionDone')finishTowerPromotion();
 if(action==='reroll')rerollTowerRecruit();if(action==='predict')launchTowerPrediction();if(action==='map')returnTowerMap();if(action==='floor')enterTowerFloor();if(action==='upgrade')upgradeTowerCharacter();if(action==='continue')continueTower();if(action==='retreat')retreatTowerRest();if(action==='done')completeTowerNode(towerFloor().kind==='shop'?'상점 정비 완료':'길드원 모집 완료');
 if(action==='new'&&(tower.gameOver||tower.phase==='complete'||tower.conquered)){resetTowerHpGameOver();closeTowerItemInfo();resetTowerFeedback();tower=newTowerState();towerSelectedUnitId=null;towerPlacementUnitId=null;towerShopTab='inventory';renderTower();}
});
if(['#tower','#towerSetup'].includes(location.hash))enterTower();

$('closeTowerRevival').onclick=()=>$('towerRevival').close();
$('confirmTowerRevival').onclick=confirmTowerRevival;
$('towerRevivalUnits').addEventListener('click',e=>{const member=e.target.closest('[data-revive-member]');if(member)selectTowerRevival(+member.dataset.reviveMember);});

$('closeTowerConquest').onclick=()=>$('towerConquest').close();
$('towerScene').addEventListener('click',skipTowerRecruitScene);
$('towerScene').addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' ')skipTowerRecruitScene(e);});
