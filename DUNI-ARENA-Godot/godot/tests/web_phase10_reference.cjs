const fs=require('fs'),vm=require('vm'),crypto=require('crypto');
// Phase8's exact TYPES fixture is reusable only while its source files still match.
const protectedSources=JSON.parse(fs.readFileSync('godot/migration/phase8-web-sha256.json','utf8'));
for(const [path,hash] of Object.entries(protectedSources))if(crypto.createHash('sha256').update(fs.readFileSync(path)).digest('hex')!==hash)throw Error('Re-extract Phase8 TYPES: source changed '+path);
const src=fs.readFileSync('dist/tower.js','utf8'),strategy=fs.readFileSync('dist/strategy.js','utf8'),spectator=fs.readFileSync('dist/spectator.js','utf8');
function fn(name){let start=src.indexOf('function '+name+'('),i=src.indexOf('{',start)+1,depth=1;while(depth){if(src[i]==='{')depth++;if(src[i]==='}')depth--;i++;}return src.slice(start,i);}
const types=JSON.parse(fs.readFileSync('godot/migration/phase8-web-catalog.json','utf8'));
const ctx={TYPES:types,clamp:(v,a,b)=>Math.max(a,Math.min(b,v)),tower:{inventory:[]},TOWER_MAX_LEVEL:10,TOWER_MAX_STARS:2,TOWER_STAR_LEVELS:40,TOWER_MAX_EQUIPMENT:2};vm.createContext(ctx);
vm.runInContext(src.match(/const TOWER_ITEMS=\[[\s\S]*?\n\];/)[0]+src.match(/const TOWER_GROWTH=\{[^;]+;/)[0]+src.match(/const TOWER_RECRUIT_PREMIUM=\{[^;]+;/)[0]+strategy.match(/const STRATEGY_CARDS=\[[\s\S]*?\n\];/)[0]+'globalThis.items=TOWER_ITEMS;globalThis.cards=STRATEGY_CARDS;'+['towerMemberStars','towerEquippedCopies','towerEquippedItems','towerRecruitCost','towerMemberStats'].map(fn).join('\n'),ctx);
const combos=JSON.parse(spectator.match(/const pools=(\[\[[^;]+);/)[1]);
const samples=[];for(let type=0;type<26;type++)for(let level of [0,1,10])for(let stars of [0,1,2])for(const gear of [[],['vital','fang'],['greenNecklace','greenNecklace'],['boots','boots']]){
ctx.tower.inventory=gear.map((kind,i)=>({id:i+1,kind,equippedTo:'member'}));let m={id:'member',type,level,stars,fangKills:3};samples.push({type,level,stars,gear,kills:3,stats:ctx.towerMemberStats(m)});}
const result={source:'Evaluated actual dist/tower.js/strategy.js functions',items:ctx.items,cards:ctx.cards,recruitPrices:Array.from({length:26},(_,type)=>ctx.towerRecruitCost(type)),predictionPools:combos,samples};fs.writeFileSync('godot/migration/phase10-web-rules.json',JSON.stringify(result,null,2));console.log('WEB',ctx.items.length,'items',samples.length,'growth samples',combos.length,'prediction pools');
