// Exercise a running satellite editor through the actual stdio MCP server.
// Usage: node verify_alternative.mjs /absolute/path/to/satellite/server /absolute/test/project
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { writeFileSync } from 'node:fs';
const server = resolve(process.argv[2]);
const project = resolve(process.argv[3]);
const require = createRequire(resolve(server, 'package.json'));
const { Client } = require('@modelcontextprotocol/sdk/client/index.js');
const { StdioClientTransport } = require('@modelcontextprotocol/sdk/client/stdio.js');
const client = new Client({ name: 'spider-city-verification', version: '1.0' });
const transport = new StdioClientTransport({command: process.execPath, args:[resolve(server,'dist/cli.js')], cwd:server, env:{...process.env,GODOT_HOST:'127.0.0.1',GODOT_PORT:'6550',GODOT_MCP_USAGE_LOG:'0'},stderr:'inherit'});
let started = false;
async function call(name,args) {
 const r=await client.callTool({name,arguments:args}, undefined, {timeout:60000});
 const text=(r.content??[]).filter(x=>x.type==='text').map(x=>x.text).join('\n');
 console.log(name,JSON.stringify(args),text);
 if(r.isError) throw new Error(text);
 for(const item of r.content??[]) if(item.type==='image') writeFileSync(resolve(project,'satellite-runtime.png'),Buffer.from(item.data,'base64'));
 return text;
}
try {
 await client.connect(transport);
 const list=await client.listTools(); console.log('TOOLS',list.tools.length);
 let info;
 for (let attempt=0;attempt<20;attempt++) {
  try { info=await call('godot_project',{action:'get_info'}); break; }
  catch(e) { if(!e.message.includes('Not connected') || attempt===19) throw e; }
  await new Promise(resolve=>setTimeout(resolve,500));
 }
 if(!info.includes(project)) throw new Error('Wrong editor project; refusing to run');
 await call('godot_project',{action:'addon_status'});
 await call('godot_editor_edit',{action:'run',frozen:true});
 started = true;
 // Let the editor launch and attach the debugger; game time remains frozen.
 await new Promise(resolve=>setTimeout(resolve,4000));
 await call('godot_game_time',{action:'step_until',until:'root.get_node("Main").game_state == "menu"',max_ms:20000,report:['root.get_node("Main").game_state']});
 const enter=await call('godot_game_time',{action:'step',duration_ms:300,inputs:[{key:'f',start_ms:0,duration_ms:80}],report:['root.get_node("Main").game_state','root.get_node("Main").mission']});
 if(!enter.includes('playing')) throw new Error('F did not enter free roam');
 const moved=await call('godot_game_time',{action:'step',duration_ms:800,inputs:[{action_name:'move_forward',start_ms:0,duration_ms:750}],report:['root.get_node("Main").player.velocity.length()','root.get_node("Main").player.position']});
 if(!(JSON.parse(moved).report['root.get_node("Main").player.velocity.length()'] > 3)) throw new Error('Movement input had no effect');
 await call('godot_game_time',{action:'step',duration_ms:500,inputs:[{action_name:'patrol',start_ms:0,duration_ms:80}],report:['root.get_node("Main").patrol.running','root.get_node("Main").patrol.wave','root.get_node("Main").patrol.remaining']});
 await call('godot_exec',{action:'run',source:'return root.get_node("Main").patrol.running and root.get_node("Main").patrol.wave == 1 and root.get_node("Main").patrol.remaining == 2'}).then(t=>{if(JSON.parse(t).result !== true)throw new Error('Patrol assertion failed');});
 await call('godot_editor_read',{action:'screenshot_game',max_width:960});
 console.log('SATELLITE_LIVE_RESULT: PASS (isolated project, freeze/step, keyboard free roam, movement, patrol, screenshot)');
} finally {
 if(started) try {await call('godot_editor_edit',{action:'stop'});} catch(e) {console.error('Stop:',e.message);}
 await client.close();
}
