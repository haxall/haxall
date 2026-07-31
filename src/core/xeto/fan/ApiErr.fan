//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jul 2026  Brian Frank  Creation
//

using concurrent
using util
using web

**
** Standardized error for the Xeto HTTP API.  Each factory is named for
** its `sys.api` err spec; where one spec has multiple factories the name
** is suffixed with the specific case.  Use `writeRes` to service the
** response - it is the single choke point for every API error body so
** that all paths, including authentication, report errors identically.
**
@NoDoc
const class ApiErr : Err
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Construct with status code, unqualified sys.api err spec name, and message
  new make(Int code, Str spec, Str dis, Err? cause := null,
           [Str:Obj]? more := null, [Str:Str]? headers := null)
    : super(dis, cause)
  {
    this.code    = code
    this.spec    = spec.contains("::") ? spec : "sys.api::" + spec
    this.dis     = dis
    this.more    = more ?: noMore
    this.headers = headers ?: noHeaders
  }

  private static const Str:Obj noMore := Str:Obj[:]
  private static const Str:Str noHeaders := Str:Str[:]

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** HTTP status code
  const Int code

  ** Qname of the sys.api error spec
  const Str spec

  ** Human readable summary
  const Str dis

  ** Additional spec specific tags for the error body
  const Str:Obj more

  ** Response headers to set in addition to the standard ones
  const Str:Str headers

//////////////////////////////////////////////////////////////////////////
// Web
//////////////////////////////////////////////////////////////////////////

  ** Disable including the stack trace in error responses.  Deployments
  ** which undergo security audits often turn traces off so that server
  ** internals are never disclosed.  Controlled by the API extension on
  ** startup and whenever its settings change.
  @NoDoc static const AtomicBool disableErrTrace := AtomicBool(false)

  ** Write this err as the HTTP response.  This is the single choke point
  ** for every API error: it sets the status line, the standard headers,
  ** any err specific headers, and the clean JSON body.  Does nothing if
  ** the response is already committed.
  Void writeRes(WebRes res)
  {
    if (res.isCommitted) return

    res.statusCode = code
    res.statusPhrase = dis
    res.headers["Content-Type"] = "application/json"
    res.headers["Xeto-Version"] = ApiVersion.cur.token
    headers.each |v, n| { res.headers[n] = v }

    JsonOutStream(res.out).writeJson(toJson).close
  }

  ** Encode to the clean JSON body map
  private Str:Obj toJson()
  {
    json := Str:Obj[:] { ordered = true }
    json["spec"]   = spec
    json["status"] = code
    json["dis"]    = dis
    more.each |v, n| { json[n] = v }
    if (!disableErrTrace.val)
      json["errTrace"] = (cause ?: this).traceToStr
    return json
  }

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  ** Op name resolves to multiple functions
  static ApiErr ambiguousFuncErr(Str name, Str[] candidates)
  {
    make(404, "AmbiguousFuncErr", "Ambiguous ops: $candidates", null,
      ["funcName": name, "candidates": candidates])
  }

  ** Credentials are missing, malformed, or expired.  The code defaults
  ** to 401, but a malformed Authorization header is reported as 400 and
  ** a rejected token as 403, so the caller may override it.
  static ApiErr authErr(Str dis, Int code := 401, Err? cause := null)
  {
    make(code, "AuthErr", dis, cause)
  }

  ** Func raised an err which is not otherwise mapped
  static ApiErr internalErr(Str dis, Err cause)
  {
    make(500, "InternalErr", dis, cause)
  }

  ** Request body cannot be parsed into function args
  static ApiErr invalidArgsErr(Str mime, Err cause)
  {
    make(400, "InvalidArgsErr", "Cannot parse $mime request", cause)
  }

  ** URI cannot be parsed as "/api/{proj}/{op}"
  static ApiErr invalidPathErr()
  {
    make(404, "InvalidPathErr", "Invalid path")
  }

  ** GET not allowed because the func has side effects
  static ApiErr methodNotAllowedErr(Str funcName)
  {
    make(405, "MethodNotAllowedErr", "GET not allowed for op '$funcName'", null,
      ["allow": Str["POST"]])
  }

  ** Request Accept header cannot be parsed
  static ApiErr notAcceptableErrHeader()
  {
    make(406, "NotAcceptableErr", "Invalid Accept header")
  }

  ** Request Accept type has no writer
  static ApiErr notAcceptableErrWriter(Str mime)
  {
    make(406, "NotAcceptableErr", "Unsupported Accept type: $mime")
  }

  ** HTTP method is not implemented at all
  static ApiErr notImplementedErrMethod(Str method)
  {
    make(501, "NotImplementedErr", "Unsupported method: $method.upper")
  }

  ** WebSocket upgrade is not implemented yet
  static ApiErr notImplementedErrWebSocket()
  {
    make(400, "NotImplementedErr", "WebSocket upgrade not available")
  }

  ** Caller is authenticated but lacks permission to call the function
  static ApiErr permissionErr(Str dis, Err? cause := null)
  {
    make(403, "PermissionErr", dis, cause)
  }

  ** Caller is authenticated but lacks permission to access project
  static ApiErr permissionErrProj(Str projName, Err? cause := null)
  {
    permissionErr("Cannot access proj: $projName", cause)
  }

  ** Caller exceeded a rate limit or quota; retryAfter is omitted when
  ** the server cannot predict when the limit resets.  It is always
  ** reported in seconds to match the HTTP Retry-After header.
  static ApiErr rateLimitErr(Str dis, Duration? retryAfter := null, Err? cause := null)
  {
    if (retryAfter == null) return make(429, "RateLimitErr", dis, cause)
    secs := retryAfter.toSec
    return make(429, "RateLimitErr", dis, cause,
      ["retryAfter": "${secs}sec"], ["Retry-After": secs.toStr])
  }

  ** Func exceeded the server evaluation time limit
  static ApiErr timeoutErr(Str dis, Err? cause := null)
  {
    make(504, "TimeoutErr", dis, cause)
  }

  ** Runtime is known but cannot service the request right now, such as a
  ** project whose host node is down
  static ApiErr unavailableErr(Str dis, Err? cause := null)
  {
    make(503, "UnavailableErr", dis, cause)
  }

  ** Entity id does not resolve in the data store
  static ApiErr unknownEntityErr(Str dis, Err? cause := null, Str? id := null)
  {
    make(404, "UnknownEntityErr", dis, cause, id == null ? null : ["id": id])
  }

  ** Op name does not resolve to a func in the namespace
  static ApiErr unknownFuncErr(Str name)
  {
    make(404, "UnknownFuncErr", "Unknown op: $name", null, ["funcName": name])
  }

  ** URI project name does not map to a runtime
  static ApiErr unknownProjErr(Str name)
  {
    make(404, "UnknownProjErr", "Proj not found: $name", null, ["projName": name])
  }

  ** Request is missing a Content-Type header
  static ApiErr unsupportedMediaTypeErrMissing()
  {
    make(415, "UnsupportedMediaTypeErr", "Content-Type not specified")
  }

  ** Request Content-Type has no reader
  static ApiErr unsupportedMediaTypeErrReader(Str mime)
  {
    make(415, "UnsupportedMediaTypeErr", "Unsupported Content-Type: $mime")
  }

  ** Xeto-Version header is malformed or unsupported
  static ApiErr unsupportedVersionErr(Str? header)
  {
    make(400, "UnsupportedVersionErr", "Unsupported Xeto-Version: $header", null,
      ["allow": ApiVersion.tokens])
  }

}

