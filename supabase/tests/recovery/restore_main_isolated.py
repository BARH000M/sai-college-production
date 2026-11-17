from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import uuid
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BACKUP = Path(r"D:\SAI-Production-Backups\MAIN-20261117-164017")
PG_BIN = Path(r"C:\Program Files\PostgreSQL\17\bin")
ARCHIVE = BACKUP / "MAIN_DATABASE.dump"
APP_SCHEMAS = {"public", "private", "auth", "storage", "supabase_migrations"}
RESTORE_SCHEMAS = APP_SCHEMAS | {"extensions"}
EXTENSIONS = {"pgcrypto", "uuid-ossp"}
ROLE_PATTERN = re.compile(r'^CREATE ROLE "((?:[^"]|"")*)"', re.MULTILINE)
ENTRY_PATTERN = re.compile(r"^\s*(\d+);(.*)$")
MULTI_DESCRIPTIONS = (
    "MATERIALIZED VIEW DATA",
    "SEQUENCE OWNED BY",
    "TABLE DATA",
    "FK CONSTRAINT",
    "CHECK CONSTRAINT",
    "ROW SECURITY",
    "DEFAULT ACL",
    "EVENT TRIGGER",
)


def fail(message: str) -> None:
    raise RuntimeError(message)


def run(
    command: list[str],
    *,
    env: dict[str, str],
    input_text: str | None = None,
    log_path: Path | None = None,
    timeout: int = 1800,
) -> subprocess.CompletedProcess[str]:
    if log_path is None:
        result = subprocess.run(
            command, input=input_text, text=True, encoding="utf-8", errors="replace",
            capture_output=True, env=env, timeout=timeout, check=False,
        )
    else:
        with log_path.open("w", encoding="utf-8", errors="replace") as log:
            result = subprocess.run(
                command, input=input_text, text=True, encoding="utf-8", errors="replace",
                stdout=log, stderr=subprocess.STDOUT, env=env, timeout=timeout, check=False,
            )
    if result.returncode:
        fail(f"Command failed ({result.returncode}): {Path(command[0]).name}")
    return result


def clean_environment() -> dict[str, str]:
    env = os.environ.copy()
    for key in list(env):
        if key.upper().startswith(("PG", "SUPABASE_")):
            env.pop(key, None)
    env["PGCONNECT_TIMEOUT"] = "5"
    env["PGAPPNAME"] = "sai-phase7r-recovery"
    return env


def quoted_identifier(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_]+", value):
        fail("Unexpected identifier in backup inventory")
    return '"' + value.replace('"', '""') + '"'


def parse_toc(line: str) -> tuple[str, str | None, str | None] | None:
    match = ENTRY_PATTERN.match(line)
    if not match:
        return None
    tokens = match.group(2).split()
    if len(tokens) < 3:
        return "UNPARSED", None, None

    body = tokens[2:]
    if body[0] == "SCHEMA":
        return "SCHEMA", None, body[2] if len(body) > 2 else None
    if body[0] == "EXTENSION":
        return "EXTENSION", None, body[2] if len(body) > 2 else None
    if body[0] == "EVENT" and len(body) > 1 and body[1] == "TRIGGER":
        return "EVENT TRIGGER", None, body[3] if len(body) > 3 else None
    if body[0] in {"COMMENT", "ACL"} and len(body) > 2 and body[1] == "-":
        object_type = body[2]
        if object_type == "SCHEMA":
            return body[0], body[3] if len(body) > 3 else None, body[3] if len(body) > 3 else None
        if object_type == "EXTENSION":
            return body[0], None, body[3] if len(body) > 3 else None
        return body[0], body[3] if len(body) > 3 else None, None
    if body[0] == "DEFAULT" and len(body) > 4 and body[1] == "ACL":
        if body[2] == "-" and body[3] == "SCHEMA":
            return "DEFAULT ACL", body[4], None
        return "DEFAULT ACL", body[2], None

    description = next(
        (candidate for candidate in MULTI_DESCRIPTIONS if " ".join(body[: len(candidate.split())]) == candidate),
        body[0],
    )
    namespace_index = len(description.split())
    namespace = body[namespace_index] if len(body) > namespace_index else None
    if namespace == "-":
        namespace = None
    return description, namespace, None


def toc_entry_in_scope(parsed: tuple[str, str | None, str | None]) -> bool:
    kind, schema, object_name = parsed
    if kind == "EVENT TRIGGER":
        return False
    if kind == "SCHEMA":
        return object_name in RESTORE_SCHEMAS
    if kind == "EXTENSION":
        return object_name in EXTENSIONS
    if kind in {"COMMENT", "ACL"} and schema is None:
        return object_name in EXTENSIONS
    if schema == "extensions" and kind in {"COMMENT", "ACL", "DEFAULT ACL"}:
        return False
    return schema in RESTORE_SCHEMAS


def preflight_sql(database: str, data_dir: Path) -> str:
    expected_path = data_dir.resolve().as_posix().replace("'", "''")
    expected_db = database.replace("'", "''")
    return f"""
DO $preflight$
BEGIN
  IF current_database() <> '{expected_db}'
     OR replace(current_setting('data_directory'), chr(92), '/') <> '{expected_path}'
     OR current_setting('listen_addresses') <> '127.0.0.1' THEN
    RAISE EXCEPTION 'isolated_cluster_identity_mismatch';
  END IF;
END
$preflight$;
"""


class Recovery:
    def __init__(self) -> None:
        self.tag = uuid.uuid4().hex
        self.output = BACKUP / f"phase7r-recovery-{self.tag}"
        self.data_dir = self.output / "data"
        self.marker = self.output / ".recovery-owner"
        self.database = f"sai_recovery_{self.tag[:12]}"
        self.port = self._find_port()
        self.env = clean_environment()
        self.pg_ctl = str(PG_BIN / "pg_ctl.exe")
        self.psql_exe = str(PG_BIN / "psql.exe")
        self.pg_restore = str(PG_BIN / "pg_restore.exe")
        self.initdb = str(PG_BIN / "initdb.exe")
        self.started = False
        self.stage = "preflight"
        self.report: dict[str, object] = {
            "scope": "isolated native PostgreSQL application recovery",
            "production_connection_attempted": False,
            "managed_runtime_recovered": False,
            "database": self.database,
            "port": self.port,
            "evidence_directory": str(self.output),
        }

    @staticmethod
    def _find_port() -> int:
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            return int(sock.getsockname()[1])

    def psql(
        self,
        sql: str,
        database: str | None = None,
        app_name: str | None = None,
        include_stderr: bool = False,
    ) -> str:
        env = self.env.copy()
        if app_name:
            env["PGAPPNAME"] = app_name
        command = [
            self.psql_exe,
            "--no-psqlrc",
            "--host", "127.0.0.1",
            "--port", str(self.port),
            "--username", "postgres",
            "--dbname", database or self.database,
            "--set", "ON_ERROR_STOP=1",
            "--tuples-only",
            "--no-align",
            "--quiet",
        ]
        sql = preflight_sql(database or self.database, self.data_dir) + sql
        result = subprocess.run(
            command, input=sql, text=True, encoding="utf-8", errors="replace",
            capture_output=True, env=env, timeout=300, check=False,
        )
        if result.returncode:
            error_lines = [
                line.strip() for line in result.stderr.splitlines()
                if any(marker in line for marker in ("ERROR:", "FATAL:", "CONTEXT:", "LINE "))
            ]
            if self.output.exists():
                with (self.output / "psql-errors.log").open("a", encoding="utf-8") as log:
                    log.write(f"[{self.stage}] exit={result.returncode}\n")
                    log.write("\n".join(error_lines[:4]) + "\n")
            detail = error_lines[0] if error_lines else "database command rejected"
            raise RuntimeError(f"psql failed ({result.returncode}) during {self.stage}: {detail}")
        output = result.stdout + (result.stderr if include_stderr else "")
        return output.strip()

    def sql_file(self, path: Path, include_stderr: bool = False) -> str:
        return self.psql(path.read_text(encoding="utf-8"), include_stderr=include_stderr)

    def validate_inputs(self) -> dict[str, int]:
        for path in (ARCHIVE, BACKUP / "recovery-status.json",
                     BACKUP / "restored-table-counts.json",
                     BACKUP / "restored-relation-security.json",
                     BACKUP / "restored-policies.json",
                     BACKUP / "roles-reconstructed-no-passwords.sql"):
            if not path.is_file():
                fail(f"Required recovery input missing: {path.name}")
        if not PG_BIN.joinpath("pg_restore.exe").is_file() or not PG_BIN.joinpath("initdb.exe").is_file():
            fail("PostgreSQL 17 tools are unavailable at the verified installation path")

        status = json.loads((BACKUP / "recovery-status.json").read_text(encoding="utf-8"))
        digest = hashlib.sha256(ARCHIVE.read_bytes()).hexdigest()
        if status.get("archive_sha256") != digest:
            fail("The archive does not match the recorded recovery checksum")
        sums = json.loads((BACKUP / "VERIFIED-SHA256SUMS.json").read_text(encoding="utf-8"))
        recorded = [
            value for key, value in sums.items()
            if key.replace("\\", "/").endswith("MAIN_DATABASE.dump")
        ]
        if not recorded or digest not in recorded:
            fail("The archive does not match the verified checksum inventory")
        counts = json.loads((BACKUP / "restored-table-counts.json").read_text(encoding="utf-8"))
        expected = {
            key: value for key, value in counts.items()
            if key.split(".", 1)[0] in APP_SCHEMAS
        }
        if not expected:
            fail("No expected application table counts are available")
        self.report.update({
            "archive_checksum_verified": True,
            "prior_restore_exit_code": status.get("restore_exit_code"),
            "prior_restore_error_count": len(status.get("restore_errors", [])),
            "expected_application_tables": len(expected),
        })
        return expected

    def initialize(self) -> None:
        self.stage = "initializing isolated cluster"
        self.output.mkdir()
        self.marker.write_text(self.tag, encoding="ascii")
        run([
            self.initdb, "--pgdata", str(self.data_dir), "--username", "postgres",
            "--encoding", "UTF8", "--no-locale", "--auth-local", "trust",
            "--auth-host", "trust", "--data-checksums",
        ], env=self.env, log_path=self.output / "initdb.log", timeout=300)
        run([
            self.pg_ctl, "--pgdata", str(self.data_dir), "--log", str(self.output / "postgres.log"),
            "--options", f"-h 127.0.0.1 -p {self.port} -c listen_addresses=127.0.0.1",
            "--wait", "--timeout", "60", "start",
        ], env=self.env, log_path=self.output / "pg-start.log", timeout=90)
        self.started = True
        self.psql("SELECT 1;", database="postgres")
        available = set(self.psql(
            "SELECT name FROM pg_available_extensions WHERE name IN ('pgcrypto', 'uuid-ossp');",
            database="postgres",
        ).splitlines())
        self.report["available_native_extensions"] = sorted(available)
        if available != EXTENSIONS:
            fail("The required native crypto/UUID extensions are not installed; no stubs will be used")

    def create_roles_and_database(self) -> None:
        self.stage = "creating local database roles and database"
        role_file = (BACKUP / "roles-reconstructed-no-passwords.sql").read_text(encoding="utf-8")
        roles = sorted(set(ROLE_PATTERN.findall(role_file)))
        if not roles:
            fail("No role names could be safely extracted from the recovery evidence")
        statements = []
        for escaped_name in roles:
            name = escaped_name.replace('""', '"')
            bypass = "BYPASSRLS" if name in {"service_role", "supabase_auth_admin"} else "NOBYPASSRLS"
            sql_name = name.replace("'", "''")
            statements.append(
                f"DO $role$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = "
                f"'{sql_name}') THEN CREATE ROLE {quoted_identifier(name)} "
                f"NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION {bypass}; "
                "END IF; END $role$;"
            )
        self.psql("\n".join(statements) + f"\nCREATE DATABASE {quoted_identifier(self.database)} TEMPLATE template0;",
                  database="postgres")
        self.psql("CREATE SCHEMA IF NOT EXISTS public AUTHORIZATION postgres;")
        self.report["local_roles_created"] = len(roles)
        self.report["role_attributes_replayed"] = False
        self.report["role_memberships_replayed"] = False
        self.report["role_passwords_replayed"] = False

    def restore(self, expected: dict[str, int]) -> Counter[str]:
        self.stage = "building filtered restore list"
        listing = run([self.pg_restore, "--list", str(ARCHIVE)], env=self.env, timeout=300)
        lines = listing.stdout.splitlines()
        parsed_lines = []
        skipped: Counter[str] = Counter()
        supported_data = 0
        for line in lines:
            parsed = parse_toc(line)
            if parsed is None:
                parsed_lines.append(line)
                continue
            if toc_entry_in_scope(parsed):
                parsed_lines.append(line)
                if parsed[0] == "TABLE DATA" and parsed[1] in APP_SCHEMAS:
                    supported_data += 1
            else:
                skipped[parsed[0]] += 1
        if supported_data != len(expected):
            fail("The filtered archive does not contain every expected application table-data entry")
        filtered = self.output / "filtered-application-toc.list"
        filtered.write_text("\n".join(parsed_lines) + "\n", encoding="utf-8")
        self.report["filtered_toc_data_entries"] = supported_data
        self.report["skipped_toc_entry_types"] = dict(sorted(skipped.items()))

        self.psql("SELECT 1;")
        result = subprocess.run([
            self.pg_restore,
            "--exit-on-error",
            "--no-owner",
            "--verbose",
            "--use-list", str(filtered),
            "--host", "127.0.0.1",
            "--port", str(self.port),
            "--username", "postgres",
            "--dbname", self.database,
            str(ARCHIVE),
        ], text=True, encoding="utf-8", errors="replace", env=self.env,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=1800, check=False)
        (self.output / "restore.log").write_text(result.stdout, encoding="utf-8", errors="replace")
        if result.returncode:
            self.stage = "filtered pg_restore"
            fail(f"Filtered native restore failed with exit code {result.returncode}")

        self.stage = "initial archived row counts"
        self.compare_row_counts(expected, "initial")
        self.stage = "catalog and RLS contract verification"
        self.verify_catalog_contracts(expected, lines)
        self.stage = "read-only security invariant checks"
        security_result = self.sql_file(
            ROOT / "supabase" / "tests" / "security_invariants.sql",
            include_stderr=True,
        )
        (self.output / "security-invariants.log").write_text(security_result + "\n", encoding="utf-8")
        self.report["security_invariants_execution"] = "PASS"
        self.report["security_invariant_warnings"] = [
            line for line in security_result.splitlines()
            if "WARNING" in line.upper() or "PENDING" in line.upper()
        ]
        return skipped

    def compare_row_counts(self, expected: dict[str, int], label: str) -> None:
        self.stage = f"{label} application row counts"
        selects = []
        for key in sorted(expected):
            schema, table = key.split(".", 1)
            selects.append(
                f"SELECT '{key}' || '|' || count(*)::text FROM {quoted_identifier(schema)}.{quoted_identifier(table)}"
            )
        actual_lines = self.psql("\nUNION ALL\n".join(selects) + ";").splitlines()
        actual = {}
        for line in actual_lines:
            key, value = line.split("|", 1)
            actual[key] = int(value)
        mismatches = {
            key: {"expected": expected[key], "actual": actual.get(key)}
            for key in expected if actual.get(key) != expected[key]
        }
        self.report[f"{label}_row_count_mismatches"] = mismatches
        if mismatches:
            fail(f"{label} application table row counts did not match the archived inventory")

    def verify_catalog_contracts(self, expected: dict[str, int], toc_lines: list[str]) -> None:
        toc_counts: Counter[tuple[str, str]] = Counter()
        for line in toc_lines:
            parsed = parse_toc(line)
            if parsed and parsed[1] in APP_SCHEMAS:
                toc_counts[(parsed[0], parsed[1])] += 1

        security_snapshot = json.loads(
            (BACKUP / "restored-relation-security.json").read_text(encoding="utf-8")
        )
        expected_relations = {
            (item["nspname"], item["relname"], item["relkind"],
             bool(item["relrowsecurity"]), bool(item["relforcerowsecurity"]))
            for item in security_snapshot
            if item.get("nspname") in APP_SCHEMAS and item.get("relkind") in {"r", "p"}
        }
        policy_snapshot = json.loads(
            (BACKUP / "restored-policies.json").read_text(encoding="utf-8")
        )
        expected_policies = {
            (item["schemaname"], item["tablename"], item["policyname"])
            for item in policy_snapshot if item.get("schemaname") in APP_SCHEMAS
        }

        self.stage = "RLS relation-security comparison"
        actual_relations = self.psql("""
SELECT n.nspname || '|' || c.relname || '|' || c.relkind::text || '|' ||
       c.relrowsecurity::text || '|' || c.relforcerowsecurity::text
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public', 'private', 'auth', 'storage', 'supabase_migrations')
  AND c.relkind IN ('r', 'p');
""").splitlines()
        relation_set = {
            (parts[0], parts[1], parts[2], parts[3] == "true", parts[4] == "true")
            for line in actual_relations if (parts := line.split("|")) and len(parts) == 5
        }
        if relation_set != expected_relations:
            fail("RLS relation-security metadata differs from the recovery snapshot")

        self.stage = "RLS policy comparison"
        actual_policies = self.psql("""
SELECT n.nspname || '|' || c.relname || '|' || p.polname
FROM pg_catalog.pg_policy p
JOIN pg_catalog.pg_class c ON c.oid = p.polrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public', 'private', 'auth', 'storage', 'supabase_migrations');
""").splitlines()
        policy_set = {tuple(line.split("|", 2)) for line in actual_policies}
        if policy_set != expected_policies:
            fail("Restored row-level security policy names differ from the recovery snapshot")

        self.stage = "catalog counts for tables, constraints, functions, and triggers"
        metadata = self.psql(f"""
SELECT 'tables|' || count(*) FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('public', 'private', 'auth', 'storage', 'supabase_migrations')
  AND c.relkind IN ('r', 'p')
UNION ALL
SELECT 'constraints|' || count(*) FROM pg_catalog.pg_constraint c
JOIN pg_catalog.pg_class r ON r.oid = c.conrelid
JOIN pg_catalog.pg_namespace n ON n.oid = r.relnamespace
WHERE n.nspname IN ('public', 'private', 'auth', 'storage', 'supabase_migrations')
UNION ALL
SELECT 'functions|' || count(*) FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname IN ('public', 'private', 'auth', 'storage', 'supabase_migrations')
  AND p.prokind IN ('f', 'p', 'a', 'w')
UNION ALL
SELECT 'triggers|' || count(*) FROM pg_catalog.pg_trigger t
JOIN pg_catalog.pg_class r ON r.oid = t.tgrelid
JOIN pg_catalog.pg_namespace n ON n.oid = r.relnamespace
WHERE n.nspname IN ('public', 'private', 'auth', 'storage', 'supabase_migrations')
  AND NOT t.tgisinternal
UNION ALL
SELECT 'policies|' || count(*) FROM pg_catalog.pg_policy p
JOIN pg_catalog.pg_class r ON r.oid = p.polrelid
JOIN pg_catalog.pg_namespace n ON n.oid = r.relnamespace
WHERE n.nspname IN ('public', 'private', 'auth', 'storage', 'supabase_migrations');
""").splitlines()
        counts = {key: int(value) for key, value in (line.split("|", 1) for line in metadata)}
        if counts.get("policies") != len(expected_policies):
            fail("Policy catalog count differs from the recovery snapshot")
        self.verify_constraint_definitions(counts["constraints"])
        self.report["application_catalog_counts"] = counts
        self.report["archive_toc_contract_counts"] = {
            kind: sum(count for (entry_kind, _schema), count in toc_counts.items() if entry_kind == kind)
            for kind in ("TABLE", "CONSTRAINT", "FK CONSTRAINT", "FUNCTION", "PROCEDURE", "TRIGGER", "POLICY")
        }
        self.report["expected_table_data_entries"] = len(expected)
        self.report["security_policies_verified"] = len(policy_set)
        self.report["rls_relations_verified"] = len(relation_set)

    def verify_constraint_definitions(self, catalog_count: int) -> None:
        self.stage = "constraint DDL/catalog reconciliation"
        schema_dump = self.output / "constraint-check.sql"
        run([
            self.pg_restore,
            "--schema-only",
            "--no-owner",
            "--use-list", str(self.output / "filtered-application-toc.list"),
            "--file", str(schema_dump),
            str(ARCHIVE),
        ], env=self.env, log_path=self.output / "schema-dump.log", timeout=600)
        try:
            sql = schema_dump.read_text(encoding="utf-8", errors="replace")
            inline = 0
            in_create_table = False
            for line in sql.splitlines():
                if re.match(r"(?i)^\s*CREATE TABLE\b", line):
                    in_create_table = True
                elif in_create_table and re.match(r"^[ \t]*CONSTRAINT\b", line, re.I):
                    inline += 1
                elif in_create_table and re.match(r"^\s*\);", line):
                    in_create_table = False
            altered = len(re.findall(r"(?i)\bADD CONSTRAINT\b", sql))
            ddl_count = inline + altered
        finally:
            schema_dump.unlink(missing_ok=True)
        self.report["constraint_ddl_count"] = ddl_count
        self.report["constraint_catalog_count"] = catalog_count
        if ddl_count != catalog_count:
            fail("Constraint DDL count differs from the restored PostgreSQL catalog")

    def run_mutation_hold_tests(self) -> None:
        tests = ROOT / "supabase" / "tests" / "recovery"
        self.stage = "maintenance test fixture setup"
        self.sql_file(tests / "mutation_hold_fixture.sql")
        self.stage = "install reversible maintenance hold"
        self.sql_file(ROOT / "supabase" / "deployment" / "maintenance" / "001_global_mutation_hold.sql")
        self.stage = "maintenance positive and negative authorization tests"
        self.sql_file(tests / "mutation_hold_behavior.sql")
        self.stage = "concurrent maintenance transition test"
        self.verify_concurrent_transition()
        self.stage = "maintenance rollback test"
        self.sql_file(ROOT / "supabase" / "deployment" / "maintenance" / "rollback_global_mutation_hold.sql")
        self.stage = "maintenance test fixture cleanup"
        self.sql_file(tests / "mutation_hold_cleanup.sql")
        self.report["maintenance_authorization_tests"] = "PASS"
        self.report["maintenance_concurrent_write_barrier"] = "PASS"
        self.report["maintenance_rollback"] = "PASS"

    def _super_admin_claims(self) -> str:
        return """
DO $claims$
DECLARE v_actor uuid;
BEGIN
  SELECT u.id INTO v_actor
  FROM auth.users u
  JOIN public.user_roles r ON r.user_id = u.id AND r.role = 'super_admin'
  WHERE u.email_confirmed_at IS NOT NULL AND u.deleted_at IS NULL
    AND (u.banned_until IS NULL OR u.banned_until <= now())
  ORDER BY u.id LIMIT 1;
  IF v_actor IS NULL THEN RAISE EXCEPTION 'usable_super_admin_missing'; END IF;
  PERFORM set_config('request.jwt.claim.sub', v_actor::text, false);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', false);
END
$claims$;
SET ROLE authenticated;
"""

    def verify_concurrent_transition(self) -> None:
        writer_env = self.env.copy()
        writer_env["PGAPPNAME"] = "sai-hold-writer"
        writer = subprocess.Popen(
            [
                self.psql_exe, "--no-psqlrc", "--host", "127.0.0.1", "--port", str(self.port),
                "--username", "postgres", "--dbname", self.database,
                "--set", "ON_ERROR_STOP=1", "--quiet",
            ],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            text=True, encoding="utf-8", errors="replace", env=writer_env,
        )
        writer_input = preflight_sql(self.database, self.data_dir) + """
BEGIN;
INSERT INTO public.sai_mutation_hold_probe(note) VALUES ('concurrent-writer');
SELECT pg_sleep(2.5);
COMMIT;
"""
        if writer.stdin is None:
            fail("Could not start the concurrent mutation test")
        writer.stdin.write(writer_input)
        writer.stdin.close()
        writer.stdin = None
        deadline = time.monotonic() + 10
        active = False
        while time.monotonic() < deadline:
            active = self.psql("""
SELECT count(*) FROM pg_catalog.pg_stat_activity
WHERE application_name = 'sai-hold-writer'
  AND state = 'active' AND query LIKE '%pg_sleep%';
""") == "1"
            if active:
                break
            if writer.poll() is not None:
                break
            time.sleep(0.1)
        if not active:
            writer.terminate()
            writer.communicate(timeout=10)
            fail("Concurrent writer did not reach its transaction hold point")

        started = time.monotonic()
        self.psql(
            self._super_admin_claims()
            + "SELECT public.sai_set_mutation_hold(true, 'concurrent barrier verification');\nRESET ROLE;\n"
        )
        elapsed = time.monotonic() - started
        writer_output = writer.communicate(timeout=10)[0]
        if writer.returncode != 0:
            fail("Concurrent writer transaction failed")
        if elapsed < 1:
            fail("Maintenance activation did not wait for the in-flight write transaction")

        blocked = subprocess.run(
            [
                self.psql_exe, "--no-psqlrc", "--host", "127.0.0.1", "--port", str(self.port),
                "--username", "postgres", "--dbname", self.database,
                "--set", "ON_ERROR_STOP=1", "--quiet",
            ],
            input=preflight_sql(self.database, self.data_dir)
            + "INSERT INTO public.sai_mutation_hold_probe(note) VALUES ('after-concurrent-hold');\n",
            text=True, encoding="utf-8", errors="replace", capture_output=True, env=self.env,
            timeout=30, check=False,
        )
        if blocked.returncode == 0 or "maintenance_mode" not in blocked.stderr:
            fail("A write started after the hold transition was not rejected")
        self.psql(
            self._super_admin_claims()
            + "SELECT public.sai_set_mutation_hold(false, 'concurrent barrier verification complete');\nRESET ROLE;\n"
        )
        self.report["concurrent_transition_wait_seconds"] = round(elapsed, 2)

    def stop_and_cleanup(self) -> None:
        if self.started:
            stopped = subprocess.run(
                [self.pg_ctl, "--pgdata", str(self.data_dir), "--mode", "fast", "--wait", "stop"],
                text=True, encoding="utf-8", errors="replace", capture_output=True,
                env=self.env, timeout=60, check=False,
            )
            status = subprocess.run(
                [self.pg_ctl, "--pgdata", str(self.data_dir), "status"],
                text=True, encoding="utf-8", errors="replace", capture_output=True,
                env=self.env, timeout=30, check=False,
            )
            if status.returncode == 0:
                fail("Disposable PostgreSQL cluster is still running; its data was preserved")
            if stopped.returncode and status.returncode not in {3, 4}:
                fail("Could not verify the disposable PostgreSQL cluster stopped")
        if self.marker.is_file() and self.marker.read_text(encoding="ascii") == self.tag:
            resolved_output = self.output.resolve()
            resolved_data = self.data_dir.resolve()
            if resolved_data.parent != resolved_output or resolved_data.name != "data":
                fail("Disposable cluster cleanup path changed unexpectedly")
            if self.data_dir.exists():
                shutil.rmtree(self.data_dir)

    def execute(self) -> dict[str, object]:
        expected = self.validate_inputs()
        self.initialize()
        self.create_roles_and_database()
        self.restore(expected)
        self.run_mutation_hold_tests()
        self.compare_row_counts(expected, "final")
        self.report["application_data_rows_verified"] = sum(expected.values())
        self.report["schema_data_integrity"] = "PASS"
        self.report["native_database_recovered"] = True
        self.report["managed_components_not_recovered"] = [
            "Supabase Auth, Storage, Realtime and Edge runtimes",
            "managed Cron scheduling and jobs",
            "Vault key material and decrypted-secret service",
            "hosted extensions unavailable in native PostgreSQL",
            "Storage object bytes and external runtime secrets",
        ]
        return self.report


def main() -> int:
    recovery = Recovery()
    exit_code = 0
    try:
        report = recovery.execute()
        report["result"] = "PASS"
    except Exception as error:
        report = recovery.report
        report["result"] = "FAIL"
        report["failure"] = str(error)
        exit_code = 1
    finally:
        try:
            recovery.stop_and_cleanup()
        except Exception as cleanup_error:
            recovery.report["cleanup_failure"] = str(cleanup_error)
            exit_code = 1
    report.update(recovery.report)
    if recovery.output.exists():
        (recovery.output / "recovery-result.json").write_text(
            json.dumps(report, indent=2), encoding="utf-8"
        )
    print(json.dumps(report, indent=2))
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
