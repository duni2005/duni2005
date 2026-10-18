'use strict';
// Presentation uses wall time; headless simulation keeps its normal fixed step.
let gameKind='custom',customRoster=null,predictionTeams=[],predictionPick=null,predictionResult=null;
let cinema={enabled:false,intro:0,anticipation:0,cooldown:0,ending:0,confirmed:false,zoom:1,x:400,y:400,focus:{x:400,y:400}},battleSnapshot=null;
function restoreCustomRoster(){if(customRoster){roster=customRoster.map(p=>({...p}));customRoster=null;}}
function createPredictionTeams(){const count=Math.random()<.55?2:3,size=Math.random()<.7?2:3;
 const pools=[[0,5],[0,2],[0,3],[0,0],[3,5],[1,4],[1,2],[3,4],[2,5],[1,3],[6,4],[6,5],[7,8],[7,5],[8,0],[6,7],[8,8],[9,5],[9,4],[9,6],[9,8],[9,1],[10,5],[10,11],[11,6],[11,8],[10,4],[11,9],[12,5],[12,4],[12,11],[12,0],[13,4],[13,5],[13,0],[13,7],[17,5],[17,4],[17,18],[18,0],[18,5],[18,15],[19,0],[19,18],[19,17],[20,15],[20,4],[20,19],[21,0],[21,5],[21,20],[22,0],[22,1],[22,4],[22,3],[23,4],[23,5],[23,0],[23,22]];const teams=[];
 for(let team=0;team<count;team++){const combo=pools[Math.floor(Math.random()*pools.length)].slice();if(size===3)combo.push(Math.floor(Math.random()*TYPES.length));teams.push({team,types:combo});}
 return teams;}
function generatePrediction(){
 if(typeof towerCombatEntryLocked==='function'&&towerCombatEntryLocked()){towerCombatNavigationNotice();return false;}
 if(typeof towerRetreatActive==='function'&&towerRetreatActive())return false;
 if(gameKind==='tower'&&running){if(!canRetreatTower())return false;predictionPick=null;predictionResult=null;predictionTeams=createPredictionTeams();renderPrediction();retreatTowerBattle({destination:'prediction'});return false;}
 if(typeof hasTowerPrediction==='function'&&hasTowerPrediction())leaveTowerPrediction();
 if(gameKind==='tower')leaveTowerMode();
 restoreCustomRoster();gameKind='prediction';predictionPick=null;predictionResult=null;predictionTeams=createPredictionTeams();renderPrediction();showScreen('prediction');
}
function predictionChoicesMarkup(teams,pick,attribute='data-pick'){return teams.map(t=>`<button class="prediction-card ${pick===t.team?'selected':''}" ${attribute}="${t.team}" aria-pressed="${pick===t.team}" style="--team:${TEAM_COLORS[t.team]}"><span class="team-heading">${TEAM_NAMES[t.team]} 팀 <i>${pick===t.team?'✓':'○'}</i></span><div class="prediction-members">${t.types.map(type=>`<div>${portrait(type)}<b>${TYPES[type].name}</b></div>`).join('')}</div><span class="prediction-tags">${t.types.map(i=>TYPES[i].tags.find(tag=>tag!=='일반')).join(' · ')}</span></button>`).join('');}
function createPredictionRoster(teams){return teams.flatMap(t=>t.types.map(type=>({id:nextId++,type,team:t.team})));}
function renderPrediction(){$('predictionChoices').innerHTML=predictionChoicesMarkup(predictionTeams,predictionPick);$('startPrediction').disabled=predictionPick===null;$('predictionSelection').textContent=predictionPick===null?'승리할 팀을 선택하세요':TEAM_NAMES[predictionPick]+' 팀 승리를 예측했습니다';}
function launchPrediction(){if(typeof towerCombatEntryLocked==='function'&&towerCombatEntryLocked()){towerCombatNavigationNotice();return false;}if(predictionPick===null||running||typeof hasTowerPrediction==='function'&&hasTowerPrediction())return false;gameKind='prediction';if(!customRoster)customRoster=roster.map(p=>({...p}));roster=createPredictionRoster(predictionTeams);predictionResult=null;return startBattle({cinematic:true});}
function predictionVerdict(left){if(gameKind!=='prediction')return '';const winning=left[0]?.team;predictionResult=winning===undefined?'draw':winning===predictionPick?'correct':'incorrect';const towerReward=typeof hasTowerPrediction==='function'&&hasTowerPrediction()?settleTowerPrediction(predictionResult):'';return `<div class="prediction-verdict ${predictionResult}">${predictionResult==='correct'?'예측 성공!':predictionResult==='incorrect'?'예측 실패':'무승부 · 예측 판정 없음'}</div><p>내 선택: ${TEAM_NAMES[predictionPick]} 팀</p>${towerReward}`;}
function beginSpectacle(enabled){if(typeof resetTurningPoint==='function')resetTurningPoint(enabled);$('returnSetup').hidden=false;$('returnSetup').classList.remove('retreat-action');$('rematch').classList.remove('retreat-action');battleSnapshot={kind:gameKind,pick:predictionPick,roster:roster.map(p=>({...p}))};cinema={enabled,intro:enabled?2.5:0,anticipation:0,cooldown:0,ending:0,confirmed:false,zoom:1,x:400,y:400,focus:{x:400,y:400}};$('cinemaBars').hidden=true;$('battleIntro').hidden=!enabled;$('pause').disabled=enabled;$('battleModeLabel').textContent=gameKind==='prediction'?`승부 예측 · ${TEAM_NAMES[predictionPick]} 팀 선택`:'커스텀 전투';$('returnSetup').textContent=gameKind==='prediction'?'← 승부 예측':'← 전투 설정';$('rematch').textContent=gameKind==='prediction'?'↻ 다음 예측':'↻ 다시 전투';
 if(gameKind==='tower'){$('battleModeLabel').textContent='두니 타워 · '+towerFloor().name;renderTowerBattleHud();}else{$('rematch').disabled=false;$('towerBattleHud').hidden=true;}
 if(typeof hasTowerPrediction==='function'&&hasTowerPrediction())renderTowerPredictionBattleHud();
 if(enabled){const groups=new Map();for(const p of roster){const key=faction(p);if(!groups.has(key))groups.set(key,[]);groups.get(key).push(p);}const list=[...groups.values()].slice(0,8);$('battleIntro').innerHTML=`<div class="intro-matchup ${list.length>4?'many-teams':''}">${list.map((group,i)=>`${i?'<strong class="intro-vs">VS</strong>':''}<div class="intro-team" style="--team:${group[0].team>=0?TEAM_COLORS[group[0].team]:TYPES[group[0].type].color}"><b>${group[0].team>=0?TEAM_NAMES[group[0].team]+' 팀':TYPES[group[0].type].name}</b><div>${group.slice(0,4).map(p=>portrait(p.type)).join('')}${group.length>4?'<small>+'+(group.length-4)+'</small>':''}</div></div>`).join('')}</div><span class="intro-caption">${groups.size>8?groups.size+'개 진영 · ':''}최후의 생존자가 승리합니다</span>`;}
}
function isDecisiveTarget(target,source){const live=alive();return target.faction!==source.faction&&new Set(live.map(puppetOriginalFaction)).size===2&&live.filter(u=>puppetOriginalFaction(u)===puppetOriginalFaction(target)).length===1;}
function finalHitConfirmed(target,source,force=false){if(!cinema.enabled||!force&&!isDecisiveTarget(target,source))return;cinema.confirmed=true;cinema.ending=1.55;cinema.intro=0;cinema.focus={x:target.x,y:target.y};$('cinemaBars').hidden=false;}
function watchFinalThreat(){if(!cinema.enabled||cinema.confirmed||cinema.anticipation>0||cinema.cooldown>0)return;for(const t of alive()){if(t.invincible>0)continue;for(const s of alive()){if(!isDecisiveTarget(t,s))continue;const power=Math.max(s.dmg*1.5,...projectiles.filter(p=>p.source.id===s.id&&p.life>0&&dist(p,t)<(p.kind==='bomb'?p.blastRadius+24:155)).map(p=>(p.damage??s.dmg)*1.5));const estimate=power*(t.type===4?.8:1)*100/(100+combatArmor(t))*(1+Math.max(0,elapsed-60)/70);if(t.hp+activeShieldHp(t)>estimate)continue;const a=s.attack;const melee=a&&a.kind!=='heal'&&a.targetId===t.id&&s.range<100&&dist(s,t)<a.profile.reach+20;
 const missile=projectiles.some(p=>p.kind!=='bomb'&&p.source.id===s.id&&p.life>0&&dist(p,t)<155&&((t.x-p.x)*p.vx+(t.y-p.y)*p.vy)>0&&distanceToSegment(t,p,{x:p.x+p.vx*.4,y:p.y+p.vy*.4})<38);
 const explosive=projectiles.some(p=>p.kind==='bomb'&&p.source.id===s.id&&p.life>0&&p.fuse<.65&&dist(p,t)<p.blastRadius+24)||s.type===13&&s.bomberFuse!=null&&s.bomberFuse<.6&&dist(s,t)<165*unitScale(s);
 if(melee||missile||explosive){cinema.anticipation=1.5;cinema.focus={x:t.x,y:t.y};return;}}
 }}
// Framing follows every living unit, independently of battle speed and finale effects.
const BATTLE_CAMERA_MAX_ZOOM=2.2;
function battleCameraBounds(live,padding=0,predict=false){
 const b={minX:Infinity,minY:Infinity,maxX:-Infinity,maxY:-Infinity};
 for(const u of live){const scale=unitScale(u),rx=32*scale+padding,top=52*scale+padding,bottom=36*scale+padding,px=u.x+(predict?clamp((u.vx??0)*.25,-55,55):0),py=u.y+(predict?clamp((u.vy??0)*.25,-55,55):0);
  b.minX=Math.min(b.minX,u.x-rx,px-rx);b.maxX=Math.max(b.maxX,u.x+rx,px+rx);b.minY=Math.min(b.minY,u.y-top,py-top);b.maxY=Math.max(b.maxY,u.y+bottom,py+bottom);
 }return b;
}
function battleCameraFraming(live=alive()){
 if(!live.length)return null;const b=battleCameraBounds(live,48,true);
 return{x:(b.minX+b.maxX)/2,y:(b.minY+b.maxY)/2,zoom:Math.min(BATTLE_CAMERA_MAX_ZOOM,800/Math.max(b.maxX-b.minX,b.maxY-b.minY,1))};
}
function battleCameraFitZoom(bounds,x,y){return 400/Math.max(x-bounds.minX,bounds.maxX-x,y-bounds.minY,bounds.maxY-y,1);}
function advanceBattleCamera(dt){
 if(typeof transcendenceFrozen==='function'&&transcendenceFrozen())return;
 if(screen!=='battle'||paused||dt<=0||cinema.intro>0||typeof towerRetreatActive==='function'&&towerRetreatActive()||typeof strategyBattleFrozen==='function'&&strategyBattleFrozen())return;
 const finale=cinema.enabled&&cinema.confirmed&&cinema.ending>0;
 if(!running&&!finale)return;
 const live=alive(),framing=battleCameraFraming(live);if(!framing&&!finale)return;
 const strategyOverview=typeof strategyBattleActive==='function'&&strategyBattleActive(),target=finale?{x:cinema.focus.x,y:cinema.focus.y,zoom:2.8}:strategyOverview?{x:400,y:400,zoom:1}:framing;
 // Reduced motion suppresses shake and decorative effects, not essential framing.
 const pan=1-Math.exp(-dt*(reducedMotion?1.5:finale?8:2.7));cinema.x+=(target.x-cinema.x)*pan;cinema.y+=(target.y-cinema.y)*pan;
 const zoomRate=reducedMotion?(target.zoom<cinema.zoom?3:1):finale?8:target.zoom<cinema.zoom?5:1.5;cinema.zoom+=(target.zoom-cinema.zoom)*(1-Math.exp(-dt*zoomRate));
 // Keep bodies and HP bars in view even during a fast dash or a spread-out clash.
 if(!finale&&!strategyOverview&&live.length)cinema.zoom=Math.min(cinema.zoom,battleCameraFitZoom(battleCameraBounds(live,12),cinema.x,cinema.y));
}
function advanceSpectacle(dt){if(!cinema.enabled)return false;if(cinema.intro>0){cinema.intro=Math.max(0,cinema.intro-dt);if(cinema.intro===0){$('battleIntro').hidden=true;$('pause').disabled=false;}return true;}
 if(!paused){cinema.cooldown=Math.max(0,cinema.cooldown-dt);if(cinema.anticipation>0){cinema.anticipation=Math.max(0,cinema.anticipation-dt);if(!cinema.anticipation)cinema.cooldown=3;}if(cinema.ending>0){cinema.ending=Math.max(0,cinema.ending-dt);if(!cinema.ending){$('cinemaBars').hidden=true;cinema.anticipation=0;presentBattleResult();}}}return false;
}
function spectacleScale(){return cinema.enabled&&cinema.anticipation>0&&!reducedMotion?.32/speed:1;}
function drawSpectatorCamera(){ctx.translate(400,400);ctx.scale(cinema.zoom,cinema.zoom);ctx.translate(-cinema.x,-cinema.y);}
function endingMotion(dt){const slow=dt*.18;advancePresentation(slow);for(const strike of meleeStrikes){strike.age=Math.min(strike.duration,strike.age+slow);strike.life=Math.max(0,strike.life-slow);}for(const p of projectiles){if(p.life>0){p.x+=p.vx*slow;p.y+=p.vy*slow;p.life-=slow;}}for(const u of units){if(u.attack?.phase==='active'){u.attack.t=Math.min(u.attack.profile.active,u.attack.t+slow);}u.flash=Math.max(0,u.flash-dt*.18);u.hitRecoil=(u.hitRecoil??0)*Math.exp(-dt*2);if(u.hp<=0){u.x=clamp(u.x+u.kx*dt*.18,28,772);u.y=clamp(u.y+u.ky*dt*.18,28,772);u.kx*=Math.exp(-dt*1.5);u.ky*=Math.exp(-dt*1.5);}}}
function initSpectator(){$('newPrediction').onclick=generatePrediction;$('predictionHome').onclick=()=>showScreen('home');$('shufflePrediction').onclick=generatePrediction;$('predictionChoices').addEventListener('click',e=>{const b=e.target.closest('[data-pick]');if(!b||screen!=='prediction'||running)return;predictionPick=+b.dataset.pick;renderPrediction();});$('startPrediction').onclick=launchPrediction;$('closeBattleDetails').onclick=()=>$('battleDetails').close();$('showStatus').onclick=()=>{$('battleDetails').showModal();updateStats();};}

const MULTI_KILL_NAMES=['','','더블킬','트리플킬','쿼드라킬','펜타킬','헥사킬'];
const KILL_CHAIN_WINDOW=6;
let killPresentation={clock:0,feed:[],streaks:new Map(),banner:null,queue:[],serial:0};
function resetKillPresentation(){killPresentation={clock:0,feed:[],streaks:new Map(),banner:null,queue:[],serial:0};$('killFeed').innerHTML='';$('multiKill').innerHTML='';$('multiKill').hidden=true;}
function killUnitSnapshot(u){return{id:u.id,type:u.type,name:TYPES[u.type].name,color:unitHpColor(u)};}
function killUnitMarkup(u){return `<span class="kill-unit" style="--kill-color:${u.color}"><i aria-hidden="true">${EMOJIS[u.type]}</i><span><b>${u.name}</b><small>#${u.id}</small></span></span>`;}
function renderKillFeed(){const k=killPresentation;$('killFeed').innerHTML=k.feed.map(row=>`<div class="kill-row" data-kill-id="${row.id}" aria-label="${row.killer.name} ${row.killer.id} 처치 ${row.victim.name} ${row.victim.id}">${killUnitMarkup(row.killer)}<span class="kill-sword" aria-hidden="true">⚔️</span>${killUnitMarkup(row.victim)}</div>`).join('');positionKillFeed();}
function positionKillFeed(){const k=killPresentation;for(const el of document.querySelectorAll('#killFeed [data-kill-id]')){const row=k.feed.find(r=>r.id===+el.dataset.killId);if(!row)continue;const age=k.clock-row.born,enter=clamp(age/.16,0,1);el.style.opacity=String(Math.min(enter,clamp((3-age)/.8,0,1)));el.style.transform=`translateY(calc(${row.y} * (100% + 5px))) translateX(${reducedMotion?0:(1-enter)*12}px)`;}}
function showMultiKill(item){killPresentation.banner={...item,born:killPresentation.clock};const level=Math.min(6,item.count);$('multiKill').innerHTML=`<div class="multi-kill-unit">${killUnitMarkup(item.killer)}</div><strong>${MULTI_KILL_NAMES[level]}</strong><div class="multi-kill-ticks" aria-hidden="true">${Array.from({length:level},()=>'<i></i>').join('')}</div>`;$('multiKill').style.setProperty?.('--multi-color',item.killer.color);$('multiKill').hidden=false;}
function queueMultiKill(killer,count){const k=killPresentation,item={killer,count};if(!k.banner||k.banner.killer.id===killer.id){showMultiKill(item);return;}const waiting=k.queue.find(row=>row.killer.id===killer.id);if(waiting)waiting.count=count;else k.queue.push(item);}
function recordKill(source,target){const k=killPresentation;k.streaks.delete(target.id);const killer=killUnitSnapshot(source),victim=killUnitSnapshot(target);k.feed.push({id:++k.serial,killer,victim,born:k.clock,y:k.feed.length});renderKillFeed();if(source.hp<=0)return;const previous=k.streaks.get(source.id),count=previous&&elapsed-previous.lastAt<=KILL_CHAIN_WINDOW?previous.count+1:1;k.streaks.set(source.id,{count,lastAt:elapsed});if(count>=2&&count<=6)queueMultiKill(killer,count);}
function advanceKillPresentation(dt){const k=killPresentation;k.clock+=dt;const oldLength=k.feed.length;k.feed=k.feed.filter(row=>k.clock-row.born<3);const blend=reducedMotion?1:1-Math.exp(-dt*7);k.feed.forEach((row,index)=>{row.y+=(index-row.y)*blend;});if(k.feed.length!==oldLength)renderKillFeed();else positionKillFeed();if(k.banner){const age=k.clock-k.banner.born,enter=clamp(age/.18,0,1),fade=clamp((2.6-age)/.55,0,1),el=$('multiKill');el.style.opacity=String(Math.min(enter,fade));el.style.transform=`translateX(-50%) translateY(${reducedMotion?0:(1-enter)*-8}px) scale(${reducedMotion?1:1+(1-enter)*.12})`;if(age>=2.6){k.banner=null;el.hidden=true;if(k.queue.length)showMultiKill(k.queue.shift());}}}
