"""Synthetic Main-catalog replay, real RLS and concurrent sessions. No network API.

Creates a NEW task-owned cluster, loopback only, stops it in finally. Never
accepts a hosted connection string or attaches to an existing Postgres server.
Uses the already captured read-only Main catalog, not production row data.
"""
import argparse
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import time
import uuid

ROOT=Path(__file__).resolve().parents[3]
BIN=Path(r'C:\Program Files\PostgreSQL\17\bin')
parser=argparse.ArgumentParser()
parser.add_argument('--catalog-dir',type=Path,help='Optional captured metadata directory; default is the checked-in synthetic DDL fixture')
args=parser.parse_args()
if args.catalog_dir:
    catalog=json.loads((args.catalog_dir/'catalog.json').read_text())[0]['catalog']
    extended=json.loads((args.catalog_dir/'extended.json').read_text())[0]['extended']
    project=json.loads((args.catalog_dir/'project.json').read_text())
    column_flags={(x['schema'],x['table'],x['column']):x for x in json.loads((args.catalog_dir/'identity-columns.json').read_text())}
    assert project['id']=='aeryusbrulqdxjdynwfh','Wrong captured baseline'
    assert catalog['read_only']=='on','Catalog provenance must be read-only'
state=ROOT/'.tmp-phase3b-main'/str(uuid.uuid4())
data=state/'pgdata'
state.mkdir(parents=True)
with socket.socket() as s:
    s.bind(('127.0.0.1',0)); port=s.getsockname()[1]
env=os.environ.copy()
for key in list(env):
    if key.startswith('PG') or key.startswith('SUPABASE_'): env.pop(key)
env['PGOPTIONS']='-c statement_timeout=20000 -c lock_timeout=10000'
flags=getattr(subprocess,'CREATE_NO_WINDOW',0)
def command(argv,**kwargs):
    return subprocess.run([str(x) for x in argv],env=env,creationflags=flags,
                          capture_output=True,text=True,encoding='utf-8',errors='replace',**kwargs)
def require(result,label):
    (state/'run.log').open('a',encoding='utf-8').write(f'\n{label}\n{result.stdout}\n{result.stderr}')
    if result.returncode: raise RuntimeError(f'{label}: {result.stderr[-3500:]}')
    print(label+': PASS',flush=True)
def connection():
    return [BIN/'psql.exe','-X','-h','127.0.0.1','-p',str(port),'-U','postgres','-d','phase3b_main',
            '-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose']
def guard():
    # Check server identity in EVERY write session; fail closed before its SQL.
    return """do $guard$ begin if current_database()<>'phase3b_main' or
      replace(current_setting('data_directory'),'\\','/')<>%s then
      raise exception 'Isolated cluster identity mismatch'; end if; end $guard$;\n"""%literal(data.as_posix())
def sql(text,label,expect_ok=True):
    result=command(connection(),input=guard()+text)
    if expect_ok: require(result,label)
    return result
def literal(s): return "'"+str(s).replace("'","''")+"'"
def ident(s): return '"'+s.replace('"','""')+'"'
def qualified(schema,name): return ident(schema)+'.'+ident(name)
def acl_sql(obj,kind,acl):
    result=f'revoke all on {kind} {obj} from public,anon,authenticated,service_role;\n'
    privileges={'r':'select','a':'insert','w':'update','d':'delete','D':'truncate','x':'references','t':'trigger','m':'maintain','X':'execute','U':'usage'}
    if acl is None: return result
    for item in acl:
        role,rights=item.split('=',1); rights=rights.split('/')[0]
        if role=='postgres': continue
        rights=[privileges[c] for c in rights if c in privileges]
        if rights: result+=f'grant {",".join(rights)} on {kind} {obj} to {ident(role) if role else "public"};\n'
    return result

def baseline():
    # Auth/Storage stand-ins expose only the columns/contracts used here. No
    # hosted JWT verification, mail delivery or PostgREST is simulated.
    out="""create role anon nologin; create role authenticated nologin;
    create role service_role nologin bypassrls;
    revoke create on schema public from public;
    create schema auth;
    create table auth.users(id uuid primary key default gen_random_uuid(),email text,
      email_confirmed_at timestamptz,phone_confirmed_at timestamptz,deleted_at timestamptz,
      banned_until timestamptz,raw_user_meta_data jsonb default '{}'::jsonb,
      created_at timestamptz default now());
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    create function auth.role() returns text language sql stable as
      $$select nullif(current_setting('request.jwt.claim.role',true),'')$$;
    grant usage on schema auth to anon,authenticated,service_role;
    create schema storage;
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
    alter table storage.objects enable row level security;
    create function storage.foldername(text) returns text[] language sql immutable as
      $$select string_to_array($1,'/')$$;
    grant usage on schema storage to authenticated,service_role;
    create schema private;
    grant usage on schema private to authenticated,service_role;
    set check_function_bodies=false;
    create type public.app_role as enum ("""+','.join(literal(x) for x in catalog['enum'])+");\n"
    identity_sequences={(s,t+'_'+c+'_seq') for (s,t,c),x in column_flags.items() if x['identity']}
    for t in catalog['tables']:
        if t['kind']=='S' and (t['schema'],t['name']) not in identity_sequences:
            out+=f'create sequence {qualified(t["schema"],t["name"])};\n'
    for t in catalog['tables']:
        if t['kind']!='r': continue
        columns=[]
        for c in catalog['columns']:
            if (c['schema'],c['table'])!=(t['schema'],t['name']): continue
            col=ident(c['column'])+' '+c['type']
            extra=column_flags.get((c['schema'],c['table'],c['column']),{})
            if extra.get('identity'):
                col+=' generated '+('always' if extra['identity']=='a' else 'by default')+' as identity'
            elif extra.get('generated'):
                col+=' generated always as ('+c['default']+') stored'
            elif c['default'] is not None: col+=' default '+c['default']
            if c['not_null']: col+=' not null'
            columns.append(col)
        out+=f'create table {qualified(t["schema"],t["name"])} ({",".join(columns)});\n'
    # All referenced unique/primary keys must exist before cross-table FKs.
    for c in sorted(catalog['constraints'],key=lambda c:c['definition'].startswith('FOREIGN KEY')):
        out+=f'alter table {qualified(c["schema"],c["table"])} add constraint {ident(c["name"])} {c["definition"]};\n'
    for f in catalog['functions']:
        out+=f['definition']+';\n'
        name=qualified(f['schema'],f['name'])+'('+f['identity_args']+')'
        out+=acl_sql(name,'function',f['acl'] if f['acl'] is not None else ['=X/postgres'])
    for t in catalog['tables']:
        if t['kind']!='r': continue
        name=qualified(t['schema'],t['name'])
        if t['rls']: out+=f'alter table {name} enable row level security;\n'
        out+=acl_sql(name,'table',t['acl'])
    for c in catalog['columns']:
        for item in c['acl'] or []:
            role,rights=item.split('=',1);rights=rights.split('/')[0]
            ops={'r':'select','a':'insert','w':'update','x':'references'}
            for code,op in ops.items():
                if code in rights: out+=f'grant {op} ({ident(c["column"])}) on {qualified(c["schema"],c["table"])} to {ident(role)};\n'
    for p in catalog['policies']:
        out+=f'create policy {ident(p["policyname"])} on {qualified(p["schemaname"],p["tablename"])} as {p["permissive"]} for {p["cmd"]} to '+','.join('public' if x=='public' else ident(x) for x in p['roles'])
        if p['qual']: out+=' using ('+p['qual']+')'
        if p['with_check']:out+=' with check ('+p['with_check']+')'
        out+=';\n'
    for t in catalog['triggers']: out+=t['definition']+';\n'
    constraint_names={c['name'] for c in catalog['constraints']}
    for i in extended['indexes']:
        if i['indexname'] not in constraint_names: out+=i['indexdef']+';\n'
    out+='set check_function_bodies=true;\n'
    return out

started=False
try:
    require(command([BIN/'initdb.exe','-D',data,'-U','postgres','--auth=trust','--encoding=UTF8','--locale=C']), 'New synthetic cluster')
    # File handles avoid an inherited Windows pipe keeping communicate() open
    # for the entire server lifetime after pg_ctl itself exits.
    with (state/'start.log').open('w',encoding='utf-8') as log:
        start_result=subprocess.run([str(x) for x in [BIN/'pg_ctl.exe','-D',data,'-l',state/'server.log','-o',f'-h 127.0.0.1 -p {port}','-w','-t','20','start']],
          env=env,creationflags=flags,stdin=subprocess.DEVNULL,stdout=log,stderr=subprocess.STDOUT,timeout=30)
    started=(data/'postmaster.pid').exists()
    if start_result.returncode: raise RuntimeError((state/'start.log').read_text())
    print('Start own loopback cluster: PASS',flush=True)
    started=True
    require(command([BIN/'createdb.exe','-h','127.0.0.1','-p',str(port),'-U','postgres','phase3b_main']), 'Create isolated database')
    base=baseline() if args.catalog_dir else (Path(__file__).parent/'main_baseline.sql').read_text(encoding='utf-8')
    (state/'synthetic_baseline.sql').write_text(base,encoding='utf-8')
    sql(base,'Captured Main DDL/ACL/policy baseline')
    sql((Path(__file__).parent/'fixtures.sql').read_text(encoding='utf-8'),'Synthetic accounts/settings/audit fixtures')
    for file in sorted((ROOT/'supabase/deployment/phase3b-main').glob('0*.sql')):
        sql(file.read_text(encoding='utf-8'),'Proposal '+file.name)
    sql((Path(__file__).parent/'behavior.sql').read_text(encoding='utf-8'),'Role/onboarding/RLS/atomicity/preservation assertions')
    isolation=sql("begin isolation level repeatable read; set local role service_role; select public.sai_manage_role_assignment('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','grant','student','{}',true,false,null,null); commit;",'Unsupported isolation rejection',False)
    assert isolation.returncode!=0 and '25001' in isolation.stderr,'Stale transaction snapshots were accepted'
    print('Unsupported isolation fails closed: PASS',flush=True)
    # Real concurrent sessions: precisely two usable Super Admins revoke self.
    sql("""insert into auth.users(id,email,email_confirmed_at) values
      ('10000000-0000-4000-8000-000000000001','a@example.test',now()),
      ('10000000-0000-4000-8000-000000000002','b@example.test',now());
      insert into public.user_roles(user_id,role) values
      ('10000000-0000-4000-8000-000000000001','super_admin'),
      ('10000000-0000-4000-8000-000000000002','super_admin');
      delete from public.user_roles where user_id='00000000-0000-4000-8000-000000000001' and role='super_admin';""",'Concurrency fixtures')
    def revoke(uid,pause):
        return guard()+f"""begin; set local role service_role;
          select public.sai_manage_role_assignment('{uid}','{uid}','revoke','super_admin','{{}}',true,false,null,null);
          select pg_sleep({pause}); commit;"""
    first=subprocess.Popen([str(x) for x in connection()],env=env,creationflags=flags,
      stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8')
    first.stdin.write(revoke('10000000-0000-4000-8000-000000000001',1.5));first.stdin.close()
    # Observe the actual held lock, rather than assuming the first session won.
    deadline=time.monotonic()+10
    while time.monotonic()<deadline:
        r=sql("select count(*) from pg_locks where locktype='advisory' and classid=831704 and objid=1 and granted;",'lock observation',False)
        if re.search(r'\n\s*1\s*\n',r.stdout):break
        time.sleep(.05)
    else:raise RuntimeError('First session did not acquire serialization lock')
    start=time.monotonic()
    second=sql(revoke('10000000-0000-4000-8000-000000000002',0),'Concurrent second revoke',False)
    first.wait(timeout=15)
    first_output=first.stdout.read()+first.stderr.read()
    assert first.returncode==0,first_output
    assert second.returncode!=0 and '23514' in second.stderr,second.stdout+second.stderr
    assert time.monotonic()-start>.5,'No observed serialization wait'
    print('Two concurrent last-admin revocations: PASS (one commit; one 23514)',flush=True)
    sql("do $$begin if (select count(*) from public.user_roles where role='super_admin')<>1 then raise exception 'Concurrent lockout';end if;end$$;",'Concurrent survivor assertion')
    print('ALL LOCAL DATABASE CHECKS PASS',flush=True)
finally:
    if started and (data/'postmaster.pid').exists():
        require(command([BIN/'pg_ctl.exe','-D',data,'-m','fast','-w','stop']),'Stop own cluster')
    print('Artifacts: '+str(state),flush=True)
