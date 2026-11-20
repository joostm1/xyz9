#!/usr/bin/env python3
"""Upload OPI vital state to Azure Blob. The manifest next to this file is the catalog."""
import base64
import json
import os
import platform
import shutil
import sqlite3
import stat
import subprocess
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
ARCH = {"aarch64": "arm64", "x86_64": "amd64"}


def read_text(path):
    return Path(path).read_text().strip()


def azcopy(args, env, check=True):
    return subprocess.run(
        ["azcopy", "--skip-version-check", *args],
        env=env,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def ensure_azcopy(version, env):
    dest = Path("/usr/local/bin/azcopy")
    if dest.is_file() and os.access(dest, os.X_OK):
        return
    arch = ARCH.get(platform.machine())
    if arch is None:
        raise RuntimeError(f"no azcopy build for {platform.machine()}")
    tmp = Path(tempfile.mkdtemp(prefix="azcopy-"))
    try:
        tarball = tmp / "azcopy.tar.gz"
        url = (
            "https://github.com/Azure/azure-storage-azcopy/releases/download/"
            f"v{version}/azcopy_linux_{arch}_{version}.tar.gz"
        )
        subprocess.run(["curl", "-fsSL", "-o", str(tarball), url], check=True)
        subprocess.run(["tar", "-xzf", str(tarball), "-C", str(tmp)], check=True)
        binary = next(tmp.rglob("azcopy"))
        shutil.copy(binary, dest)
        dest.chmod(0o755)
    finally:
        shutil.rmtree(tmp)


def backup_sqlite(src, dst):
    source = sqlite3.connect(src)
    try:
        dest = sqlite3.connect(dst)
        try:
            source.backup(dest)
        finally:
            dest.close()
    finally:
        source.close()


def snapshot_sqlite(staged_root, original_root):
    for dirpath, _, filenames in os.walk(staged_root):
        for fn in filenames:
            if not fn.endswith((".sqlite", ".sqlite3", ".db")):
                continue
            staged = Path(dirpath) / fn
            rel = staged.relative_to(staged_root)
            original = Path(original_root) / rel
            tmp = staged.with_name(staged.name + ".consistent")
            try:
                backup_sqlite(original, tmp)
            except sqlite3.DatabaseError:
                tmp.unlink(missing_ok=True)
                continue
            st = original.stat()
            os.chown(tmp, st.st_uid, st.st_gid)
            os.chmod(tmp, stat.S_IMODE(st.st_mode))
            os.replace(tmp, staged)
            for suffix in ("-wal", "-shm"):
                side = staged.with_name(staged.name + suffix)
                side.unlink(missing_ok=True)


def stage_tree(src, stage_root, excludes):
    src = Path(src)
    cmd = ["tar", "-C", str(src.parent), "--exclude=*.sock", "-cf", "-"]
    cmd += [f"--exclude={item}" for item in excludes]
    cmd.append(src.name)
    extract = subprocess.Popen(["tar", "-C", stage_root, "-xf", "-"], stdin=subprocess.PIPE)
    packed = subprocess.Popen(cmd, stdout=extract.stdin)
    if packed.wait() != 0:
        extract.kill()
        raise RuntimeError(f"could not stage {src}")
    extract.stdin.close() # packed kept this open; close the parent copy so extract sees EOF
    if extract.wait() != 0:
        raise RuntimeError(f"could not stage {src}")
    return Path(stage_root) / src.name


def tar_tree(src, dest, excludes):
    src = Path(src)
    cmd = ["tar", "-C", str(src.parent), "--numeric-owner", "--exclude=*.sock", "-czf", str(dest)]
    cmd += [f"--exclude={item}" for item in excludes]
    cmd.append(src.name)
    subprocess.run(cmd, check=True)


def archive_files(target, dest):
    path = Path(target["path"])
    if not path.is_dir():
        raise RuntimeError(f"missing {path}")
    excludes = target.get("exclude") or []
    if target["method"] in ("sqlite_file_backup", "bitwarden_encrypted_json"):
        stage = tempfile.mkdtemp(prefix="opi-backup-")
        try:
            staged = stage_tree(path, stage, excludes)
            snapshot_sqlite(staged, path)
            tar_tree(staged, dest, [])
        finally:
            shutil.rmtree(stage)
        return
    tar_tree(path, dest, excludes)


def archive_postgres(target, dest):
    container = target.get("container")
    user = target.get("user")
    if not container or not user:
        raise RuntimeError("pg_dump target needs container and user")
    err_path = Path(str(dest) + ".err")
    with open(err_path, "wb") as err_handle:
        dump = subprocess.Popen(
            ["docker", "exec", container, "pg_dumpall", "-U", user],
            stdout=subprocess.PIPE,
            stderr=err_handle,
        )
        with open(dest, "wb") as handle:
            gzip = subprocess.Popen(["gzip", "-c"], stdin=subprocess.PIPE, stdout=handle)
            assert dump.stdout is not None
            shutil.copyfileobj(dump.stdout, gzip.stdin)
            dump.stdout.close()
            gzip.stdin.close()
            gzip_rc = gzip.wait()
        dump_rc = dump.wait()
    if dump_rc != 0 or gzip_rc != 0:
        err = err_path.read_text(errors="replace").strip().splitlines()
        raise RuntimeError(err[-1] if err else "pg_dumpall failed")


def export_vaultwarden(export, dest, env_base):
    env = env_base.copy()
    env["BW_CLIENTID"] = read_text(ROOT / export["client_id_file"])
    env["BW_CLIENTSECRET"] = read_text(ROOT / export["client_secret_file"])
    env["PATH"] = "/usr/local/bin:/usr/bin:/bin"
    def bw(args, required=True, **kwargs):
        proc = subprocess.run(["bw", *args], env=env, text=True, **kwargs)
        if required and proc.returncode != 0:
            detail = (proc.stderr or "").strip().splitlines()
            raise RuntimeError(detail[-1] if detail else f"bw {args[0]} failed")
        return proc
    bw(["logout"], required=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    bw(["config", "server", export["server"]], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    bw(["login", "--apikey"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    unlocked = bw(
        ["unlock", "--passwordfile", str(ROOT / export["master_password_file"]), "--raw"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    env["BW_SESSION"] = unlocked.stdout.strip()
    try:
        bw(["sync"], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        password = read_text(ROOT / export["export_password_file"])
        exported = subprocess.run(
            ["bw", "export", "--format", "encrypted_json", "--password", password, "--output", str(dest)],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
        )
        if exported.returncode != 0:
            detail = (exported.stderr or "").strip().splitlines()
            raise RuntimeError(detail[-1] if detail else "bw export failed")
    finally:
        subprocess.run(["bw", "lock"], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def upload(local, blob, manifest, env):
    url = f"https://{manifest['account']}.blob.core.windows.net/{manifest['container']}/{blob}"
    last = "upload failed"
    for attempt in range(1, 13):
        proc = azcopy(["copy", str(local), url, "--overwrite=true"], env, check=False)
        if proc.returncode == 0:
            print(f"uploaded {blob} ({Path(local).stat().st_size} bytes)", flush=True)
            return
        lines = (proc.stdout or "").strip().splitlines()
        last = lines[-1] if lines else f"exit {proc.returncode}"
        print(f"upload {blob} attempt {attempt} failed: {last}", flush=True)
        if "Auto-login" in last or "pkcs12" in last:
            break
        time.sleep(15)
    raise RuntimeError(f"upload {blob} failed: {last}")


def expire(manifest, env, today):
    cutoff = (datetime.now(timezone.utc) - timedelta(days=manifest["retain_days"])).strftime("%Y-%m-%dT%H:%M:%SZ")
    url = f"https://{manifest['account']}.blob.core.windows.net/{manifest['container']}"
    dry = azcopy(["remove", url, "--recursive=true", "--include-before", cutoff, "--dry-run"], env, check=False)
    text = dry.stdout or ""
    if dry.returncode != 0:
        lines = text.strip().splitlines()
        raise RuntimeError(lines[-1] if lines else "retention dry-run failed")
    hits = [ln for ln in text.splitlines() if today in ln and "INFO:" not in ln]
    if hits:
        raise RuntimeError("retention dry-run matched today's backup; not deleting")
    azcopy(["remove", url, "--recursive=true", "--include-before", cutoff], env)


def auth_env(manifest, work):
    pfx = Path(work) / "writer.pfx"
    pfx.write_bytes(base64.b64decode(read_text(ROOT / "writer.pfx.b64")))
    os.chmod(pfx, 0o600)
    env = os.environ.copy()
    env.update({
        "AZCOPY_AUTO_LOGIN_TYPE": "SPN",
        "AZCOPY_SPA_APPLICATION_ID": manifest["client_id"],
        "AZCOPY_TENANT_ID": manifest["tenant_id"],
        "AZCOPY_SPA_CERT_PATH": str(pfx),
        "AZCOPY_SPA_CERT_PASSWORD": read_text(ROOT / "writer.pfx.pass"),
        "AZCOPY_LOG_LOCATION": str(Path(work) / "azcopy-log"),
        "AZCOPY_DISABLE_SYSLOG": "true",
    })
    return env


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    work = tempfile.mkdtemp(prefix="opi-backup-")
    errors = []
    uploaded = []
    try:
        env = auth_env(manifest, work)
        ensure_azcopy(manifest["azcopy_version"], env)
        export = manifest.get("vaultwarden_export")
        if export:
            blob = f"vaultwarden/{today}.json"
            dest = Path(work) / "vaultwarden.json"
            try:
                export_vaultwarden(export, dest, env)
                upload(dest, blob, manifest, env)
                uploaded.append(blob)
            except (OSError, RuntimeError) as exc:
                errors.append(f"vaultwarden export: {exc}")
        for target in manifest["targets"]:
            name = target["name"]
            suffix = "sql.gz" if target["method"] == "pg_dump" else "tar.gz"
            blob = f"{name}/{today}.{suffix}"
            dest = Path(work) / f"{name}.{suffix}"
            try:
                if target["method"] == "pg_dump":
                    archive_postgres(target, dest)
                elif target["method"] in ("file_backup", "application_backup", "sqlite_file_backup", "bitwarden_encrypted_json"):
                    archive_files(target, dest)
                else:
                    raise RuntimeError(f"unknown method {target['method']}")
                upload(dest, blob, manifest, env)
                uploaded.append(blob)
            except (subprocess.CalledProcessError, RuntimeError, OSError) as exc:
                errors.append(f"{name}: {exc}")
        if errors:
            raise SystemExit("\n".join(errors))
        status = Path(work) / "status.json"
        status.write_text(json.dumps({"date": today, "uploaded": uploaded}) + "\n")
        upload(status, f"status/{today}.json", manifest, env)
        expire(manifest, env, today)
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
