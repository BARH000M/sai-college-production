import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { loadSettings, saveSetting, settingsSections, type SettingField, type SettingSection } from "../lib/systemSettings";

const actions = [
  {label:"إدارة المستخدمين والأدوار",to:"/portal/modules/roles",note:"الحسابات والصلاحيات تُدار عبر خدمة إدارة الأدوار المصرح لها فقط."},
  {label:"إدارة الجلسات الأكاديمية",to:"/portal/modules/sessions",note:"تسجيل الجلسات وتواريخها في قاعدة البيانات الحقيقية."},
  {label:"صفحات الموقع Front CMS",to:"/portal/modules/frontCms",note:"الصفحات المنشورة والمسودات المشتركة مع التطبيق."},
];

export function SystemSettings({ roles }: { roles: readonly string[] }) {
  const privileged = roles.includes("super_admin");
  const allowed = privileged || roles.includes("admin");
  const [section, setSection] = useState<SettingSection>(settingsSections[0]);
  const [values,setValues] = useState<Record<string,string>>({});
  const [loading,setLoading] = useState(false);
  const [saving,setSaving] = useState<string|null>(null);
  const [error,setError] = useState<string|null>(null);
  const [notice,setNotice] = useState<string|null>(null);
  const [retry,setRetry] = useState(0);
  useEffect(()=>{
    if (!allowed || (section.superOnly && !privileged)) return;
    let active = true;
    setLoading(true); setError(null); setNotice(null); setValues({});
    void loadSettings(section.category).then(rows=>{
      if (!active) return;
      setValues(Object.fromEntries(rows.map(r=>[r.setting_key,r.value_text])));
    }).catch((e:unknown)=>{if(active)setError(e instanceof Error?e.message:String(e));})
      .finally(()=>{if(active)setLoading(false);});
    return ()=>{active=false;};
  },[section,allowed,privileged,retry]);
  if (!allowed) return <main className="workspace"><section className="panel"><h1>إعدادات النظام</h1><p role="alert">لا تملك صلاحية إدارة إعدادات الكلية.</p></section></main>;
  async function save(field: SettingField) {
    setError(null);setNotice(null);setSaving(field.key);
    try { await saveSetting(section,field,values[field.key]??"");setNotice(`حُفظ «${field.label}» في قاعدة البيانات المشتركة.`);setRetry(x=>x+1); }
    catch(e){setError(e instanceof Error?e.message:String(e));}
    finally {setSaving(null);}
  }
  return <main className="workspace" dir="rtl"><section className="panel">
    <p className="eyebrow">Yemen SAI · Supabase</p><h1>إعدادات النظام</h1>
    <p className="muted">هذه إعدادات حقيقية محفوظة في Supabase ومحمية بسياسات RLS. المدير العام فقط يستطيع تغيير الإعدادات العامة للكلية؛ يستطيع المدير الاطلاع على الفئات غير الحساسة. لا تحفظ كلمات مرور هنا.</p>
    <div className="actions" style={{display:"flex",gap:8,flexWrap:"wrap",marginBlock:16}}>
      {settingsSections.filter(s=>!s.superOnly||privileged).map(s=><button key={s.category}
        type="button" className={`button ${section.category===s.category?"":"secondary"}`} onClick={()=>setSection(s)}>{s.title}</button>)}
    </div>
    <h2>{section.title}</h2>
    {section.note && <p className="data-note">{section.note}</p>}
    {loading && <p role="status">جارٍ تحميل الإعدادات...</p>}
    {error && <p className="error-box" role="alert">{error}</p>}
    {notice && <p role="status">{notice}</p>}
    {!loading && <div style={{display:"grid",gap:14,gridTemplateColumns:"repeat(auto-fit,minmax(240px,1fr))"}}>
      {section.fields.map(field=><div className="panel" key={field.key}>
        <label htmlFor={`setting-${field.key}`}>{field.label}</label>
        {field.type==="boolean" ? <select id={`setting-${field.key}`} className="input" value={values[field.key]??"false"}
          disabled={!privileged} onChange={e=>setValues(v=>({...v,[field.key]:e.target.value}))}><option value="false">معطّل</option><option value="true">مفعّل</option></select>
          : field.type==="select" ? <select id={`setting-${field.key}`} className="input" value={values[field.key]??""}
            disabled={!privileged} onChange={e=>setValues(v=>({...v,[field.key]:e.target.value}))}><option value="">اختر...</option>{field.options?.map(opt=><option key={opt} value={opt}>{opt}</option>)}</select>
          : <input id={`setting-${field.key}`} className="input" type={field.type==="email"?"email":field.type==="number"?"number":"text"}
            maxLength={2000} value={values[field.key]??""} disabled={!privileged} onChange={e=>setValues(v=>({...v,[field.key]:e.target.value}))} />}
        <div className="actions" style={{marginTop:10}}><button className="button" type="button" disabled={!privileged || saving!==null} onClick={()=>void save(field)}>
          {saving===field.key?"جارٍ الحفظ...":"حفظ في Supabase"}</button></div>
      </div>)}
    </div>}
    <h2 style={{marginTop:28}}>إدارة منفصلة وآمنة</h2>
    {actions.filter(action=>privileged || action.to!=="/portal/modules/roles").map(action=><p key={action.to}><Link to={action.to}>{action.label}</Link> — {action.note}</p>)}
    <p className="data-note">حظر عناوين IP يتم من بوابة الشبكة/WAF وليس من حقل نص في قاعدة البيانات. استعادة البيانات من النسخ الاحتياطية تحتاج إجراءً إدارياً منفصلاً بمراجعة وتأكيد.</p>
  </section></main>;
}
