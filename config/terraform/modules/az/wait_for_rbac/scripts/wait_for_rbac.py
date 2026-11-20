#!/usr/bin/env python3
"""Poll az until a role assignment is listed on a scope. Create-only."""
import os
import shutil
import subprocess
import sys
import time


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def require_env():
    names = ("scope", "role_definition_name", "object_id", "timeout_seconds", "interval_seconds")
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        fail("missing environment: " + ", ".join(missing))
    return {name: os.environ[name] for name in names}


def az_bin():
    found = shutil.which("az")
    if found:
        return found
    fail("az is not on PATH")


def poll_once(az, env):
    return subprocess.run(
        [
            az, "role", "assignment", "list",
            "--scope", env["scope"],
            "--assignee-object-id", env["object_id"],
            "--role", env["role_definition_name"],
            "--query", "length(@)",
            "-o", "tsv",
        ],
        capture_output=True,
        text=True,
        check=False,
    )


def main():
    env = require_env()
    try:
        timeout = int(env["timeout_seconds"])
        interval = int(env["interval_seconds"])
    except ValueError:
        fail("timeout_seconds and interval_seconds must be integers")
    if timeout <= 0 or interval <= 0:
        fail("timeout_seconds and interval_seconds must be positive")
    az = az_bin()
    deadline = time.monotonic() + timeout
    last_error = "assignment not listed"
    while True:
        proc = poll_once(az, env)
        if proc.returncode == 0:
            count_text = proc.stdout.strip()
            try:
                count = int(count_text or "0")
            except ValueError:
                count = 0
                last_error = f"unexpected az output: {count_text}"
            else:
                if count > 0:
                    print(f"{env['role_definition_name']} for {env['object_id']} listed on scope ({count})")
                    return
                last_error = "assignment not listed"
        else:
            last_error = (proc.stderr or proc.stdout).strip() or f"az exited {proc.returncode}"
        if time.monotonic() >= deadline:
            fail(
                f"{env['role_definition_name']} for {env['object_id']} not listed on {env['scope']} "
                f"within {timeout}s: {last_error}"
            )
        time.sleep(min(interval, max(deadline - time.monotonic(), 0)))


if __name__ == "__main__":
    main()
