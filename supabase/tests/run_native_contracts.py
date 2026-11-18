"""Portable native PostgreSQL runner for existing self-contained SQL contracts.

Creates only task-owned loopback clusters. Never accepts a connection URL.
"""
import os,shutil,socket,subprocess,tempfile,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BIN=Path(os.environ.get('SAI_PG_BIN',r'C:\Program Files\PostgreSQL\17\bin'))
ENV={k:v for k,v in os.environ.items() if not k.upper().startswith(('PG','SUPABASE_'))}
def exe(name): return str(BIN/(name+('.exe' if os.name=='nt' else '')))
def suite(name):
    out=ROOT/'.tmp-phase7m-contracts'/uuid.uuid4().hex;out.mkdir(parents=True)
    socket_dir=Path(tempfile.mkdtemp(prefix='sai-pg-'))
    data=out/'data';started=False
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    def run(name,args,log):
        with (out/log).open('wb') as file:
            result=subprocess.run([exe(name),*map(str,args)],env=ENV,stdin=subprocess.DEVNULL,stdout=file,stderr=file,timeout=120)
        if result.returncode: raise RuntimeError(f'{name} failed ({result.returncode}); {out/log}')
    try:
        run('initdb',['-D',data,'-U','postgres','--auth=trust','--no-locale','--encoding=UTF8'],'init.log')
        run('pg_ctl',['-D',data,'-l',out/'server.log','-o',f'-h 127.0.0.1 -p {port} -k {socket_dir}','-w','start'],'start.log');started=True
        args=['-X','-h','127.0.0.1','-p',str(port),'-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1']
        actual=subprocess.check_output([exe('psql'),*args,'-At','-c','show data_directory'],env=ENV,text=True).strip()
        if Path(actual).resolve()!=data.resolve(): raise RuntimeError('Wrong task-owned cluster')
        run('psql',[*args,'-f',ROOT/'supabase/tests'/name],'behavior.log')
        print('PASS:',name,flush=True)
    finally:
        if started or (data/'postmaster.pid').exists(): run('pg_ctl',['-D',data,'-m','fast','-w','stop'],'stop.log')
        shutil.rmtree(socket_dir,ignore_errors=True)
        print('Evidence:',out,flush=True)
for name in ['profile_contact_behavior.sql','examinations_behavior.sql']: suite(name)
