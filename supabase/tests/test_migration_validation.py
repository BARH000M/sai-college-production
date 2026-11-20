"""Tamper tests for offline drift gates; no DB or hosted access."""
import importlib.util,json,shutil,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('validator',ROOT/'supabase/tools/validate_migrations.py')
v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
class Gates(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        paths={p.relative_to(ROOT).as_posix() for p in (ROOT/'supabase/migrations').glob('*.sql')}
        paths.update(p.relative_to(ROOT).as_posix() for p in (ROOT/'supabase/archive/demo').glob('*.sql'))
        paths.update(json.loads((ROOT/'supabase/deployment/phase7m/integrity.json').read_text()))
        paths.update(s['path'] for s in json.loads((ROOT/'supabase/deployment/phase7r/main-deployment-manifest.json').read_text())['required_source_files'])
        paths.add('supabase/deployment/phase7m/integrity.json')
        for path in paths:
            dest=self.root/path;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/path,dest)
    def tearDown(self): self.temp.cleanup()
    def test_current(self): self.assertEqual(v.validate(self.root),[])
    def test_duplicate(self):
        (self.root/'supabase/migrations/001_duplicate.sql').write_text('select 1;')
        self.assertTrue(any('duplicate migration version' in e for e in v.validate(self.root)))
    def test_missing(self):
        (self.root/'supabase/migrations/007_finance.sql').unlink()
        self.assertTrue(any('missing migration' in e for e in v.validate(self.root)))
    def test_archived_demo_checksum(self):
        path=self.root/'supabase/archive/demo/017_demo_attendance_week.sql'
        with path.open('a') as f: f.write('\nselect 1;')
        self.assertTrue(any('archived checksum/version mismatch' in e for e in v.validate(self.root)))
    def test_missing_archived_demo(self):
        (self.root/'supabase/archive/demo/017_demo_attendance_week.sql').unlink()
        errors=v.validate(self.root)
        self.assertTrue(any('missing migration file: 017_demo_attendance_week.sql' in e for e in errors))
        self.assertTrue(any('missing legacy version 017' in e for e in errors))
    def test_applied_checksum(self):
        with (self.root/'supabase/migrations/001_initial_schema.sql').open('a') as f: f.write('\nselect 1;')
        self.assertTrue(any('checksum/version mismatch' in e for e in v.validate(self.root)))
    def test_manifest_tamper(self):
        path=self.root/'supabase/deployment/phase7r/main-deployment-manifest.json'
        data=json.loads(path.read_text());data['steps'][1]['depends_on']=['nonexistent'];path.write_text(json.dumps(data))
        errors=v.validate(self.root)
        self.assertTrue(any('invalid dependency' in e for e in errors))
        self.assertTrue(any('integrity checksum' in e for e in errors))
    def test_release_closed(self): self.assertTrue(any('NO-GO' in e for e in v.validate(self.root,release=True)))
if __name__=='__main__': unittest.main()
