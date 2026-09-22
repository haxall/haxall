//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Aug 2026  Ross Schwalm  Creation
//

using concurrent
using inet
using util
using web
using wisp

**
** Unit tests for AuthServerMetadata (RFC 8414 discovery)
**
class AuthServerMetadataTest : Test
{

//////////////////////////////////////////////////////////////////////////
// Metadata URL Construction (RFC 8414 sec 3.1)
//////////////////////////////////////////////////////////////////////////

  ** Root issuer (no path) -> append well-known to authority
  Void testMetadataUrlRootNoTrailingSlash()
  {
    url := AuthServerMetadata.metadataUrl(`https://host.example.com`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server")
  }

  ** Root issuer with trailing slash -> same result (normalize strips slash first)
  Void testMetadataUrlRootTrailingSlash()
  {
    url := AuthServerMetadata.metadataUrl(`https://host.example.com/`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server")
  }

  ** Single-segment path issuer -> insert well-known between authority and path
  Void testMetadataUrlSingleSegmentPath()
  {
    url := AuthServerMetadata.metadataUrl(`https://host.example.com/demo`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server/demo")
  }

  ** Multi-segment path issuer (e.g. issuer served under a sub-path)
  Void testMetadataUrlMultiSegmentPath()
  {
    url := AuthServerMetadata.metadataUrl(`https://host.example.com/api/demo`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server/api/demo")
  }

  ** Non-standard port with path
  Void testMetadataUrlWithPort()
  {
    url := AuthServerMetadata.metadataUrl(`https://host.example.com:8443/demo`)
    verifyEq(url.toStr, "https://host.example.com:8443/.well-known/oauth-authorization-server/demo")
  }

  ** Non-standard port, no path
  Void testMetadataUrlWithPortNoPath()
  {
    url := AuthServerMetadata.metadataUrl(`https://host.example.com:8443`)
    verifyEq(url.toStr, "https://host.example.com:8443/.well-known/oauth-authorization-server")
  }

  ** http scheme (used in dev/test environments)
  Void testMetadataUrlHttpScheme()
  {
    url := AuthServerMetadata.metadataUrl(`http://localhost:8080/demo`)
    verifyEq(url.toStr, "http://localhost:8080/.well-known/oauth-authorization-server/demo")
  }

  ** Deeply nested path
  Void testMetadataUrlDeepPath()
  {
    url := AuthServerMetadata.metadataUrl(`https://host.example.com/a/b/c`)
    verifyEq(url.toStr, "https://host.example.com/.well-known/oauth-authorization-server/a/b/c")
  }

//////////////////////////////////////////////////////////////////////////
// Normalize
//////////////////////////////////////////////////////////////////////////

  Void testNormalizeStripsTrailingSlash()
  {
    verifyEq(AuthServerMetadata.normalize(`https://host.example.com/`), "https://host.example.com")
  }

  Void testNormalizeNoOpWhenClean()
  {
    verifyEq(AuthServerMetadata.normalize(`https://host.example.com`), "https://host.example.com")
  }

  Void testNormalizeOnlyStripsOneTrailingSlash()
  {
    // Only the last trailing slash is stripped, preserving path segments
    verifyEq(AuthServerMetadata.normalize(`https://host.example.com/demo/`), "https://host.example.com/demo")
  }

//////////////////////////////////////////////////////////////////////////
// Live Discovery (WispService)
//////////////////////////////////////////////////////////////////////////

  ** Happy path: server returns a well-formed document with a matching issuer.
  Void testDiscoverSuccess()
  {
    withMock |mod, base|
    {
      issuer := base.toUri

      mod.jsonRef.val = Str:Obj[
        "issuer":                 base,
        "authorization_endpoint": "${base}/oauth/authorize",
        "token_endpoint":         "${base}/oauth/token",
      ].toImmutable

      meta := AuthServerMetadata.discover(issuer)

      verifyEq(meta.issuer,                             base)
      verifyEq(meta.authorizationEndpoint.toStr, "${base}/oauth/authorize")
      verifyEq(meta.tokenEndpoint.toStr,         "${base}/oauth/token")
      verifyNull(meta.revocationEndpoint)
      verifyNull(meta.deviceAuthorizationEndpoint)
    }
  }

  ** Server returns a document whose 'issuer' field does not match the requested issuer
  ** (RFC 8414 sec 3.3 violation).  discover must always throw.
  Void testDiscoverIssuerMismatch()
  {
    withMock |mod, base|
    {
      issuer := base.toUri

      mod.jsonRef.val = Str:Obj[
        "issuer":                 "https://wrong.example.com",
        "authorization_endpoint": "https://wrong.example.com/authorize",
        "token_endpoint":         "https://wrong.example.com/token",
      ].toImmutable

      verifyErr(Err#) { AuthServerMetadata.discover(issuer) }
    }
  }

  ** Server returns HTTP 404 -> discover throws IOErr.
  Void testDiscoverHttpError()
  {
    withMock |mod, base|
    {
      mod.return404.val = true
      verifyErr(IOErr#) { AuthServerMetadata.discover(base.toUri) }
    }
  }

  ** Nothing listening on the port -> discover throws IOErr (connection refused).
  Void testDiscoverConnectionRefused()
  {
    // obtain a port that is guaranteed idle by briefly binding then closing
    l := TcpListener()
    l.bind(IpAddr("127.0.0.1"), null)
    port := l.localPort
    l.close

    verifyErr(IOErr#) { AuthServerMetadata.discover("http://127.0.0.1:${port}".toUri) }
  }

  ** Optional fields (revocation, device) are captured when present.
  Void testDiscoverOptionalFields()
  {
    withMock |mod, base|
    {
      issuer := base.toUri

      mod.jsonRef.val = Str:Obj[
        "issuer":                        base,
        "authorization_endpoint":        "${base}/oauth/authorize",
        "token_endpoint":                "${base}/oauth/token",
        "revocation_endpoint":           "${base}/oauth/revoke",
        "device_authorization_endpoint": "${base}/oauth/device",
      ].toImmutable

      meta := AuthServerMetadata.discover(issuer)

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
** Minimal WispService WebMod for testing AuthServerMetadata.discover.
** Returns the JSON stored in 'jsonRef' only when the request path is
** exactly '/.well-known/oauth-authorization-server', ensuring URL
** construction is verified against a live HTTP request.
** Set 'return404.val = true' to exercise the HTTP-error path.
**
internal const class MockDiscoveryMod : WebMod
{
  const AtomicRef  jsonRef   := AtomicRef(Str:Obj[:].toImmutable)
  const AtomicBool return404 := AtomicBool(false)

  override Void onGet()
  {
    if (return404.val || req.uri.pathStr != "/.well-known/oauth-authorization-server")
    {
      res.statusCode = 404
      res.headers["Content-Type"] = "text/plain"
      res.out.print("Not Found").flush
      return
    }

    json := jsonRef.val as Str:Obj ?: Str:Obj[:]
    res.headers["Content-Type"] = "application/json"
    res.statusCode = 200
    JsonOutStream(res.out).writeJson(json)
    res.out.flush
  }
}
