"""Explicit offline pin refresh AFTER review/tests; never run automatically in CI."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='supabase/deployment/phase7m/'
MANIFEST='supabase/deployment/phase7r/main-deployment-manifest.json'
def digest(path): return hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
def main():
    m=json.loads((ROOT/MANIFEST).read_text())
    m['reconciliation']={'checkpoint':'Phase 7-M','release_ready':False,'decision':'NO-GO','evidence_path':BASE+'evidence.json','lock_path':BASE+'migration-lock.json','phase4b':'ACTIVE FOR LOCAL DEVELOPMENT; excluded from production, including scored-exercise rollout','historical_replay':False,'history_repairs_eligible':['030','20261116013951'],'history_repairs_authorized':False}
    m['package_tracking']={'bootstrap_path':BASE+'00_package_tracking.sql','table':'private.sai_deployment_packages','policy':'Package SQL, postcondition and receipt commit atomically; reject retries; never infer historical migration completion.'}
    steps=[s for s in m['steps'] if s['id'] not in ['phase7m-finance','phase7m-settings']]
    at=next(i for i,s in enumerate(steps) if s['id']=='refresh-mutation-guards')
    steps[at:at]=[
        {'id':'phase7m-finance','kind':'sql','path':BASE+'01_finance_main.sql','depends_on':['phase4a-examinations']},
        {'id':'phase7m-settings','kind':'sql','path':BASE+'02_settings_main.sql','depends_on':['phase7m-finance']},
    ]
    next(s for s in steps if s['id']=='refresh-mutation-guards')['depends_on']=['phase7m-settings']
    m['steps']=steps
    m['deferred_steps']=[
        {'id':'phase7m-admissions-remaining','path':BASE+'03_admissions_remaining.sql','depends_on':['phase3b-verified-onboarding'],'reason':'Requires separately approved admission-tracking Edge and public-flow cutover; not executed by Phase 7-R'},
        {'id':'phase7m-admission-events','path':BASE+'04_admission_events.sql','depends_on':['phase7m-admissions-remaining'],'reason':'Deploy together with tracking; not executed by Phase 7-R'},
    ]
    m['quarantined_migrations']=[p.relative_to(ROOT).as_posix() for p in sorted((ROOT/'supabase/migrations').glob('20261117*.sql'))]
    paths=[s['path'] for s in m['required_source_files']]
    paths.extend(BASE+p.name for p in sorted((ROOT/BASE).glob('*.sql')))
    paths.extend([BASE+'migration-lock.json',BASE+'evidence.json','supabase/inspection/phase7m_equivalence.sql','supabase/tests/phase7m/main_baseline.sql','supabase/tools/validate_migrations.py','supabase/deployment/phase7r/Invoke-MainDeployment.ps1'])
    paths.extend('supabase/tests/'+p for p in [
        'phase3b-main/run_local.py','phase3b-main/fixtures.sql','phase3b-main/behavior.sql',
        'phase7m_behavior.sql','phase7m_executor_tracking.ps1','run_native_contracts.py',
        'test_migration_validation.py','finance_completion_behavior.sql','admissions_behavior.sql',
        'admissions_tracking_behavior.sql','admission_event_integrity.sql','student_parent_access.sql',
        'attendance_behavior.sql','profile_contact_behavior.sql','examinations_behavior.sql',
        'recovery/mutation_hold_fixture.sql','recovery/mutation_hold_behavior.sql','recovery/mutation_hold_cleanup.sql'])
    paths.extend(['.gitattributes','.github/workflows/database-ci.yml'])
    m['required_source_files']=[{'path':p,'sha256':digest(p)} for p in dict.fromkeys(paths)]
    (ROOT/MANIFEST).write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
    integrity_paths=[MANIFEST,*[s['path'] for s in m['required_source_files']]]
    (ROOT/(BASE+'integrity.json')).write_text(json.dumps({p:digest(p) for p in integrity_paths},indent=2)+'\n',encoding='utf-8')
    print('Updated offline manifest pins; release_ready=false; approval hashes invalidated')
if __name__=='__main__': main()
