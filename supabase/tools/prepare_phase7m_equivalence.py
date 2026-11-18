"""Generate SELECT-only verification of the two grant-only history candidates."""
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def split(value):
    depth=0;start=0;out=[]
    for i,c in enumerate(value):
        if c=='(':depth+=1
        elif c==')':depth-=1
        elif c==',' and depth==0:out.append(value[start:i]);start=i+1
    return [x.strip() for x in out+[value[start:]]]
def quote(s):return "'"+s.replace("'","''")+"'"
def main():
    file=ROOT/'supabase/migrations/20261116013951_phase2b_service_permissions.sql'
    source=re.sub(r'--[^\n]*','',file.read_text(encoding='utf-8'))
    checks=[]
    grants=list(re.finditer(r'grant\s+(.*?)\s+on\s+(.*?)\s+to\s+service_role\s*;',source,re.S|re.I))
    rest=re.sub(r'grant\s+(.*?)\s+on\s+(.*?)\s+to\s+service_role\s*;','',source,flags=re.S|re.I)
    assert re.sub(r'\b(begin|commit)\s*;|\s+','',rest,flags=re.I)==''
    for grant in grants:
        for op in split(grant[1]):
            match=re.fullmatch(r'(select|insert|update|delete)\s*(?:\((.*?)\))?',op,re.I|re.S);assert match,op
            privilege=match[1].upper()
            for table in split(grant[2]):
                for col in split(match[2]) if match[2] else [None]:
                    expr=f"has_column_privilege('service_role',{quote(table)},{quote(col)},{quote(privilege)})" if col else f"has_table_privilege('service_role',{quote(table)},{quote(privilege)})"
                    checks.append(f"select '20261116013951'::text version,{quote(table+':'+privilege+':'+str(col))} contract,{expr} equivalent")
    checks.append("""select '030', 'exact authenticated admission INSERT/UPDATE boundary',
      not has_table_privilege('authenticated','public.admissions_enquiries','INSERT')
      and not has_table_privilege('authenticated','public.admissions_enquiries','UPDATE')
      and not exists (
        select 1 from information_schema.columns c
        cross join (values ('INSERT'),('UPDATE')) p(privilege)
        where c.table_schema='public' and c.table_name='admissions_enquiries'
          and has_column_privilege('authenticated','public.admissions_enquiries',c.column_name,p.privilege)
            is distinct from (c.column_name=any(case when p.privilege='INSERT' then
              array['branch_id','academic_session_id','applicant_full_name','guardian_name','phone','email','preferred_program','preferred_level','source','notes','assigned_to']
              else array['academic_session_id','applicant_full_name','guardian_name','phone','email','preferred_program','preferred_level','source','notes','status','assigned_to'] end))
      )""")
    out=ROOT/'supabase/inspection/phase7m_equivalence.sql';out.parent.mkdir(exist_ok=True)
    out.write_text('with checks as (\n'+'\nunion all\n'.join(checks)+"\n) select version,count(*) as contracts,bool_and(equivalent) as equivalent,jsonb_agg(contract) filter(where not equivalent) as failures from checks group by version order by version;\n",encoding='utf-8')
    print('Prepared SELECT-only equivalence query')
if __name__=='__main__':main()
