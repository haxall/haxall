//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Aug 2026  Ross Schwalm  Creation
//

using web
using util

**
** AuthServerMetadata holds the parsed OAuth 2.0 Authorization Server metadata
** document (RFC 8414) for a given issuer URI.  Use 'discover' to fetch an instance.
**
** Metadata URL construction follows RFC 8414 sec 3.1:
**
**   - Issuer with no path (or just "/"): append
**     '/.well-known/oauth-authorization-server' to the authority.
**
**   - Issuer with a path component: insert the well-known segment between
**     the authority and the path.
**
** After fetching, the 'issuer' field in the JSON response must exactly match
** the issuer URI (trailing-slash normalized) per RFC 8414 sec 3.3.  A mismatch
** always raises an 'Err' - it indicates a security violation, not a transient
** failure.
**
** This class has no built-in endpoint fallback.  Fallback policy is the
** caller's responsibility.  'discover' throws on any failure; the caller
** decides whether to fall back to conventional paths.
**
const class AuthServerMetadata
{

//////////////////////////////////////////////////////////////////////////
// Constructor / Fields
//////////////////////////////////////////////////////////////////////////

  private new make(|This| f) { f(this) }

  ** Normalized issuer string (trailing slash removed)
  const Str issuer

  ** Authorization endpoint (RFC 6749 sec 3.1)
  const Uri authorizationEndpoint

  ** Token endpoint (RFC 6749 sec 3.2)
  const Uri tokenEndpoint

  ** Token revocation endpoint (RFC 7009); null when not advertised
  const Uri? revocationEndpoint

  ** Device authorization endpoint (RFC 8628); null when not advertised
  const Uri? deviceAuthorizationEndpoint

//////////////////////////////////////////////////////////////////////////
// Discovery
//////////////////////////////////////////////////////////////////////////

  **
  ** Fetch and validate the authorization server metadata for the given
  ** issuer URI.  See class doc for URL construction and validation rules.
  **
  ** Throws 'IOErr' for transport failures, non-200 HTTP status, or a non-JSON body.
  ** Throws 'Err' for an invalid document (issuer mismatch, missing required fields).
  **
  static AuthServerMetadata discover(Uri issuer)
  {
    url  := metadataUrl(issuer)
    json := fetch(url)
    return makeFromJson(issuer, json)
  }

//////////////////////////////////////////////////////////////////////////
// Metadata URL Construction (RFC 8414 sec 3.1)
//////////////////////////////////////////////////////////////////////////

  **
  ** Build the well-known metadata URL for the given issuer URI per RFC 8414 sec 3.1.
  ** Exposed as public so it can be unit-tested independently of any network call.
  **
  static Uri metadataUrl(Uri issuer)
  {
    // normalize first: remove trailing slash
    uri  := normalize(issuer).toUri
    path := uri.pathStr == "/" ? "" : uri.pathStr

    // insert well-known between authority and path when path present
    return `${uri.scheme}://${uri.auth}/.well-known/oauth-authorization-server${path}`
  }

//////////////////////////////////////////////////////////////////////////
// Normalize
//////////////////////////////////////////////////////////////////////////

  **
  ** Normalize an issuer URI: convert to string, trim whitespace, and remove
  ** a single trailing slash.  This is what RFC 8414 sec 3.3 comparison uses.
  **
  static Str normalize(Uri issuer)
  {
    s := issuer.toStr.trim
    return s.endsWith("/") ? s[0..-2] : s
  }

//////////////////////////////////////////////////////////////////////////
// Internal
//////////////////////////////////////////////////////////////////////////

  private static Str:Obj fetch(Uri url)
  {
    c := WebClient(url)
    try
    {
      c.writeReq.readRes
      if (c.resCode != 200) throw IOErr("HTTP ${c.resCode}")
      json := JsonInStream(c.resIn).readJson as Str:Obj
      if (json == null) throw IOErr("empty response body")
      return json
    }
    finally c.close
  }

  private static AuthServerMetadata makeFromJson(Uri issuer, Str:Obj json)
  {
    // RFC 8414 sec 3.3 - validate that the returned issuer matches the requested one
    returnedIssuer := normalize((json["issuer"] as Str)?.toUri ?: ``)
    expected       := normalize(issuer)
    if (returnedIssuer != expected)
      throw Err("OAuth issuer mismatch: expected '${expected}', got '${returnedIssuer}' from ${metadataUrl(issuer)}")

    authEp   := (json["authorization_endpoint"] as Str) ?: throw Err("authorization_endpoint missing")
    tokenEp  := (json["token_endpoint"]         as Str) ?: throw Err("token_endpoint missing")
    revokeEp := json["revocation_endpoint"]             as Str
    deviceEp := json["device_authorization_endpoint"]   as Str

    return AuthServerMetadata
    {
      it.issuer                      = expected
      it.authorizationEndpoint       = authEp.toUri
      it.tokenEndpoint               = tokenEp.toUri
      it.revocationEndpoint          = revokeEp?.toUri
      it.deviceAuthorizationEndpoint = deviceEp?.toUri
    }
  }

}
