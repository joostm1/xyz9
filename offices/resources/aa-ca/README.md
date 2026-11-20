# aa-ca

Org CA key, self-signed certificate, and Key Vault certificate `xyz9-ca`.

Subject, lifetime, and the Key Vault object name (`vault_name`) come from `org/org.json` `about.x509`.

The issued certificate has no subject key id, authority key id, or path-length constraint. Setting those replaces `xyz9-ca`.

State is container `offices`, key `aa-ca.tfstate`. `resources/Makefile` applies this root before `aa-config`.
