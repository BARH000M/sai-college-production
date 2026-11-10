import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { supabase } from "@/portal/lib/supabase";

type PublicPage = { branch_id: string; slug: string; title: string; body: string|null; description: string|null };

/** Only published Front CMS pages; public RLS denies access to drafts. No raw HTML injection. */
export default function PublicCmsPage() {
  const { branchId, slug } = useParams();
  const [pages,setPages] = useState<PublicPage[]>([]);
  const [error,setError] = useState("");
  const [loading,setLoading] = useState(true);
  useEffect(()=>{
    if ((slug && (!branchId || !/^[0-9a-f-]{36}$/i.test(branchId))) || (slug && slug.length>120)) {
      setError("الرابط غير صحيح");setLoading(false);return;
    }
    let active=true;setLoading(true);setError("");
    let query=supabase.from("sai_cms_pages")
      .select("branch_id,slug,title,body,description").eq("is_published",true)
      .order("title").limit(100);
    if (slug && branchId) query=query.eq("branch_id",branchId).eq("slug",slug);
    void (async () => {
      try {
        const {data,error} = await query;
        if(!active)return;
        if(error){setError("تعذر تحميل صفحات الموقع من قاعدة البيانات.");return;}
        setPages((data??[]) as PublicPage[]);
      } catch {
        if(active)setError("تعذر تحميل صفحات الموقع من قاعدة البيانات.");
      } finally {
        if(active)setLoading(false);
      }
    })();
    return ()=>{active=false;};
  },[branchId,slug]);
  return <main dir="rtl" style={{maxWidth:900,margin:"60px auto",padding:"0 24px",fontFamily:"Cairo,sans-serif"}}>
    <p><Link to="/">الرئيسية</Link> / <Link to="/pages">صفحات الكلية</Link></p>
    <h1>{slug?"صفحة الكلية":"صفحات الكلية"}</h1>
    {loading?<p>جارٍ تحميل الصفحة...</p>:error?<p role="alert">{error}</p>:pages.length===0?<p>لا توجد صفحات منشورة.</p>
      :slug?pages.map(page=><article key={`${page.branch_id}-${page.slug}`}>
          <h2>{page.title}</h2>{page.description && <p>{page.description}</p>}
          <div style={{whiteSpace:"pre-wrap",lineHeight:2}}>{page.body??""}</div>
        </article>):<ul>{pages.filter(p=>p.slug).map(page=><li key={`${page.branch_id}-${page.slug}`}>
          <Link to={`/pages/${page.branch_id}/${encodeURIComponent(page.slug)}`}>{page.title}</Link>
          {page.description && <p>{page.description}</p>}
        </li>)}</ul>}
  </main>;
}
