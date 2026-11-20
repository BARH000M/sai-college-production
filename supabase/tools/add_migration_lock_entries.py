"""Append reviewable migration-lock entries for migrations missing from the lock.

Computes sha256 over LF-normalized bytes exactly as validate_migrations.py does,
so the recorded digest matches the gate instead of being typed by hand.

Guarantees:
  * never marks a migration as applied (history stays false);
  * never edits, moves or replays migration SQL;
  * never deploys, repairs history or contacts a database;
  * refuses to invent a classification — it must be passed explicitly;
  * preserves the existing lock ordering (inserts at the version position).

Usage:
    python supabase/tools/add_migration_lock_entries.py --classification "APPLIED BUT NOT RECORDED"
    python supabase/tools/add_migration_lock_entries.py --classification "NOT APPLIED" \
        --only 20261120000000 20261120120000 --dry-run

After a real run, regenerate the dependent pins as well, because
migration-lock.json is itself pinned by the manifest and integrity.json:
    python supabase/tools/refresh_phase7m_pins.py
"""

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = 'supabase/deployment/phase7m/'
LOCK = BASE + 'migration-lock.json'
MIGRATIONS = 'supabase/migrations'
CLASSIFICATIONS = (
    'MATCHED',
    'SUPERSEDED',
    'APPLIED BUT NOT RECORDED',
    'NOT APPLIED',
    'PARTIALLY APPLIED',
    'CONFLICTING',
)
NAME = re.compile(r'(\d+)_[A-Za-z0-9_]+\.sql')


def sha256_lf(path):
    data = path.read_bytes().replace(b'\r\n', b'\n')
    return hashlib.sha256(data).hexdigest()


def insert_entry(entries, entry):
    for index, existing in enumerate(entries):
        if existing['version'] > entry['version']:
            entries.insert(index, entry)
            return index
    entries.append(entry)
    return len(entries) - 1


def main():
    parser = argparse.ArgumentParser(
        description='Add missing repository migrations to migration-lock.json.',
    )
    parser.add_argument('--classification', required=True, choices=CLASSIFICATIONS)
    parser.add_argument(
        '--only',
        nargs='+',
        metavar='VERSION',
        help='limit to these migration versions (e.g. 20261120120000)',
    )
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()

    lock_path = ROOT / LOCK
    lock = json.loads(lock_path.read_text(encoding='utf-8'))
    entries = lock['migrations']
    known_names = {entry['filename'] for entry in entries}
    known_versions = {entry['version'] for entry in entries}
    wanted = set(args.only or ())

    additions = []
    for path in sorted((ROOT / MIGRATIONS).glob('*.sql')):
        if path.name in known_names:
            continue
        match = NAME.fullmatch(path.name)
        if not match:
            raise SystemExit(f'invalid migration name: {path.name}')
        version = match[1]
        if wanted and version not in wanted:
            continue
        empty = not path.read_text(encoding='utf-8-sig').strip()
        if empty:
            print(f'WARNING: {path.name} is empty but is being classified {args.classification}')
        additions.append({
            'version': version,
            'filename': path.name,
            'sha256_lf': sha256_lf(path),
            'history': False,
            'empty': empty,
            'classification': args.classification,
        })

    unknown = sorted(wanted - known_versions - {entry['version'] for entry in additions})
    if unknown:
        raise SystemExit('no such migration version(s): ' + ', '.join(unknown))
    if not additions:
        print('Nothing to add; every repository migration already has a lock entry.')
        return

    for entry in additions:
        index = insert_entry(entries, entry)
        print(
            f"add  {entry['filename']}  version={entry['version']}  "
            f"sha256_lf={entry['sha256_lf']}  empty={entry['empty']}  "
            f"classification={entry['classification']}  index={index}"
        )

    if args.dry_run:
        print('dry run: migration-lock.json not written')
        return

    lock['migrations'] = entries
    lock_path.write_text(json.dumps(lock, indent=2) + '\n', encoding='utf-8')
    print(f'\nwrote {LOCK} with {len(entries)} entries')
    print('NEXT: python supabase/tools/refresh_phase7m_pins.py')
    print('THEN: python supabase/tools/validate_migrations.py')


if __name__ == '__main__':
    main()