import { useCallback, useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { supabase } from "../lib/supabase";
import { loadUnifiedBranches, loadUnifiedRows, removeUnifiedRow, saveUnifiedRow, type Field, type UnifiedRow, type UnifiedSpec } from "../lib/unifiedModules";

export function UnifiedModulePage({spec,roles}:{spec:UnifiedSpec;roles:readonly string[]}) {
  const permitted = roles.some(role=>spec.roles.includes(role));
  const writable = roles.some(role=>spec.writeRoles.includes(role));
  const [branches,setBranches] = useState<{id:string;name:string}[]>([]);
  const [branch,setBranch] = useState("");
  const [rows,setRows] = useState<UnifiedRow[]>([]);
  const [editing,setEditing] = useState<UnifiedRow|null>(null);
  const [form,setForm] = useState<Record<string,unknown>>({title:"",description:""});
  const [open,setOpen] = useState(false);
  const [busy,setBusy] = useState(false);
  const [loading,setLoading] = useState(true);
  const [error,setError] = useState<string|null>(null);
  const [notice,setNotice] = useState<string|null>(null);
  const [version,setVersion] = useState(0);
  const refresh = useCallback(()=>setVersion(v=>v+1),[]);
  useEffect(()=>{
    if (!permitted) return;
    let active=true;
    void loadUnifiedBranches().then(next=>{
      if (!active)return;
      setBranches(next);setBranch(v=>next.some(row=>row.id===v)?v:(next[0]?.id??""));
    }).catch((e:unknown)=>{if(active)setError(e instanceof Error?e.message:String(e));});
    return ()=>{active=false;};
  },[permitted]);
  useEffect(()=>{
    if (!permitted || !branch) {setLoading(false);setRows([]);return;}
    let active=true;setError(null);setLoading(true);
    void loadUnifiedRows(spec,branch).then(next=>{if(active)setRows(next);})
      .catch((e:unknown)=>{if(active)setError(e instanceof Error?e.message:String(e));})
      .finally(()=>{if(active)setLoading(false);});
    return ()=>{active=false;};
  },[permitted,branch,spec,version]);
  useEffect(()=>{
    if (!permitted || !branch)return;
    const channel=supabase.channel(`sai-web-${spec.id}-${branch}`)
      .on("postgres_changes",{event:"*",schema:"public",table:spec.table,filter:`branch_id=eq.${branch}`},refresh)
      .subscribe();
    return ()=>{void supabase.removeChannel(channel);};
  },[permitted,branch,spec,refresh]);
  if (!permitted) return <main className="workspace"><section className="panel"><h1>وصول غير مصرح</h1></section></main>;
  const fieldValue=(key:string)=>form[key]==null?"":String(form[key]);
  const openEditor=(row:UnifiedRow|null)=>{setEditing(row);setForm(row?{...row}:{title:"",description:""});setOpen(true);setError(null);setNotice(null);};
  async function save(){
    setBusy(true);setError(null);setNotice(null);
    try{await saveUnifiedRow(spec,branch,editing?.id??null,form);setOpen(false);setNotice("تم حفظ السجل في قاعدة بيانات الكلية المشتركة.");refresh();}
    catch(e){setError(e instanceof Error?e.message:String(e));}
    finally{setBusy(false);}
  }
  async function remove(row:UnifiedRow){
    if (!window.confirm(`حذف السجل «${row.title}» نهائياً؟`))return;
    setBusy(true);setError(null);
    try{await removeUnifiedRow(spec,branch,row.id);setNotice("تم الحذف من Supabase.");refresh();}
    catch(e){setError(e instanceof Error?e.message:String(e));}
    finally{setBusy(false);}
  }
  function control(field:Field){
    const value=fieldValue(field.key);
    if (field.kind==="boolean")return <select id={`${spec.id}-${field.key}`} value={value||"false"} onChange={e=>setForm(v=>({...v,[field.key]:e.target.value==="true"}))}>
      <option value="false">لا</option><option value="true">نعم</option></select>;
    return <input id={`${spec.id}-${field.key}`} value={value} type={field.kind==="number"?"number":field.kind==="date"?"date":"text"}
      onChange={e=>setForm(v=>({...v,[field.key]:field.kind==="number"?(e.target.value===""?null:Number(e.target.value)):e.target.value}))} />;
  }
  return <main className="workspace" dir="rtl"><section className="panel">
    <p className="eyebrow">قاعدة البيانات الموحدة · Supabase</p><h1>{spec.title}</h1>
    <p className="muted">جدول {spec.table} مشترك مع تطبيق Yemen SAI. البيانات الظاهرة فقط هي البيانات التي تسمح سياسة RLS بقراءتها.</p>
    <div className="actions" style={{display:"flex",alignItems:"center",gap:12,flexWrap:"wrap"}}>
      <label htmlFor={`branch-${spec.id}`}>الفرع</label><select id={`branch-${spec.id}`} value={branch} onChange={e=>setBranch(e.target.value)}>
        <option value="">اختر الفرع</option>{branches.map(b=><option key={b.id} value={b.id}>{b.name}</option>)}
      </select>
      <button className="button secondary" type="button" onClick={refresh}>تحديث البيانات</button>
      {writable && branch && <button className="button" type="button" onClick={()=>openEditor(null)}>سجل جديد</button>}
    </div>
    {notice && <p role="status">{notice}</p>}{error && <p role="alert" className="error-box">{error}</p>}
    {loading && <p>جارٍ التحميل...</p>}
    {!loading && !rows.length && <p className="data-note">لا توجد سجلات متاحة أو لم يتم إنشاء بيانات بعد.</p>}
    <div style={{display:"grid",gap:12,marginTop:18}}>{rows.map(row=><section className="panel" key={row.id}>
      <h2>{row.title}</h2>{row.description && <p>{row.description}</p>}
      {spec.fields.map(f=><p key={f.key}><strong>{f.label}:</strong> {row[f.key] == null?"—":String(row[f.key])}</p>)}
      {writable && <div className="actions" style={{display:"flex",gap:8}}>
        <button className="button secondary" type="button" onClick={()=>openEditor(row)}>تعديل</button>
        {spec.allowDelete && <button type="button" className="button secondary" disabled={busy} onClick={()=>void remove(row)}>حذف</button>}
      </div>}
    </section>)}</div>
    {open && <section className="panel" style={{marginTop:24}}><h2>{editing?"تعديل السجل":"سجل جديد"}</h2>
      <div style={{display:"grid",gap:12}}><label htmlFor={`${spec.id}-title`}>العنوان</label>
        <input id={`${spec.id}-title`} maxLength={200} required value={fieldValue("title")} onChange={e=>setForm(v=>({...v,title:e.target.value}))}/>
        <label htmlFor={`${spec.id}-description`}>الوصف</label><textarea id={`${spec.id}-description`} value={fieldValue("description")}
          onChange={e=>setForm(v=>({...v,description:e.target.value}))}/>
        {spec.fields.map(field=><div key={field.key} style={{display:"grid",gap:4}}><label htmlFor={`${spec.id}-${field.key}`}>{field.label}</label>{control(field)}</div>)}
        <div className="actions" style={{display:"flex",gap:8}}><button className="button" type="button" disabled={busy} onClick={()=>void save()}>حفظ</button>
          <button className="button secondary" type="button" onClick={()=>setOpen(false)}>إلغاء</button></div>
      </div>
    </section>}
    {spec.id==="frontCms" && <p className="data-note">تُعرض الصفحات المنشورة فقط للزوار من رابط /pages/slug. لا يتم تنفيذ HTML الخام في الموقع.</p>}
    {spec.id==="certificates" && <p className="data-note">هذه سجلات شهادات وليست شهادات رقمية موقعة؛ التحقق العام والإصدار الرسمي يتطلبان خدمة منفصلة.</p>}
    <p><Link to="/portal/dashboard">العودة للرئيسية</Link></p>
  </section></main>;
}
