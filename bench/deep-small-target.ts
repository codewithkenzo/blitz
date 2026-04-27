#!/usr/bin/env bun
import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";
const BLITZ = "/home/kenzo/dev/blitz/zig-out/bin/blitz";
const ITER=5; const SIZES=[100_000,500_000,1_000_000];
const median=(xs:number[])=>[...xs].sort((a,b)=>a-b)[Math.floor(xs.length/2)]!;
const pct=(n:number)=>`${n.toFixed(1)}%`;
function run(cmd:string[], stdin?:string, cwd?:string){const t0=performance.now();const r=spawnSync(cmd[0]!,cmd.slice(1),{input:stdin,cwd,encoding:'utf8',maxBuffer:200*1024*1024});return{ms:performance.now()-t0,status:r.status??-1,stdout:r.stdout??'',stderr:r.stderr??''}}
async function coreReplace(file:string, oldText:string, newText:string){const t0=performance.now();const s=await readFile(file,'utf8');const idx=s.indexOf(oldText);if(idx<0)throw new Error('old not found');await writeFile(file,s.slice(0,idx)+newText+s.slice(idx+oldText.length));return performance.now()-t0;}
function makeFile(targetBytes:number){
 const oldFn='function smallTarget(name: string): string {\n  return "hi " + name;\n}\n';
 const newFn='function smallTarget(name: string): string {\n  return "hello " + name.toUpperCase();\n}\n';
 const snippet=newFn.trimEnd();
 const lines=[oldFn]; let i=0;
 while(lines.join('\n').length<targetBytes){lines.push(`const filler_${i} = ${i};`); i++;}
 const original=lines.join('\n')+'\n'; const expected=original.replace(oldFn,newFn);
 return{original,expected,oldFn,newFn,snippet,lines:i};
}
async function main(){const dir=await mkdtemp(join(tmpdir(),'blitz-small-target-')); try{
 console.log('# Huge file, small target benchmark');
 console.log('This is the pathological/use-core case: tiny symbol in big file.\n');
 console.log('| File size | Core payload | Blitz payload | Saved | Core write ms | Blitz ms | Diff ms | Diff bytes | OK |');
 console.log('|---:|---:|---:|---:|---:|---:|---:|---:|:--:|');
 for(const size of SIZES){const {original,expected,oldFn,newFn,snippet,lines}=makeFile(size); const corePayload=Buffer.byteLength(oldFn)+Buffer.byteLength(newFn); const blitzPayload=Buffer.byteLength(snippet)+Buffer.byteLength('smallTarget')+32; const saved=100*(1-blitzPayload/corePayload); const cms:number[]=[], bms:number[]=[], dms:number[]=[], db:number[]=[]; let ok=true; for(let i=0;i<ITER;i++){const core=join(dir,`core-${size}-${i}.ts`), blitz=join(dir,`blitz-${size}-${i}.ts`), before=join(dir,`before-${size}-${i}.ts`); await writeFile(core,original); await writeFile(blitz,original); await writeFile(before,original); cms.push(await coreReplace(core,oldFn,newFn)); const b=run([BLITZ,'edit',blitz,'--snippet','-','--replace','smallTarget'],snippet); bms.push(b.ms); if(b.status!==0){ok=false; console.error(b.stderr)} const out=await readFile(blitz,'utf8'); if(out!==expected) ok=false; const d=run(['git','diff','--no-index','--no-ext-diff','--',before,blitz],undefined,dir); dms.push(d.ms); db.push(Buffer.byteLength(d.stdout)+Buffer.byteLength(d.stderr));}
 console.log(`| ${Math.round(Buffer.byteLength(original)/1000)}KB/${lines} filler | ${corePayload} | ${blitzPayload} | ${pct(saved)} | ${median(cms).toFixed(2)} | ${median(bms).toFixed(2)} | ${median(dms).toFixed(2)} | ${median(db).toLocaleString()} | ${ok?'✅':'❌'} |`)}
 } finally {await rm(dir,{recursive:true,force:true})}}
main().catch(e=>{console.error(e);process.exit(1)});
