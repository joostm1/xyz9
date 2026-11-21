#!/usr/bin/env python3
# /// script
# dependencies = [
#   "cryptography==46.0.5",
#   "msal==1.33.0",
# ]
# ///
import base64
import hashlib
import json
import sys
import time

try:
    import msal
except ImportError:
    msal = None

try:
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.serialization import pkcs12
except ImportError:
    pkcs12 = None
    serialization = None


def fail(message):
    print(json.dumps({"error": message}), file=sys.stderr)
    sys.exit(1)


def extract_p12_material(p12_bundle, p12_password):
    if pkcs12 is None:
        fail("python package 'cryptography' is required when p12_bundle is used")

    try:
        p12_bytes = base64.b64decode(p12_bundle, validate=True)
    except ValueError as exc:
        fail(f"p12_bundle must be base64 encoded: {exc}")

    password = p12_password.encode("utf-8") if p12_password else None

    try:
        private_key, certificate, _additional_certificates = pkcs12.load_key_and_certificates(
            p12_bytes,
            password,
        )
    except ValueError as exc:
        fail(f"failed to load p12_bundle: {exc}")

    if private_key is None:
        fail("p12_bundle does not contain a private key")
    if certificate is None:
        fail("p12_bundle does not contain a client certificate")

    key_pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    ).decode("utf-8")

    cert_der = certificate.public_bytes(serialization.Encoding.DER)
    thumbprint = hashlib.sha1(cert_der).hexdigest()
    return key_pem, thumbprint


def build_certificate_credential(p12_bundle, p12_password):
    key_pem, thumbprint = extract_p12_material(p12_bundle, p12_password)
    return {
        "private_key": key_pem,
        "thumbprint": thumbprint,
    }


def authority_from_token_endpoint(token_endpoint):
    suffix = "/oauth2/v2.0/token"
    if token_endpoint.endswith(suffix):
        return token_endpoint[: -len(suffix)]
    fail("token_endpoint must end with /oauth2/v2.0/token when using MSAL")


def main():
    if msal is None:
        fail("python package 'msal' is required")

    query = json.load(sys.stdin)
    token_endpoint = query.get("token_endpoint", "")
    client_id = query.get("client_id", "")
    scopes = query.get("scopes", "")
    client_credential = query.get("client_credential", "")
    p12_bundle = query.get("p12_bundle", "")
    p12_password = query.get("p12_password", "")

    if not token_endpoint:
        fail("token_endpoint is required")
    if not client_id:
        fail("client_id is required")
    if not scopes:
        fail("scopes is required")
    if bool(client_credential) == bool(p12_bundle):
        fail("set exactly one of client_credential or p12_bundle")

    if client_credential:
        credential = client_credential
    else:
        credential = build_certificate_credential(p12_bundle, p12_password)

    app = msal.ConfidentialClientApplication(
        client_id=client_id,
        authority=authority_from_token_endpoint(token_endpoint),
        client_credential=credential,
    )

    token = app.acquire_token_for_client(scopes=scopes.split())
    access_token = token.get("access_token")
    if not access_token:
        error = token.get("error") or "token acquisition failed"
        description = token.get("error_description") or json.dumps(token)
        fail(f"{error}: {description}")

    expires_in = int(token.get("expires_in", 0))
    print(json.dumps({
        "access_token": access_token,
        "expires_on": str(int(time.time()) + expires_in),
        "token_type": token.get("token_type", "Bearer"),
    }))


if __name__ == "__main__":
    main()
