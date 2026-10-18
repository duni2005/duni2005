const fs=require('fs'),create=require('../../tests/arena-harness.cjs');const results=[];
for(const stance of ['normal','cautious','rush','cover']){const h=create(4029);h.box.stance=stance;
h.run(`gameKind='custom';roster=[{id:1,type:0,team:0,x:400,y:400},{id:2,type:0,team:1,x:470,y:400}];startBattle();const u=units[0],e=units[1];u.stance=u.combatStance=stance;globalThis.counts={parry:0,dodge:0,counter:0,hold:0};
for(let i=0;i<4000;i++){elapsed=i*3;u.hp=u.maxHp;u.parryTime=u.parryCooldown=u.stun=u.evadeTime=0;u.attack=u.ultCast=u.dodgeState=u.strategyDash=null;u.face=0;u.ai.response=null;u.ai.readAttacks=new Map();u.ai.attackDecision=null;u.ai.commitUntil=u.ai.disengageUntil=u.ai.punishUntil=0;effects=[];particles=[];
e.attack={kind:'attack',phase:'windup',t:0,profile:ATTACK_PROFILES[0],angle:Math.PI,targetId:u.id,serial:i+1};advanceThreatResponse(u,[e]);const read=u.ai.readAttacks.get(e.attack);elapsed=read.at+.00001;advanceThreatResponse(u,[e]);if(!u.ai.response)throw Error('Missing response');counts[u.ai.response.mode]++;}
`);results.push({stance,trials:4000,counts:h.run('counts')});}
fs.writeFileSync('godot/migration/phase105-web-reactions.json',JSON.stringify(results,null,2));console.log(results);
