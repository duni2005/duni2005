const fs=require('fs'),vm=require('vm');
const src=fs.readFileSync('dist/tower.js','utf8');
function extract(name){let start=src.indexOf('function '+name+'('),open=src.indexOf('{',start),depth=1,i=open+1;while(depth&&i<src.length){if(src[i]==='{')depth++;if(src[i]==='}')depth--;i++;}return src.slice(start,i);}
const catalog=JSON.parse(fs.readFileSync('godot/migration/phase8-web-catalog.json','utf8'));
const ctx={TYPES:catalog,Math,clamp:(v,a,b)=>Math.max(a,Math.min(b,v)),TOWER_BASE_ROOMS:6,TOWER_ROOM_GROWTH_FLOORS:3,TOWER_CHAPTER_FLOORS:5};vm.createContext(ctx);
vm.runInContext(src.match(/const TOWER_GROWTH=\{[^;]+;/)[0]+['towerRoomCount','towerRoomQuotas','towerAverageEnemyLevel','towerEnemyLevel','towerEnemyStats','towerEnemyProfile'].map(extract).join('\n'),ctx);
let samples=[];for(let type=0;type<26;type++)for(let level of [0,3,22])for(let rank of ['normal','elite','boss']){const enemy={...ctx.towerEnemyProfile(type,rank),enemyLevel:level};samples.push({type,level,rank,stats:ctx.towerEnemyStats(enemy,{depth:0})});}
fs.writeFileSync('godot/migration/phase9-web-rules.json',JSON.stringify({source:'dist/tower.js executable functions evaluated in Node VM, not documentation',floors:Array.from({length:15},(_,depth)=>({depth,count:ctx.towerRoomCount(depth),level:ctx.towerAverageEnemyLevel(depth),quotas:ctx.towerRoomQuotas(ctx.towerRoomCount(depth))})),samples},null,2));console.log('WEB GOLDEN:',samples.length,'stats samples');
