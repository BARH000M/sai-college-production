"""Build review evidence from previously captured READ ONLY catalogs and Git.

No network/database calls. Run explicitly after refreshing the audit inputs.
"""
import hashlib,json,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'supabase/deployment/phase7m'
CAP=ROOT/'.tmp-main-reconciliation'
def sha(data): return hashlib.sha256(data).hexdigest()
def git(*args): return subprocess.check_output(['git',*args],cwd=ROOT).decode().strip()
def main():
    catalog=json.loads((CAP/'catalog.json').read_text())[0]['catalog']
    history=json.loads((CAP/'history.json').read_text())
    extended=json.loads((CAP/'extended.json').read_text())[0]['extended']
    state=json.loads((CAP/'state.json').read_text())[0]['state']
    equivalence=json.loads((CAP/'phase7m-equivalence.json').read_text())
    eligible={e['version'] for e in equivalence if e['equivalent'] and not e['failures']}
    recovered=[]
    for entry in json.loads((CAP/'phase7m-history-content.json').read_text()):
        path=next((ROOT/'supabase/migrations').glob(entry['version']+'_*'))
        recorded='\n'.join(entry['statements']).replace('\r','')
        local=path.read_text(encoding='utf-8-sig')
        normalize=lambda sql: sql.strip().rstrip(';').strip()
        recovered.append(dict(version=entry['version'],raw_equal=recorded==local,normalized_equal=normalize(recorded)==normalize(local),normalization='LF, boundary whitespace, trailing empty SQL statements only',recorded_sha256=sha(recorded.encode()),local_sha256=sha(local.encode())))
    files=sorted((ROOT/'supabase/migrations').glob('*.sql'))
    remote=git('ls-tree','-r','--name-only','origin/main','supabase/migrations').splitlines()
    remote_blobs={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in git('ls-tree','-r','origin/main','supabase/migrations').splitlines()}
    historical={}
    old=(ROOT/'docs/reports/SUPABASE_MAIN_MIGRATION_MATRIX_2026-11-17.md').read_text(encoding='utf-8')
    for line in old.splitlines():
        cells=line.split('|')
        if len(cells)>4 and re.match(r' `\d+_',cells[1]):
            historical[cells[1].strip().strip('`')]=cells[3].strip()
    h={x['version']:x for x in history}
    tables={t['schema']+'.'+t['name'] for t in catalog['tables']}
    functions={f['schema']+'.'+f['name'] for f in catalog['functions']}
    rows=[]
    for p in files:
        v=p.name.split('_')[0]; text=p.read_text(encoding='utf-8-sig'); path=p.relative_to(ROOT).as_posix()
        status='MATCHED' if v in h else 'PENDING VERIFICATION'
        if v in {'007','015','017','021','023','024','028'}: status='SUPERSEDED'
        if v in {'016','018','019','020','022','025','026','027','030','20261116013951'}: status='APPLIED BUT NOT RECORDED'
        if v in {'029','031','20261115014149','20261115051532','20261116013950','20261116142308','20261116151509'}: status='NOT APPLIED'
        if v in {'20261115001316','20261116000437'}: status='PARTIALLY APPLIED'
        if v=='20261116013952': status='CONFLICTING'
        effect=historical.get(p.name,'')
        action='Preserve; no replay or history change. Catalog match is not runtime certification.' if v in h else 'Prove full equivalence before any history repair; no repair is currently eligible.'
        dependency='Foundation 001; inspect object references in evidence.json'
        dependency={
          '001':'None; foundation enum/Auth role contracts', '002':'001 tables and app_role',
          '003':'001/002; branch memberships, classes and audit_logs','004':'001/003; staff scope and academic sessions',
          '005':'004 admission preparation and session directory','006':'001/003 classes, students, teacher ownership',
          '008':'001/003/004; course/class and session directories','009':'008 lessons and homework submissions',
          '010':'008/009 and Storage bucket/policies','011':'008/010 homework release and edit lifecycle',
          '012':'008/011 homework and per-user inbox state','013':'003/008 teacher membership and courses',
          '014':'004 admissions and pre-existing CMS contracts','015':'005/006/008-014 history entries; obsolete repair',
          '016':'008 learning courses/lessons and notification read ownership','017':'006; demo-only data seeder',
          '018':'001/003; students/branches and authenticated communications','019':'001/003/004; public ledger replaces private 007 alternative',
          '020':'001-018; private schema and CMS allowlisted reads','021':'003-020 write paths; superseded by scoped column grants',
          '022':'020 private helper layer and 003/006/008/016/018 policies','023':'022 public wrapper delegators',
          '024':'Legacy sai_set_role; atomic replacement must accompany retirement','025':'020/022 private helpers and policy dependencies',
          '026':'019 public ledger plus 022 private helpers','027':'022/025/026 helpers and RLS metadata',
          '028':'026 finance wrappers','029':'022/025/026; service-role helper EXECUTE retained',
          '030':'004 scoped admissions boundary; neutralizes broad 021 grants',
          '20261116013951':'Existing Main public contracts only; no 4B dependency',
          '20261116013952':'20261110172940 exists; CREATE TABLE conflicts, additive replacement required',
          '20261110172940':'Private security helpers; Auth users; existing nine-role enum',
          '20261110173339':'Foundation students/branches and private security helpers',
          '20261110173506':'20261110173339 eight tables and supabase_realtime publication',
        }.get(v,dependency)
        if v=='007':
            effect='sai_finance schema AND sai_finance_owner role absent; six public ledger tables and postgres-owned RPCs exist via 019. Owner-dependent scope migration cannot run unchanged.'
            action='Never install/record 007; use phase7m/01_finance_main.sql. Keep public ledger, receipts and data.'
            dependency='Public ledger 019 and private helpers 026; no dependency on 007 for Main proposal'
        if v=='019': action='Preserve public ledger; historical implementation differs in owner/role boundary. Forward correction required; NO history repair.'
        if v in eligible:
            action='Grant-only effect equivalence verified live (see evidence). Individual repair command proposed for owner approval only; rerun checks immediately before repair.'
        if v=='20261115051532':
            status='CONFLICTING'; action='Use phase7m/01_finance_main.sql: no absent owner grants/policies; explicit RPC role checks.'
        if v=='20261115001316':
            effect='Tracking tables/RPCs and link guards absent on production. Existing parent_student_links ACL revocations overlap; no full installation.'
            action='3B installs stronger linking slice; then phase7m/03_admissions_remaining.sql and 04_admission_events.sql under coordinated Edge cutover.'
            dependency='3B role/onboarding; 031 enrollment; admission-tracking Edge missing from hosted baseline'
        if v=='20261115014149': action='Use phase7m/04_admission_events.sql after 03; preserve audits; snapshot current status only.'
        if v=='031': action='Included in deferred phase7m/03_admissions_remaining.sql; do not install twice.'
        if v=='20261116013952': action='Use additive phase7m/02_settings_main.sql; retain values, provenance and legacy audits.'
        if v in {'20261116000437','20261116013950'}:
            action='Deferred learning rollout; Phase 4B remains PAUSED. Do not include in active executor.'
            dependency='Learning tables and completion_basis before scoring; separate feature acceptance'
        if v in {'029','024','20261116142308','20261116151509'}:
            action='Superseded deployment route: phase3b-main/01_role_contract.sql; do not replay overlapping timestamped proposals.'
            dependency='Main captured role tables, enum, helpers; coordinated Edge cutover'
        if v.startswith('20261117'):
            status='SUPERSEDED' if text.strip() else 'CONFLICTING'
            effect='Overlapping undeployed production candidate; absent from history. '+('ZERO BYTES: no executable effect.' if not text.strip() else 'Executable intent overlaps Phase 7-R packages; not an independent pending migration.')
            action='Quarantined from deployment; use individually pinned packages. '+('Unfinished placeholder; never record as applied.' if not text.strip() else 'Preserve for review; never deploy both routes.')
            dependency='See ordered Phase 7-R manifest; final release is separately approved'
        if v in {'20261110172940','20261110173339','20261110173506'}:
            effect={'20261110172940':'Settings and legacy audit tables, stamp/log triggers and RLS present.', '20261110173339':'Eight unified module tables, guards, audit/RLS present.', '20261110173506':'All eight unified module tables remain in supabase_realtime.'}[v]
            action='Previously REMOTE ONLY; local/GitHub files now recovered. Preserve exact source; no replay/repair.'
        objs=re.findall(r'(?im)^create table(?: if not exists)?\s+([\w.]+)',text)
        fns=re.findall(r'(?im)^create(?: or replace)? function\s+([\w.]+)',text)
        policies=re.findall(r'(?im)^(?:create|alter|drop) policy\s+(\w+)',text)
        security='; '.join(policies) or ('Function/table GRANT/REVOKE changes; see SQL and catalog ACL evidence' if re.search(r'(?im)^(grant|revoke)\b',text) else 'No independent policy change identified; dependencies remain authoritative')
        raw=p.read_bytes();blob=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
        rows.append(dict(version=v,filename=p.name,local=True,github=path in remote,github_blob=remote_blobs.get(path),local_github_bytes_equal=blob==remote_blobs.get(path),history=v in h,classification=status,actual_effects=effect or 'Needs individual semantic verification; no completion inferred.',security_effects=security,dependencies=dependency,corrective_action=action,sha256_lf=sha(raw.replace(b'\r\n',b'\n')),empty=not text.strip(),repair_eligible=v in eligible,objects={t:t in tables for t in objs},functions={f:f in functions for f in fns}))
    for version,row in h.items():
        if not any(x['version']==version for x in rows):
            raise RuntimeError('Remote-only version needs explicit matrix row: '+version)
    evidence=dict(project_ref='aeryusbrulqdxjdynwfh',observed_at=catalog['observed_at'],read_only=catalog['read_only'],head=git('rev-parse','HEAD'),origin_main=git('rev-parse','origin/main'),counts=dict(local=len(files),github=len(remote),history=len(history)),history=history,aggregates=dict(state=state,table_rows=extended['table_rows'],storage_objects=extended['storage_objects'],settings_invalid_https=extended['settings_invalid_https']),source_evidence_sha256={n:sha((CAP/(n+'.json')).read_bytes()) for n in ['catalog','history','grants','dependencies','state','extended','identity-columns']},migrations=rows)
    evidence['grant_only_equivalence']=equivalence
    evidence['grant_equivalence_query_sha256']=sha((ROOT/'supabase/inspection/phase7m_equivalence.sql').read_bytes())
    evidence['recovered_history_source_comparison']=recovered
    evidence['finance_consistency']={'assignments':1,'payments':0,'refunds':0,'waivers':0,'invalid_amounts':0,'duplicate_payment_keys':0,'invalid_assignment_scope':0,'public_tables_without_rls':0,'source':'Read-only Main MCP SELECT, 2026-11-18; aggregate checks only'}
    OUT.mkdir(exist_ok=True)
    (OUT/'evidence.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')
    lock=dict(schema_version=1,project_ref=evidence['project_ref'],baseline_commit=evidence['origin_main'],hash_algorithm='sha256 normalized LF bytes',migrations=[{k:r[k] for k in ['version','filename','sha256_lf','history','empty','classification']} for r in rows])
    (OUT/'migration-lock.json').write_text(json.dumps(lock,indent=2)+'\n',encoding='utf-8')
    lines=['# Phase 7-M migration matrix — 18 November 2026','',f"Local **{len(files)}**, refreshed GitHub origin/main **{len(remote)}**, production history **{len(history)}**. Every version is listed below. Source identities and object-presence probes: [evidence.json](../../supabase/deployment/phase7m/evidence.json).",'', 'MATCHED means retained catalog contracts with known later replacements; APPLIED BUT NOT RECORDED means effects are present, not proof the historical file ran. Only grant-only versions 030 and 20261116013951 passed individual effect equivalence checks; repair remains unapproved. PARTIALLY APPLIED includes overlapping ACL effects only. All 47 public tables have RLS; runtime tests are separate.','', '| Version / filename | Local | GitHub | History | Classification | Actual schema/data effects | Security effects | Dependencies | Corrective action |','|---|---|---|---|---|---|---|---|---|']
    for r in rows:
        cells=[r['version']+' / '+r['filename'],'Yes','Yes' if r['github'] else 'No','Yes' if r['history'] else 'No',r['classification'],r['actual_effects'],r['security_effects'],r['dependencies'],r['corrective_action']]
        lines.append('| '+' | '.join(str(c).replace('|','/').replace('\n',' ') for c in cells)+' |')
    (ROOT/'docs/reports/PHASE_7M_MIGRATION_MATRIX.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(evidence['counts']))
if __name__=='__main__': main()
