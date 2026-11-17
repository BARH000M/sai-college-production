"""Native PostgreSQL isolated contact contract test; no hosted connection or Docker."""
import os,pathlib,subprocess,uuid,json
root=pathlib.Path(__file__).resolve().parents[2]
out=root/'.tmp-profile-contact'/str(uuid.uuid4());out.mkdir(parents=True)
data=out/'pgdata'
bin=pathlib.Path(os.environ.get('SAI_PG_BIN',r'C:\Program Files\PostgreSQL\17\bin'))
env={k:v for k,v in os.environ.items() if not k.upper().startswith(('PG','SUPABASE'))}
def run(exe,args,log):
    with (out/log).open('wb') as f:
        result=subprocess.run([str(bin/(exe+'.exe')),*map(str,args)],env=env,stdout=f,stderr=f,timeout=120)
    if result.returncode:raise RuntimeError(exe+' failed; inspect '+str(out/log))
run('initdb',['-D',data,'-U','contact_test','--auth=trust','--no-locale','--encoding=UTF8'],'init.log')
with (data/'postgresql.conf').open('a') as f:f.write("\nlisten_addresses='127.0.0.1'\nport=55481\nshared_preload_libraries=''\n")
started=False
try:
    run('pg_ctl',['-D',data,'-l',out/'server.log','-w','start'],'start.log');started=True
    conn=['-h','127.0.0.1','-p','55481','-U','contact_test','-d','postgres','-w','-X','-v','ON_ERROR_STOP=1']
    actual=subprocess.check_output([str(bin/'psql.exe'),*conn,'-At','-c','SHOW data_directory'],env=env).decode().strip()
    assert pathlib.Path(actual).resolve()==data.resolve(),'Wrong isolated cluster'
    run('psql',[*conn,'-f',root/'supabase/tests/profile_contact_behavior.sql'],'behavior.log')
    print('PASS: isolated profile contact behavior, nine roles and negative permission cases')
finally:
    if started:run('pg_ctl',['-D',data,'-m','fast','-w','stop'],'stop.log')
print('Isolated cluster stopped; evidence:',out)
