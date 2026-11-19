"""Portable native PostgreSQL runner for existing self-contained SQL contracts.

Creates only task-owned loopback clusters. Never accepts a connection URL.
"""

import os
import shutil
import socket
import subprocess
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / 'supabase' / 'tests'
EVIDENCE = ROOT / '.tmp-phase7m-contracts'
SUITES = ('profile_contact_behavior.sql', 'examinations_behavior.sql')
HOST = '127.0.0.1'
SUFFIX = '.exe' if os.name == 'nt' else ''
REQUIRED = ('initdb', 'pg_ctl', 'postgres', 'psql')
ENV = {
    k: v for k, v in os.environ.items()
    if not k.upper().startswith(('PG', 'SUPABASE_'))
}
ENV['PGCONNECT_TIMEOUT'] = '10'


def find_bin():
    def valid(path):
        return all((path / (name + SUFFIX)).is_file() for name in REQUIRED)

    configured = os.environ.get('SAI_PG_BIN')
    if configured:
        path = Path(configured).expanduser().resolve()
        if not valid(path):
            raise RuntimeError(f'Invalid SAI_PG_BIN: {path}')
        return path

    candidates = []
    if os.name == 'nt':
        candidates.append(Path(r'D:\pgsql\bin'))
    ctl = shutil.which('pg_ctl')
    if ctl:
        candidates.append(Path(ctl).resolve().parent)
    config = shutil.which('pg_config')
    if config:
        result = subprocess.run(
            [config, '--bindir'], env=ENV, capture_output=True,
            text=True, timeout=10, check=False,
        )
        if result.returncode == 0 and result.stdout.strip():
            candidates.append(Path(result.stdout.strip()))
    if os.name == 'nt':
        base = Path(os.environ.get('ProgramFiles', r'C:\Program Files'))
        candidates.extend((base / 'PostgreSQL').glob('*/bin'))
    else:
        candidates.extend(Path('/usr/lib/postgresql').glob('*/bin'))

    for path in candidates:
        if valid(path):
            return path.resolve()
    raise RuntimeError('PostgreSQL server tools not found. Set SAI_PG_BIN.')


def suite(name, bin_dir):
    sql = TESTS / name
    if not sql.is_file():
        raise FileNotFoundError(sql)
    out = EVIDENCE / uuid.uuid4().hex
    out.mkdir(parents=True)
    data = out / 'data'
    started = False
    failed = False
    child_env = dict(ENV)
    child_env['PATH'] = str(bin_dir) + os.pathsep + ENV.get('PATH', '')

    def exe(tool):
        return str(bin_dir / (tool + SUFFIX))

    def show_logs(*names):
        for filename in names:
            path = out / filename
            if path.is_file():
                content = path.read_text(encoding='utf-8', errors='replace')
                print(f'\n--- {filename} (tail) ---\n{content[-12000:]}', flush=True)

    def run(tool, args, log, timeout=120):
        path = out / log
        with path.open('wb') as file:
            result = subprocess.run(
                [exe(tool), *map(str, args)], env=child_env,
                stdin=subprocess.DEVNULL, stdout=file, stderr=file,
                timeout=timeout, check=False,
            )
        if result.returncode:
            raise RuntimeError(f'{tool} failed ({result.returncode}); {path}')
        return path

    try:
        run('initdb', ['-D', data, '-U', 'postgres', '--auth=trust',
                       '--no-locale', '--encoding=UTF8'], 'init.log')
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.bind((HOST, 0))
            port = sock.getsockname()[1]

        # Configure ONLY the newly initialized, task-owned cluster.
        with (data / 'postgresql.conf').open('a', encoding='utf-8') as conf:
            conf.write(f"\nlisten_addresses = '{HOST}'\n"
                       f'port = {port}\n'
                       "unix_socket_directories = ''\n")

        run('pg_ctl', ['-D', data, '-l', out / 'server.log',
                       '-w', '-t', '60', 'start'], 'start.log')
        started = True

        args = ['-X', '-w', '-h', HOST, '-p', str(port), '-U', 'postgres',
                '-d', 'postgres', '-v', 'ON_ERROR_STOP=1']
        identity = run('psql', [*args, '-At', '-c', 'show data_directory'],
                       'identity.log')
        actual = identity.read_text(encoding='utf-8').strip()
        if Path(actual).resolve() != data.resolve():
            raise RuntimeError('Wrong task-owned cluster; refusing SQL execution')

        run('psql', [*args, '-f', sql], 'behavior.log')
        print('PASS:', name, flush=True)
    except BaseException:
        failed = True
        show_logs('init.log', 'start.log', 'server.log', 'identity.log', 'behavior.log')
        raise
    finally:
        try:
            if started or (data / 'postmaster.pid').is_file():
                run('pg_ctl', ['-D', data, '-m', 'fast', '-w', '-t', '60',
                               'stop'], 'stop.log')
        except Exception as error:
            show_logs('stop.log', 'server.log')
            print(f'PostgreSQL cleanup failed: {error}', flush=True)
            if not failed:
                raise
        finally:
            print('Evidence:', out, flush=True)


def main():
    if hasattr(os, 'geteuid') and os.geteuid() == 0:
        raise RuntimeError('Run native PostgreSQL tests as a non-root user.')
    bin_dir = find_bin()
    print('PostgreSQL binaries:', bin_dir, flush=True)
    for name in SUITES:
        suite(name, bin_dir)
    print('PASS: all native PostgreSQL contracts', flush=True)


if __name__ == '__main__':
    main()
