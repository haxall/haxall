//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jul 2026  Brian Frank  Creation
//

using xeto
using haystack
using web

**
** Constants for the standardized error status codes and specs.
** Each factory is named for its `sys.api` err spec; where one spec
** has multiple factories the name is suffixed with the specific case.
**
const class ApiErr : Err
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Construct with status code, unqualified sys.api err spec name, and message
  new make(Int code, Str spec, Str dis, Err? cause := null, Dict? more := null)
    : super(dis, cause)
  {
    this.code = code
    this.spec = spec.contains("::") ? spec : "sys.api::" + spec
    this.dis  = dis
    this.more = more ?: Etc.dict0
  }

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
  const Dict more

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  ** Op name resolves to multiple functions
  static ApiErr ambiguousFuncErr(Str name, Spec[] candidates)
  {
    make(404, "AmbiguousFuncErr", "Ambiguous ops: $candidates", null,
      Etc.dict2("funcName", name, "candidates", candidates.map |x->Str| { x.qname }))
  }

  ** Func raised an err which is not otherwise mapped
  static ApiErr internalErr(Str dis, Err cause)
  {
    make(500, "InternalErr", dis, cause)
  }

  ** Request body cannot be parsed into function args
  static ApiErr invalidArgsErr(MimeType mime, Err cause)
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
      Etc.dict1("allow", ["POST"]))
  }

  ** Request Accept header cannot be parsed
  static ApiErr notAcceptableErrHeader()
  {
    make(406, "NotAcceptableErr", "Invalid Accept header")
  }

  ** Request Accept type has no writer
  static ApiErr notAcceptableErrWriter(MimeType mime)
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

  ** Caller lacks the su or admin permission for the func
  static ApiErr permissionErr(Str dis, Err? cause := null)
  {
    make(403, "PermissionErr", dis, cause)
  }

  ** Op name does not resolve to a func in the namespace
  static ApiErr unknownFuncErr(Str name)
  {
    make(404, "UnknownFuncErr", "Unknown op: $name", null,
      Etc.dict1("funcName", name))
  }

  ** URI project name does not map to a runtime
  static ApiErr unknownProjErr(Str name)
  {
    make(404, "UnknownProjErr", "Proj not found: $name", null,
      Etc.dict1("projName", name))
  }

  ** Request is missing a Content-Type header
  static ApiErr unsupportedMediaTypeErrMissing()
  {
    make(415, "UnsupportedMediaTypeErr", "Content-Type not specified")
  }

  ** Request Content-Type has no reader
  static ApiErr unsupportedMediaTypeErrReader(MimeType mime)
  {
    make(415, "UnsupportedMediaTypeErr", "Unsupported Content-Type: $mime")
  }

  ** Xeto-Version header is malformed or unsupported
  static ApiErr unsupportedVersionErr(Str? header)
  {
    make(400, "UnsupportedVersionErr", "Unsupported Xeto-Version: $header", null,
      Etc.dict1("allow", ApiPipeline.versionTokens))
  }

}

