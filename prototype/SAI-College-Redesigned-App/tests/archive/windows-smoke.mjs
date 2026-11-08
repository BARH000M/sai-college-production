import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../windows-app');
const proc=spawn(process.execPath,['start.mjs'],{cwd:root,env:{...process.env,NODE_ENV:'production',PORT:'3031',APP_ID:'local-smoke-test',APP_SECRET:'local-smoke-test-only',DATABASE_URL:'mysql://unused:unused@127.0.0.1:1/unused',KIMI_AUTH_URL:'https://example.invalid',KIMI_OPEN_URL:'https://example.invalid'},stdio:'ignore'});
try{let ready=false;for(let i=0;i<60;i++){try{const res=await fetch('http://127.0.0.1:3031/');if(res.ok){ready=true;break}}catch{}await new Promise(r=>setTimeout(r,100))}assert.ok(ready,'server startup');for(const route of ['/','/programs/hsk-1','/profile']){const res=await fetch('http://127.0.0.1:3031'+route,{headers:{Accept:'text/html'}});assert.equal(res.status,200,route);assert.ok((await res.text()).includes('<html'),route);console.log('PASS',route)}const notFound=await fetch('http://127.0.0.1:3031/api/not-a-route');assert.equal(notFound.status,404);console.log('PASS API 404');}finally{proc.kill()}
