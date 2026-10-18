'use strict';
const TRANSCENDENCE={hold:.16,deadzone:32,duration:1.15,windup:.38,active:.2,reach:310,cone:1.08};
let transcendence={press:null,aim:null,cast:null,controls:null},transSuppressClick=0;
function transcendenceOwned(u){return gameKind==='tower'?!!u.towerAlly:gameKind==='custom';}
function transcendenceFriendly(u){return transcendenceOwned(u)&&(gameKind==='custom'||u.faction==='team:0')&&!u.puppetControl;}
function setupTranscendencePractice(){if(gameKind==='custom')for(const u of units)u.transGauge=100;}
function refillCustomTranscendence(){
 if(gameKind!=='custom'||screen!=='battle'||!running||finished||cinema.intro>0||transcendenceFrozen())return false;
 let charged=false;for(const u of units)if(transcendenceFriendly(u)&&!skillChargeBlocked(u)&&(u.transGauge??0)<100){u.transGauge=100;charged=true;}
 renderTranscendenceBar();return charged;
}
function transcendenceFrozen(){return !!(transcendence.aim||transcendence.cast);}
function transcendenceReady(u){return !!u&&transcendenceFriendly(u)&&u.hp>0&&(u.transGauge??0)>=100&&!skillChargeBlocked(u)&&!u.ultCast&&!u.frogAction&&!u.heroRescue&&!novelLocked(u)&&running&&!finished&&screen==='battle'&&cinema.intro<=0&&!towerRetreatActive()&&!towerHpGameOverActive();}
function chargeTranscendence(u,damage,dealt){
 if(!transcendenceFriendly(u)||skillChargeBlocked(u)||damage<=0||transcendence.cast?.unitId===u.id)return 0;
 const before=u.transGauge??0,gain=damage/Math.max(1,u.maxHp)*(dealt?12:16)*combatFatigueFactor(u,'charge');u.transGauge=clamp(before+gain,0,100);return u.transGauge-before;
}
function setTranscendenceControls(disabled){
 if(disabled){if(transcendence.controls)return;const elements=[$('pause'),$('showStatus'),$('rematch'),$('returnSetup'),$('homeLogo'),...document.querySelectorAll('[data-speed]')];transcendence.controls=elements.map(element=>({element,disabled:!!element.disabled}));for(const element of elements)element.disabled=true;}
 else{for(const entry of transcendence.controls??[])entry.element.disabled=entry.disabled;transcendence.controls=null;}
}
function resetTranscendence(){
 const press=transcendence.press;transcendence.press=transcendence.aim=transcendence.cast=null;setTranscendenceControls(false);delete $('battleScreen').dataset.transcend;$('transJoystick').hidden=true;$('transCutin').hidden=true;
 if(press?.button?.hasPointerCapture?.(press.pointer))press.button.releasePointerCapture(press.pointer);
 accumulator=0;
}
function beginTranscendenceAim(unitId,origin={x:0,y:0},keyboard=false){
 const u=units.find(v=>v.id===unitId);if(transcendenceFrozen()||!transcendenceReady(u))return false;
 transcendence.aim={unitId,origin:{...origin},angle:u.face,outside:false,keyboard};accumulator=0;setTranscendenceControls(true);$('battleScreen').dataset.transcend='aim';updateTranscendenceAim(origin.x,origin.y);return true;
}
function updateTranscendenceAim(x,y){
 const aim=transcendence.aim;if(!aim)return;const dx=x-aim.origin.x,dy=y-aim.origin.y,length=Math.hypot(dx,dy);aim.outside=length>=TRANSCENDENCE.deadzone;if(aim.outside)aim.angle=Math.atan2(dy,dx);
 const stick=$('transJoystick');stick.hidden=false;stick.style.left=aim.origin.x+'px';stick.style.top=aim.origin.y+'px';stick.style.setProperty?.('--stick-x',dx/Math.max(1,length)*Math.min(length,64)+'px');stick.style.setProperty?.('--stick-y',dy/Math.max(1,length)*Math.min(length,64)+'px');stick.dataset.outside=String(aim.outside);
}
function releaseTranscendenceAim(cancel=false){
 const aim=transcendence.aim;if(!aim)return false;
 const u=units.find(v=>v.id===aim.unitId);if(cancel||!aim.outside||!transcendenceReady(u)){resetTranscendence();return false;}
 transcendence.aim=null;transcendence.press=null;$('transJoystick').hidden=true;
 u.transGauge=0;u.attack=null;u.dodgeState=u.strategyDash=null;u.evadeTime=0;u.kx=u.ky=u.vx=u.vy=u.headingX=u.headingY=0;u.face=aim.angle;u.revealTime=3;
 for(const strike of meleeStrikes)if(strike.source.id===u.id)strike.life=0;
 transcendence.cast={unitId:u.id,angle:aim.angle,t:0,released:false,hitIds:new Set(),origin:{x:u.x,y:u.y}};accumulator=0;$('battleScreen').dataset.transcend='cast';
 $('transCutinIcon').textContent=EMOJIS[u.type];$('transCutin').setAttribute('aria-label',u.name+' · 초월 검격');$('transCutin').style.opacity='1';$('transCutin').hidden=false;renderTranscendenceBar();return true;
}
function advanceTranscendence(dt){
 const wasFrozen=transcendenceFrozen();if(screen!=='battle'||!running||finished||gameKind==='tower'&&tower?.gameOver){if(wasFrozen||transcendence.press)resetTranscendence();return false;}
 const press=transcendence.press;if(press&&!press.scrolling&&!transcendence.aim&&!transcendence.cast){const u=units.find(v=>v.id===press.unitId);if(!transcendenceReady(u)){resetTranscendence();return false;}press.held+=Math.max(0,dt);if(press.held>=TRANSCENDENCE.hold&&beginTranscendenceAim(press.unitId,press.origin)){press.activated=true;updateTranscendenceAim(press.x,press.y);}}
 const cast=transcendence.cast;if(cast){
  const u=units.find(v=>v.id===cast.unitId);if(!u||u.hp<=0){resetTranscendence();return true;}
  const previous=cast.t;cast.t+=Math.max(0,dt);u.face=cast.angle;u.action='초월 · 검격';$('transCutin').style.opacity=String(1-clamp((cast.t-.72)/.3,0,1));
  const progress=t=>clamp((t-TRANSCENDENCE.windup)/TRANSCENDENCE.active,0,1),move=(progress(cast.t)-progress(previous))*34;
  u.x=clamp(u.x+Math.cos(cast.angle)*move,28,772);u.y=clamp(u.y+Math.sin(cast.angle)*move,28,772);
  if(!cast.released&&cast.t>=TRANSCENDENCE.windup){cast.released=true;
   for(const enemy of alive()){if(enemy.faction===u.faction||frogUnavailable(enemy))continue;const distance=dist(u,enemy),angle=Math.atan2(enemy.y-u.y,enemy.x-u.x);if(distance>TRANSCENDENCE.reach*unitScale(u)+27*unitScale(enemy)||Math.abs(angleDelta(angle,cast.angle))>TRANSCENDENCE.cone)continue;cast.hitIds.add(enemy.id);hit(enemy,u.dmg*5+60,u,{angle:cast.angle,impulse:380,transcendent:true,attackOrigin:{x:u.x,y:u.y}});}
   addLog(u.name+' · 초월 검격');
  }
  if(cast.t>=TRANSCENDENCE.duration){resetTranscendence();renderTranscendenceBar();const left=alive();if(new Set(left.map(puppetOriginalFaction)).size<=1)finish(left);}
 }
 return wasFrozen||transcendenceFrozen();
}
function renderTranscendenceBar(){
 const bar=$('transcendenceBar'),owned=units.filter(transcendenceOwned);bar.hidden=screen!=='battle'||!running||finished||!owned.length;
 if(bar.hidden)return;bar.setAttribute('aria-label',gameKind==='custom'?'모든 팀 초월 스킬 시험 · 길게 누르고 끌어 방향 지정':'아군 초월 스킬 · 길게 누르고 끌어 방향 지정');const signature=gameKind+':'+owned.map(u=>u.id).join(',');
 if(bar.dataset.signature!==signature){bar.dataset.signature=signature;bar.innerHTML=(gameKind==='custom'?'<button class="trans-practice" data-trans-refill type="button" title="커스텀 전투 · 생존 유닛의 초월 게이지 충전" aria-label="초월 충전 · 커스텀 전투에서 다시 시험하기"><span aria-hidden="true">💠</span><small>초월 충전</small></button>':'')+owned.map(u=>`<button class="trans-unit" data-trans-unit="${u.id}" type="button" style="--trans-team:${unitHpColor(u)}" title="${u.team>=0?TEAM_NAMES[u.team]+' · ':''}${u.name} · 초월 검격"><span class="trans-avatar"><span class="trans-glyph">${EMOJIS[u.type]}</span><span class="trans-ready-fx" aria-hidden="true">${Array.from({length:6},(_,i)=>'<i style="--spark:'+i+'"></i>').join('')}</span></span><i class="trans-meter" role="progressbar" aria-label="${u.name} 초월 게이지" aria-valuemin="0" aria-valuemax="100" aria-valuenow="${Math.floor(u.transGauge??0)}"><em style="width:${u.transGauge??0}%"></em></i><small>${Math.floor(u.transGauge??0)}%</small></button>`).join('');}
 for(const button of bar.querySelectorAll?.('[data-trans-unit]')??[]){const u=units.find(v=>v.id===+button.dataset.transUnit),gauge=Math.floor(u.transGauge??0),ready=transcendenceReady(u),locked=skillChargeBlocked(u)||!transcendenceFriendly(u);button.dataset.ready=String(ready);button.classList.toggle('ready',ready);button.classList.toggle('locked',locked);button.classList.toggle('dead',u.hp<=0);button.classList.toggle('selected',turning.selectedId===u.id&&strategyBattleFrozen());button.setAttribute('aria-label',(u.team>=0?TEAM_NAMES[u.team]+' · ':'')+u.name+' · 초월 검격 '+gauge+'%'+(u.hp<=0?' · 전투불능':locked?' · 군중제어':ready?' · 길게 눌러 방향 지정':''));button.querySelector('small').textContent=u.hp<=0?'—':locked?'🔒 '+gauge+'%':gauge+'%';button.querySelector('.trans-meter').setAttribute('aria-valuenow',gauge);button.querySelector('.trans-meter em').style.width=gauge+'%';}
 const refill=bar.querySelector?.('[data-trans-refill]');if(refill)refill.disabled=transcendenceFrozen()||cinema.intro>0||!owned.some(u=>!skillChargeBlocked(u)&&transcendenceFriendly(u)&&(u.transGauge??0)<100);
 fitTurningArena();
}
// Size the mobile map from the actual compact controls, including wrapped messages.
function fitTurningArena(){
 if(!strategyBattleFrozen()||!window.matchMedia('(max-width:720px)').matches||!$('turningPanel').getBoundingClientRect)return;
 const column=$('arena').parentElement.parentElement,panel=$('turningPanel'),bar=$('transcendenceBar'),top=column.getBoundingClientRect().top;
 const available=(window.visualViewport?.height??window.innerHeight)-top-panel.getBoundingClientRect().height-(bar.hidden?0:bar.getBoundingClientRect().height+5)-16;
 if(Number.isFinite(available))$('battleScreen').style.setProperty('--turning-arena',Math.max(140,Math.floor(available))+'px');
}
function transPointerDown(e){
 const button=e.target.closest('[data-trans-unit]');if(!button||e.button!==0||transcendenceFrozen())return;const u=units.find(v=>v.id===+button.dataset.transUnit);if(!transcendenceReady(u))return;
 const rect=(button.querySelector('.trans-avatar')??button).getBoundingClientRect();transcendence.press={unitId:u.id,pointer:e.pointerId,button,origin:{x:rect.x+rect.width/2,y:rect.y+rect.height/2},x:e.clientX,y:e.clientY,startX:e.clientX,startY:e.clientY,startScroll:$('transcendenceBar').scrollLeft,held:0,activated:false,scrolling:false};button.setPointerCapture?.(e.pointerId);
}
function transPointerMove(e){
 const press=transcendence.press;if(!press||press.pointer!==e.pointerId)return;press.x=e.clientX;press.y=e.clientY;
 if(transcendence.aim){e.preventDefault();if(Math.hypot(e.clientX-press.startX,e.clientY-press.startY)>4)press.dragged=true;updateTranscendenceAim(e.clientX,e.clientY);return;}
 if(Math.hypot(e.clientX-press.startX,e.clientY-press.startY)>12){press.scrolling=true;$('transcendenceBar').scrollLeft=press.startScroll-(e.clientX-press.startX);}
}
function transPointerUp(e,cancel=false){
 const press=transcendence.press;if(!press||press.pointer!==e.pointerId)return;
 transSuppressClick=Date.now()+400;if(transcendence.aim){if(!cancel)updateTranscendenceAim(press.dragged?e.clientX:press.origin.x,press.dragged?e.clientY:press.origin.y);releaseTranscendenceAim(cancel);}else if(!cancel&&!press.scrolling&&strategyBattleFrozen()){turning.selectedId=press.unitId;renderTurningPanel();}
 transcendence.press=null;if(press.button.hasPointerCapture?.(e.pointerId))press.button.releasePointerCapture(e.pointerId);
}
const transBar=$('transcendenceBar');transBar.addEventListener('pointerdown',transPointerDown);transBar.addEventListener('pointermove',transPointerMove);transBar.addEventListener('pointerup',e=>transPointerUp(e));transBar.addEventListener('pointercancel',e=>transPointerUp(e,true));transBar.addEventListener('lostpointercapture',e=>transPointerUp(e,true));
transBar.addEventListener('contextmenu',e=>e.preventDefault());
transBar.addEventListener('click',e=>{if(transcendenceFrozen())return;if(e.target.closest('[data-trans-refill]')){refillCustomTranscendence();return;}if(Date.now()<transSuppressClick||!strategyBattleFrozen())return;const button=e.target.closest('[data-trans-unit]');if(!button)return;turning.selectedId=+button.dataset.transUnit;renderTurningPanel();});
transBar.addEventListener('keydown',e=>{const button=e.target.closest('[data-trans-unit]');if(!button)return;if((e.key==='Enter'||e.key===' ')&&!transcendence.aim){e.preventDefault();const r=button.getBoundingClientRect();beginTranscendenceAim(+button.dataset.transUnit,{x:r.x+r.width/2,y:r.y+r.height/2},true);}else if(transcendence.aim?.keyboard){e.preventDefault();if(e.key==='Escape')releaseTranscendenceAim(true);else if(e.key==='Enter'||e.key===' ')releaseTranscendenceAim();else{const direction={ArrowRight:[64,0],ArrowLeft:[-64,0],ArrowUp:[0,-64],ArrowDown:[0,64]}[e.key],origin=transcendence.aim.origin;if(direction)updateTranscendenceAim(origin.x+direction[0],origin.y+direction[1]);}}});
window.addEventListener('blur',()=>{if(transcendence.aim||transcendence.press){resetTranscendence();renderTranscendenceBar();}});
window.addEventListener('keydown',e=>{if(e.key==='Escape'&&transcendence.aim){e.preventDefault();releaseTranscendenceAim(true);}});
window.addEventListener('resize',fitTurningArena);

function renderTranscendence(){
 const state=transcendence.aim??transcendence.cast;if(!state)return;const u=units.find(v=>v.id===state.unitId);if(!u||u.hp<=0)return;const aim=transcendence.aim,range=TRANSCENDENCE.reach*unitScale(u),angle=state.angle;
 if(aim){ctx.save();ctx.translate(u.x,u.y);ctx.rotate(angle);ctx.beginPath();ctx.moveTo(0,0);ctx.arc(0,0,range,-TRANSCENDENCE.cone,TRANSCENDENCE.cone);ctx.closePath();ctx.fillStyle=aim.outside?'#b9dcff20':'#b9dcff0b';ctx.fill();ctx.strokeStyle=aim.outside?'#c6e6ffb0':'#abc6dd40';ctx.lineWidth=2;ctx.stroke();if(aim.outside){bladeStreak(range*.55,0,0,range*.5,5,'#cbe8ff',.9);pixelSprite(range,0,'#fff4c9',1.5,'star');}ctx.restore();return;}
 const t=state.t,windup=clamp(t/TRANSCENDENCE.windup,0,1),swing=clamp((t-TRANSCENDENCE.windup)/TRANSCENDENCE.active,0,1),recovery=clamp((t-TRANSCENDENCE.windup-TRANSCENDENCE.active)/.57,0,1);
 ctx.save();ctx.translate(u.x,u.y);ctx.rotate(angle+(t<TRANSCENDENCE.windup?-windup*1.8:-1.8+swing*3.6));ctx.translate(22,12);sword(120*unitScale(u),15,'#e4f4ff');ctx.restore();
 if(t<TRANSCENDENCE.windup){for(let i=0;i<7;i++){const a=angle+i*Math.PI*2/7,d=65*(1-windup)+30;pixelSprite(u.x+Math.cos(a)*d,u.y+Math.sin(a)*d,'#c4e5ff',.6+windup*.6,'star',windup*.8);}return;}
 const fade=1-recovery;if(fade<=0)return;for(let i=0;i<4;i++){const radius=range*(.62+i*.1);slashStroke(u.x,u.y,radius,angle-TRANSCENDENCE.cone,angle-TRANSCENDENCE.cone+Math.max(.08,swing*2*TRANSCENDENCE.cone),i===3?'#f9fdff':'#b9dfff',i===3?10:24-i*3,fade*(i===3?1:.35));}
 for(let i=0;i<13;i++){const a=angle-TRANSCENDENCE.cone+2*TRANSCENDENCE.cone*i/12,d=range*(.85+recovery*.12);bladeStreak(u.x+Math.cos(a)*d,u.y+Math.sin(a)*d,a,25+recovery*30,4,'#e5f4ff',fade*.75);}
}
function launchOpeningEquipment(){
 if(!['tower','custom'].includes(gameKind))return;const room=gameKind==='tower'?towerFloor():null;if(room&&(room.combatStarted||Object.keys(room.enemyState??{}).length))return;
 for(const u of alive())for(let i=0;i<(u.openingAwlCount??0);i++)projectiles.push({kind:'openingAwl',x:u.x+30,y:u.y,vx:1050,vy:0,source:u,type:u.type,color:'#ead6a4',damage:0,power:45,radius:28,visualScale:1,life:1.1,trail:[],homing:false,guaranteed:false,hiddenLaunch:false});
}
function openingAwlImpact(p,target){
 p.life=0;if(target.hp<=0||target.invincible>0)return;
 if(interceptMirrorAttack(target,p.source,p.power,{angle:0,attackToken:p,impulse:0})||tryBasicParry(target,p.source,0,p.power,p))return;
 stunParryEnemy(target,4);fx('awlPin',target.x,target.y,'#ffe3a4',.55,{r:65});impact(target.x,target.y,'#ead6a4',1.4,0);burst(target.x,target.y,'#fff0c5',18,280,1.5,0,'shard');
}
function renderOpeningAwl(p){ctx.save();ctx.translate(p.x,p.y);ctx.rotate(Math.atan2(p.vy,p.vx));bladeStreak(-10,0,0,65,5,'#ead6a4',.75);ctx.fillStyle='#8a6240';ctx.fillRect(-22,-5,16,10);ctx.fillStyle='#edf5fc';ctx.beginPath();ctx.moveTo(-6,-4);ctx.lineTo(27,0);ctx.lineTo(-6,4);ctx.closePath();ctx.fill();ctx.restore();}
function renderAwlPin(e){const fade=e.life/e.max;for(let i=0;i<8;i++){const a=i*Math.PI/4,r=30+(1-fade)*e.r;bladeStreak(e.x+Math.cos(a)*r,e.y+Math.sin(a)*r,a,18,4,'#ffe4a5',fade);}pixelSprite(e.x,e.y,'#fff5d4',2.5*fade,'star',fade);}
