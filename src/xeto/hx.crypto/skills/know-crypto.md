# Know Crypto

The crypto ext manages TLS certificates and keys in one keystore.
Most user problems are one of four workflows: trust a self-signed
server, install a client cert, configure the HTTPS server cert, or
figure out why a connection fails TLS. All crypto funcs require su.

# Fixing TLS Errors

During a TLS handshake the client performs three checks. Understanding
which one failed determines the fix.

1. **Name check** — The URI/IP must match one of the certificates
   Subject Alternative Names. A mismatch cannot be fixed by trusting so
   the TLS client must be configured to use an address in the certificate.
2. **Chain-to-root check** — The server's certificate chain must reach a root
   CA in the keystore trust store. Fix by trusting the chain.
3. **Date validity check** — Every certificate in the chain must be within its
   `notBefore`/`notAfter` window. Ensure there are no expired certificates in
   the TLS client trust store. An expired cert cannot be fixed by trusting so
   contact the server operator to renew it.

## Error messages and fixes

| Error message | Cause | Fix |
|---|---|---|
| `unable to find valid certification path` | Chain doesn't reach a trusted root | Trust the chain (see below) |
| `validity check failed` | A cert in the chain is expired | Server operator must renew; check `notAfter` via `cryptoCheckUri` |
| `Received fatal alert: handshake_failure` | Name mismatch **or** protocol/cipher mismatch | Fix the connect address, or upgrade Java |
| `Connection reset` | Protocol/cipher mismatch | Upgrade Java |
| `Could not obtain server certificate chain` | Server is not doing TLS on that port | Verify the host and port |

## Trusting an untrusted chain

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

## Incomplete chain from the server

If the server only sends its end-entity cert and omits intermediate
certificate authorities (CAs), the chain check fails even though each
cert is individually valid. Most browsers silently fetch missing
intermediates, but Java does not. Two options:

**Option A** — trust the intermediate CA explicitly via
`cryptoTrustUri` or `cryptoAddCert`.

**Option B** — enable Java's Authority Information Access (AIA) fetcher
by adding this line to `{home}/etc/sys/config.props`:

```
java.options=-Dcom.sun.security.enableAIAcaIssuers=true
```

Restart the runtime after editing `config.props`.

## Web proxy / TLS inspection

When outbound HTTPS passes through an intercepting proxy, the proxy
terminates TLS and re-issues certificates signed by its own CA. You
must trust **the proxy's CA**, not the real server cert.

`cryptoTrustUri` does **not** route through the configured
web proxy and will time out. Use the CLI instead:

```
hx crypto trust -d /path/to/var -uri https://device.local
```

Also note: the proxy may substitute a generic error for the real TLS
error, making diagnosis harder. If the error seems vague, check
whether traffic goes through a web proxy.

## Last-resort: Java TLS debug logging

Add to `{home}/etc/sys/config.props` (restart required):

```
java.options=-Djavax.net.debug=ssl:handshake
```

For full detail: `-Djavax.net.debug=all`. Run the runtime manually and
append the line below to redirect output to capture the trace:

```
> debug.txt 2>&1
```

Remove the option and restart once debugging is complete.

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

Not including the entire certificate chain in the bundle can cause
problems for some HTTP clients that don't automatically fetch
intermediate certificate authorities.

**Hot reload**: a restart is only required to *first enable* HTTPS
(`httpsEnabled`/`httpsPort`). Once the HTTPS listener is running, any
replacement of the `https` bundle — via `cryptoAddCert`, EST enroll,
EST reenroll, or automatic EST renewal — hot-reloads the running web
server immediately. The http ext logs "HTTPS certificate rotated" and
rebuilds its socket config; no restart or connection disruption is
needed. See [EST (Enrollment over Secure Transport)](#est) below for
fully-automated, zero-downtime cert lifecycle management.

# Certificate Bundle Order

The order of bundles is important. It must start with the private
key, then the entire certificate chain.

The order of the certificate chain must start with the server
certificate (which matches the private key), then each Intermediate
Certificate Authority (if any), and end with the Root Certificate
Authority.

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

# EST (Enrollment over Secure Transport) {#est}

EST (RFC 7030) lets the runtime request and automatically renew
certificates from a CA server over HTTPS. All EST funcs require su.

## EST Functions

**`cryptoEstGetCaCerts(server, opts)`** — fetch and inspect the CA
certificate chain from the EST server without enrolling:

```axon
cryptoEstGetCaCerts(`https://est.example.com`)
cryptoEstGetCaCerts(`https://est.example.com`, {caLabel:"myca"})
```

Returns a grid with a `certRole` column classifying each cert per
RFC 4210: `root`, `intermediate`, `endEntity`; during a CA key
rollover also `oldWithOld`, `newWithNew`, `newWithOld`, `oldWithNew`,
or `rollover`.

**`cryptoEstEnroll(dict)`** — enroll for a brand-new certificate:

```axon
// Enroll as the HTTPS server cert (alias defaults to "https")
cryptoEstEnroll({
  uri:         `https://est.example.com`,
  subjectName: "CN=myhost.example.com",
  sanDns:      "myhost.example.com,myhost",
  renewalWindow: 30day
})

// Enroll with a custom alias and multiple SANs
cryptoEstEnroll({
  uri:         `https://est.example.com`,
  subjectName: "CN=api.example.com",
  alias:       "api-server",
  sanDns:      "api.example.com",
  sanIp:       "192.168.1.10",
  username:    "enroll-user",
  password:    cryptoAddCert("enroll-user", ...)
})
```

Key parameters: `uri` (required), `subjectName` (required), at least
one of `sanDns`/`sanIp`/`sanUri` (required), `alias` (default
`https`), `caLabel`, `renewalWindow` (default 30d, clamped 1–180d),
`sigAlgorithm` (default `sha256WithRSAEncryption`), `username`,
`password`.

**`cryptoEstReenroll(alias)`** — renew an existing EST-managed cert
using mutual TLS (the current cert authenticates the request):

```axon
cryptoEstReenroll("https")
cryptoEstReenroll("api-server")
```

## EST-Managed Entries

After a successful enroll or reenroll the keystore entry carries an
`estManaged` tag recording the EST config (server, caLabel,
renewalWindow, sigAlgorithm). Find all managed entries:

```axon
cryptoReadAllKeys().filter(estManaged)
```

## Automatic Renewal

The crypto ext runs housekeeping every 3 hours. Any `estManaged`
entry whose expiration is within its `renewalWindow` is automatically
reenrolled — the cert is renewed and installed without any manual
action.

## Hot Reload of HTTPS

When EST enrolls or reenrolls the `https` alias (including via
automatic renewal), the running HTTPS web server picks up the new
certificate **immediately** — no restart required. The http ext logs
"HTTPS certificate rotated" and rebuilds its TLS socket config in
place. This makes EST the preferred approach for fully-automated,
zero-downtime HTTPS certificate lifecycle management.

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
- After trusting, re-open the affected conns; replacing the `https`
  bundle hot-reloads the running web server — a restart is only needed
  to *first enable* HTTPS (`httpsEnabled`/`httpsPort`)
- Watch `notAfter` dates - expired certs produce the same errors as
  untrusted ones
- The keystore password is fixed; file system permissions on
  var/crypto are the real protection
