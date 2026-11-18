"""Offline drift/manifest validation. Never deploys or repairs history."""
import argparse,hashlib,json,re,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='supabase/deployment/phase7m/'
def digest(path,lf=False):
    data=path.read_bytes()
    return hashlib.sha256(data.replace(b'\r\n',b'\n') if lf else data).hexdigest()
def validate(root=ROOT,base_ref=None,release=False):
    errors=[]
    lock=json.loads((root/(BASE+'migration-lock.json')).read_text())
    entries=lock['migrations']; files=list((root/'supabase/migrations').glob('*.sql'))
    expected={e['filename']:e for e in entries}; seen=set()
    if len(expected)!=len(entries): errors.append('duplicate lock filenames')
    for p in files:
        match=re.fullmatch(r'(\d+)_[A-Za-z0-9_]+\.sql',p.name)
        if not match: errors.append('invalid migration name: '+p.name); continue
        version=match[1]
        if version in seen: errors.append('duplicate migration version: '+version)
        seen.add(version)
        e=expected.get(p.name)
        if e is None: errors.append('unreviewed migration: '+p.name); continue
        if e['version']!=version or digest(p,True)!=e['sha256_lf']: errors.append('checksum/version mismatch: '+p.name)
        if not p.read_text(encoding='utf-8-sig').strip() and not e['empty']: errors.append('empty migration: '+p.name)
        if release and (e['empty'] or e['classification']=='CONFLICTING'): errors.append('unresolved release migration: '+p.name)
    for missing in set(expected)-{p.name for p in files}: errors.append('missing migration file: '+missing)
    for n in range(1,32):
        if f'{n:03}' not in seen: errors.append(f'missing legacy version {n:03}')
    if base_ref:
        def blob(path):
            return subprocess.check_output(['git','show',base_ref+':'+path],cwd=root,stderr=subprocess.DEVNULL)
        applied={e['filename'] for e in entries if e['history']}
        try:
            prior=json.loads(blob(BASE+'migration-lock.json'))
            applied|={e['filename'] for e in prior['migrations'] if e['history']}
        except subprocess.CalledProcessError: pass # first introduction of the lock
        for name in applied:
            try: old=blob('supabase/migrations/'+name).replace(b'\r\n',b'\n')
            except subprocess.CalledProcessError:
                errors.append('applied source missing from base: '+name); continue
            current=root/'supabase/migrations'/name
            if not current.exists() or current.read_bytes().replace(b'\r\n',b'\n')!=old:
                errors.append('unauthorized applied migration modification: '+name)
    m=json.loads((root/'supabase/deployment/phase7r/main-deployment-manifest.json').read_text())
    if m['project']['ref']!='aeryusbrulqdxjdynwfh' or m['project']['git_branch']!='main': errors.append('wrong deployment target')
    pinned={}
    for source in m['required_source_files']:
        path=source['path']; resolved=(root/path).resolve()
        if not resolved.is_relative_to(root.resolve()): errors.append('manifest path escapes repository'); continue
        if path in pinned: errors.append('duplicate manifest path: '+path)
        pinned[path]=source['sha256']
        if not resolved.is_file() or digest(resolved)!=source['sha256']: errors.append('manifest hash mismatch: '+path)
        if 'phase4b' in path.lower(): errors.append('unfinished Phase 4B in manifest')
    done=set()
    for step in m['steps']:
        if step['id'] in done: errors.append('duplicate deployment step')
        if any(d not in done for d in step['depends_on']): errors.append('invalid dependency order: '+step['id'])
        if step['kind']=='sql' and step['path'] not in pinned: errors.append('unpinned SQL step')
        if step['kind']=='sql' and '/migrations/' in step['path']: errors.append('historical replay route')
        done.add(step['id'])
    for step in m.get('deferred_steps',[]):
        if step['id'] in done or step['path'] not in pinned: errors.append('invalid deferred step')
    for function in m['edge_function_baseline']:
        if any(p not in pinned for p in [function['entrypoint'],*function['dependencies']]): errors.append('unpinned Edge dependency')
    for path,expected_hash in json.loads((root/(BASE+'integrity.json')).read_text()).items():
        if not (root/path).is_file() or digest(root/path)!=expected_hash: errors.append('integrity checksum mismatch: '+path)
    if release and not m['reconciliation']['release_ready']: errors.append('Phase 7-M release gate is NO-GO')
    return errors
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--base-ref');parser.add_argument('--release',action='store_true');args=parser.parse_args()
    errors=validate(base_ref=args.base_ref,release=args.release)
    for error in errors: print('FAIL:',error)
    if errors: sys.exit(1)
    print('PASS: migration versions, inventory, checksums, dependency graph and manifest integrity; no deployment')
