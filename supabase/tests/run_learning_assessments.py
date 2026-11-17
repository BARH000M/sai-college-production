"""Run the Phase 4B assessment contract against a disposable native PostgreSQL cluster."""
import os
import pathlib
import socket
import subprocess
import sys
import tempfile

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
    finally:
        if started or (data / "postmaster.pid").exists():
            run("pg_ctl", ["-D", data, "-m", "fast", "-w", "stop"], out, capture=False)

print("PASS: isolated learning assessment workflow, roles, answer-key protection and released results")
