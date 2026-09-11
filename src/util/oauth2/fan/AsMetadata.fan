//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Aug 2026  Ross Schwalm  Creation
//

using concurrent
using web
using util

**
** AsMetadata holds the parsed OAuth 2.0 Authorization Server metadata document
** (RFC 8414) for a given issuer URI.  Use `discover` to fetch and cache an
** instance.
**
** Metadata URL construction follows RFC 8414 §3.1:
**
**   - Issuer with no path (or just "/"): append
**     `/.well-known/oauth-authorization-server` to the authority.
**     e.g. `https://host` → `https://host/.well-known/oauth-authorization-server`
**
**   - Issuer with a path component: insert the well-known segment *between*
**     the authority and the path.
**     e.g. `https://host/api/demo` →
**            `https://host/.well-known/oauth-authorization-server/api/demo`
**
** After fetching, the `issuer` field in the JSON response must exactly match
** the issuer URI (trailing-slash normalized) per RFC 8414 §3.3.  A mismatch
** always raises an `Err` regardless of the `checked` argument -- it indicates
** a security violation (spoofing / misconfiguration), not a transient failure.
**
** This class has **no built-in endpoint fallback**.  Endpoint fallback policy
** is the caller's responsibility.  On a fetch failure `discover` either throws
** (checked=true) or returns null (checked=false); the caller decides what to do.
**
** Only successfully validated documents are cached in-process keyed by
** normalized issuer URI.  Fetch failures are not cached, so the next login
** attempt retries discovery.
**
const class AsMetadata
{

//////////////////////////////////////////////////////////////////////////
// Discovery
//////////////////////////////////////////////////////////////////////////

  **
  ** Per-issuer cache: normalized issuer Str → AsMetadata.
  **
  private static const ConcurrentMap cache := ConcurrentMap()

  **
  ** Fetch (and cache) the authorization server metadata for the given
  ** issuer URI.  See class doc for URL construction and validation rules.
  **
  ** Two-tier failure policy:
  **   - Fetch failure (connection refused, timeout, HTTP != 200, non-JSON
  **     body): throws when `checked=true`; returns null when `checked=false`.
  **   - Invalid fetched document (issuer mismatch per RFC 8414 §3.3, missing
  **     required fields): **always throws** regardless of `checked`.
  **
  static AsMetadata? discover(Uri issuer, Log log, Bool checked := true)
  {
    key    := normalize(issuer)
    cached := cache.get(key) as AsMetadata
    if (cached != null) return cached

    meta := fetch(issuer, log, checked)
    if (meta != null) cache[key] = meta
    return meta
  }

  ** Remove the cached metadata for the given issuer (e.g. to force refresh in tests).
  static Void invalidate(Uri issuer) { cache.remove(normalize(issuer)) }

//////////////////////////////////////////////////////////////////////////
// Metadata URL Construction (RFC 8414 §3.1)
//////////////////////////////////////////////////////////////////////////

  **
  ** Build the well-known metadata URL for the given issuer URI per RFC 8414 §3.1.
  ** Exposed as public so it can be unit-tested independently of any network call.
  **
  static Uri metadataUrl(Uri issuer)
  {
    // Normalize first: remove trailing slash
    uri  := normalize(issuer).toUri
    path := uri.pathStr == "/" ? "" : uri.pathStr

    // RFC 8414 §3.1: insert well-known between authority and path when path present.
    // Uri.auth already includes the port when present (e.g. "host:8443").
    return "${uri.scheme}://${uri.auth}/.well-known/oauth-authorization-server${path}".toUri
  }

//////////////////////////////////////////////////////////////////////////
// Internal fetch / construction
//////////////////////////////////////////////////////////////////////////

  private static AsMetadata? fetch(Uri issuer, Log log, Bool checked)
  {
    url := metadataUrl(issuer)
    log.info("OAuth discovery: GET $url")

    // Attempt the network fetch.  Only transient I/O failures are caught here;
    // document validation (makeFromJson) runs after the catch so its errors
    // always propagate regardless of the checked flag.
    [Str:Obj?]? json := null
    try
    {
      c := WebClient(url)
      try
      {
        c.writeReq.readRes
        if (c.resCode != 200) throw IOErr("HTTP ${c.resCode}")
        json = JsonInStream(c.resIn).readJson as Str:Obj ?: throw IOErr("empty response body")
      }
      finally c.close
    }
    catch (Err e)
    {
      if (checked) throw e
      log.warn("OAuth discovery unavailable for <$issuer>: $e.msg")
      return null
    }

    // Validation errors (issuer mismatch, missing required fields) always propagate.
    return makeFromJson(issuer, json)
  }

  private static AsMetadata makeFromJson(Uri issuer, Str:Obj json)
  {
    // RFC 8414 §3.3 — validate that the returned issuer exactly matches the requested one
    returnedIssuer := normalize((json["issuer"] as Str)?.toUri ?: ``)
    expected       := normalize(issuer)
    if (returnedIssuer != expected)
      throw Err("OAuth issuer mismatch: expected '$expected', got '$returnedIssuer' from ${metadataUrl(issuer)}")

    authEp   := (json["authorization_endpoint"] as Str) ?: throw Err("authorization_endpoint missing")
    tokenEp  := (json["token_endpoint"]         as Str) ?: throw Err("token_endpoint missing")
    revokeEp := json["revocation_endpoint"]             as Str
    deviceEp := json["device_authorization_endpoint"]   as Str

    return AsMetadata
    {
      it.issuer                      = expected.toUri
      it.authorizationEndpoint       = authEp.toUri
      it.tokenEndpoint               = tokenEp.toUri
      it.revocationEndpoint          = revokeEp?.toUri
      it.deviceAuthorizationEndpoint = deviceEp?.toUri
      it.json                        = json.toImmutable
    }
  }

//////////////////////////////////////////////////////////////////////////
// Normalize
//////////////////////////////////////////////////////////////////////////

  **
  ** Normalize an issuer URI: convert to string, trim whitespace, and remove
  ** a single trailing slash.  This is what RFC 8414 §3.3 comparison uses.
  **
  static Str normalize(Uri issuer)
  {
    s := issuer.toStr.trim
    return s.endsWith("/") ? s[0..-2] : s
  }

//////////////////////////////////////////////////////////////////////////
// Constructor / Fields
//////////////////////////////////////////////////////////////////////////

  private new make(|This| f) { f(this) }

  ** Normalized issuer URI (no trailing slash)
  const Uri issuer

  ** Authorization endpoint (RFC 6749 §3.1)
  const Uri authorizationEndpoint

  ** Token endpoint (RFC 6749 §3.2)
  const Uri tokenEndpoint

  ** Token revocation endpoint (RFC 7009); null when not advertised
  const Uri? revocationEndpoint := null

  ** Device authorization endpoint (RFC 8628); null when not advertised
  const Uri? deviceAuthorizationEndpoint := null

  ** Raw JSON metadata document
  const Str:Obj json := [:]
}
