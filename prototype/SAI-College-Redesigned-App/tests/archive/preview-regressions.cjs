const test=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const vm=require('node:vm');const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../browser-preview/app.js'),'utf8').split('const roleSelector=')[0];
const elements=new Map();function element(selector){if(!elements.has(selector))elements.set(selector,{innerHTML:'',textContent:'',value:'',classList:{add(){},remove(){},toggle(){}},focus(){}});return elements.get(selector)}
const document={querySelector:element,querySelectorAll:()=>[],addEventListener(){},removeEventListener(){},activeElement:null};
const context=vm.createContext({test,assert,document,window:{matchMedia:()=>({matches:false}),scrollTo(){}},setTimeout:()=>0,clearTimeout(){},console});
vm.runInContext(source+`\nlet authenticated=true;\n`+fs.readFileSync(path.join(__dirname,'preview-cases.js'),'utf8'),context);

vm.runInContext("render=()=>{};"+fs.readFileSync(path.join(__dirname,"../browser-preview/version1086.js"),"utf8"),context);
vm.runInContext(fs.readFileSync(path.join(__dirname,"version1086-cases.js"),"utf8"),context);
