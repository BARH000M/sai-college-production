"""Run the Phase 4B assessment contract against a disposable native PostgreSQL cluster."""
import os
import pathlib
import socket
import subprocess
import sys
import tempfile
import time

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")

root = pathlib.Path(__file__).resolve().parents[2]
bin_dir = pathlib.Path(os.environ.get("SAI_PG_BIN", r"C:\Program Files\PostgreSQL\17\bin"))
env = {key: value for key, value in os.environ.items()
       if not key.upper().startswith(("PG", "SUPABASE"))}


def run(
    executable: str,
    args: list[object],
    cwd: pathlib.Path,
    timeout: int = 120,
    capture: bool = True,
) -> None:
    command = [str(bin_dir / f"{executable}.exe"), *map(str, args)]
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            env=env,
            capture_output=capture,
            text=capture,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as failure:
        stdout = (
            failure.stdout.decode(errors="replace")
            if isinstance(failure.stdout, bytes) else failure.stdout
        )
        stderr = (
            failure.stderr.decode(errors="replace")
            if isinstance(failure.stderr, bytes) else failure.stderr
        )
        raise RuntimeError(
            f"{executable} timed out after {timeout}s:\n{stdout or ''}\n{stderr or ''}"
        ) from failure
    if result.returncode:
        raise RuntimeError(
            f"{executable} exited {result.returncode}:"
            + (f"\n{result.stdout}\n{result.stderr}" if capture else "")
        )


def check_concurrent_attempt(connection: list[object], cwd: pathlib.Path) -> None:
    setup = """
      set role authenticated;
      select public.as_user('00000000-0000-0000-0000-000000000101');
      insert into public.learning_assessments (id,course_id,lesson_id,title,attempt_limit)
      values ('00000000-0000-0000-0000-000000000709',
        '00000000-0000-0000-0000-000000000401','00000000-0000-0000-0000-000000000501',
        'Concurrent assessment',1);
      insert into public.learning_exercise_questions
        (lesson_id,kind,prompt,choices,correct_choice,assessment_id)
      values ('00000000-0000-0000-0000-000000000501','multiple_choice','First question',
        '["A","B"]',0,'00000000-0000-0000-0000-000000000709');
      update public.learning_assessments set status='published'
        where id='00000000-0000-0000-0000-000000000709';
    """
    run("psql", [*connection, "-c", setup], cwd)
    psql = str(bin_dir / "psql.exe")
    args = [psql, *map(str, connection), "-v", "VERBOSITY=verbose"]
    first = subprocess.Popen(
        args, cwd=cwd, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, text=True, encoding="utf-8",
    )
    try:
        if first.stdin is None:
            raise RuntimeError("Attempt session stdin is unavailable")
        first.stdin.write("""
          begin;
          set local role authenticated;
          select public.as_user('00000000-0000-0000-0000-000000000102');
          select public.sai_learning_assessment_start('00000000-0000-0000-0000-000000000709');
          select pg_advisory_xact_lock(88300,7);
          select pg_sleep(5);
          commit;
        """)
        first.stdin.close()
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            held = subprocess.check_output(
                [*args, "-At", "-c",
                 "select count(*) from pg_locks where locktype='advisory' "
                 "and classid=88300 and objid=7 and granted"],
                cwd=cwd, env=env, text=True, timeout=15,
            ).strip()
            if held == "1":
                break
            if first.poll() is not None:
                raise RuntimeError("Attempt session exited before acquiring its test lock")
            time.sleep(0.05)
        else:
            raise RuntimeError("Attempt session did not acquire its test lock")
        second_env = {**env, "PGAPPNAME": "sai-assessment-race"}
        second = subprocess.Popen(
            args, cwd=cwd, env=second_env, text=True, encoding="utf-8",
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        try:
            if second.stdin is None:
                raise RuntimeError("Question session stdin is unavailable")
            second.stdin.write("""
              set role authenticated;
              select public.as_user('00000000-0000-0000-0000-000000000101');
              insert into public.learning_exercise_questions
                (lesson_id,kind,prompt,choices,correct_choice,assessment_id)
              values ('00000000-0000-0000-0000-000000000501','multiple_choice',
                'Late concurrent question','["A","B"]',0,'00000000-0000-0000-0000-000000000709');
            """)
            second.stdin.close()
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                waiting = subprocess.check_output(
                    [*args, "-At", "-c",
                     "select count(*) from pg_stat_activity "
                     "where application_name='sai-assessment-race' and wait_event_type='Lock'"],
                    cwd=cwd, env=env, text=True, timeout=15,
                ).strip()
                if waiting == "1":
                    break
                if second.poll() is not None:
                    raise RuntimeError("Question insert did not wait for the active attempt")
                time.sleep(0.05)
            else:
                raise RuntimeError("Question insert never waited for the active attempt")
        finally:
            second.wait(timeout=15)
        if second.stderr is None:
            raise RuntimeError("Question session stderr is unavailable")
        second_error = second.stderr.read()
        if second.returncode == 0 or "23514" not in second_error:
            raise RuntimeError(f"Concurrent question insert was not rejected:\n{second_error}")
    finally:
        first.wait(timeout=15)
    if first.stdout is None or first.stderr is None:
        raise RuntimeError("Attempt session output is unavailable")
    if first.returncode:
        raise RuntimeError(f"Concurrent attempt failed:\n{first.stdout.read()}\n{first.stderr.read()}")
    print("PASS: concurrent question changes cannot race assessment start")


with tempfile.TemporaryDirectory(prefix="sai-learning-assessments-") as temporary:
    out = pathlib.Path(temporary)
    data = out / "pgdata"
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    run("initdb", ["-D", data, "-U", "assessment_test", "--auth=trust",
                   "--no-locale", "--encoding=UTF8"], out)
    with (data / "postgresql.conf").open("a", encoding="utf-8") as config:
        config.write(
            f"\nlisten_addresses='127.0.0.1'\nport={port}\nshared_preload_libraries=''\n"
            "log_statement='all'\n"
        )
    started = False
    try:
        try:
            run("pg_ctl", ["-D", data, "-l", out / "server.log", "-w", "start"],
                out, capture=False)
        except RuntimeError:
            server_log = out / "server.log"
            if server_log.exists():
                print(f"PostgreSQL server log:\n{server_log.read_text(encoding='utf-8')}")
            raise
        started = True
        connection = ["-h", "127.0.0.1", "-p", str(port), "-U", "assessment_test",
                      "-d", "postgres", "-w", "-X", "-v", "ON_ERROR_STOP=1"]
        actual = subprocess.check_output(
            [str(bin_dir / "psql.exe"), *connection, "-At", "-c", "SHOW data_directory"],
            cwd=out,
            env=env,
            text=True,
            timeout=15,
        ).strip()
        if pathlib.Path(actual).resolve() != data.resolve():
            raise RuntimeError(f"Connected to unexpected PostgreSQL data directory: {actual}")
        run("psql", [*connection, "-c", "SET statement_timeout='30s'",
                     "-f", root / "supabase/tests/learning_assessments_behavior.sql"],
            out, timeout=45)
        check_concurrent_attempt(connection, out)
    finally:
        if started or (data / "postmaster.pid").exists():
            run("pg_ctl", ["-D", data, "-m", "fast", "-w", "stop"], out, capture=False)

print("PASS: isolated learning assessment workflow, roles, answer-key protection and released results")
