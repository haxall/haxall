# Know Crypto

The crypto ext manages TLS certificates and keys in one keystore.
Most user problems are one of four workflows: trust a self-signed
server, install a client cert, configure the HTTPS server cert, or
figure out why a connection fails TLS. All crypto funcs require su.

# Fixing TLS Errors

When a connector or ioHttp call fails with a certificate error
(unable to find valid certification path, handshake failure,
self-signed certificate), the remote cert is not trusted. Fix:

```axon
// 1. preview the remote certificate chain (imports nothing)
cryptoCheckUri(`https://device.local:443`)

// 2. trust it
cryptoTrustUri({alias:"device-local", uri:`https://device.local:443`})

// 3. re-open the connection - existing sockets keep the old trust
connClose(conn)
connPing(conn)
```

Step 3 matters: new trust entries apply only to sockets opened
afterward. Close/reopen the conn, or restart the runtime for
non-conn clients.

# The Keystore

One PKCS12 file at `var/crypto/keystore.p12` holds both trusted
certs and private key bundles (a backup is kept alongside). Entries
are keyed by alias. Reserved aliases - never rename or delete:

- `https`: the web server's certificate (see below)
- `host`: auto-generated self-signed identity for the runtime
- `jvm$...`: certs auto-synced from the JVM trust store at startup

The keystore is wired in as the default trust store for all
outbound TLS in the runtime, layered on top of the JVM defaults.

# Inspecting

```axon
cryptoReadAllKeys()   // grid of all entries
```

Key columns: `alias`, `trusted` (public cert only) vs `bundle`
(includes private key), `ca`, `selfSigned`, `subject`, `issuer`,
`notBefore`/`notAfter` (check for expirations), `keyAlg`/`keySize`.
Export an entry's public cert as PEM with `cryptoShowPub(alias)`.

# Trusting Certificates

`cryptoTrustUri` fetches the server's chain, sorts it root to
end-entity, and stores each cert as `alias`, `alias.1`, ... Only CA
and self-signed certs are added to the trust store. If the alias
already exists, delete it first with `cryptoEntryDelete`.

To trust a cert you have as a PEM file instead:

```axon
cryptoAddCert("acme-ca", ioReadStr(`io/acme-ca.pem`))
```

A PEM with a single certificate and no private key becomes a trust
entry.

# Client Certificates (Mutual TLS)

Combine the private key and full cert chain into one PEM and add it
as a bundle:

```axon
pem: ioReadStr(`io/client.key.pem`) + ioReadStr(`io/client.cert.pem`)
cryptoAddCert("mqtt-client", pem)
```

Rules: the PEM must contain exactly one private key plus its cert
chain; a key without certs or multiple certs without a key throws.
Use `force:true` to overwrite an existing alias. Connectors
reference the bundle by alias, e.g. the MQTT connector's
`mqttCertAlias: "mqtt-client"` tag.

# HTTPS Server Certificate

The web server uses the entry aliased exactly `https`, which must
be a bundle (private key + chain). Import it, enable HTTPS on the
http ext settings (`httpsEnabled`, `httpsPort`), and restart:

```axon
cryptoAddCert("https", ioReadStr(`io/server.pem`), true)
```

If no valid `https` bundle exists, HTTPS is disabled at startup
with a log error. When HTTPS is enabled, HTTP redirects to HTTPS.

# Self-Signed Certificates

```axon
cryptoGenSelfSignedCert("test-server", "cn=host.example.com,o=Acme")
cryptoGenSelfSignedCert("https", "cn=myhost", {notAfter: today()+730day})
```

Generates an RSA 2048 key and self-signed cert (default validity
365 days) stored as a bundle.

# Managing Entries

```axon
cryptoEntryDelete("old-alias")               // also accepts a list
cryptoEntryRename({id:@alias-id, alias:"new-name"})
cryptoEntryRename({id:@alias-id, alias:"copy", keep})
```

# CLI Tool

Before the runtime is running (bootstrap, offline installs), use
the `hx crypto` command against the install dir:

```
hx crypto list -d /path/to/var
hx crypto add -d /path/to/var -alias https -priv key.pem -certs chain.pem
hx crypto add -d /path/to/var -import keystore.p12 -pass secret
hx crypto trust -d /path/to/var -uri https://device.local
hx crypto export / remove / rename
```

Import accepts p12/pfx/jks/fks keystores and PEM files.

# Style Notes

- Always cryptoCheckUri before cryptoTrustUri to see what you are
  about to trust
- After trusting, re-open the affected conns; after changing the
  `https` entry, restart the runtime
- Watch `notAfter` dates - expired certs produce the same errors as
  untrusted ones
- The keystore password is fixed; file system permissions on
  var/crypto are the real protection
