//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Aug 2026  Ross Schwalm  Creation
//

using concurrent
using util
using web
using wisp

**
** Unit tests for AsMetadata:
**   D6 — metadata URL construction (RFC 8414 §3.1) and issuer normalization
**   D7 — live-wisp discovery: correct issuer → success; mismatched issuer → fallback
**
class AsMetadataTest : Test
{

//////////////////////////////////////////////////////////////////////////
// D6 — Metadata URL Construction (RFC 8414 §3.1)
//////////////////////////////////////////////////////////////////////////

  ** Root issuer (no path) → append well-known to authority
  Void testMetadataUrlRootNoTrailingSlash()
  {
    url := AsMetadata.metadataUrl(`https://host.example.com`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server")
  }

  ** Root issuer with trailing slash → same result (normalize strips slash first)
  Void testMetadataUrlRootTrailingSlash()
  {
    url := AsMetadata.metadataUrl(`https://host.example.com/`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server")
  }

  ** Single-segment path issuer → insert well-known between authority and path
  Void testMetadataUrlSingleSegmentPath()
  {
    url := AsMetadata.metadataUrl(`https://host.example.com/demo`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server/demo")
  }

  ** Multi-segment path issuer (e.g. issuer served under a sub-path)
  Void testMetadataUrlMultiSegmentPath()
  {
    url := AsMetadata.metadataUrl(`https://host.example.com/api/demo`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server/api/demo")
  }

  ** Non-standard port with path
  Void testMetadataUrlWithPort()
  {
    url := AsMetadata.metadataUrl(`https://host.example.com:8443/demo`)
    verifyEq(url.toStr, "https://host.example.com:8443/.well-known/oauth-authorization-server/demo")
  }

  ** Non-standard port, no path
  Void testMetadataUrlWithPortNoPath()
  {
    url := AsMetadata.metadataUrl(`https://host.example.com:8443`)
    verifyEq(url.toStr, "https://host.example.com:8443/.well-known/oauth-authorization-server")
  }

  ** http scheme (used in dev/test environments)
  Void testMetadataUrlHttpScheme()
  {
    url := AsMetadata.metadataUrl(`http://localhost:8080/demo`)
    verifyEq(url.toStr, "http://localhost:8080/.well-known/oauth-authorization-server/demo")
  }

  ** Deeply nested path
  Void testMetadataUrlDeepPath()
  {
    url := AsMetadata.metadataUrl(`https://host.example.com/a/b/c`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server/a/b/c")
  }

//////////////////////////////////////////////////////////////////////////
// Normalize
//////////////////////////////////////////////////////////////////////////

  Void testNormalizeStripsTrailingSlash()
  {
    verifyEq(AsMetadata.normalize(`https://host.example.com/`), "https://host.example.com")
  }

  Void testNormalizeNoOpWhenClean()
  {
    verifyEq(AsMetadata.normalize(`https://host.example.com`), "https://host.example.com")
  }

  Void testNormalizeOnlyStripsOneTrailingSlash()
  {
    // Only the last trailing slash is stripped, preserving path segments
    verifyEq(AsMetadata.normalize(`https://host.example.com/demo/`), "https://host.example.com/demo")
  }

//////////////////////////////////////////////////////////////////////////
// Cache invalidation (sanity)
//////////////////////////////////////////////////////////////////////////

  Void testInvalidateSmokeTest()
  {
    // invalidate should not throw even if the issuer was never cached
    AsMetadata.invalidate(`https://not-cached.example.com`)
  }

//////////////////////////////////////////////////////////////////////////
// D7 — Live Discovery (WispService)
//////////////////////////////////////////////////////////////////////////

  ** D7 happy path: server returns a well-formed document with a matching issuer.
  ** discover() must return the endpoints from the document.
  Void testDiscoverSuccess()
  {
    withMock |mod, base|
    {
      issuer := base.toUri

      // Seed the mock with a valid document whose issuer matches the request
      mod.jsonRef.val = Str:Obj[
        "issuer":                 base,
        "authorization_endpoint": "${base}/oauth/authorize",
        "token_endpoint":         "${base}/oauth/token",
      ].toImmutable

      AsMetadata.invalidate(issuer)        // clear any prior cached value
      meta := AsMetadata.discover(issuer, Log.get("test"))

      // Fantom's Uri normalizes root URIs by adding a trailing slash
      // (e.g. "http://host:port".toUri.toStr → "http://host:port/"),
      // so compare issuer through normalize() for a consistent comparison.
      verifyEq(AsMetadata.normalize(meta.issuer), base)
      verifyEq(meta.authorizationEndpoint.toStr,   "${base}/oauth/authorize")
      verifyEq(meta.tokenEndpoint.toStr,            "${base}/oauth/token")
      verifyNull(meta.revocationEndpoint)
      verifyNull(meta.deviceAuthorizationEndpoint)
    }
  }

  ** D7 negative: server returns a document whose "issuer" field does not match
  ** the issuer used to construct the well-known URL (RFC 8414 §3.3 violation).
  ** discover() must always throw regardless of the `checked` argument.
  Void testDiscoverIssuerMismatch()
  {
    withMock |mod, base|
    {
      issuer := base.toUri

      // Serve a document whose issuer does not match the requested issuer
      mod.jsonRef.val = Str:Obj[
        "issuer":                 "https://wrong.example.com",
        "authorization_endpoint": "https://wrong.example.com/authorize",
        "token_endpoint":         "https://wrong.example.com/token",
      ].toImmutable

      // checked=true  → must throw on mismatch
      AsMetadata.invalidate(issuer)
      verifyErr(Err#) { AsMetadata.discover(issuer, Log.get("test")) }

      // checked=false → must still throw on mismatch (security violation)
      AsMetadata.invalidate(issuer)
      verifyErr(Err#) { AsMetadata.discover(issuer, Log.get("test"), false) }
    }
  }

  ** D7 negative: well-known endpoint is unreachable (nothing listening).
  ** checked=true → throws; checked=false → returns null.
  ** Note: port 19999 is assumed idle; on a busy machine this test could flake.
  Void testDiscoverUnavailable()
  {
    issuer := `http://127.0.0.1:19999`

    // checked=true (default) → must throw (IOErr: connection refused)
    AsMetadata.invalidate(issuer)
    verifyErr(IOErr#) { AsMetadata.discover(issuer, Log.get("test")) }

    // checked=false → must return null (and not be cached)
    AsMetadata.invalidate(issuer)
    meta := AsMetadata.discover(issuer, Log.get("test"), false)
    verifyNull(meta)

    // Confirm the failed fetch was not cached: a second checked=false call
    // also returns null (retries discovery rather than returning a stale null)
    meta2 := AsMetadata.discover(issuer, Log.get("test"), false)
    verifyNull(meta2)
  }

  ** D7 edge case: optional fields (revocation, device) are captured when present
  Void testDiscoverOptionalFields()
  {
    withMock |mod, base|
    {
      issuer := base.toUri

      mod.jsonRef.val = Str:Obj[
        "issuer":                       base,
        "authorization_endpoint":       "${base}/oauth/authorize",
        "token_endpoint":               "${base}/oauth/token",
        "revocation_endpoint":          "${base}/oauth/revoke",
        "device_authorization_endpoint":"${base}/oauth/device",
      ].toImmutable

      AsMetadata.invalidate(issuer)
      meta := AsMetadata.discover(issuer, Log.get("test"))

      verifyEq(meta.revocationEndpoint.toStr,          "${base}/oauth/revoke")
      verifyEq(meta.deviceAuthorizationEndpoint.toStr, "${base}/oauth/device")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Helpers
//////////////////////////////////////////////////////////////////////////

  ** Start an ephemeral WispService backed by a MockDiscoveryMod, call f with
  ** the mod and the base URL ("http://127.0.0.1:<port>"), then stop the service.
  private Void withMock(|MockDiscoveryMod mod, Str base| f)
  {
    mod  := MockDiscoveryMod()
    wisp := WispService { it.httpPort = -1; it.root = mod }.start
    try
    {
      wisp.waitUntilListening(10sec)
      f(mod, "http://127.0.0.1:${wisp.httpPort}")
    }
    finally wisp.stop
  }
}

**************************************************************************
** MockDiscoveryMod
**************************************************************************

**
** Minimal WispService WebMod that serves the JSON stored in jsonRef
** for any GET request (simulates the /.well-known/oauth-authorization-server
** endpoint without caring about the exact path).
**
internal const class MockDiscoveryMod : WebMod
{
  ** Holds the JSON object to serve; replace via jsonRef.val = newMap.toImmutable
  const AtomicRef jsonRef := AtomicRef(Str:Obj[:].toImmutable)

  override Void onGet()
  {
    json := jsonRef.val as Str:Obj ?: Str:Obj[:]
    res.headers["Content-Type"] = "application/json"
    res.statusCode = 200
    JsonOutStream(res.out).writeJson(json)
    res.out.flush
  }
}
