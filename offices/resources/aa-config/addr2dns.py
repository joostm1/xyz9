#!/usr/bin/env python3
"""Collect sp1 host addresses and return Terraform external-data DNS records.

The Terraform Cloudflare resources are the controller. This script only observes
live addresses on egx and opi and converts them to desired DNS record data.
"""

import base64
import ipaddress
import json
import subprocess
import sys
import tempfile
from pathlib import Path


def fail(message):
    # Terraform's external data source expects JSON on stdout, even on failure.
    print(json.dumps({"error": message}))
    sys.exit(1)


def normalize_private_key(value):
    # Key Vault values commonly arrive with literal "\n" sequences.
    return value.replace("\\n", "\n").strip() + "\n"


def run_ssh(key_path, user, host, command):
    # Use a temporary identity file instead of ssh-agent so Terraform runs are self-contained.
    result = subprocess.run(
        [
            "ssh",
            "-i",
            str(key_path),
            "-o",
            "BatchMode=yes",
            "-o",
            "IdentitiesOnly=yes",
            f"{user}@{host}",
            command,
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        fail(f"ssh {host!r} failed: {result.stderr.strip() or result.stdout.strip()}")
    return result.stdout


def ip_kind(value):
    ip = ipaddress.ip_address(value)
    # Skip addresses that should never become public DNS records.
    if ip.is_loopback or ip.is_link_local or ip.is_unspecified or ip.is_multicast:
        return None
    scope = "private" if ip.is_private else "public"
    family = "ipv4" if ip.version == 4 else "ipv6"
    rtype = "A" if ip.version == 4 else "AAAA"
    return scope, family, rtype


def parse_edgeos_interfaces(output):
    # Objective: output DNS records for EdgeRouter interfaces.
    #
    # 'show interfaces':
    # Codes: S - State, L - Link, u - Up, D - Down, A - Admin Down
    # Interface    IP Address                        S/L  Description
    # ---------    ----------                        ---  -----------
    # eth0         -                                 u/u  wan
    # eth0.6       -                                 u/u  kpn wan
    # eth1         172.17.114.4/24                   u/u  lan
    #              2a02:a472:8101:1::1/64
    #              fd17:114::4/64
    # lo           127.0.0.1/8                       u/u
    #              ::1/128
    # pppoe0       86.80.44.142                      u/u
    addresses = []
    in_table = False

    # Loop through the interface table and ignore the header/separator lines.
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("Interface") and "IP Address" in line:
            in_table = True
            continue
        if not in_table or line.startswith("--------"):
            continue

        words = line.split()
        if len(words) >= 3:
            # Interface row. Description is optional and can contain multiple words.
            address = words[1]
        elif len(words) == 1:
            # Continuation row for interfaces with multiple addresses.
            address = words[0]
        else:
            continue

        if address == "-":
            continue
        # Remove the optional netmask from the IP address.
        address = address.split("/", 1)[0]
        try:
            if ip_kind(address):
                addresses.append(address)
        except ValueError:
            continue

    return addresses


def parse_linux_ip_json(output):
    # OPI has a real Linux network stack. Use `ip -json` instead of scraping text.
    start = output.find("[")
    if start < 0:
        fail("opi ip command did not return JSON")

    data = json.loads(output[start:])
    addresses = []
    for iface in data:
        for addr in iface.get("addr_info", []):
            family = addr.get("family")
            if family not in {"inet", "inet6"}:
                continue
            address = addr.get("local")
            if not address:
                continue
            try:
                if ip_kind(address):
                    addresses.append(address)
            except ValueError:
                continue
    return addresses


def add_record(records, key, name, rtype, content, source):
    records[key] = {
        "name": name,
        "type": rtype,
        "content": content,
        "source": source,
    }


def add_host_records(records, host_name, addresses, source, aliases):
    for address in addresses:
        kind = ip_kind(address)
        if not kind:
            continue

        scope, family, rtype = kind
        prefix = host_name if scope == "public" else f"{host_name}-private"
        versioned_name = f"{prefix}-{family}"

        # Create both versioned records (egx-ipv4) and versionless records (egx).
        # The `-versionless` suffix preserves old Terraform for_each keys for egx.
        add_record(records, versioned_name, versioned_name, rtype, address, source)
        add_record(records, f"{versioned_name}-versionless", prefix, rtype, address, source)

        # Service aliases deliberately choose their source by host/scope/family.
        # Example: postgres A follows egx public IPv4, while postgres AAAA follows opi public IPv6.
        alias_key = f"{source}_{scope}_{family}"
        for alias in aliases.get(alias_key, []):
            add_record(records, f"{alias}-{family}", alias, rtype, address, source)


def main():
    # Read JSON input from Terraform's external data source on stdin.
    query = json.load(sys.stdin)

    required = ["admin_user", "admin_pk", "egx_host", "opi_host", "opi_iface", "aliases_json"]
    missing = [key for key in required if not query.get(key)]
    if missing:
        fail(f"missing query values: {', '.join(missing)}")

    aliases = json.loads(query["aliases_json"])

    with tempfile.TemporaryDirectory() as tmpdir:
        key_path = Path(tmpdir) / "ssh_key"
        key_path.write_text(normalize_private_key(query["admin_pk"]), encoding="utf-8")
        key_path.chmod(0o600)

        # Collect current addresses from both machines. Terraform will decide what to create/update.
        egx_output = run_ssh(
            key_path,
            query["admin_user"],
            query["egx_host"],
            "vbash -ic 'show interfaces'",
        )
        opi_output = run_ssh(
            key_path,
            query["admin_user"],
            query["opi_host"],
            f"ip -json address show {query['opi_iface']}",
        )

    records = {}
    add_host_records(records, "egx", parse_edgeos_interfaces(egx_output), "egx", aliases)
    add_host_records(records, "opi", parse_linux_ip_json(opi_output), "opi", aliases)

    encoded_records = base64.b64encode(
        json.dumps(records, sort_keys=True).encode("utf-8")
    ).decode("ascii")
    # Return base64 JSON to avoid Terraform external-provider string escaping issues.
    print(json.dumps({"records_base64": encoded_records}))


if __name__ == "__main__":
    main()
