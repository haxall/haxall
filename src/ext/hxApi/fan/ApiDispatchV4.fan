//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon
using hx
using web

**
** ApiDispatchV4 for version 4 legacy pre-xeto protocol
**
class ApiDispatchV4 : ApiDispatch
{
  new make(ApiPipeline p) : super(p) {}

//////////////////////////////////////////////////////////////////////////
// Read Request
//////////////////////////////////////////////////////////////////////////

  override Obj?[] readReqGet()
  {
    tags := Str:Obj[:]
    req.uri.query.each |valStr, key|
    {
      if (ApiUtil.isControlParam(key)) return
      Obj? val := null
      try
        val = ZincReader(valStr.in).readVal
      catch
        val = valStr
      tags[key] = val
    }
    return toArgs(Etc.makeMapGrid(null, tags))
  }

  override Obj?[] readReqPost()
  {
    // file typed params are a version 5 feature
    if (ApiUtil.fileParam(func) != null) throw ApiErr(400, "InvalidArgsErr", "File param op requires API version 5: $func.name")

    // resolve filetype per v4 rules: bare application/json is hayson
    mime := reqMime
    filetype := Filetype.apiMime(mime, ApiVersion.v4)
    if (filetype == null || !filetype.canRead) throw ApiErr.unsupportedMediaTypeErrReader(mime.toStr)

    return toArgs(readReqGrid(filetype))
  }

  ** Map the version 4 request grid onto the function args.  An op which
  ** still takes the legacy envelope gets the grid whole; one which has
  ** modeled its params has its args read from the first row's cells by name.
  **
  ** A cell which matches no param is ignored rather than rejected: a v4
  ** client may send extra columns, and callers do (Api4Test posts a 'ts'
  ** column to eval).  A param with no cell falls back to its default.
  **
  ** Note only the first row is read, so a multi-row grid posted to a modeled
  ** op drops rows 2..n.  Every modeled op today is inherently single-row; an
  ** op which needs the other rows must keep its 'req' param.
  private Obj?[] toArgs(Grid grid)
  {
    if (takesReqGrid) return Obj?[grid]
    row := grid.first
    return mapArgs |p->Obj?| { row?.get(p.name) }
  }

  ** Does this op take the whole version 4 request grid as its single
  ** argument?  Version 4 passed the grid to any func invoked as an op no
  ** matter what it declared - `hxApi::ApiPipeline.doResolveOpFunc` resolves
  ** any func in the namespace, not just those marked '<op>'.  So args are
  ** only mapped by name for an '<op>' which has modeled its params; the
  ** grid based ops receive the grid whole per `ApiUtil.isOpGrid`.
  virtual Bool takesReqGrid()
  {
    ApiUtil.takesReqGridV4(func)
  }

//////////////////////////////////////////////////////////////////////////
// Call
//////////////////////////////////////////////////////////////////////////

  ** Version 4 reports a failure raised by the op function itself as a 200
  ** response with an error grid.  This is the legacy wire contract:
  ** haystack::Client parses the grid to raise CallErr, so a real status
  ** code here would surface as IOErr instead.  ApiErr is a failure in the
  ** HTTP processing which never reached the function, so it is rethrown to
  ** be reported by ApiPipeline.writeErr with its status code.
  **
  ** This applies only when we are the one writing the response body.  An op
  ** which streams its own response, or returns a file for the dispatcher to
  ** serve, has no grid to put the error in: the client would read the err
  ** grid as the bytes it asked for, so the error is rethrown instead.
  override Obj? call(Obj?[] args)
  {
    try
      return super.call(args)
    catch (ApiErr e)
      throw e
    catch (Err e)
    {
      if (!writesGrid) throw e
      pipeline.writeErrGrid(e)
    }
    return null
  }

  ** Will this op's response body be a grid we encode?  Note a func may
  ** declare 'returns: None' and still get a grid: sys.api::close answers
  ** the empty grid.  What matters is whether the func writes the response
  ** itself, which is the '<opWebRes>' marker.
  private Bool writesGrid()
  {
    !pipeline.funcOwnsRes && !func.func.isFileReturn
  }

//////////////////////////////////////////////////////////////////////////
// Write Response
//////////////////////////////////////////////////////////////////////////

  override Void writeResVal(Obj? result)
  {
    // resolve filetype per v4 rules: the default is zinc and bare
    // application/json is hayson
    mime := acceptMimeType(req)
    filetype := Filetype.apiMime(mime, ApiVersion.v4)
    if (filetype == null || !filetype.canWrite) throw ApiErr.notAcceptableErrWriter(mime?.toStr ?: "")

    writeResGrid(result, filetype)
  }
}

