#!/usr/bin/env python3
"""Read cert_pem and key_pem on stdin and write a base64 PKCS#12 on stdout.

The azurerm and azuread client_certificate arguments decode that base64 as PKCS#12.
OpenSSL 3 is told to use the legacy ciphers Go's pkcs12 parser accepts.
"""
import base64
import json
import subprocess
import sys
import tempfile
from pathlib import Path

query = json.load(sys.stdin)
with tempfile.TemporaryDirectory() as tmp:
    directory = Path(tmp)
    cert_path = directory / "cert.pem"
    key_path = directory / "key.pem"
    out_path = directory / "out.p12"
    cert_path.write_text(query["cert_pem"])
    key_path.write_text(query["key_pem"])
    subprocess.run(
        [
            "openssl", "pkcs12", "-export", "-legacy",
            "-inkey", str(key_path),
            "-in", str(cert_path),
            "-out", str(out_path),
            "-passout", "pass:",
        ],
        check=True,
        capture_output=True,
    )
    encoded = base64.b64encode(out_path.read_bytes()).decode()
json.dump({"p12_b64": encoded}, sys.stdout)
