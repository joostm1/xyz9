#!/usr/bin/env python3
"""Create Compose inputs under .generated before Terraform plans.

docker_compose hashes config_paths and env_files during plan. Those paths are
gitignored, so a fresh checkout does not have them. Compose JSON comes from
the query. Secret file bodies are read from Key Vault here so the query, which
Terraform stores in state, keeps only secret names.
"""
import json
import os
import subprocess
import sys


def write_file(directory, relative, content, mode=None):
    path = os.path.join(directory, relative)
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(content)
    if mode is not None:
        os.chmod(path, mode)


def vault_secret(vault_name, secret_name):
    raw = subprocess.check_output(
        [
            "az",
            "keyvault",
            "secret",
            "show",
            "--vault-name",
            vault_name,
            "--name",
            secret_name,
            "-o",
            "json",
        ],
        text=True,
    )
    return json.loads(raw)["value"]


def main():
    query = json.load(sys.stdin)
    compose_dir = query["compose_dir"]
    secrets_dir = query["secrets_dir"]
    os.makedirs(compose_dir, exist_ok=True)
    os.makedirs(secrets_dir, exist_ok=True)
    for name, content in json.loads(query["compose"]).items():
        write_file(compose_dir, name, content, 0o644)
    for dest, secret_name in json.loads(query["secrets"]).items():
        write_file(secrets_dir, dest, vault_secret(query["vault_name"], secret_name), 0o600)
    json.dump({"compose_dir": compose_dir, "secrets_dir": secrets_dir}, sys.stdout)


if __name__ == "__main__":
    main()
