/* Review fixtures only. The production server must resolve and enforce these rules. */
const Core = {
  account(id){return MODEL.accounts.find(a=>a.id===id)||MODEL.accounts[0]},
  hasRole(account,role){return account.roles.includes(role)},
  visibleModules(role){return MODEL.modules.filter(m=>m.roles.includes(role))},
  canOpen(account,role,page){return this.hasRole(account,role)&&this.visibleModules(role).some(m=>m.id===page)},
  tabs(role,page){if(role==='teacher'&&page==='students')return ['ملفات الطلاب'];let tabs=MODEL.modules.find(m=>m.id===page)?.tabs||[];if(['parent','student'].includes(role)){
    const map={students:['ملفات الطلاب'],finance:['الفواتير','الإيصالات'],exams:['الجدول والنتائج'],certificates:['شهادات الإنجاز','بطاقات الطلاب','السيرة الدراسية'],library:['الفهرس','الإعارة والإرجاع','الحجوزات'],settings:['حسابي','دليل الصلاحيات','نطاق النسخة'],reports:['تقارير نطاقي','الطباعة']};if(map[page])tabs=map[page];
  }if(role==='teacher'&&page==='approvals')tabs=['قائمة المراجعة','السجل'];if(!['super_admin','admin'].includes(role)&&page==='settings')tabs=tabs.filter(t=>!['سجل التدقيق','التكاملات'].includes(t));return tabs},
  classes(role,account,branch,session){return MODEL.classes.filter(c=>c.branch===branch&&c.session===session&&(!['student','parent'].includes(role)||MODEL.students.some(s=>s.classId===c.id&&(role==='student'?s.id==='STU00125':s.parent===account.id)))&&(role!=='teacher'||(account.id==='dual'?['c1']:['c1','c2']).includes(c.id)))},
  students(role,account,branch,session){const ids=this.classes(role,account,branch,session).map(c=>c.id);return MODEL.students.filter(s=>ids.includes(s.classId)&&(role!=='student'||s.id==='STU00125')&&(role!=='parent'||s.parent===account.id))},
  can(role,action){const rules={author:['super_admin','admin','content_editor','teacher'],approve:['super_admin','admin'],publish:['super_admin','admin'],admit:['super_admin','admin','receptionist'],attendance:['super_admin','admin','teacher','receptionist'],finance:['super_admin','admin','accountant'],library:['super_admin','admin','librarian'],grade:['super_admin','admin','teacher'],cms:['super_admin','admin','content_editor']};return (rules[action]||[]).includes(role)},
  canApprove(role,account,draft){return this.can(role,'approve')&&draft.status==='review'&&draft.author!==account.id},
  capacity(c){return {pct:Math.round(c.enrolled/c.capacity*100),free:c.capacity-c.enrolled,status:c.enrolled>=c.capacity?'ممتلئ':c.enrolled/c.capacity>=.85?'قريب من الامتلاء':'متاح'}},
  csv(value){let s=String(value??'');if(/^[=+@-]/.test(s.trimStart()))s="'"+s;return '"'+s.replaceAll('"','""')+'"'},
  quiz(answer){return answer==='شكراً'},
  score(attempts){return attempts.length?Math.round(attempts.filter(Boolean).length/attempts.length*100):0},
  canIssue(book){return !book.borrower},
  revision(draft,fields){return {...draft,...fields,status:'draft',revision:draft.revision+1,approvedBy:null}}
};
