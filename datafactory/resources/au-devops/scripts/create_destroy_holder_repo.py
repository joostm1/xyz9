#!/usr/bin/env python3
"""Create the ADO destroy-holder git repo. Create-only: no delete path."""
import json
import os
import shutil
import subprocess
import sys
import urllib.error
import urllib.request

ADO_RESOURCE = "499b84ac-1321-427f-aa17-267ca6975798"
SUCCESS = {200, 201, 409}


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def require_env():
    missing = [name for name in ("org_url", "project_id", "repo_name") if not os.environ.get(name)]
    if missing:
        fail("missing environment: " + ", ".join(missing))
    return {name: os.environ[name] for name in ("org_url", "project_id", "repo_name")}


def az_bin():
    found = shutil.which("az")
    if found:
        return found
    fail("az is not on PATH")


def access_token():
    # azuredevops provider use_cli defaults to true, so apply runs as this login.
    # The owner app is in the org and can see no projects, which is the VS800075 404.
    proc = subprocess.run(
        [az_bin(), "account", "get-access-token", "--resource", ADO_RESOURCE, "--query", "accessToken", "-o", "tsv"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        fail(proc.stderr.strip() or "az account get-access-token failed")
    token = proc.stdout.strip()
    if not token:
        fail("az account get-access-token returned an empty token")
    return token


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # urllib would turn this POST into a GET and drop the body
        raise urllib.error.HTTPError(req.full_url, code, msg, headers, fp)


def create_repo(env, token):
    url = f"{env['org_url'].rstrip('/')}/{env['project_id']}/_apis/git/repositories?api-version=7.1"
    request = urllib.request.Request(
        url,
        data=json.dumps({"name": env["repo_name"]}).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            # same header the azuredevops provider sets; without it ADO redirects and the caller looks anonymous
            "X-TFS-FedAuthRedirect": "Suppress",
        },
        method="POST",
    )
    opener = urllib.request.build_opener(NoRedirect)
    try:
        with opener.open(request) as response:
            return response.status
    except urllib.error.HTTPError as exc:
        if exc.code in SUCCESS:
            return exc.code
        body = exc.read().decode("utf-8", errors="replace")
        fail(f"POST {url} returned {exc.code}: {body}")


def main():
    env = require_env()
    status = create_repo(env, access_token())
    print(f"{env['repo_name']} ready ({status})")


if __name__ == "__main__":
    main()
